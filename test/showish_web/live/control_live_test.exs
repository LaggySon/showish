defmodule ShowishWeb.ControlLiveTest do
  use ShowishWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Showish.BroadcastsFixtures

  alias Showish.Broadcasts
  alias Showish.Broadcasts.Show

  describe "on-air controls" do
    test "bumping a score writes through and pushes to overlays", %{conn: conn} do
      show = show_fixture()
      :ok = Broadcasts.subscribe(show.slug)

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      view |> element("#score-up-1") |> render_click()

      assert_receive {:show_updated, %Show{} = pushed}
      assert Show.team(pushed, 1).score == 1
    end

    test "a score never goes below zero", %{conn: conn} do
      show = show_fixture()

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      view |> element("#score-down-2") |> render_click()

      assert Show.team(Broadcasts.get_show!(show.id), 2).score == 0
    end

    test "swapping sides is remembered", %{conn: conn} do
      show = show_fixture()

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      view |> element("#swap-sides") |> render_click()

      assert Broadcasts.get_show!(show.id).swap_sides
    end

    test "stepping through the series stops at the last game", %{conn: conn} do
      show = show_with_games_fixture(2)

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      view |> element("#next-game") |> render_click()
      view |> element("#next-game") |> render_click()

      assert Broadcasts.get_show!(show.id).current_game == 2
    end
  end

  describe "the form" do
    test "saves as the operator types", %{conn: conn} do
      show = show_fixture()

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      view
      |> form("#control-form")
      |> render_change(show: %{stage: "Grand Finals", best_of: "7"})

      reloaded = Broadcasts.get_show!(show.id)
      assert reloaded.stage == "Grand Finals"
      assert reloaded.best_of == 7
    end

    test "shows an error instead of saving nonsense", %{conn: conn} do
      show = show_fixture(%{title: "Keep Me"})

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      html =
        view
        |> form("#control-form")
        |> render_change(show: %{title: ""})

      assert html =~ "can&#39;t be blank"
      assert Broadcasts.get_show!(show.id).title == "Keep Me"
    end
  end

  describe "series editing" do
    test "adding a game appends a row", %{conn: conn} do
      show = show_fixture()

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      view |> element("#add-game") |> render_click()

      assert length(Broadcasts.get_show!(show.id).games) == 1
    end

    test "adding a person appends a talent row", %{conn: conn} do
      show = show_fixture()

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      view |> element("#add-talent") |> render_click()

      assert length(Broadcasts.get_show!(show.id).talents) == 1
    end
  end

  describe "preview" do
    test "switches the previewed scene", %{conn: conn} do
      show = show_fixture()

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      html = view |> element(~s{button[phx-value-scene="series"]}) |> render_click()

      assert html =~ "/overlay/#{show.slug}/series"
    end
  end
end
