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
  alias Showish.Accounts.PreviewAuth
  alias ShowishWeb.UserAuth

  @state_key :google_oauth_state
  @preview_return_to_key :google_preview_return_to
  @preview_nonce_key :google_preview_nonce

  def request(conn, %{"return_to" => return_to, "nonce" => nonce}) do
    callback_uri = PreviewAuth.callback_uri()

    if Google.configured?() and not PreviewAuth.use_broker?(callback_uri) and
         PreviewAuth.valid_return_to?(return_to) and valid_nonce?(nonce) do
      start_google(conn, return_to, nonce)
    else
      failed(conn, "That preview sign-in request is not valid.")
    end
  end

  def request(conn, _params) do
    callback_uri = PreviewAuth.callback_uri()

    cond do
      PreviewAuth.use_broker?(callback_uri) ->
        nonce = PreviewAuth.new_nonce()

        conn
        |> put_session(@preview_nonce_key, nonce)
        |> redirect(external: PreviewAuth.broker_request_url(callback_uri, nonce))

      Google.configured?() ->
        start_google(conn)

      true ->
        conn
        |> put_flash(:error, "Signing in with Google is not set up on this server.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  # Google sends `error=access_denied` when someone changes their mind at the
  # account chooser. That is not a failure worth shouting about.
  def callback(conn, %{"error" => _error}) do
    return_to = get_session(conn, @preview_return_to_key)

    conn = clear_oauth_session(conn)

    if PreviewAuth.valid_return_to?(return_to) do
      redirect(conn, external: add_query(return_to, %{"error" => "access_denied"}))
    else
      conn
      |> put_flash(:info, "Sign-in cancelled.")
      |> redirect(to: ~p"/users/log-in")
    end
  end

  def callback(conn, %{"code" => code, "state" => state}) do
    expected = get_session(conn, @state_key)
    conn = delete_session(conn, @state_key)

    if is_binary(expected) and Plug.Crypto.secure_compare(state, expected) do
      complete(conn, code)
    else
      conn
      |> clear_preview_session()
      |> failed("That sign-in link has expired. Please try again.")
    end
  end

  def callback(conn, _params), do: failed(conn, "That sign-in did not complete.")

  def preview_callback(conn, %{"error" => _error}) do
    conn
    |> delete_session(@preview_nonce_key)
    |> put_flash(:info, "Sign-in cancelled.")
    |> redirect(to: ~p"/users/log-in")
  end

  def preview_callback(conn, %{"code" => code}) do
    nonce = get_session(conn, @preview_nonce_key)
    conn = delete_session(conn, @preview_nonce_key)

    with true <- is_binary(nonce),
         {:ok, profile} <- PreviewAuth.exchange_code(code, PreviewAuth.callback_uri(), nonce),
         {:ok, user} <- Accounts.sign_in_with_google(profile) do
      conn
      |> put_flash(:info, "Signed in as #{user.email}.")
      |> UserAuth.log_in_user(user)
    else
      {:error, :not_allowed} ->
        failed(conn, "That Google account is not on the list for this server.")

      {:error, :email_taken} ->
        failed(conn, "Another account here already uses that address.")

      _error ->
        failed(conn, "That preview sign-in has expired. Please try again.")
    end
  end

  def preview_callback(conn, _params), do: failed(conn, "That preview sign-in did not complete.")

  def exchange(conn, %{"code" => code, "return_to" => return_to, "nonce" => nonce}) do
    conn = put_resp_header(conn, "cache-control", "no-store")

    case PreviewAuth.consume_code(code, return_to, nonce) do
      {:ok, profile} ->
        json(conn, %{profile: profile})

      {:error, :invalid_or_expired} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "invalid_or_expired"})
    end
  end

  def exchange(conn, _params) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_status(:bad_request)
    |> json(%{error: "invalid_request"})
  end

  defp complete(conn, code) do
    return_to = get_session(conn, @preview_return_to_key)
    nonce = get_session(conn, @preview_nonce_key)
    conn = clear_preview_session(conn)

    if PreviewAuth.valid_return_to?(return_to) and valid_nonce?(nonce) do
      complete_for_preview(conn, code, return_to, nonce)
    else
      complete_locally(conn, code)
    end
  end

  defp complete_for_preview(conn, code, return_to, nonce) do
    with {:ok, profile} <- Google.fetch_profile(code, redirect_uri(conn)),
         {:ok, _broker_user} <- Accounts.sign_in_with_google(profile),
         {:ok, raw_token} <- PreviewAuth.issue_code(profile, return_to, nonce) do
      redirect(conn, external: add_query(return_to, %{"code" => raw_token}))
    else
      {:error, :email_not_verified} ->
        failed(conn, "Google has not verified that address.")

      {:error, :not_allowed} ->
        failed(conn, "That Google account is not on the list for this server.")

      {:error, :email_taken} ->
        failed(conn, "Another account here already uses that address.")

      {:error, _reason} ->
        failed(conn, "Something went wrong signing in with Google.")
    end
  end

  defp complete_locally(conn, code) do
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

  defp start_google(conn, return_to \\ nil, nonce \\ nil) do
    state = Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false)

    conn
    |> clear_preview_session()
    |> put_session(@state_key, state)
    |> maybe_put_preview_session(return_to, nonce)
    |> redirect(external: Google.authorize_url(redirect_uri(conn), state))
  end

  defp maybe_put_preview_session(conn, return_to, nonce)
       when is_binary(return_to) and is_binary(nonce) do
    conn
    |> put_session(@preview_return_to_key, return_to)
    |> put_session(@preview_nonce_key, nonce)
  end

  defp maybe_put_preview_session(conn, _return_to, _nonce), do: conn

  defp clear_oauth_session(conn) do
    conn
    |> delete_session(@state_key)
    |> clear_preview_session()
  end

  defp clear_preview_session(conn) do
    conn
    |> delete_session(@preview_return_to_key)
    |> delete_session(@preview_nonce_key)
  end

  defp add_query(uri, params) do
    uri
    |> URI.parse()
    |> Map.put(:query, URI.encode_query(params))
    |> URI.to_string()
  end

  defp valid_nonce?(nonce) when is_binary(nonce) do
    byte_size(nonce) in 24..128 and Regex.match?(~r/\A[A-Za-z0-9_-]+\z/, nonce)
  end

  defp valid_nonce?(_nonce), do: false
end
