defmodule ShowishWeb.GoogleAuthController do
  @moduledoc """
  The two ends of a sign-in with Google.

  `request` sends the browser to Google with a one-shot `state` in the session;
  `callback` will not look at a code unless the `state` it comes back with is
  the one we put there, which is what stops a stranger from handing an operator
  a link that logs them into the stranger's account.
  """

  use ShowishWeb, :controller

  alias Showish.Accounts
  alias Showish.Accounts.Google
  alias ShowishWeb.UserAuth

  @state_key :google_oauth_state

  def request(conn, _params) do
    if Google.configured?() do
      state = Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false)

      conn
      |> put_session(@state_key, state)
      |> redirect(external: Google.authorize_url(redirect_uri(conn), state))
    else
      conn
      |> put_flash(:error, "Signing in with Google is not set up on this server.")
      |> redirect(to: ~p"/users/log-in")
    end
  end

  # Google sends `error=access_denied` when someone changes their mind at the
  # account chooser. That is not a failure worth shouting about.
  def callback(conn, %{"error" => _error}) do
    conn
    |> delete_session(@state_key)
    |> put_flash(:info, "Sign-in cancelled.")
    |> redirect(to: ~p"/users/log-in")
  end

  def callback(conn, %{"code" => code, "state" => state}) do
    expected = get_session(conn, @state_key)
    conn = delete_session(conn, @state_key)

    if is_binary(expected) and Plug.Crypto.secure_compare(state, expected) do
      complete(conn, code)
    else
      failed(conn, "That sign-in link has expired. Please try again.")
    end
  end

  def callback(conn, _params), do: failed(conn, "That sign-in did not complete.")

  defp complete(conn, code) do
    with {:ok, profile} <- Google.fetch_profile(code, redirect_uri(conn)),
         {:ok, user} <- Accounts.sign_in_with_google(profile) do
      conn
      |> put_flash(:info, "Signed in as #{user.email}.")
      |> UserAuth.log_in_user(user)
    else
      {:error, :email_not_verified} ->
        failed(conn, "Google has not verified that address, so we cannot sign you in with it.")

      {:error, :email_taken} ->
        failed(conn, "Another account here already uses that address.")

      {:error, _reason} ->
        failed(conn, "Something went wrong signing in with Google. Please try again.")
    end
  end

  defp failed(conn, message) do
    conn
    |> put_flash(:error, message)
    |> redirect(to: ~p"/users/log-in")
  end

  # Must match a redirect URI registered on the Google credential exactly, which
  # is why it is derived from the endpoint rather than from the request.
  defp redirect_uri(_conn), do: url(~p"/auth/google/callback")
end
