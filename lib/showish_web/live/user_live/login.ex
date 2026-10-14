defmodule ShowishWeb.UserLive.Login do
  @moduledoc """
  The sign-in page: one button, and an honest explanation if nobody has given
  this server any Google credentials yet. It follows the sign-in recipe in
  DESIGN.md section 5.9: one narrow panel, the brand above it, nothing else.
  """

  use ShowishWeb, :live_view

  alias Showish.Accounts.Allowlist
  alias Showish.Accounts.Google
  alias Showish.Accounts.PreviewAuth

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Sign in")
     |> assign(:configured?, Google.configured?() or PreviewAuth.configured?())
     |> assign(:restricted?, Allowlist.enforced?())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} section="sign-in">
      <div class="app-sign-in">
        <p class="ui-brand app-sign-in-brand">
          <span class="ui-brand-mark" aria-hidden="true"></span>Showish
        </p>
        <section class="ui-panel" aria-labelledby="sign-in-title">
          <h1 id="sign-in-title" class="ui-panel-title">Sign in</h1>

          <div
            :if={!@configured?}
            id="sign-in-unavailable"
            class="ui-notice"
            data-status="warning"
            role="status"
          >
            <span>
              Google sign-in is not set up on this server. Create an OAuth client in the
              Google Cloud console, set <code class="ui-mono">GOOGLE_CLIENT_ID</code>
              and <code class="ui-mono">GOOGLE_CLIENT_SECRET</code>, and restart. The README
              has the five-minute version.
            </span>
          </div>

          <p class="ui-muted app-sign-in-note">
            Signing in lets you change your shows. Overlays keep running without it.
          </p>

          <.button
            :if={@configured?}
            href={~p"/auth/google"}
            id="sign-in-with-google"
            variant="primary"
            class="app-sign-in-button"
          >
            Continue with Google
          </.button>
          <p :if={@configured? and @restricted?} class="ui-hint app-sign-in-note">
            This server only signs in invited accounts.
          </p>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
