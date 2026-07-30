defmodule ShowishWeb.UserSessionController do
  @moduledoc """
  Where the login form posts.

  A plain controller rather than a LiveView, because setting a session cookie
  needs a real HTTP response.
  """

  use ShowishWeb, :controller

  alias Showish.Accounts
  alias ShowishWeb.UserAuth

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Welcome to Showish!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> create(params, "Password updated successfully.")
  end

  def create(conn, params), do: create(conn, params, "Welcome back!")

  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user, user_params)
    else
      # The form is re-rendered with the email filled in, but never the
      # password, and the message does not say which half was wrong.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/users/log-in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
