defmodule ShowishWeb.GoogleAuthControllerTest do
  # Not async: one test takes the Google credentials out of the application
  # environment, which every other test that renders the sign-in page can see.
  use ShowishWeb.ConnCase, async: false

  import Showish.AccountsFixtures

  alias Showish.Accounts
  alias Showish.Accounts.Allowlist
  alias Showish.Accounts.Google

  describe "GET /auth/google" do
    test "sends the operator to Google with a state to come back with", %{conn: conn} do
      conn = get(conn, ~p"/auth/google")

      assert url = redirected_to(conn, 302)
      assert url =~ "https://accounts.google.com/o/oauth2/v2/auth?"

      query = url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

      assert query["client_id"] == "test-client-id"
      assert query["response_type"] == "code"
      assert query["scope"] == "openid email profile"
      assert query["redirect_uri"] =~ "/auth/google/callback"
      assert query["state"] == get_session(conn, :google_oauth_state)
      assert byte_size(query["state"]) > 16
    end

    test "says so when the server has no Google credentials", %{conn: conn} do
      without_google_credentials(fn ->
        conn = get(conn, ~p"/auth/google")

        assert redirected_to(conn) == ~p"/users/log-in"
        assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not set up"
      end)
    end
  end

  describe "GET /auth/google/callback" do
    test "signs a new operator in and lands them on their shows", %{conn: conn} do
      claims = google_claims(email: "bo@example.com", name: "Bo Ferreira")
      stub_google(claims)

      conn = complete_sign_in(conn)

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :user_token)
      assert conn.resp_cookies["_showish_web_user_remember_me"]

      user = Accounts.get_user_by_email("bo@example.com")
      assert user.google_id == claims["sub"]
      assert user.name == "Bo Ferreira"
    end

    test "signs an existing operator back in", %{conn: conn} do
      user = user_fixture(%{email: "back@example.com"})
      stub_google(google_claims(email: user.email, google_id: user.google_id))

      conn = complete_sign_in(conn)

      assert redirected_to(conn) == ~p"/"
      assert Accounts.get_user_by_session_token(get_session(conn, :user_token)).id == user.id
    end

    test "returns the operator to the page that asked for a login", %{conn: conn} do
      stub_google(google_claims())

      conn =
        conn
        |> init_test_session(user_return_to: "/shows/finals/control")
        |> complete_sign_in()

      assert redirected_to(conn) == "/shows/finals/control"
    end

    test "refuses a state that is not the one we issued", %{conn: conn} do
      stub_google(google_claims())

      conn = get(conn, ~p"/auth/google")
      conn = get(conn, ~p"/auth/google/callback?code=abc&state=not-the-state")

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "expired"
      refute get_session(conn, :user_token)
    end

    test "refuses a code that arrives with no state at all", %{conn: conn} do
      conn = get(conn, ~p"/auth/google/callback?code=abc&state=guessed")

      assert redirected_to(conn) == ~p"/users/log-in"
      refute get_session(conn, :user_token)
    end

    test "will not sign in an address Google has not verified", %{conn: conn} do
      stub_google(google_claims() |> Map.put("email_verified", false))

      conn = complete_sign_in(conn)

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not verified"
      refute get_session(conn, :user_token)
    end

    test "reports a token exchange that Google rejects", %{conn: conn} do
      Req.Test.stub(Google, fn conn ->
        conn
        |> Plug.Conn.put_status(400)
        |> Req.Test.json(%{"error" => "invalid_grant"})
      end)

      conn = complete_sign_in(conn)

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Something went wrong"
      refute get_session(conn, :user_token)
    end

    test "takes a cancelled sign-in quietly", %{conn: conn} do
      conn = get(conn, ~p"/auth/google/callback?error=access_denied")

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "cancelled"
      refute get_session(conn, :user_token)
    end

    test "the state is single use", %{conn: conn} do
      stub_google(google_claims())

      conn = get(conn, ~p"/auth/google")
      state = get_session(conn, :google_oauth_state)

      conn = get(conn, ~p"/auth/google/callback?code=abc&state=#{state}")
      assert redirected_to(conn) == ~p"/"

      conn =
        conn
        |> recycle()
        |> get(~p"/auth/google/callback?code=abc&state=#{state}")

      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "GET /auth/google/callback with an allowlist" do
    setup do
      # Putting `nil` back would leave the key in place holding nil, which is
      # not what an unconfigured server looks like.
      original = Application.get_env(:showish, Allowlist)

      on_exit(fn ->
        if original do
          Application.put_env(:showish, Allowlist, original)
        else
          Application.delete_env(:showish, Allowlist)
        end
      end)

      Application.put_env(:showish, Allowlist, emails: "invited@example.com")
    end

    test "signs in an invited account", %{conn: conn} do
      stub_google(google_claims(email: "invited@example.com"))

      conn = complete_sign_in(conn)

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :user_token)
    end

    test "turns away an account that is not on the list", %{conn: conn} do
      stub_google(google_claims(email: "stranger@example.com"))

      conn = complete_sign_in(conn)

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not on the list"
      refute get_session(conn, :user_token)
      refute Accounts.get_user_by_email("stranger@example.com")
    end
  end

  describe "DELETE /users/log-out" do
    test "drops the session and the token behind it", %{conn: conn} do
      user = user_fixture()

      conn = conn |> log_in_user(user) |> delete(~p"/users/log-out")

      refute get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "is harmless when nobody is signed in", %{conn: conn} do
      conn = delete(conn, ~p"/users/log-out")

      refute get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  # Answers both legs of the flow: the token exchange, then userinfo.
  defp stub_google(claims) do
    Req.Test.stub(Google, fn conn ->
      case conn.request_path do
        "/token" -> Req.Test.json(conn, %{"access_token" => "an-access-token"})
        "/v1/userinfo" -> Req.Test.json(conn, claims)
      end
    end)
  end

  defp complete_sign_in(conn) do
    conn = get(conn, ~p"/auth/google")
    state = get_session(conn, :google_oauth_state)

    get(conn, ~p"/auth/google/callback?code=an-auth-code&state=#{state}")
  end

  defp without_google_credentials(fun) do
    original = Application.get_env(:showish, Google)

    Application.put_env(:showish, Google, Keyword.drop(original, [:client_id, :client_secret]))

    try do
      fun.()
    after
      Application.put_env(:showish, Google, original)
    end
  end
end
