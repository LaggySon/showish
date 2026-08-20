defmodule ShowishWeb.ControlLiveTest do
  use ShowishWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Showish.AccountsFixtures
  import Showish.BroadcastsFixtures

  alias Showish.Broadcasts
  alias Showish.Broadcasts.Show

  setup :register_and_log_in_user

  describe "on-air controls" do
    test "bumping a score writes through and pushes to overlays", %{conn: conn, scope: scope} do
      show = show_fixture(scope)
      :ok = Broadcasts.subscribe(show.slug)

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      view |> element("#score-up-1") |> render_click()

      assert_receive {:show_updated, %Show{} = pushed}
      assert Show.team(pushed, 1).score == 1
    end

    test "a score never goes below zero", %{conn: conn, scope: scope} do
      show = show_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      view |> element("#score-down-2") |> render_click()

      assert Show.team(Broadcasts.get_show!(scope, show.id), 2).score == 0
    end

    test "swapping sides is remembered", %{conn: conn, scope: scope} do
      show = show_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      view |> element("#swap-sides") |> render_click()

      assert Broadcasts.get_show!(scope, show.id).swap_sides
    end

    test "stepping through the series stops at the last game", %{conn: conn, scope: scope} do
      show = show_with_games_fixture(2, scope)

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      view |> element("#next-game") |> render_click()
      view |> element("#next-game") |> render_click()

      assert Broadcasts.get_show!(scope, show.id).current_game == 2
    end
  end

  describe "baseball controls" do
    test "switching sports replaces the series controls", %{conn: conn, scope: scope} do
      show = show_fixture(scope)
      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      view
      |> form("#control-form", show: %{sport: "baseball"})
      |> render_change()

      assert has_element?(view, "#baseball-controls")
      assert has_element?(view, "#baseball-inning")
      refute has_element?(view, "#esports-controls")
      refute has_element?(view, "#add-game")
    end

    test "updates runs, count, bases and half innings", %{conn: conn, scope: scope} do
      show = show_fixture(scope, %{sport: "baseball"})
      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      view |> element("#run-up-1") |> render_click()
      view |> element("#baseball-balls-up") |> render_click()
      view |> element("#baseball-base-first") |> render_click()
      view |> element("#baseball-next-half") |> render_click()

      reloaded = Broadcasts.get_show!(scope, show.id)
      assert Show.team(reloaded, 1).score == 1
      assert reloaded.sport_state["half"] == "bottom"
      assert reloaded.sport_state["balls"] == 0
      refute reloaded.sport_state["bases"]["first"]
      assert has_element?(view, "#baseball-inning")
    end
  end

  describe "the form" do
    test "saves as the operator types", %{conn: conn, scope: scope} do
      show = show_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      view
      |> form("#control-form")
      |> render_change(show: %{stage: "Grand Finals", best_of: "7"})

      reloaded = Broadcasts.get_show!(scope, show.id)
      assert reloaded.stage == "Grand Finals"
      assert reloaded.best_of == 7
    end

    test "shows an error instead of saving nonsense", %{conn: conn, scope: scope} do
      show = show_fixture(scope, %{title: "Keep Me"})

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      html =
        view
        |> form("#control-form")
        |> render_change(show: %{title: ""})

      assert html =~ "can&#39;t be blank"
      assert Broadcasts.get_show!(scope, show.id).title == "Keep Me"
    end
  end

  describe "series editing" do
    test "adding a game appends a row", %{conn: conn, scope: scope} do
      show = show_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      view |> element("#add-game") |> render_click()

      assert length(Broadcasts.get_show!(scope, show.id).games) == 1
    end

    test "adding a person appends a talent row", %{conn: conn, scope: scope} do
      show = show_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      view |> element("#add-talent") |> render_click()

      assert length(Broadcasts.get_show!(scope, show.id).talents) == 1
    end
  end

  describe "preview" do
    test "switches the previewed scene", %{conn: conn, scope: scope} do
      show = show_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      html = view |> element(~s{button[phx-value-scene="series"]}) |> render_click()

      assert html =~ "/overlay/#{show.slug}/series"
    end
  end

  describe "someone else's control room" do
    test "is a 404, not a hint that the show exists", %{conn: conn} do
      theirs = show_fixture(user_scope_fixture())

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/shows/#{theirs.slug}/control")
      end
    end
  end
end
