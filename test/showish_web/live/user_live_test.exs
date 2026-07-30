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
  end
end
