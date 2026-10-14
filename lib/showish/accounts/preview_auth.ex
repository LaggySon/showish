defmodule Showish.Accounts.PreviewAuth do
  @moduledoc """
  A short-lived bridge from the stable Google callback to a PR deployment.

  The browser authenticates on the broker and carries only a random, single-use
  code back to the preview. The preview redeems that code over HTTPS, so Google
  credentials and reusable identity assertions never need to live in a PR
  environment.
  """

  import Ecto.Query

  alias Showish.Accounts.PreviewAuthCode
  alias Showish.Repo

  @callback_path "/auth/google/preview/callback"
  @exchange_path "/auth/google/preview/exchange"
  @valid_for_seconds 120
  @nonce_bytes 24
  @token_bytes 32

  @doc "Whether this deployment has a stable preview-auth broker configured."
  def configured?, do: valid_broker_uri?(broker_uri())

  @doc "A fresh browser nonce used to bind a broker response to its login session."
  def new_nonce, do: random_token(@nonce_bytes)

  @doc "The canonical callback URI for this deployment."
  def callback_uri do
    ShowishWeb.Endpoint.url()
    |> URI.merge(@callback_path)
    |> URI.to_string()
  end

  @doc "Whether this deployment should send Google login through the broker."
  def use_broker?(callback_uri) when is_binary(callback_uri) do
    case broker_uri() do
      %URI{scheme: "https", host: broker_host} = broker when is_binary(broker_host) ->
        callback = URI.parse(callback_uri)

        valid_broker_uri?(broker) and
          {callback.scheme, callback.host, effective_port(callback)} !=
            {broker.scheme, broker.host, effective_port(broker)}

      _other ->
        false
    end
  end

  @doc "Builds the stable broker URL that begins a preview login."
  def broker_request_url(return_to, nonce) when is_binary(return_to) and is_binary(nonce) do
    broker_uri()
    |> URI.merge("/auth/google")
    |> Map.put(:query, URI.encode_query(%{"return_to" => return_to, "nonce" => nonce}))
    |> URI.to_string()
  end

  @doc "Accepts only this Railway project's generated PR callback URLs."
  def valid_return_to?(return_to) when is_binary(return_to) do
    uri = URI.parse(return_to)

    byte_size(return_to) <= 255 and uri.scheme == "https" and uri.port in [nil, 443] and
      is_nil(uri.userinfo) and
      uri.path == @callback_path and is_nil(uri.query) and is_nil(uri.fragment) and
      valid_preview_host?(uri.host)
  end

  def valid_return_to?(_return_to), do: false

  @doc "Stores a two-minute, one-use code and returns its opaque value."
  def issue_code(profile, return_to, nonce) do
    now = DateTime.utc_now()
    raw_token = random_token(@token_bytes)

    Repo.delete_all(from code in PreviewAuthCode, where: code.expires_at <= ^now)

    %PreviewAuthCode{
      token: hash(raw_token),
      google_id: profile.google_id,
      email: profile.email,
      name: profile.name || "",
      avatar_url: profile.avatar_url || "",
      return_to: return_to,
      nonce: nonce,
      expires_at: DateTime.add(now, @valid_for_seconds, :second)
    }
    |> Repo.insert()
    |> case do
      {:ok, _code} -> {:ok, raw_token}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc "Atomically consumes a code bound to this callback and browser nonce."
  def consume_code(raw_token, return_to, nonce)
      when is_binary(raw_token) and is_binary(return_to) and is_binary(nonce) do
    now = DateTime.utc_now()

    Repo.transaction(fn ->
      code =
        Repo.one(
          from code in PreviewAuthCode,
            where:
              code.token == ^hash(raw_token) and code.return_to == ^return_to and
                code.nonce == ^nonce and code.expires_at > ^now,
            lock: "FOR UPDATE"
        )

      case code do
        %PreviewAuthCode{} ->
          Repo.delete!(code)

          %{
            google_id: code.google_id,
            email: code.email,
            name: code.name,
            avatar_url: code.avatar_url
          }

        nil ->
          Repo.rollback(:invalid_or_expired)
      end
    end)
  end

  def consume_code(_raw_token, _return_to, _nonce), do: {:error, :invalid_or_expired}

  @doc "Redeems a code with the configured broker over HTTPS."
  def exchange_code(raw_token, return_to, nonce) do
    request =
      [
        method: :post,
        url: broker_exchange_url(),
        json: %{"code" => raw_token, "return_to" => return_to, "nonce" => nonce},
        retry: false,
        receive_timeout: 15_000
      ]
      |> Keyword.merge(config()[:req_options] || [])

    case Req.request(request) do
      {:ok, %{status: 200, body: %{"profile" => profile}}} -> normalize_profile(profile)
      {:ok, %{status: status}} when status in 400..499 -> {:error, :invalid_or_expired}
      {:ok, _response} -> {:error, :broker_unavailable}
      {:error, _reason} -> {:error, :broker_unavailable}
    end
  end

  defp normalize_profile(%{"google_id" => google_id, "email" => email} = profile)
       when is_binary(google_id) and is_binary(email) do
    {:ok,
     %{
       google_id: google_id,
       email: email,
       name: profile["name"] || "",
       avatar_url: profile["avatar_url"] || ""
     }}
  end

  defp normalize_profile(_profile), do: {:error, :broker_unavailable}

  defp valid_preview_host?(host) when is_binary(host) do
    prefix = config()[:allowed_host_prefix]

    if is_binary(prefix) and prefix != "" do
      Regex.match?(~r/\A#{Regex.escape(prefix)}\d+\.up\.railway\.app\z/, host)
    else
      false
    end
  end

  defp valid_preview_host?(_host), do: false

  defp broker_exchange_url do
    broker_uri()
    |> URI.merge(@exchange_path)
    |> URI.to_string()
  end

  defp broker_uri do
    case config()[:broker_url] do
      url when is_binary(url) and url != "" -> URI.parse(url)
      _other -> nil
    end
  end

  defp effective_port(%URI{port: port}) when is_integer(port), do: port
  defp effective_port(%URI{scheme: "https"}), do: 443
  defp effective_port(%URI{scheme: "http"}), do: 80
  defp effective_port(_uri), do: nil

  defp valid_broker_uri?(%URI{
         scheme: "https",
         host: host,
         port: port,
         path: path,
         userinfo: nil,
         query: nil,
         fragment: nil
       })
       when is_binary(host) and port in [nil, 443] and path in [nil, "", "/"],
       do: true

  defp valid_broker_uri?(_uri), do: false

  defp random_token(bytes),
    do: Base.url_encode64(:crypto.strong_rand_bytes(bytes), padding: false)

  defp hash(token), do: :crypto.hash(:sha256, token)
  defp config, do: Application.get_env(:showish, __MODULE__, [])
end
