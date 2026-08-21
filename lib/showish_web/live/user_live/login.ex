defmodule ShowishWeb.UserLive.Login do
  @moduledoc """
  The sign-in page: one button, and an honest explanation if nobody has given
  this server any Google credentials yet.
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
    <Layouts.app flash={@flash} current_scope={@current_scope} max_width="max-w-md">
      <div class="rounded-box border border-base-300 bg-base-100 p-8">
        <h1 class="text-2xl font-black tracking-tight">Sign in</h1>

        <p class="mt-1 text-sm text-base-content/70">
          Your shows, your overlay URLs, your control room. Overlays keep running
          while you are away — you only need this to change them.
        </p>

        <a
          :if={@configured?}
          href={~p"/auth/google"}
          id="sign-in-with-google"
          class="mt-6 flex w-full items-center justify-center gap-3 rounded-btn border border-base-300 bg-base-100 px-4 py-3 font-semibold transition hover:bg-base-200 hover:shadow-sm"
        >
          <.google_mark /> Continue with Google
        </a>
        <p :if={@configured? and @restricted?} class="mt-3 text-center text-xs text-base-content/60">
          This server only signs in invited accounts.
        </p>

        <div
          :if={!@configured?}
          class="mt-6 rounded-box border border-warning/40 bg-warning/10 p-4 text-sm"
        >
          <p class="font-semibold">Google sign-in is not set up on this server.</p>

          <p class="mt-1 text-base-content/70">
            Create an OAuth client in the Google Cloud console, then set
            <code class="rounded bg-base-200 px-1">GOOGLE_CLIENT_ID</code>
            and <code class="rounded bg-base-200 px-1">GOOGLE_CLIENT_SECRET</code>
            and restart. The README has the five-minute version.
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # Google's mark, inline: the asset pipeline only ships app.css and app.js, and
  # a remote <img> would be one more thing to fail mid-broadcast.
  defp google_mark(assigns) do
    ~H"""
    <svg class="size-5" viewBox="0 0 48 48" aria-hidden="true">
      <path
        fill="#EA4335"
        d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"
      />
      <path
        fill="#4285F4"
        d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"
      />
      <path
        fill="#FBBC05"
        d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24s.92 7.54 2.56 10.78l7.97-6.19z"
      />
      <path
        fill="#34A853"
        d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"
      />
    </svg>
    """
  end
end
