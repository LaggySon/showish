defmodule ShowishWeb.UserAuth do
  @moduledoc """
  Logging in and out, and the plugs and LiveView hooks that decide who is
  allowed through.

  Both halves put the same thing on the connection or socket: a
  `Showish.Accounts.Scope` under `:current_scope`, or `nil` for a visitor.
  """

  use ShowishWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Showish.Accounts
  alias Showish.Accounts.Scope

  # Renewing the session on login is what stops session fixation.
  @remember_me_cookie "_showish_web_user_remember_me"
  @max_age 60 * 60 * 24 * 60
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  @doc """
  Logs `user` in and sends them on their way.

  The session is remembered across browser restarts. Signing in is a trip to
  Google and back, and an operator setting up in a truck should not have to make
  it again because they closed the lid.
  """
  def log_in_user(conn, user) do
    token = Accounts.generate_user_session_token(user)
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> put_resp_cookie(@remember_me_cookie, token, @remember_me_options)
    |> redirect(to: user_return_to || signed_in_path(conn))
  end

  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the current user out, everywhere this browser is concerned.

  The token is revoked server-side too, so a copy of the cookie taken earlier is
  worthless.
  """
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      ShowishWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/users/log-in")
  end

  @doc """
  Plug that puts the current scope on the connection.

  Runs for every browser request, including the ones that do not require a
  login, so templates can always read `@current_scope`.
  """
  def fetch_current_scope_for_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    user = user_token && Accounts.get_user_by_session_token(user_token)

    assign(conn, :current_scope, Scope.for_user(user))
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, put_token_in_session(conn, token)}
      else
        {nil, conn}
      end
    end
  end

  @doc """
  LiveView hooks.

    * `:mount_current_scope` — assigns `:current_scope`, logged in or not.
    * `:require_authenticated` — the same, but sends visitors to the login page.

  """
  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:require_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/users/log-in")

      {:halt, socket}
    end
  end

  defp mount_current_scope(socket, session) do
    Phoenix.Component.assign_new(socket, :current_scope, fn ->
      user = session["user_token"] && Accounts.get_user_by_session_token(session["user_token"])
      Scope.for_user(user)
    end)
  end

  @doc "Plug that bounces a logged-in user away from the login and signup pages."
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_scope] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Plug that requires a logged-in user.

  Remembers where they were headed, so logging in lands them on the page they
  actually asked for.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_scope] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/log-in")
      |> halt()
    end
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: ~p"/"
end
