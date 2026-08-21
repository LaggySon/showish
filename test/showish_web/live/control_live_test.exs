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
      assert has_element?(view, "#baseball-live-state")
      assert has_element?(view, "#baseball-inning")
      assert has_element?(view, "#baseball-rosters")
      assert has_element?(view, "#baseball-graphics-controls")
      assert has_element?(view, "#baseball-lineup-form-1")
      assert has_element?(view, "#baseball-pitcher-form-2")
      assert has_element?(view, "#baseball-defense-form-1")
      assert has_element?(view, "#baseball-bullpen-form-2")
      assert has_element?(view, "#baseball-play-single")
      assert has_element?(view, "#baseball-play-error")
      refute has_element?(view, "#baseball-single-stats-form")
      refute has_element?(view, "#esports-controls")
      refute has_element?(view, "#add-game")
    end

    test "saves defensive and bullpen data while deriving highlight data", %{
      conn: conn,
      scope: scope
    } do
      show = show_fixture(scope, %{sport: "baseball"})
      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      view
      |> form("#baseball-lineup-form-1", lineup: %{position: "1", names: "Alex Cruz"})
      |> render_submit()

      view
      |> form("#baseball-defense-form-1",
        defense: %{position: "1", players: "P: Jordan Lee\nSS: Morgan Ellis"}
      )
      |> render_submit()

      view
      |> form("#baseball-bullpen-form-2",
        bullpen: %{position: "2", pitchers: "Taylor Reed | Warming"}
      )
      |> render_submit()

      view |> element("#baseball-play-single") |> render_click()

      state = Broadcasts.get_show!(scope, show.id).sport_state
      assert state["defense"]["1"]["P"] == "Jordan Lee"

      assert Enum.map(state["bullpens"]["2"], &Map.take(&1, ~w(name status))) == [
               %{"name" => "Taylor Reed", "status" => "Warming"}
             ]

      assert state["graphics"]["single"]["name"] == "Alex Cruz"
      assert %{"label" => "H-AB", "value" => "1-1"} in state["graphics"]["single"]["stats"]
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
      assert has_element?(view, "#baseball-advance-half")
    end

    test "manages lineups, the active batter and pitching", %{conn: conn, scope: scope} do
      show = show_fixture(scope, %{sport: "baseball"})
      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      view
      |> form("#baseball-lineup-form-1",
        lineup: %{position: "1", names: "A. Leadoff\nB. Slugger"}
      )
      |> render_submit()

      view
      |> form("#baseball-pitcher-form-2", pitcher: %{position: "2", name: "Phillips"})
      |> render_submit()

      view |> element("#baseball-batter-1-1") |> render_click()
      view |> element("#baseball-play-single") |> render_click()
      view |> element("#baseball-pitches-up-2") |> render_click()

      reloaded = Broadcasts.get_show!(scope, show.id)

      assert Enum.map(reloaded.sport_state["lineups"]["1"], & &1["name"]) == [
               "A. Leadoff",
               "B. Slugger"
             ]

      assert reloaded.sport_state["active_batters"]["1"] == 0
      assert Enum.at(reloaded.sport_state["lineups"]["1"], 1)["at_bats"] == 1
      assert Enum.at(reloaded.sport_state["lineups"]["1"], 1)["hits"] == 1

      assert Map.take(reloaded.sport_state["pitchers"]["2"], ~w(name pitch_count)) == %{
               "name" => "Phillips",
               "pitch_count" => 1
             }
    end

    test "records and undoes pitches from the live action surface", %{conn: conn, scope: scope} do
      show = show_fixture(scope, %{sport: "baseball"})
      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      assert has_element?(view, "#baseball-live-actions")
      assert has_element?(view, "#baseball-undo[disabled]")

      view |> element("#baseball-pitch-ball") |> render_click()

      reloaded = Broadcasts.get_show!(scope, show.id)
      assert reloaded.sport_state["balls"] == 1
      assert reloaded.sport_state["pitchers"]["2"]["pitch_count"] == 1
      refute has_element?(view, "#baseball-undo[disabled]")

      view |> element("#baseball-undo") |> render_click()

      reloaded = Broadcasts.get_show!(scope, show.id)
      assert reloaded.sport_state["balls"] == 0
      assert reloaded.sport_state["pitchers"]["2"]["pitch_count"] == 0
    end

    test "shows the completed at-bat on the struck-out hitter's lineup row", %{
      conn: conn,
      scope: scope
    } do
      show = show_fixture(scope, %{sport: "baseball"})
      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      view
      |> form("#baseball-lineup-form-1",
        lineup: %{position: "1", names: "A. Leadoff\nB. Slugger"}
      )
      |> render_submit()

      for _pitch <- 1..3 do
        view |> element("#baseball-pitch-strike") |> render_click()
      end

      assert has_element?(view, "#baseball-batter-1-0", "A. Leadoff 0-1")
      assert has_element?(view, "#baseball-batter-1-1", "B. Slugger 0-0")
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
