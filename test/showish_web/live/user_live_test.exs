defmodule ShowishWeb.UserLiveTest do
  use ShowishWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Showish.AccountsFixtures

  alias Showish.Accounts

  describe "registration" do
    test "renders the form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/users/register")

      assert html =~ "Create your account"
      assert html =~ "Log in"
    end

    test "sends a logged-in operator back to their shows", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/users/register")
    end

    test "reports problems as the operator types", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/register")

      html =
        view
        |> form("#registration-form", user: %{email: "with spaces", password: "short"})
        |> render_change()

      assert html =~ "must have the @ sign and no spaces"
      assert html =~ "should be at least 12 character"
    end

    test "creates an account and logs it in", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()

      form =
        form(view, "#registration-form", user: %{email: email, password: valid_user_password()})

      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/"
      assert Accounts.get_user_by_email(email)

      assert conn |> get(~p"/") |> html_response(200) =~ email
    end

    test "refuses an address that is already registered", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} = live(conn, ~p"/users/register")

      html =
        view
        |> form("#registration-form", user: %{email: user.email, password: valid_user_password()})
        |> render_submit()

      assert html =~ "has already been taken"
    end
  end

  describe "login" do
    test "renders the form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/users/log-in")

      assert html =~ "Log in"
      assert html =~ "Create one"
    end

    test "sends a logged-in operator back to their shows", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/users/log-in")
    end
  end

  describe "settings" do
    setup :register_and_log_in_user

    test "shows who is signed in", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/users/settings")

      assert html =~ "Account"
      assert html =~ user.email
    end

    test "needs a login", %{conn: _conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(build_conn(), ~p"/users/settings")
    end

    test "changes the email address", %{conn: conn, user: user} do
      new_email = unique_user_email()

      {:ok, view, _html} = live(conn, ~p"/users/settings")

      view
      |> form("#email-form", %{
        "current_password" => valid_user_password(),
        "user" => %{"email" => new_email}
      })
      |> render_submit()

      assert Accounts.get_user!(user.id).email == new_email
    end

    test "refuses an email change without the current password", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/users/settings")

      html =
        view
        |> form("#email-form", %{
          "current_password" => "not the password",
          "user" => %{"email" => unique_user_email()}
        })
        |> render_submit()

      assert html =~ "is not valid"
      assert Accounts.get_user!(user.id).email == user.email
    end

    test "changes the password and logs the browser back in", %{conn: conn, user: user} do
      new_password = "a brand new password"

      {:ok, view, _html} = live(conn, ~p"/users/settings")

      form =
        form(view, "#password-form", %{
          "current_password" => valid_user_password(),
          "user" => %{
            "email" => user.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)
      new_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_conn) == ~p"/users/settings"
      assert get_session(new_conn, :user_token)
      assert Accounts.get_user_by_email_and_password(user.email, new_password)
    end

    test "reports a confirmation that does not match", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/settings")

      html =
        view
        |> form("#password-form", %{
          "current_password" => valid_user_password(),
          "user" => %{
            "password" => "a brand new password",
            "password_confirmation" => "something else"
          }
        })
        |> render_submit()

      assert html =~ "does not match password"
    end
  end
end
