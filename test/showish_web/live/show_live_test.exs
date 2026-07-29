defmodule ShowishWeb.ShowLiveTest do
  use ShowishWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Showish.BroadcastsFixtures

  describe "index" do
    test "lists shows and links to their control rooms", %{conn: conn} do
      show = show_fixture(%{title: "Autumn Cup"})

      {:ok, view, html} = live(conn, ~p"/")

      assert html =~ "Autumn Cup"
      assert has_element?(view, ~s{a[href="/shows/#{show.slug}/control"]})
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
    test "offers a browser source URL for every scene", %{conn: conn} do
      show = show_fixture()

      {:ok, view, html} = live(conn, ~p"/shows/#{show.slug}")

      for scene <- ShowishWeb.Scenes.all() do
        assert html =~ scene.name
        assert has_element?(view, "#copy-#{scene.key}")
      end
    end
  end
end
