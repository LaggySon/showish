defmodule ShowishWeb.UserLive.Settings do
  @moduledoc """
  Account settings: email address and password.

  Both changes ask for the current password, so a control room laptop left
  unlocked between matches cannot be turned into someone else's account.
  """

  use ShowishWeb, :live_view

  alias Showish.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    {:ok,
     socket
     |> assign(:page_title, "Account")
     |> assign(:current_email, user.email)
     |> assign(:current_password, nil)
     |> assign(:email_form_current_password, nil)
     |> assign(:trigger_submit, false)
     |> assign(:email_form, to_form(Accounts.change_user_email(user), as: "user"))
     |> assign(:password_form, to_form(Accounts.change_user_password(user), as: "user"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} max_width="max-w-2xl">
      <div>
        <h1 class="text-3xl font-black tracking-tight">Account</h1>
        <p class="mt-1 text-base-content/70">
          Signed in as <span class="font-semibold">{@current_email}</span>.
        </p>
      </div>

      <div class="rounded-box border border-base-300 bg-base-100 p-6">
        <h2 class="text-lg font-bold">Email</h2>
        <.form
          for={@email_form}
          id="email-form"
          phx-submit="update_email"
          phx-change="validate_email"
          class="mt-4 space-y-4"
        >
          <.input field={@email_form[:email]} type="email" label="Email" required />
          <.input
            field={@email_form[:current_password]}
            name="current_password"
            id="current-password-for-email"
            type="password"
            label="Current password"
            value={@email_form_current_password}
            required
          />
          <.button variant="primary" class="btn btn-primary" phx-disable-with="Saving…">
            Change email
          </.button>
        </.form>
      </div>

      <div class="rounded-box border border-base-300 bg-base-100 p-6">
        <h2 class="text-lg font-bold">Password</h2>
        <p class="mt-1 text-sm text-base-content/70">
          Changing your password logs out every other browser you are signed in on.
        </p>
        <.form
          for={@password_form}
          id="password-form"
          action={~p"/users/log-in?_action=password_updated"}
          method="post"
          phx-change="validate_password"
          phx-submit="update_password"
          phx-trigger-action={@trigger_submit}
          class="mt-4 space-y-4"
        >
          <input
            name={@password_form[:email].name}
            type="hidden"
            id="hidden-user-email"
            autocomplete="username"
            value={@current_email}
          />
          <.input
            field={@password_form[:password]}
            type="password"
            label="New password"
            autocomplete="new-password"
            required
          />
          <.input
            field={@password_form[:password_confirmation]}
            type="password"
            label="Confirm new password"
            autocomplete="new-password"
          />
          <.input
            field={@password_form[:current_password]}
            name="current_password"
            type="password"
            label="Current password"
            id="current-password-for-password"
            value={@current_password}
            autocomplete="current-password"
            required
          />
          <.button variant="primary" class="btn btn-primary" phx-disable-with="Saving…">
            Change password
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form(as: "user")

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_scope.user

    case Accounts.update_user_email(user, password, user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Email changed.")
         |> assign(:current_scope, Showish.Accounts.Scope.for_user(user))
         |> assign(:current_email, user.email)
         |> assign(:email_form_current_password, nil)
         |> assign(:email_form, to_form(Accounts.change_user_email(user), as: "user"))}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert, as: "user"))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form(as: "user")

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_scope.user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        # The new password invalidated this session's token along with the
        # others, so the form is posted for real to pick up a fresh one.
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form(as: "user")

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        form = to_form(changeset, action: :insert, as: "user")
        {:noreply, assign(socket, :password_form, form)}
    end
  end
end
