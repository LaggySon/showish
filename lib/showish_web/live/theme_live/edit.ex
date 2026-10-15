defmodule ShowishWeb.ThemeLive.Edit do
  @moduledoc """
  The theme editor.

  Laid out like the control room: the fields on the left save as you type, and
  the preview on the right is a real scene of one of the account's shows, drawn
  in this theme through a signed preview parameter. The show itself is not
  touched, so a theme can be built while that show is on air in another look.
  """

  use ShowishWeb, :live_view

  import ShowishWeb.ShowLive.Components, only: [collapsible_panel: 1, save_state: 1]

  alias Showish.Broadcasts
  alias Showish.Broadcasts.Preset
  alias Showish.Themes
  alias Showish.Themes.CustomCSS
  alias Showish.Themes.Theme
  alias Showish.Themes.Tokens
  alias ShowishWeb.Scenes
  alias ShowishWeb.ThemePreview

  # A starting point for a color token the theme has not set yet. Picked to be
  # visible, not to match any base look: the operator is about to change it.
  @color_starts %{
    "panel_color" => "#0a0a0a",
    "border_color" => "#ffffff",
    "text_color" => "#f8fafc"
  }

  @enum_labels %{
    "system" => "System",
    "geist" => "Geist",
    "heebo" => "Heebo",
    "oswald" => "Oswald",
    "geist-mono" => "Geist Mono",
    "custom" => "Custom (uploaded)",
    "same" => "Same as the font",
    "none" => "None",
    "soft" => "Soft",
    "hard" => "Hard",
    "slide" => "Slide (the base look's own)",
    "fade" => "Fade",
    "slate" => "Slate (blue)",
    "gray" => "Gray (cool)",
    "zinc" => "Zinc",
    "neutral" => "Neutral",
    "stone" => "Stone (warm)"
  }

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope
    theme = Themes.get_theme!(scope, id)
    shows = Broadcasts.list_shows(scope)

    socket =
      socket
      |> assign(:page_title, "#{theme.name} · Themes")
      |> assign(:shows, shows)
      |> assign(:saved_at, nil)
      |> assign(:save_failed, false)
      |> assign(:font_error, nil)
      # Signed once: a token carries its signing time, so signing on every
      # render would change the preview URL and reload the frame each second.
      |> assign(:preview_token, ThemePreview.sign(theme))
      |> assign_theme(theme)

    socket =
      Enum.reduce(Theme.font_roles(), socket, fn role, socket ->
        allow_upload(socket, upload_name(role),
          accept: Enum.map(Theme.font_formats(), &".#{&1}"),
          max_entries: 1,
          max_file_size: Theme.max_font_bytes(),
          auto_upload: true,
          progress: &handle_progress/3
        )
      end)

    {:ok, socket}
  end

  # Which show and scene the preview draws live in the URL, so a refresh keeps
  # them (DESIGN.md section 12.2).
  @impl true
  def handle_params(params, _uri, socket) do
    shows = socket.assigns.shows
    show = Enum.find(shows, List.first(shows), &(&1.slug == params["show"]))

    scene =
      if show do
        available = Scenes.for_sport(show.sport)
        Enum.find(available, hd(available), &(&1.key == params["scene"]))
      end

    {:noreply, assign(socket, preview_show: show, preview_scene: scene)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} section="themes">
      <.header>
        {@theme.name}
        <:aside>
          <span class="ui-muted">Built on {Preset.fetch(@theme.base).name}</span>
          <.button href={~p"/themes/#{@theme.id}/download"} size="small" variant="quiet">
            Download file
          </.button>
        </:aside>
      </.header>

      <nav class="ui-subnav" aria-label="Themes">
        <.link navigate={~p"/themes"} class="ui-chip">← All themes</.link>
      </nav>

      <div id="theme-editor" class="app-control-room">
        <div class="app-control-preview">
          <.theme_preview
            theme={@theme}
            token={@preview_token}
            shows={@shows}
            show={@preview_show}
            scene={@preview_scene}
          />
        </div>

        <div class="app-control-edit">
          <.form
            for={@form}
            id="theme-form"
            class="app-control-form"
            phx-change="save"
            phx-submit="save"
          >
            <div
              :if={@save_failed}
              id="theme-save-failed"
              class="ui-notice"
              data-status="failure"
              role="alert"
            >
              Not saved. Fix the fields with an error below; overlays keep the last saved version.
            </div>

            <.collapsible_panel id="theme-basics-panel" title="Theme" open>
              <:aside>
                <.save_state id="saved-theme" saved_at={@saved_at} failed={@save_failed} />
              </:aside>
              <div class="app-fields">
                <.input field={@form[:name]} label="Name" required prose phx-debounce="500" />
                <.input
                  field={@form[:base]}
                  type="select"
                  label="Built on"
                  options={Preset.options()}
                  hint="Every scene keeps this look's layout. The settings below change how it is drawn."
                />
              </div>
            </.collapsible_panel>

            <.collapsible_panel id="theme-tokens-panel" title="Design" open>
              <:aside>{token_count(@theme)}</:aside>
              <p class="ui-hint app-block-hint">
                Anything left blank keeps {Preset.fetch(@theme.base).name}'s own value.
              </p>
              <div
                :if={token_errors(@form) != []}
                id="token-errors"
                class="ui-notice"
                data-status="failure"
              >
                {Enum.join(token_errors(@form), " · ")}
              </div>
              <div class="app-fields">
                <.token_field
                  :for={token <- Tokens.all()}
                  token={token}
                  value={@token_values[token.key]}
                  base={Preset.fetch(@theme.base).name}
                />
              </div>
            </.collapsible_panel>

            <.collapsible_panel id="theme-css-panel" title="Custom CSS">
              <:aside>{css_summary(@theme)}</:aside>
              <div class="app-fields">
                <.input
                  field={@form[:css]}
                  type="textarea"
                  rows="12"
                  label="CSS"
                  spellcheck="false"
                  phx-debounce="800"
                  class="app-field-full"
                  placeholder=".overlay-panel { border-radius: 0; }"
                  hint={"Loaded after everything else, on this theme's overlays only. No @import and no url() except data: URLs. Up to #{div(CustomCSS.max_bytes(), 1000)} KB."}
                />
              </div>
              <p class="ui-hint app-block-hint">
                The classes worth targeting are listed in the overlay guide under "Reaching what tokens cannot".
              </p>
            </.collapsible_panel>
          </.form>

          <.collapsible_panel id="theme-fonts-panel" title="Fonts" open={@theme.fonts != %{}}>
            <:aside>{font_summary(@theme)}</:aside>
            <p class="ui-hint app-block-hint">
              A font file travels inside the theme, so overlays never fetch it from anywhere else.
              WOFF2, WOFF, TTF or OTF, up to {div(Theme.max_font_bytes(), 1000)} KB.
              Pick it under Design with Font: Custom.
            </p>
            <div
              :if={@font_error}
              id="font-error"
              class="ui-notice"
              data-status="failure"
              role="alert"
            >
              {@font_error}
            </div>
            <div class="app-theme-fonts">
              <.font_slot
                :for={role <- Theme.font_roles()}
                role={role}
                font={@theme.fonts[role]}
                upload={@uploads[upload_name(role)]}
              />
            </div>
          </.collapsible_panel>

          <.collapsible_panel id="theme-share-panel" title="Share">
            <p class="ui-hint app-block-hint">
              Anyone signed in with this link can add a copy of the theme to their own account.
              Their copy does not follow your later edits.
            </p>
            <div class="app-url-row">
              <code class="ui-pre ui-truncate" title={share_url(@theme)}>{share_url(@theme)}</code>
              <button
                type="button"
                id="copy-share-link"
                phx-hook="ClipboardCopy"
                data-clipboard-text={share_url(@theme)}
                class="ui-button ui-button--ghost ui-button--small"
              >
                Copy
              </button>
            </div>
            <div class="ui-button-group app-form-actions">
              <.button href={~p"/themes/#{@theme.id}/download"} size="small">
                Download file
              </.button>
              <.button
                type="button"
                size="small"
                variant="quiet"
                phx-click="reset_share_code"
                data-confirm="Reset the share link?"
                data-confirm-body="The current link stops working. Copies already made are not affected."
                data-confirm-action="Reset link"
              >
                Reset link
              </.button>
            </div>
          </.collapsible_panel>

          <.collapsible_panel id="theme-delete-panel" title="Delete">
            <p class="ui-hint app-block-hint">
              Shows drawn in this theme go back to {Preset.fetch(@theme.base).name}, on air, at once.
            </p>
            <.button
              type="button"
              variant="danger"
              phx-click="delete"
              data-confirm={"Delete #{@theme.name}?"}
              data-confirm-body="This cannot be undone. Download the file first to keep a copy."
              data-confirm-action="Delete theme"
            >
              Delete theme
            </.button>
          </.collapsible_panel>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :token, :map, required: true
  attr :value, :any, required: true
  attr :base, :string, required: true

  # A token the theme has not set has no value at all, which a color input
  # cannot show (it always holds some color). So an unset color is a "Set"
  # button, and a set one carries a "Clear" button to hand it back to the base.
  defp token_field(%{token: %{type: :color}} = assigns) do
    ~H"""
    <div class="ui-field">
      <span class="ui-field-label" id={"token-#{@token.key}-label"}>{@token.label}</span>
      <div :if={@value} class="app-color">
        <input
          type="color"
          id={"token-#{@token.key}"}
          name={"theme[tokens][#{@token.key}]"}
          value={@value}
          class="app-color-input"
          aria-labelledby={"token-#{@token.key}-label"}
          phx-debounce="250"
        />
        <span class="ui-mono">{String.upcase(@value)}</span>
        <.button
          type="button"
          size="small"
          variant="ghost"
          phx-click="clear_token"
          phx-value-key={@token.key}
        >
          Clear
        </.button>
      </div>
      <div :if={!@value} class="app-color">
        <span class="ui-muted">From {@base}</span>
        <.button
          type="button"
          size="small"
          variant="ghost"
          id={"token-#{@token.key}"}
          phx-click="set_token"
          phx-value-key={@token.key}
        >
          Set
        </.button>
      </div>
      <span class="ui-hint">{@token.hint}</span>
    </div>
    """
  end

  defp token_field(%{token: %{type: {:enum, options}}} = assigns) do
    assigns = assign(assigns, :options, Enum.map(options, &{enum_label(&1), &1}))

    ~H"""
    <.input
      id={"token-#{@token.key}"}
      name={"theme[tokens][#{@token.key}]"}
      value={@value}
      type="select"
      label={@token.label}
      prompt={"From #{@base}"}
      options={@options}
      hint={@token.hint}
    />
    """
  end

  defp token_field(%{token: %{type: {kind, min, max}}} = assigns) do
    assigns =
      assign(assigns, min: min, max: max, step: if(kind == :number, do: "0.05", else: "1"))

    ~H"""
    <.input
      id={"token-#{@token.key}"}
      name={"theme[tokens][#{@token.key}]"}
      value={@value}
      type="number"
      label={@token.label}
      min={@min}
      max={@max}
      step={@step}
      placeholder={"From #{@base}"}
      hint={@token.hint}
      phx-debounce="400"
    />
    """
  end

  attr :role, :string, required: true
  attr :font, :map, default: nil
  attr :upload, :any, required: true

  defp font_slot(assigns) do
    ~H"""
    <div class="app-theme-font" id={"font-#{@role}"}>
      <span class="ui-field-label">{font_role_label(@role)}</span>
      <div :if={@font} class="app-theme-font-file">
        <span class="ui-truncate">{@font["name"]}</span>
        <span class="ui-mono ui-muted">{@font["format"]} · {font_size(@font)}</span>
      </div>
      <span :if={!@font} class="ui-muted">None</span>
      <form id={"font-#{@role}-form"} phx-change="validate_font" class="ui-button-group">
        <label class="ui-button ui-button--small" for={@upload.ref}>
          {if @font, do: "Replace…", else: "Upload…"}
        </label>
        <.live_file_input upload={@upload} class="ui-sr-only" />
        <.button
          :if={@font}
          type="button"
          size="small"
          variant="ghost"
          phx-click="remove_font"
          phx-value-role={@role}
        >
          Remove
        </.button>
      </form>
      <progress
        :for={entry <- @upload.entries}
        :if={!entry.done?}
        class="ui-progress"
        value={entry.progress}
        max="100"
      >
        {entry.progress}%
      </progress>
    </div>
    """
  end

  attr :theme, :any, required: true
  attr :token, :string, required: true
  attr :shows, :list, required: true
  attr :show, :any, required: true
  attr :scene, :any, required: true

  defp theme_preview(assigns) do
    ~H"""
    <.collapsible_panel id="theme-preview-panel" title="Preview" open>
      <:aside :if={@show}>{@scene.name} · 1920×1080</:aside>
      <div :if={@show == nil} id="theme-preview-empty" class="ui-empty">
        No shows yet. Create a show to preview this theme on its scenes.
        <.button navigate={~p"/shows/new"} variant="primary">+ New show</.button>
      </div>
      <%= if @show do %>
        <form id="theme-preview-form" phx-change="preview" class="app-preview-picker">
          <label class="ui-field ui-field--inline">
            <span class="ui-field-label">Show</span>
            <select name="show" class="ui-select ui-input--compact">
              {Phoenix.HTML.Form.options_for_select(
                Enum.map(@shows, &{&1.title, &1.slug}),
                @show.slug
              )}
            </select>
          </label>
          <label class="ui-field ui-field--inline">
            <span class="ui-field-label">Scene</span>
            <select name="scene" class="ui-select ui-input--compact">
              {Phoenix.HTML.Form.options_for_select(
                Enum.map(Scenes.for_sport(@show.sport), &{&1.name, &1.key}),
                @scene.key
              )}
            </select>
          </label>
        </form>
        <div class="ui-preview ui-checker" style="--preview-ratio: 16 / 9">
          <iframe
            id={"theme-preview-#{@show.slug}-#{@scene.key}"}
            src={preview_path(@show, @scene, @token)}
            title={"#{@scene.name} preview in #{@theme.name}"}
          >
          </iframe>
        </div>
        <p class="ui-hint app-after-fields">
          The preview follows every save. {@show.title} itself keeps its own look.
        </p>
      <% end %>
    </.collapsible_panel>
    """
  end

  @impl true
  def handle_event("save", %{"theme" => params}, socket) do
    params = Map.put_new(params, "tokens", %{})

    case Themes.update_theme(socket.assigns.current_scope, socket.assigns.theme, params) do
      {:ok, theme} ->
        {:noreply,
         socket
         |> assign(saved_at: DateTime.utc_now(), save_failed: false)
         |> assign_theme(theme)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:save_failed, true)
         |> assign(:token_values, params["tokens"])
         |> assign(:form, to_form(changeset, action: :validate))}
    end
  end

  def handle_event("set_token", %{"key" => key}, socket) do
    put_token(socket, key, Map.get(@color_starts, key, "#ffffff"))
  end

  def handle_event("clear_token", %{"key" => key}, socket) do
    tokens = Map.delete(socket.assigns.theme.tokens, key)
    save(socket, %{"tokens" => tokens})
  end

  def handle_event("validate_font", _params, socket) do
    {:noreply, assign(socket, :font_error, upload_error(socket))}
  end

  def handle_event("remove_font", %{"role" => role}, socket) do
    save(socket, %{"fonts" => Map.delete(socket.assigns.theme.fonts, role)})
  end

  def handle_event("preview", params, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/themes/#{socket.assigns.theme.id}?#{Map.take(params, ["show", "scene"])}"
     )}
  end

  def handle_event("reset_share_code", _params, socket) do
    {:ok, theme} = Themes.reset_share_code(socket.assigns.current_scope, socket.assigns.theme)

    {:noreply,
     socket
     |> put_flash(:info, "Share link reset. The old one no longer works.")
     |> assign_theme(theme)}
  end

  def handle_event("delete", _params, socket) do
    {:ok, theme} = Themes.delete_theme(socket.assigns.current_scope, socket.assigns.theme)

    {:noreply,
     socket
     |> put_flash(:info, "Deleted #{theme.name}.")
     |> push_navigate(to: ~p"/themes")}
  end

  # A font is stored the moment it finishes uploading, and picked straight away
  # if the theme was not using a font of its own yet: an upload is a decision.
  defp handle_progress(name, entry, socket) do
    if entry.done? do
      role = role_for(name)

      bytes =
        consume_uploaded_entry(socket, entry, fn %{path: path} -> {:ok, File.read!(path)} end)

      font = %{
        "name" => font_name(entry.client_name),
        "format" =>
          entry.client_name |> Path.extname() |> String.trim_leading(".") |> String.downcase(),
        "data" => Base.encode64(bytes)
      }

      theme = socket.assigns.theme
      token = if role == "text", do: "font", else: "numbers_font"

      tokens =
        if Map.get(theme.tokens, token) in [nil, "same"],
          do: Map.put(theme.tokens, token, "custom"),
          else: theme.tokens

      save(assign(socket, :font_error, nil), %{
        "fonts" => Map.put(theme.fonts, role, font),
        "tokens" => tokens
      })
    else
      {:noreply, socket}
    end
  end

  defp put_token(socket, key, value) do
    save(socket, %{"tokens" => Map.put(socket.assigns.theme.tokens, key, value)})
  end

  # Saves a change that did not come from the form itself (a button, an
  # upload), with the same feedback as typing in a field.
  defp save(socket, attrs) do
    case Themes.update_theme(socket.assigns.current_scope, socket.assigns.theme, attrs) do
      {:ok, theme} ->
        {:noreply,
         socket
         |> assign(saved_at: DateTime.utc_now(), save_failed: false)
         |> assign_theme(theme)}

      {:error, changeset} ->
        message =
          changeset
          |> Ecto.Changeset.traverse_errors(&ShowishWeb.CoreComponents.translate_error/1)
          |> Enum.flat_map(fn {_field, messages} -> messages end)
          |> Enum.join(" · ")

        {:noreply, assign(socket, :font_error, message)}
    end
  end

  defp assign_theme(socket, %Theme{} = theme) do
    socket
    |> assign(:theme, theme)
    |> assign(:token_values, theme.tokens)
    |> assign(:form, to_form(Themes.change_theme(theme)))
  end

  defp upload_error(socket) do
    Theme.font_roles()
    |> Enum.flat_map(fn role ->
      upload = socket.assigns.uploads[upload_name(role)]
      Enum.flat_map(upload.entries, &upload_errors(upload, &1)) ++ upload_errors(upload)
    end)
    |> case do
      [:too_large | _] -> "The font is larger than #{div(Theme.max_font_bytes(), 1000)} KB."
      [:not_accepted | _] -> "Fonts must be WOFF2, WOFF, TTF or OTF."
      [_ | _] -> "The font could not be uploaded."
      [] -> nil
    end
  end

  defp upload_name("text"), do: :text_font
  defp upload_name("numbers"), do: :numbers_font

  defp role_for(:text_font), do: "text"
  defp role_for(:numbers_font), do: "numbers"

  defp font_role_label("text"), do: "Font"
  defp font_role_label("numbers"), do: "Numbers font"

  # The name a person sees for the font, from its file name; the family it is
  # declared under in CSS is made up separately (Showish.Themes).
  defp font_name(file_name) do
    file_name
    |> Path.rootname()
    |> String.replace(~r/[^\w .-]+/u, " ")
    |> String.trim()
    |> String.slice(0, 60)
    |> then(&if(&1 == "", do: "Font", else: &1))
  end

  defp font_size(%{"data" => data}) do
    kb = (byte_size(data) * 3 / 4 / 1000) |> round()
    "#{kb} KB"
  end

  defp token_errors(form) do
    form.errors |> Keyword.get_values(:tokens) |> Enum.map(fn {message, _} -> message end)
  end

  defp token_count(%Theme{tokens: tokens}) do
    case map_size(tokens) do
      0 -> "Nothing changed yet"
      1 -> "1 setting changed"
      n -> "#{n} settings changed"
    end
  end

  defp css_summary(%Theme{css: ""}), do: "None"

  defp css_summary(%Theme{css: css}) do
    case css |> String.split("\n") |> length() do
      1 -> "1 line"
      n -> "#{n} lines"
    end
  end

  defp font_summary(%Theme{fonts: fonts}) when map_size(fonts) == 0, do: "None"

  defp font_summary(%Theme{fonts: fonts}),
    do: fonts |> Map.values() |> Enum.map_join(" · ", & &1["name"])

  defp enum_label(value), do: Map.get(@enum_labels, value, value)

  defp share_url(%Theme{share_code: code}), do: url(~p"/themes/shared/#{code}")

  defp preview_path(show, scene, token) do
    Scenes.path(show.slug, scene.key) <> "?" <> URI.encode_query(theme_preview: token)
  end
end
