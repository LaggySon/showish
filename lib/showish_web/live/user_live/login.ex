defmodule ShowishWeb.UserLive.Login do
  @moduledoc """
  Logging in.

  The form posts to `ShowishWeb.UserSessionController` rather than submitting
  over the socket, because only a real HTTP response can set the session
  cookie.
  """

  use ShowishWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")

    {:ok,
     socket
     |> assign(:page_title, "Log in")
     |> assign(:form, form), temporary_assigns: [form: form]}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} max_width="max-w-md">
      <div class="rounded-box border border-base-300 bg-base-100 p-8">
        <h1 class="text-2xl font-black tracking-tight">Log in</h1>
        <p class="mt-1 text-sm text-base-content/70">
          Overlays keep running while you are away — you only need this to change them.
        </p>

        <.form
          for={@form}
          id="login-form"
          action={~p"/users/log-in"}
          method="post"
          class="mt-6 space-y-4"
        >
          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            placeholder="you@example.com"
            required
          />
          <.input
            field={@form[:password]}
            type="password"
            label="Password"
            autocomplete="current-password"
            required
          />
          <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" />

          <.button
            variant="primary"
            class="btn btn-primary w-full"
            phx-disable-with="Logging in…"
          >
            Log in
          </.button>
        </.form>

        <p class="mt-6 text-sm text-base-content/70">
          No account yet?
          <.link
            navigate={~p"/users/register"}
            class="font-semibold text-primary hover:underline"
          >
            Create one
          </.link>
        </p>
      </div>
    </Layouts.app>
    """
  end
end
