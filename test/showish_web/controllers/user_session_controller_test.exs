defmodule ShowishWeb.UserSessionControllerTest do
  use ShowishWeb.ConnCase, async: true

  import Showish.AccountsFixtures

  setup do
    %{user: user_fixture()}
  end

  describe "POST /users/log-in" do
    test "logs the operator in and lands them on their shows", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"

      assert conn |> get(~p"/") |> html_response(200) =~ user.email
    end

    test "remembers the operator when asked", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_showish_web_user_remember_me"]
    end

    test "returns to the page that asked for a login", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(user_return_to: "/shows/somewhere")
        |> post(~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert redirected_to(conn) == "/shows/somewhere"
    end

    test "says nothing about which half was wrong", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => "not the password"}
        })

      refute get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
    end
  end

  describe "DELETE /users/log-out" do
    test "drops the session and the token behind it", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete(~p"/users/log-out")

      refute get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "is harmless when nobody is logged in", %{conn: conn} do
      conn = delete(conn, ~p"/users/log-out")

      refute get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end
end
