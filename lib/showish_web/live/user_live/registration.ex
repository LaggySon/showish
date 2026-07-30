defmodule ShowishWeb.UserLive.Registration do
  @moduledoc """
  Signing up.

  On success the form is handed to the browser to post at the session
  controller, which is the only place that can set a login cookie — so a new
  account lands straight in its (empty) shelf of shows.
  """

  use ShowishWeb, :live_view

  alias Showish.Accounts
  alias Showish.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    {:ok,
     socket
     |> assign(:page_title, "Create your account")
     |> assign(:trigger_submit, false)
     |> assign_form(changeset)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} max_width="max-w-md">
      <div class="rounded-box border border-base-300 bg-base-100 p-8">
        <h1 class="text-2xl font-black tracking-tight">Create your account</h1>
        <p class="mt-1 text-sm text-base-content/70">
          Your shows, your overlay URLs, your control room.
        </p>

        <.form
          for={@form}
          id="registration-form"
          action={~p"/users/log-in?_action=registered"}
          method="post"
          phx-submit="save"
          phx-change="validate"
          phx-trigger-action={@trigger_submit}
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
            autocomplete="new-password"
            placeholder="At least 12 characters"
            required
          />

          <.button
            variant="primary"
            class="btn btn-primary w-full"
            phx-disable-with="Creating…"
          >
            Create account
          </.button>
        </.form>

        <p class="mt-6 text-sm text-base-content/70">
          Already have an account?
          <.link navigate={~p"/users/log-in"} class="font-semibold text-primary hover:underline">
            Log in
          </.link>
        </p>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  def handle_event("save", %{"user" => params}, socket) do
    case Accounts.register_user(params) do
      {:ok, user} ->
        # Re-render the form with the submitted values and let the browser post
        # it for real; `phx-trigger-action` does the rest.
        changeset = Accounts.change_user_registration(user, params)

        {:noreply,
         socket
         |> assign(:trigger_submit, true)
         |> assign_form(changeset)}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: "user"))
  end
end
