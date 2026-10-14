defmodule ShowishWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.

  The app layout is the page shell from the Laggish design guide (DESIGN.md
  section 5.2): a skip link, a top bar with the brand, the site nav, who is
  signed in and the theme picker, then `main` with the page. Overlays do not use it; they render
  into the bare `overlay_root` layout.
  """
  use ShowishWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  ## Examples

      <Layouts.app flash={@flash} section="shows">
        <.header>Shows</.header>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :section, :string,
    default: nil,
    doc: "the site nav entry for the current page, when the page is that entry"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <a class="ui-skip-link" href="#main">Skip to content</a>
    <div class="ui-shell">
      <header class="ui-topbar">
        <.link navigate={~p"/"} class="ui-brand">
          <span class="ui-brand-mark" aria-hidden="true"></span>Showish
        </.link>
        <nav :if={@current_scope} class="ui-sitenav" aria-label="Site">
          <.link navigate={~p"/"} aria-current={@section == "shows" && "page"}>Shows</.link>
        </nav>
        <div class="ui-topbar-aside">
          <%= if @current_scope do %>
            <span id="signed-in-as" class="ui-truncate app-user" title={@current_scope.user.email}>
              {Showish.Accounts.User.display_name(@current_scope.user)}
            </span>
            <.link
              href={~p"/users/log-out"}
              method="delete"
              class="ui-button ui-button--ghost ui-button--small"
            >
              Sign out
            </.link>
          <% else %>
            <.link
              :if={@section != "sign-in"}
              navigate={~p"/users/log-in"}
              class="ui-button ui-button--small"
            >
              Sign in
            </.link>
          <% end %>
          <.theme_toggle />
        </div>
      </header>

      <main class="ui-main" id="main">
        <.flash_group flash={@flash} />
        {render_slot(@inner_block)}
      </main>
    </div>
    """
  end

  @doc """
  Shows the flash messages, and the app-wide notice while the connection to
  the server is lost.

  Notices sit at the top of `main`, not in a corner, and stay until they are
  dismissed or the condition ends.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} class="app-notices">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <div
        id="client-error"
        class="ui-notice"
        data-status="warning"
        role="status"
        phx-disconnected={JS.remove_attribute("hidden", to: ".phx-client-error #client-error")}
        phx-connected={JS.set_attribute({"hidden", ""}, to: "#client-error")}
        hidden
      >
        {gettext("Connection lost. Changes do not reach the overlays until it is back. Reconnecting…")}
      </div>

      <div
        id="server-error"
        class="ui-notice"
        data-status="failure"
        role="alert"
        phx-disconnected={JS.remove_attribute("hidden", to: ".phx-server-error #server-error")}
        phx-connected={JS.set_attribute({"hidden", ""}, to: "#server-error")}
        hidden
      >
        {gettext("Server error. This page stopped. Reconnecting…")}
      </div>
    </div>
    """
  end

  @doc """
  The theme picker: System, Light or Dark (DESIGN.md section 2.4).

  "Light" and "Dark" set `data-theme` on `<html>`, "System" removes it. The
  script in root.html.heex applies the stored choice before the first paint;
  the `ThemePicker` hook in app.js marks the current choice and moves it with
  the arrow keys.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div
      id="theme-picker"
      class="ui-segmented"
      role="radiogroup"
      aria-label="Theme"
      phx-hook="ThemePicker"
      phx-update="ignore"
    >
      <button
        :for={{choice, label} <- [{"system", "System"}, {"light", "Light"}, {"dark", "Dark"}]}
        type="button"
        class="ui-chip"
        role="radio"
        aria-checked={to_string(choice == "system")}
        tabindex={if choice == "system", do: "0", else: "-1"}
        data-phx-theme={choice}
      >
        {label}
      </button>
    </div>
    """
  end
end
