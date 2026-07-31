defmodule ShowishWeb.ShowLiveTest do
  use ShowishWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Showish.AccountsFixtures
  import Showish.BroadcastsFixtures

  describe "when nobody is logged in" do
    test "the shelf of shows sends you to the login page", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in", flash: flash}}} = live(conn, ~p"/")
      assert flash["error"] == "You must log in to access this page."
    end
  end

  describe "index" do
    setup :register_and_log_in_user

    test "lists shows and links to their control rooms", %{conn: conn, scope: scope} do
      show = show_fixture(scope, %{title: "Autumn Cup"})

      {:ok, view, html} = live(conn, ~p"/")

      assert html =~ "Autumn Cup"
      assert has_element?(view, ~s{a[href="/shows/#{show.slug}/control"]})
    end

    test "does not list another account's shows", %{conn: conn, scope: scope} do
      show_fixture(scope, %{title: "Mine"})
      theirs = show_fixture(user_scope_fixture(), %{title: "Theirs"})

      {:ok, view, html} = live(conn, ~p"/")

      assert html =~ "Mine"
      refute html =~ "Theirs"
      refute has_element?(view, ~s{a[href="/shows/#{theirs.slug}/control"]})
    end

    test "creates a show and lands in the control room", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/shows/new")

      assert has_element?(view, "#new-show-form")

      {:error, {:live_redirect, %{to: to}}} =
        view
        |> form("#new-show-form", show: %{title: "Winter Open", slug: ""})
        |> render_submit()

      assert to == "/shows/winter-open/control"
    end

    test "the new show belongs to whoever created it", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/shows/new")

      view
      |> form("#new-show-form", show: %{title: "Spring Open", slug: "spring-open"})
      |> render_submit()

      assert Showish.Broadcasts.get_public_show_by_slug!("spring-open").user_id == user.id
    end

    test "reports a duplicate slug instead of creating a second show", %{conn: conn} do
      show_fixture(%{slug: "duplicate"})

      {:ok, view, _html} = live(conn, ~p"/shows/new")

      html =
        view
        |> form("#new-show-form", show: %{title: "Another", slug: "duplicate"})
        |> render_submit()

      assert html =~ "has already been taken"
    end
  end

  describe "detail" do
    setup :register_and_log_in_user

    test "offers a browser source URL for every scene", %{conn: conn, scope: scope} do
      show = show_fixture(scope)

      {:ok, view, html} = live(conn, ~p"/shows/#{show.slug}")

      for scene <- ShowishWeb.Scenes.all() do
        assert html =~ scene.name
        assert has_element?(view, "#copy-#{scene.key}")
      end
    end

    test "another account's show is not there to look at", %{conn: conn} do
      theirs = show_fixture(user_scope_fixture())

      assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/shows/#{theirs.slug}") end
    end
  end
end
