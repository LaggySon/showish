defmodule ShowishWeb.ThemeLive.Index do
  @moduledoc """
  The account's own themes: looks made in the app, uploaded as a file, or
  copied from a share link, ready to pick from any show's Look menu.
  """

  use ShowishWeb, :live_view

  alias Showish.Broadcasts.Preset
  alias Showish.Themes
  alias Showish.Themes.Theme

  # A theme file carries its fonts inside it, so it can be a few hundred KB.
  @max_file_bytes 3_000_000

  @impl true
  def mount(_params, _session, socket) do
    themes = Themes.list_themes(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "Themes")
     |> assign(:theme_count, length(themes))
     |> assign(:import_error, nil)
     |> assign(:form, new_form(socket))
     |> stream(:themes, themes)
     |> allow_upload(:theme_file,
       accept: ~w(.json .css),
       max_entries: 1,
       max_file_size: @max_file_bytes,
       auto_upload: true,
       progress: &handle_progress/3
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} section="themes">
      <.header>
        Themes
        <:aside>
          <span class="ui-mono">{count(@theme_count)}</span>
          <.button id="download-template" href={~p"/theme-template.css"} variant="quiet">
            Download template
          </.button>
          <form id="import-theme-form" phx-change="validate_import" class="app-import">
            <label class="ui-button" for={@uploads.theme_file.ref}>Import file…</label>
            <.live_file_input upload={@uploads.theme_file} class="ui-sr-only" />
          </form>
          <.button
            :if={@live_action != :new}
            id="new-theme"
            patch={~p"/themes/new"}
            variant="primary"
          >
            + New theme
          </.button>
        </:aside>
      </.header>

      <div
        :if={import_error(@uploads.theme_file, @import_error)}
        id="import-failed"
        class="ui-notice app-block"
        data-status="failure"
        role="alert"
      >
        Import failed. {import_error(@uploads.theme_file, @import_error)}
      </div>

      <.panel
        :if={@live_action == :new}
        id="new-theme-panel"
        title="New theme"
        class="app-block app-narrow"
      >
        <.form for={@form} id="new-theme-form" phx-change="validate" phx-submit="create">
          <div class="app-fields">
            <.input
              field={@form[:name]}
              label="Name"
              placeholder="Acme Esports"
              required
              prose
              phx-mounted={JS.focus()}
            />
            <.input
              field={@form[:base]}
              type="select"
              label="Built on"
              options={Preset.options()}
              hint="The look the theme starts from. Every scene keeps that look's layout."
            />
          </div>
          <div class="ui-button-group app-form-actions">
            <.button variant="primary" phx-disable-with="Creating…">Create theme</.button>
            <.button patch={~p"/themes"} variant="ghost">Cancel</.button>
          </div>
        </.form>
      </.panel>

      <div :if={@theme_count == 0} id="themes-empty" class="ui-empty">
        No themes yet. Create a theme to give your overlays your own colors, fonts and corners,
        import a theme file someone shared with you, or download the template, edit it and
        import it.
        <.button :if={@live_action != :new} patch={~p"/themes/new"} variant="primary">
          + New theme
        </.button>
      </div>

      <.table :if={@theme_count > 0} id="themes" rows={@streams.themes}>
        <:col :let={{_id, theme}} label="Theme">
          <.link
            navigate={~p"/themes/#{theme.id}"}
            class="ui-quiet-link ui-row-name ui-truncate"
            title={theme.name}
          >
            {theme.name}
          </.link>
        </:col>
        <:col :let={{_id, theme}} label="Built on">{Preset.fetch(theme.base).name}</:col>
        <:col :let={{_id, theme}} label="Tokens" class="ui-cell-num app-wide-only">
          {map_size(theme.tokens)}
        </:col>
        <:col :let={{_id, theme}} label="Fonts" class="app-wide-only">
          {font_names(theme)}
        </:col>
        <:col :let={{_id, theme}} label="Custom CSS" class="app-wide-only">
          {if theme.css == "", do: "—", else: lines(theme.css)}
        </:col>
        <:col :let={{_id, theme}} label="Updated (UTC)" class="ui-cell-mono app-wide-only">
          {Calendar.strftime(theme.updated_at, "%Y-%m-%d %H:%M")}
        </:col>
        <:action :let={{_id, theme}}>
          <.button navigate={~p"/themes/#{theme.id}"} size="small">Edit</.button>
          <.button href={~p"/themes/#{theme.id}/download"} size="small" variant="quiet">
            Download
          </.button>
        </:action>
        <:action :let={{_id, theme}}>
          <.button
            type="button"
            size="small"
            variant="danger"
            phx-click="delete"
            phx-value-id={theme.id}
            data-confirm={"Delete #{theme.name}?"}
            data-confirm-body="Shows drawn in it go back to the look it was built on, on air, at once. This cannot be undone."
            data-confirm-action="Delete theme"
          >
            Delete
          </.button>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"theme" => params}, socket) do
    form = socket |> blank_theme() |> Themes.change_theme(params) |> to_form(action: :validate)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("create", %{"theme" => params}, socket) do
    case Themes.create_theme(socket.assigns.current_scope, params) do
      {:ok, theme} ->
        {:noreply, push_navigate(socket, to: ~p"/themes/#{theme.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
    end
  end

  def handle_event("validate_import", _params, socket) do
    {:noreply, assign(socket, :import_error, nil)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    theme = Themes.get_theme!(scope, id)
    {:ok, _theme} = Themes.delete_theme(scope, theme)

    {:noreply,
     socket
     |> put_flash(:info, "Deleted #{theme.name}.")
     |> update(:theme_count, &(&1 - 1))
     |> stream_delete(:themes, theme)}
  end

  # The file is read the moment it finishes uploading: there is nothing else to
  # fill in, so a separate "Import" button would only be one more click.
  defp handle_progress(:theme_file, entry, socket) do
    if entry.done? do
      contents =
        consume_uploaded_entry(socket, entry, fn %{path: path} -> {:ok, File.read!(path)} end)

      scope = socket.assigns.current_scope

      result =
        if String.downcase(Path.extname(entry.client_name)) == ".css",
          do: Themes.import_css(scope, entry.client_name, contents),
          else: Themes.import_file(scope, contents)

      case result do
        {:ok, theme} ->
          {:noreply,
           socket
           |> put_flash(:info, "Imported #{theme.name}.")
           |> push_navigate(to: ~p"/themes/#{theme.id}")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, :import_error, changeset_message(changeset))}

        {:error, message} ->
          {:noreply, assign(socket, :import_error, message)}
      end
    else
      {:noreply, socket}
    end
  end

  defp import_error(upload, error) do
    upload_errors =
      Enum.flat_map(upload.entries, &upload_errors(upload, &1)) ++ upload_errors(upload)

    case upload_errors do
      [:too_large | _] -> "The file is larger than #{div(@max_file_bytes, 1_000_000)} MB."
      [:not_accepted | _] -> "Import a theme file (.json) or a CSS file (.css)."
      [_ | _] -> "The file could not be uploaded."
      [] -> error
    end
  end

  # Every problem the file has, so a hand-edited theme can be fixed in one pass.
  defp changeset_message(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(&ShowishWeb.CoreComponents.translate_error/1)
    |> Enum.flat_map(fn {field, messages} -> Enum.map(messages, &"#{field}: #{&1}") end)
    |> Enum.join(" · ")
  end

  defp new_form(socket), do: socket |> blank_theme() |> Themes.change_theme() |> to_form()

  defp blank_theme(socket), do: %Theme{user_id: socket.assigns.current_scope.user.id}

  defp font_names(%Theme{fonts: fonts}) when map_size(fonts) == 0, do: "—"

  defp font_names(%Theme{fonts: fonts}),
    do: fonts |> Map.values() |> Enum.map_join(" · ", & &1["name"])

  defp lines(css) do
    case css |> String.split("\n") |> length() do
      1 -> "1 line"
      n -> "#{n} lines"
    end
  end

  defp count(1), do: "1 theme"
  defp count(n), do: "#{n} themes"
end
