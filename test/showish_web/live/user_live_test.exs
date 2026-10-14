defmodule ShowishWeb.UserLiveTest do
  @moduledoc """
  The sign-in page. The round trip to Google itself lives in
  `ShowishWeb.GoogleAuthControllerTest`.
  """

  use ShowishWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Showish.AccountsFixtures

  describe "sign in" do
    test "offers one way in", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/users/log-in")

      assert html =~ "Continue with Google"
      assert has_element?(view, ~s{a#sign-in-with-google[href="/auth/google"]})
    end

    test "sends an operator who is already signed in back to their shows", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/users/log-in")
    end
  end

  describe "the header" do
    setup :register_and_log_in_user

    test "names whoever is signed in and offers a way out", %{conn: conn, user: user} do
      {:ok, view, html} = live(conn, ~p"/")

      assert html =~ user.name
      assert has_element?(view, ~s{a[href="/users/log-out"]})
    end

    test "keeps the theme choice and sign-out in the user menu", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "header.ui-topbar details#user-menu #theme-picker")
      assert has_element?(view, ~s{details#user-menu a#sign-out[href="/users/log-out"]})
    end

    test "keeps the lost-connection notice under the top bar, and no Live badge", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "header.ui-topbar + #connection-lost.ui-notice")
      refute has_element?(view, "header.ui-topbar .ui-badge")
    end
  end

  describe "the brand mark" do
    test "is the favicon", %{conn: conn} do
      assert conn |> get("/favicon.svg") |> response(200) =~ "<rect"
      assert conn |> get("/apple-touch-icon.png") |> response(200)
    end
  end
end
