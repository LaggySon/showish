defmodule ShowishWeb.PreviewGoogleAuthControllerTest do
  use ShowishWeb.ConnCase, async: false

  alias Showish.Accounts
  alias Showish.Accounts.Google
  alias Showish.Accounts.PreviewAuth

  @broker_url "https://dev.show.laggi.sh"
  @preview_host "showish-showish-pr-42.up.railway.app"
  @return_to "https://#{@preview_host}/auth/google/preview/callback"

  setup do
    original = Application.get_env(:showish, PreviewAuth)

    on_exit(fn -> Application.put_env(:showish, PreviewAuth, original) end)

    :ok
  end

  describe "starting from a PR deployment" do
    test "sends the browser to the stable broker and keeps a nonce in the PR session", %{
      conn: conn
    } do
      configure_broker()

      conn = get(conn, "https://#{@preview_host}/auth/google")

      broker_request = conn |> redirected_to(302) |> URI.parse()
      query = URI.decode_query(broker_request.query)

      assert broker_request.scheme == "https"
      assert broker_request.host == "dev.show.laggi.sh"
      assert broker_request.path == "/auth/google"
      assert query["return_to"] == PreviewAuth.callback_uri()
      assert query["nonce"] == get_session(conn, :google_preview_nonce)
    end
  end

  describe "the stable broker" do
    test "returns a one-time code instead of signing into the broker", %{conn: conn} do
      configure_broker(broker_url: nil)
      stub_google()
      nonce = PreviewAuth.new_nonce()

      conn =
        get(conn, ~p"/auth/google?return_to=#{@return_to}&nonce=#{nonce}")

      google_query =
        conn
        |> redirected_to(302)
        |> URI.parse()
        |> Map.fetch!(:query)
        |> URI.decode_query()

      conn = get(conn, ~p"/auth/google/callback?code=google-code&state=#{google_query["state"]}")

      preview_callback = conn |> redirected_to(302) |> URI.parse()
      callback_query = URI.decode_query(preview_callback.query)

      assert preview_callback.host == @preview_host
      assert callback_query["code"]
      refute get_session(conn, :user_token)

      assert {:ok, %{email: "preview@example.com"}} =
               PreviewAuth.consume_code(callback_query["code"], @return_to, nonce)

      assert {:error, :invalid_or_expired} =
               PreviewAuth.consume_code(callback_query["code"], @return_to, nonce)
    end

    test "refuses a return URL outside this Railway project", %{conn: conn} do
      configure_broker(broker_url: nil)

      conn =
        get(
          conn,
          ~p"/auth/google?return_to=https://attacker.example/auth/google/preview/callback&nonce=#{PreviewAuth.new_nonce()}"
        )

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not valid"
    end

    test "returns a cancelled login to the preview", %{conn: conn} do
      configure_broker(broker_url: nil)
      nonce = PreviewAuth.new_nonce()

      conn = get(conn, ~p"/auth/google?return_to=#{@return_to}&nonce=#{nonce}")
      conn = get(conn, ~p"/auth/google/callback?error=access_denied")

      callback = conn |> redirected_to(302) |> URI.parse()

      assert callback.host == @preview_host
      assert URI.decode_query(callback.query) == %{"error" => "access_denied"}
    end

    test "the exchange endpoint consumes a code once and is never cached", %{conn: conn} do
      profile = %{
        google_id: "google-preview-42",
        email: "preview@example.com",
        name: "Preview Operator",
        avatar_url: ""
      }

      assert {:ok, code} = PreviewAuth.issue_code(profile, @return_to, "browser-nonce")

      params = %{code: code, return_to: @return_to, nonce: "browser-nonce"}
      conn = post(conn, ~p"/auth/google/preview/exchange", params)

      assert get_resp_header(conn, "cache-control") == ["no-store"]
      assert %{"profile" => %{"email" => "preview@example.com"}} = json_response(conn, 200)

      conn = conn |> recycle() |> post(~p"/auth/google/preview/exchange", params)
      assert json_response(conn, 422) == %{"error" => "invalid_or_expired"}
    end
  end

  describe "finishing in a PR deployment" do
    test "redeems the broker code and creates the PR's own login session", %{conn: conn} do
      configure_broker()

      Req.Test.stub(PreviewAuth, fn conn ->
        assert conn.request_path == "/auth/google/preview/exchange"
        assert conn.body_params["code"] == "one-time-code"
        assert conn.body_params["return_to"] == PreviewAuth.callback_uri()
        assert is_binary(conn.body_params["nonce"])

        Req.Test.json(conn, %{
          profile: %{
            google_id: "google-preview-42",
            email: "preview@example.com",
            name: "Preview Operator",
            avatar_url: ""
          }
        })
      end)

      conn = get(conn, "https://#{@preview_host}/auth/google")

      conn =
        conn
        |> recycle()
        |> get("https://#{@preview_host}/auth/google/preview/callback?code=one-time-code")

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :user_token)
      assert Accounts.get_user_by_email("preview@example.com")
    end

    test "does not redeem a code without the initiating browser session", %{conn: conn} do
      configure_broker()

      conn =
        get(conn, "https://#{@preview_host}/auth/google/preview/callback?code=stolen-code")

      assert redirected_to(conn) == ~p"/users/log-in"
      refute get_session(conn, :user_token)
    end
  end

  defp configure_broker(overrides \\ []) do
    current = Application.get_env(:showish, PreviewAuth, [])

    config =
      current
      |> Keyword.put(:broker_url, @broker_url)
      |> Keyword.merge(overrides)

    Application.put_env(:showish, PreviewAuth, config)
  end

  defp stub_google do
    Req.Test.stub(Google, fn conn ->
      case conn.request_path do
        "/token" ->
          Req.Test.json(conn, %{"access_token" => "access-token"})

        "/v1/userinfo" ->
          Req.Test.json(conn, %{
            "sub" => "google-preview-42",
            "email" => "preview@example.com",
            "email_verified" => true,
            "name" => "Preview Operator"
          })
      end
    end)
  end
end
