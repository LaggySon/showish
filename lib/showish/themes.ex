defmodule Showish.Themes do
  @moduledoc """
  Themes: looks an account builds for itself, without touching the code.

  A theme starts from one of the built-in looks (`Showish.Broadcasts.Preset`)
  and changes it with design tokens, its own font files and, if it needs to,
  its own CSS. It is saved to the account, applied to a show from the control
  room's *Look* menu, and moves between accounts two ways:

    * as a file, which `export/1` writes and `import_file/2` reads; and
    * as a share link, whose code `copy_shared/2` turns into a copy in the
      reader's own account.

  Both give the receiver their own copy. A theme on air only ever changes when
  the account that owns the show changes it.

  ## Who can see what

  Like shows, themes are read and written through the owner's scope. The two
  unscoped reads are `get_theme/1`, for the stylesheet an overlay loads (an
  overlay is public, so its stylesheet is too), and `get_shared/1`, which finds
  a theme by the code its owner chose to hand out.
  """

  import Ecto.Query, warn: false

  alias Showish.Accounts.Scope
  alias Showish.Accounts.User
  alias Showish.Broadcasts
  alias Showish.Broadcasts.Show
  alias Showish.Repo
  alias Showish.Themes.Theme
  alias Showish.Themes.Tokens

  @pubsub Showish.PubSub

  # The first line of every theme file, so an upload can be told apart from any
  # other JSON at a glance, and so a later format can be told apart from this one.
  @format "showish-theme"
  @format_version 1

  ## Reading

  @doc "The scope's own themes, by name."
  def list_themes(%Scope{user: %User{id: user_id}}) do
    Theme
    |> where(user_id: ^user_id)
    |> order_by(asc: :name)
    |> Repo.all()
  end

  @doc "One of the scope's themes, raising if it is somebody else's or missing."
  def get_theme!(%Scope{user: %User{id: user_id}}, id) do
    Repo.get_by!(Theme, id: id, user_id: user_id)
  end

  @doc "One of the scope's themes, or `nil`."
  def get_own_theme(%Scope{user: %User{id: user_id}}, id) do
    case Integer.parse(to_string(id)) do
      {id, ""} -> Repo.get_by(Theme, id: id, user_id: user_id)
      _ -> nil
    end
  end

  @doc """
  Any theme by id, with no owner check. For the stylesheet an overlay loads only;
  see "Who can see what" above.
  """
  def get_theme(id), do: Repo.get(Theme, id)

  @doc "The theme a share code was handed out for, or `nil`."
  def get_shared(code) when is_binary(code) do
    Theme |> Repo.get_by(share_code: code) |> Repo.preload(:user)
  end

  ## Writing

  @doc "Creates a theme owned by the scope's user."
  def create_theme(%Scope{user: %User{id: user_id}}, attrs) do
    %Theme{user_id: user_id, share_code: new_share_code()}
    |> Theme.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates one of the scope's themes, and redraws every overlay drawn in it.
  """
  def update_theme(%Scope{} = scope, %Theme{} = theme, attrs) do
    theme
    |> owned!(scope)
    |> Theme.changeset(attrs)
    |> Repo.update()
    |> tap(fn
      {:ok, theme} -> redraw(theme)
      _error -> :ok
    end)
  end

  @doc """
  Deletes one of the scope's themes. Shows drawn in it go back to the look the
  theme was built on, the moment it goes.
  """
  def delete_theme(%Scope{} = scope, %Theme{} = theme) do
    theme = owned!(theme, scope)
    shows = shows_using(theme)

    with {:ok, theme} <- Repo.delete(theme) do
      Enum.each(shows, fn show ->
        show |> Broadcasts.reload() |> Broadcasts.broadcast_show()
      end)

      {:ok, theme}
    end
  end

  @doc "A changeset for the theme editor."
  def change_theme(%Theme{} = theme, attrs \\ %{}), do: Theme.changeset(theme, attrs)

  @doc "Issues a new share code, so links handed out before stop working."
  def reset_share_code(%Scope{} = scope, %Theme{} = theme) do
    theme
    |> owned!(scope)
    |> Ecto.Changeset.change(share_code: new_share_code())
    |> Repo.update()
  end

  @doc """
  Copies a shared theme into the scope's account and returns the copy.

  The copy is the reader's own from then on: it does not follow the original.
  """
  def copy_shared(%Scope{} = scope, code) when is_binary(code) do
    case get_shared(code) do
      nil -> {:error, :not_found}
      %Theme{} = theme -> create_theme(scope, portable(scope, theme))
    end
  end

  ## Theme files

  @doc """
  The theme as a file someone else can import: JSON, with its fonts inside.
  """
  def export(%Theme{} = theme) do
    theme |> portable() |> Jason.encode!(pretty: true)
  end

  @doc "A file name for an exported theme."
  def export_filename(%Theme{name: name}) do
    slug = name |> Show.slugify() |> then(&if(&1 == "", do: "theme", else: &1))
    "#{slug}.showish-theme.json"
  end

  @doc """
  Reads a theme file into the scope's account.

  A name the account already uses gets a number on the end rather than
  overwriting anything.
  """
  def import_file(%Scope{} = scope, contents) when is_binary(contents) do
    with {:ok, decoded} <- decode(contents),
         {:ok, attrs} <- from_file(decoded) do
      create_theme(scope, Map.put(attrs, "name", free_name(scope, attrs["name"])))
    end
  end

  defp decode(contents) do
    case Jason.decode(contents) do
      {:ok, %{} = decoded} -> {:ok, decoded}
      _ -> {:error, "This is not a theme file: it is not valid JSON."}
    end
  end

  defp from_file(%{"format" => @format, "version" => @format_version} = file) do
    {:ok, Map.take(file, ~w(name base tokens fonts css))}
  end

  defp from_file(%{"format" => @format, "version" => version}),
    do: {:error, "This theme file is version #{version}; this Showish reads version 1."}

  defp from_file(_file),
    do: {:error, ~s(This is not a theme file: it has no "format": "#{@format}".)}

  defp portable(%Theme{} = theme) do
    %{
      "format" => @format,
      "version" => @format_version,
      "name" => theme.name,
      "base" => theme.base,
      "tokens" => theme.tokens,
      "fonts" => theme.fonts,
      "css" => theme.css
    }
  end

  defp portable(scope, %Theme{} = theme) do
    theme |> portable() |> Map.put("name", free_name(scope, theme.name))
  end

  # "Acme", then "Acme (2)", "Acme (3)": an import never replaces a theme.
  defp free_name(scope, name) do
    name = String.trim(to_string(name || ""))
    taken = scope |> list_themes() |> MapSet.new(& &1.name)

    if name == "" or not MapSet.member?(taken, name) do
      name
    else
      Stream.iterate(2, &(&1 + 1))
      |> Stream.map(&"#{name} (#{&1})")
      |> Enum.find(&(not MapSet.member?(taken, &1)))
    end
  end

  ## The stylesheet

  @doc """
  The class a themed stage carries, and that every rule of its stylesheet is
  scoped to.
  """
  def stage_class(%Theme{id: id}), do: "theme-#{id}"

  @doc """
  Changes whenever the theme does, so the stylesheet URL can be cached forever.
  """
  def version(%Theme{updated_at: updated_at}),
    do: updated_at |> DateTime.to_unix(:microsecond) |> Integer.to_string(36)

  @doc """
  The whole stylesheet for a theme: its fonts, its tokens, then its own CSS.

  It loads outside the cascade layers the built-in looks live in, so every rule
  here wins over the base look's without needing to out-specify it.
  """
  def stylesheet(%Theme{} = theme) do
    selector = ".overlay-stage.#{stage_class(theme)}"
    families = font_families(theme)

    [
      "/* #{String.replace(theme.name, "*/", "")} — a Showish theme on #{theme.base} */\n",
      font_faces(theme, families),
      Tokens.to_css(theme.tokens, selector, families),
      custom_css(theme)
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  # Family names are made up here rather than taken from the file, so two
  # themes' fonts can never collide, and a name in a file can never be used to
  # write anything but a name.
  defp font_families(%Theme{fonts: fonts} = theme) do
    Map.new(fonts, fn {role, _font} -> {role, "#{stage_class(theme)}-#{role}"} end)
  end

  defp font_faces(%Theme{fonts: fonts}, families) do
    Enum.map_join(fonts, "\n", fn {role, %{"format" => format, "data" => data}} ->
      """
      @font-face {
        font-family: "#{families[role]}";
        src: url(data:#{mime(format)};base64,#{data}) format("#{css_format(format)}");
        font-weight: 100 900;
        font-display: block;
      }
      """
    end)
  end

  defp mime("woff2"), do: "font/woff2"
  defp mime("woff"), do: "font/woff"
  defp mime("ttf"), do: "font/ttf"
  defp mime("otf"), do: "font/otf"

  defp css_format("ttf"), do: "truetype"
  defp css_format("otf"), do: "opentype"
  defp css_format(format), do: format

  defp custom_css(%Theme{css: ""}), do: ""
  defp custom_css(%Theme{css: css}), do: "/* The theme's own CSS */\n#{css}\n"

  ## Live updates

  @doc "Subscribes to edits of one theme, for the editor's live preview."
  def subscribe(%Theme{id: id}), do: Phoenix.PubSub.subscribe(@pubsub, topic(id))

  defp topic(id), do: "theme:#{id}"

  defp redraw(%Theme{} = theme) do
    Phoenix.PubSub.broadcast(@pubsub, topic(theme.id), {:theme_updated, theme})

    theme
    |> shows_using()
    |> Enum.each(fn show -> show |> Broadcasts.reload() |> Broadcasts.broadcast_show() end)
  end

  defp shows_using(%Theme{id: id}), do: Show |> where(theme_id: ^id) |> Repo.all()

  defp owned!(%Theme{user_id: user_id} = theme, %Scope{user: %User{id: user_id}}), do: theme

  defp owned!(%Theme{}, %Scope{}),
    do: raise(Ecto.NoResultsError, queryable: Theme)

  defp new_share_code do
    16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end
end
