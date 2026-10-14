defmodule ShowishWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.

  The app layout is the page shell from the Laggish design guide (DESIGN.md
  section 5.2): a skip link, a top bar with the brand, the site nav, the
  connection badge and the user menu, the app-wide notices, then `main`.
  It matches the shell of the other apps built on the guide (transitmaps):
  "Live" sits in the top bar while the socket is up, and a lost connection
  is one full-width notice under it. Overlays do not use it; they render
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
          <span
            id="connection-live"
            class="ui-badge app-live"
            data-status={elem(ShowishWeb.Status.connection(:connected), 1)}
          >
            <span class="ui-dot" aria-hidden="true"></span>{elem(
              ShowishWeb.Status.connection(:connected),
              0
            )}
          </span>
          <.user_menu :if={@current_scope} current_scope={@current_scope} />
          <.link
            :if={!@current_scope && @section != "sign-in"}
            navigate={~p"/users/log-in"}
            class="ui-button ui-button--small"
          >
            Sign in
          </.link>
        </div>
      </header>
      <div id="connection-lost" class="ui-notice app-connection" data-status="warning" role="alert">
        {gettext("Connection lost. Reconnecting…")}
      </div>
      <.flash_group flash={@flash} />
      <main class="ui-main" id="main">
        {render_slot(@inner_block)}
      </main>
    </div>
    """
  end

  @doc """
  Shows the flash messages.

  Notices sit under the top bar, not in a corner, and stay until they are
  dismissed. The connection notice is part of the shell (see `app/1`).

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
    </div>
    """
  end

  @doc """
  The signed-in operator's menu (DESIGN.md section 7.15): their name in the top
  bar, and behind it the theme choice (section 2.4) and the way out.
  """
  attr :current_scope, :map, required: true

  def user_menu(assigns) do
    ~H"""
    <details phx-mounted={JS.ignore_attributes(["open"])} id="user-menu" class="ui-menu">
      <summary
        class="ui-button ui-button--ghost ui-button--small app-user"
        title={@current_scope.user.email}
      >
        <span id="signed-in-as" class="ui-truncate">
          {Showish.Accounts.User.display_name(@current_scope.user)}
        </span>
        <span aria-hidden="true">▾</span>
      </summary>
      <div class="ui-menu-panel">
        <span class="ui-label">Theme</span>
        <.theme_toggle />
        <.link
          id="sign-out"
          href={~p"/users/log-out"}
          method="delete"
          class="ui-button ui-button--small app-menu-item"
        >
          Sign out
        </.link>
      </div>
    </details>
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
