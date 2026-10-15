defmodule ShowishWeb.ThemeLive.Shared do
  @moduledoc """
  Where a theme's share link lands: what the theme is and who shared it, and
  one button that copies it into the reader's own account.
  """

  use ShowishWeb, :live_view

  alias Showish.Accounts.User
  alias Showish.Broadcasts.Preset
  alias Showish.Themes
  alias Showish.Themes.Theme

  @impl true
  def mount(%{"code" => code}, _session, socket) do
    theme = Themes.get_shared(code)

    {:ok,
     socket
     |> assign(:page_title, if(theme, do: "#{theme.name} · Shared theme", else: "Shared theme"))
     |> assign(:code, code)
     |> assign(:theme, theme)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} section="themes">
      <.header>Shared theme</.header>

      <div :if={@theme == nil} id="shared-theme-missing" class="ui-empty">
        Theme link not found. Its owner may have reset it; ask them for the new one.
        <.button navigate={~p"/themes"}>Your themes</.button>
      </div>

      <.panel :if={@theme} id="shared-theme" title={@theme.name} class="app-block app-narrow">
        <.list>
          <:item title="Built on">{Preset.fetch(@theme.base).name}</:item>
          <:item title="Shared by">{User.display_name(@theme.user)}</:item>
          <:item title="Settings changed">{map_size(@theme.tokens)}</:item>
          <:item title="Fonts">{font_names(@theme)}</:item>
          <:item title="Custom CSS">{if @theme.css == "", do: "None", else: "Yes"}</:item>
        </.list>
        <p class="ui-hint app-after-fields">
          Adding it makes a copy in your account. Your copy is yours to change, and does not
          follow later edits by {User.display_name(@theme.user)}.
        </p>
        <div class="ui-button-group app-form-actions">
          <.button
            id="add-shared-theme"
            variant="primary"
            phx-click="copy"
            phx-disable-with="Adding…"
          >
            + Add to my themes
          </.button>
          <.button navigate={~p"/themes"} variant="ghost">Cancel</.button>
        </div>
      </.panel>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("copy", _params, socket) do
    case Themes.copy_shared(socket.assigns.current_scope, socket.assigns.code) do
      {:ok, theme} ->
        {:noreply,
         socket
         |> put_flash(:info, "Added #{theme.name} to your themes.")
         |> push_navigate(to: ~p"/themes/#{theme.id}")}

      {:error, _reason} ->
        {:noreply,
         put_flash(socket, :error, "Could not add the theme. The link may have been reset.")}
    end
  end

  defp font_names(%Theme{fonts: fonts}) when map_size(fonts) == 0, do: "None"

  defp font_names(%Theme{fonts: fonts}),
    do: fonts |> Map.values() |> Enum.map_join(" · ", & &1["name"])
end
