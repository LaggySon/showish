defmodule Showish.Accounts.Google do
  @moduledoc """
  The OAuth 2.0 authorization-code flow against Google, by hand.

  Deliberately no `ueberauth`/`assent` dependency: the flow is three URLs and
  two HTTP calls, and `Req` is already here. What comes back is a profile map:

      %{google_id: "1043...", email: "op@example.com", name: "Bo", avatar_url: "https://..."}

  The id token Google returns alongside the access token is ignored on purpose.
  Verifying it means fetching and caching Google's signing keys; asking the
  userinfo endpoint over TLS with the access token we just received is one more
  request and no crypto, and it tells us the same thing.

  ## Configuration

      config :showish, Showish.Accounts.Google,
        client_id: System.get_env("GOOGLE_CLIENT_ID"),
        client_secret: System.get_env("GOOGLE_CLIENT_SECRET")

  """

  require Logger

  @authorize_url "https://accounts.google.com/o/oauth2/v2/auth"
  @token_url "https://oauth2.googleapis.com/token"
  @userinfo_url "https://openidconnect.googleapis.com/v1/userinfo"

  @doc "Whether the app has been given Google credentials to work with."
  def configured?, do: is_binary(client_id()) and is_binary(client_secret())

  @doc """
  Where to send the browser to start a sign-in.

  `state` is echoed back to the callback untouched, which is how the callback
  knows the request came from us.
  """
  def authorize_url(redirect_uri, state) do
    query =
      URI.encode_query(%{
        "client_id" => client_id(),
        "redirect_uri" => redirect_uri,
        "response_type" => "code",
        "scope" => "openid email profile",
        "state" => state,
        # Showish only ever reads the profile once, at sign-in, so there is no
        # refresh token to look after.
        "access_type" => "online",
        # An operator may well run two shows from two accounts; never assume.
        "prompt" => "select_account"
      })

    @authorize_url <> "?" <> query
  end

  @doc """
  Turns the `code` Google sent to the callback into a profile.

  Returns `{:error, reason}` for anything that goes wrong, including an address
  Google has not verified — matching accounts on an unverified address would let
  anyone who can name it walk into somebody else's shows.
  """
  def fetch_profile(code, redirect_uri) when is_binary(code) do
    with {:ok, access_token} <- exchange_code(code, redirect_uri),
         {:ok, claims} <- fetch_userinfo(access_token) do
      build_profile(claims)
    end
  end

  defp exchange_code(code, redirect_uri) do
    form = [
      code: code,
      client_id: client_id(),
      client_secret: client_secret(),
      redirect_uri: redirect_uri,
      grant_type: "authorization_code"
    ]

    case request(method: :post, url: @token_url, form: form) do
      {:ok, %{status: 200, body: %{"access_token" => access_token}}} ->
        {:ok, access_token}

      {:ok, %{status: status, body: body}} ->
        Logger.warning("Google token exchange failed (#{status}): #{inspect(body)}")
        {:error, :token_exchange_failed}

      {:error, reason} ->
        Logger.warning("Google token exchange failed: #{inspect(reason)}")
        {:error, :token_exchange_failed}
    end
  end

  defp fetch_userinfo(access_token) do
    case request(method: :get, url: @userinfo_url, auth: {:bearer, access_token}) do
      {:ok, %{status: 200, body: %{} = claims}} ->
        {:ok, claims}

      {:ok, %{status: status, body: body}} ->
        Logger.warning("Google userinfo failed (#{status}): #{inspect(body)}")
        {:error, :userinfo_failed}

      {:error, reason} ->
        Logger.warning("Google userinfo failed: #{inspect(reason)}")
        {:error, :userinfo_failed}
    end
  end

  defp build_profile(%{"sub" => sub, "email" => email} = claims)
       when is_binary(sub) and is_binary(email) do
    if claims["email_verified"] in [true, "true"] do
      {:ok,
       %{
         google_id: sub,
         email: email,
         name: claims["name"] || "",
         avatar_url: claims["picture"] || ""
       }}
    else
      {:error, :email_not_verified}
    end
  end

  defp build_profile(_claims), do: {:error, :incomplete_profile}

  defp request(options) do
    [retry: false, receive_timeout: 15_000]
    |> Keyword.merge(options)
    |> Keyword.merge(req_options())
    |> Req.request()
  end

  defp client_id, do: config()[:client_id]
  defp client_secret, do: config()[:client_secret]

  # Lets the tests hand Req a stub plug instead of reaching Google.
  defp req_options, do: config()[:req_options] || []

  defp config, do: Application.get_env(:showish, __MODULE__, [])
end
