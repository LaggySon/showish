defmodule Showish.Themes.Theme do
  @moduledoc """
  A look an account made for itself: a built-in look to start from, the design
  tokens it changes, the fonts it brings and any CSS it adds on top.

  A theme belongs to the account that created or imported it. Sharing one hands
  out a copy (see `Showish.Themes.copy_shared/2`), never the original, so the
  author editing their theme can never change a broadcast somebody else has on
  air.

  `user_id` and `share_code` are set by `Showish.Themes`, never cast from
  params.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Showish.Broadcasts.Preset
  alias Showish.Themes.CustomCSS
  alias Showish.Themes.Tokens

  @type t :: %__MODULE__{}

  @font_roles ~w(text numbers)
  @font_formats ~w(woff2 woff ttf otf)
  # Per font file, before base64. A full Latin variable font fits comfortably;
  # a font with every script in it is a sign the file should be subset first.
  @max_font_bytes 600_000

  schema "themes" do
    field :name, :string
    field :base, :string, default: "broadcast"
    field :tokens, :map, default: %{}
    field :fonts, :map, default: %{}
    field :css, :string, default: ""
    field :share_code, :string

    belongs_to :user, Showish.Accounts.User
    timestamps(type: :utc_datetime_usec)
  end

  @doc "The roles a theme can bring its own font file for."
  def font_roles, do: @font_roles

  @doc "The font file formats a theme can carry."
  def font_formats, do: @font_formats

  @doc "The largest font file a theme can carry, in bytes."
  def max_font_bytes, do: @max_font_bytes

  def changeset(theme, attrs) do
    theme
    |> cast(attrs, [:name, :base, :tokens, :fonts, :css])
    |> update_change(:name, &String.trim/1)
    |> update_change(:css, &String.trim/1)
    |> validate_required([:name])
    |> validate_length(:name, max: 80)
    |> validate_inclusion(:base, Preset.keys(), message: "must be one of the built-in looks")
    |> validate_tokens()
    |> validate_fonts()
    |> validate_css()
    |> unique_constraint([:user_id, :name],
      error_key: :name,
      message: "you already have a theme with this name"
    )
    |> unique_constraint(:share_code)
  end

  defp validate_tokens(changeset) do
    case get_change(changeset, :tokens) do
      nil ->
        changeset

      tokens ->
        case Tokens.cast(tokens) do
          {:ok, clean} -> put_change(changeset, :tokens, clean)
          {:error, errors} -> Enum.reduce(errors, changeset, &add_error(&2, :tokens, &1))
        end
    end
  end

  defp validate_css(changeset) do
    validate_change(changeset, :css, fn :css, css ->
      case CustomCSS.check(css) do
        :ok -> []
        {:error, message} -> [css: message]
      end
    end)
  end

  defp validate_fonts(changeset) do
    validate_change(changeset, :fonts, fn :fonts, fonts ->
      fonts
      |> Enum.flat_map(fn {role, font} -> font_errors(to_string(role), font) end)
      |> Enum.map(&{:fonts, &1})
    end)
  end

  defp font_errors(role, _font) when role not in @font_roles,
    do: ["#{role} is not a font role (use #{Enum.join(@font_roles, " or ")})"]

  defp font_errors(role, %{"name" => name, "format" => format, "data" => data})
       when is_binary(name) and is_binary(format) and is_binary(data) do
    cond do
      not String.match?(name, ~r/^[\w .-]{1,60}$/u) ->
        ["the #{role} font name may only use letters, numbers, spaces, dots and dashes"]

      format not in @font_formats ->
        ["the #{role} font must be #{Enum.join(@font_formats, ", ")}"]

      true ->
        case Base.decode64(data) do
          {:ok, bytes} when byte_size(bytes) > @max_font_bytes ->
            ["the #{role} font is larger than #{div(@max_font_bytes, 1000)} KB"]

          {:ok, bytes} ->
            if font_file?(bytes), do: [], else: ["the #{role} font is not a font file"]

          :error ->
            ["the #{role} font data is not base64"]
        end
    end
  end

  defp font_errors(role, _font), do: ["the #{role} font needs a name, a format and its data"]

  @doc """
  Whether `bytes` start the way a WOFF2, WOFF, OpenType or TrueType file does.
  """
  def font_file?(<<"wOF2", _rest::binary>>), do: true
  def font_file?(<<"wOFF", _rest::binary>>), do: true
  def font_file?(<<"OTTO", _rest::binary>>), do: true
  def font_file?(<<0, 1, 0, 0, _rest::binary>>), do: true
  def font_file?(<<"true", _rest::binary>>), do: true
  def font_file?(_bytes), do: false
end
