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

      # The button is disabled at zero, and the server clamps a stray event too.
      assert has_element?(view, "#score-down-2[disabled]")
      render_click(view, "score", %{"position" => "2", "delta" => "-1"})

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

      # On the last game the button is disabled, and the server clamps a stray event too.
      assert has_element?(view, "#next-game[disabled]")
      render_click(view, "step_game", %{"delta" => "1"})

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
      assert has_element?(view, "details#baseball-live-actions[open]")
      assert has_element?(view, "details#baseball-scoreboard[open]")
      assert has_element?(view, "#baseball-live-state + details#baseball-live-actions")
      assert has_element?(view, "#baseball-live-actions + details#baseball-scoreboard")
      assert has_element?(view, "#baseball-quick-changes")
      assert has_element?(view, "details#baseball-personnel-change")
      refute has_element?(view, "#baseball-pitching-change")
      refute has_element?(view, "#baseball-player-substitution")
      refute has_element?(view, "#baseball-quick-pitcher-form-2")
      assert has_element?(view, "#baseball-substitution-form-1")
      refute has_element?(view, "#baseball-substitution-name-1")
      assert has_element?(view, "#baseball-inning")
      assert has_element?(view, "#baseball-rosters")
      assert has_element?(view, "details#baseball-graphics-controls")
      assert has_element?(view, "button#baseball-open-game-rosters-modal")
      assert has_element?(view, "#baseball-game-rosters-modal[role='dialog'][aria-modal='true']")
      assert has_element?(view, "button#baseball-close-game-rosters-modal")
      assert has_element?(view, "button#baseball-clear-count[aria-label]")
      assert has_element?(view, "button#baseball-clear-bases[aria-label]")
      assert has_element?(view, "button#baseball-reset-game[aria-label]")
      assert has_element?(view, "button#baseball-save-highlight-selection[aria-label]")
      assert has_element?(view, "#baseball-game-rosters-form")
      assert has_element?(view, "#baseball-game-rosters-data")
      refute has_element?(view, "#baseball-roster-form-1")
      refute has_element?(view, "#baseball-pitcher-form-2")
      refute has_element?(view, "#baseball-defense-form-1")
      refute has_element?(view, "#baseball-bullpen-form-2")
      assert has_element?(view, "#baseball-play-single")
      assert has_element?(view, "#baseball-play-strikeout")
      assert has_element?(view, "#baseball-play-error")
      assert has_element?(view, "#baseball-play-fielders-choice")
      assert has_element?(view, "#baseball-play-sac-fly")
      assert has_element?(view, "#baseball-play-double-play")
      assert has_element?(view, "#baseball-play-triple-play")
      assert has_element?(view, "#baseball-play-interference")
      assert has_element?(view, "#baseball-play-triple")
      assert has_element?(view, "#baseball-play-hit-by-pitch")
      assert has_element?(view, "#baseball-play-strikeout-reached")
      assert has_element?(view, "#baseball-record-notation")
      assert has_element?(view, "div#baseball-more-results")
      refute has_element?(view, "details#baseball-more-results")
      refute has_element?(view, "#baseball-single-stats-form")
      refute has_element?(view, "#esports-controls")
      refute has_element?(view, "#add-game")
      assert has_element?(view, "details#live-controls-panel[open]")
      assert has_element?(view, "details#match-config-panel:not([open])")
      assert has_element?(view, "details#teams-config-panel:not([open])")
      assert has_element?(view, "details#team-config-1:not([open])")
      assert has_element?(view, "details#talent-config-panel:not([open])")
      assert has_element?(view, "details#preview-panel[open]")
    end

    test "one substitution flow handles pitchers and lineup players", %{conn: conn, scope: scope} do
      show = show_fixture(scope, %{sport: "baseball"})
      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      view
      |> form("#baseball-game-rosters-form",
        game_rosters: %{
          data:
            "AWAY\nLINEUP\n1. Starter | CF\n2. Slugger | 1B\nROSTER\nPinch Runner\nHOME\nSTARTING PITCHER\nStarter Arm\nROSTER\nReliever"
        }
      )
      |> render_submit()

      setup_state = Broadcasts.get_show!(scope, show.id).sport_state

      reliever_id =
        setup_state["rosters"]["2"]
        |> Enum.find(&(&1["name"] == "Reliever"))
        |> Map.fetch!("id")

      pinch_runner_id =
        setup_state["rosters"]["1"]
        |> Enum.find(&(&1["name"] == "Pinch Runner"))
        |> Map.fetch!("id")

      starting_pitcher_id = setup_state["pitchers"]["2"]["id"]

      view
      |> form("#baseball-substitution-form-2",
        substitution: %{
          position: "2",
          outgoing_player_id: to_string(starting_pitcher_id),
          incoming_player_id: to_string(reliever_id),
          field_position: ""
        }
      )
      |> render_submit()

      outgoing_id =
        Broadcasts.get_show!(scope, show.id).sport_state["lineups"]["1"]
        |> hd()
        |> Map.fetch!("id")

      view
      |> form("#baseball-substitution-form-1",
        substitution: %{
          position: "1",
          outgoing_player_id: to_string(outgoing_id),
          incoming_player_id: to_string(pinch_runner_id),
          field_position: "RF"
        }
      )
      |> render_submit()

      state = Broadcasts.get_show!(scope, show.id).sport_state
      assert state["pitchers"]["2"]["name"] == "Reliever"
      assert hd(state["lineups"]["1"])["name"] == "Pinch Runner"
    end

    test "saves defensive and bullpen data while deriving highlight data", %{
      conn: conn,
      scope: scope
    } do
      show = show_fixture(scope, %{sport: "baseball"})
      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      view
      |> form("#baseball-game-rosters-form",
        game_rosters: %{
          data: """
          AWAY
          TEAM
          Name: Bay City Captains
          Logo URL: https://example.com/captains.svg
          Primary color: #123456
          Secondary color: #abcdef
          LINEUP
          1. Alex Cruz | SS
          STARTING PITCHER
          Jordan Lee
          HOME
          BULLPEN
          Taylor Reed | Warming
          """
        }
      )
      |> render_submit()

      view
      |> element("#baseball-play-form")
      |> render_submit(%{"play" => %{"notation" => "", "result" => "single"}})

      state = Broadcasts.get_show!(scope, show.id).sport_state
      assert state["defense"]["1"]["P"] == "Jordan Lee"
      assert state["defense"]["1"]["SS"] == "Alex Cruz"
      assert Enum.map(state["lineups"]["1"], & &1["name"]) == ["Alex Cruz"]

      away = scope |> Broadcasts.get_show!(show.id) |> Show.team(1)
      assert away.name == "Bay City Captains"
      assert away.logo_url == "https://example.com/captains.svg"
      assert away.primary_color == "#123456"

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

    test "treats entered scorebook notation as authoritative", %{conn: conn, scope: scope} do
      show = show_fixture(scope, %{sport: "baseball"})
      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      view
      |> form("#baseball-game-rosters-form",
        game_rosters: %{data: "AWAY\nLINEUP\n1. Error Batter | SS\nHOME\nROSTER"}
      )
      |> render_submit()

      view
      |> element("#baseball-play-form")
      |> render_submit(%{"play" => %{"notation" => "E1", "result" => "out"}})

      reloaded = Broadcasts.get_show!(scope, show.id)
      [batter] = reloaded.sport_state["lineups"]["1"]

      assert {batter["hits"], batter["at_bats"]} == {0, 1}
      assert reloaded.sport_state["outs"] == 0
      assert reloaded.sport_state["bases"]["first"]
      assert has_element?(view, "#baseball-last-play", "E1 · Error")
    end

    test "manages lineups, the active batter and pitching", %{conn: conn, scope: scope} do
      show = show_fixture(scope, %{sport: "baseball"})
      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      view
      |> form("#baseball-game-rosters-form",
        game_rosters: %{
          data:
            "AWAY\nLINEUP\n1. A. Leadoff | CF\n2. B. Slugger | 1B\nHOME\nSTARTING PITCHER\nPhillips"
        }
      )
      |> render_submit()

      pitcher_id = Broadcasts.get_show!(scope, show.id).sport_state["pitchers"]["2"]["id"]

      assert has_element?(
               view,
               "#baseball-highlight-selection-form select option[value='#{pitcher_id}']",
               "Phillips · P"
             )

      view |> element("#baseball-batter-1-1") |> render_click()

      view
      |> element("#baseball-play-form")
      |> render_submit(%{"play" => %{"notation" => "9", "result" => "single"}})

      view |> element("#baseball-pitches-up-2") |> render_click()

      reloaded = Broadcasts.get_show!(scope, show.id)

      assert Enum.map(reloaded.sport_state["lineups"]["1"], & &1["name"]) == [
               "A. Leadoff",
               "B. Slugger"
             ]

      assert reloaded.sport_state["defense"]["1"]["CF"] == "A. Leadoff"
      assert reloaded.sport_state["defense"]["1"]["1B"] == "B. Slugger"
      assert reloaded.sport_state["last_play"] == %{"notation" => "9", "result" => "single"}
      assert has_element?(view, "#baseball-last-play", "9 · Single")

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
      |> form("#baseball-game-rosters-form",
        game_rosters: %{
          data: "AWAY\nLINEUP\nA. Leadoff | CF\nB. Slugger | 1B\nHOME\nROSTER"
        }
      )
      |> render_submit()

      for _pitch <- 1..3 do
        view |> element("#baseball-pitch-strike") |> render_click()
      end

      assert has_element?(view, "#baseball-batter-1-0 span.ui-mono", "0-1")
      assert has_element?(view, "#baseball-batter-1-1 span.ui-mono", "0-0")
    end
  end

  describe "the live controls" do
    test "explain a control that does not apply instead of hiding it", %{conn: conn, scope: scope} do
      show = show_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      assert has_element?(view, ~s{#reset-scores[disabled][title="Both scores are already 0"]})
      assert has_element?(view, ~s{#previous-game[disabled][title="Game 1 is the first game"]})

      view |> element("#score-up-1") |> render_click()

      assert has_element?(view, ~s{#reset-scores[data-confirm]:not([disabled])})
    end

    test "show swapped sides as a pressed toggle", %{conn: conn, scope: scope} do
      show = show_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      assert has_element?(view, ~s{#swap-sides[aria-pressed="false"]})
      view |> element("#swap-sides") |> render_click()
      assert has_element?(view, ~s{#swap-sides[aria-pressed="true"]})
    end

    test "baseball plays that cannot happen say why", %{conn: conn, scope: scope} do
      show = show_fixture(scope, %{sport: "baseball"})

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      assert has_element?(
               view,
               ~s{#baseball-play-sac-fly[disabled][title="Needs a runner on third and fewer than 2 outs"]}
             )

      assert has_element?(view, ~s{#baseball-undo[disabled][title="Nothing to undo yet"]})
      assert has_element?(view, ~s{#baseball-reset-game[data-confirm]})
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

      assert html =~ "Can&#39;t be blank."
      assert has_element?(view, "#show_title[aria-invalid=true]")
      assert has_element?(view, "#save-failed")
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

    test "removing a game asks first", %{conn: conn, scope: scope} do
      show = show_with_games_fixture(2, scope)
      [first, _second] = show.games

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      view
      |> element(
        ~s{#game-#{first.id} button[phx-click="delete_game"][data-confirm="Remove game 1?"]}
      )
      |> render_click()

      assert length(Broadcasts.get_show!(scope, show.id).games) == 1
    end

    test "the game on air carries the rail and the On air state", %{conn: conn, scope: scope} do
      show = show_with_games_fixture(2, scope)
      [first, _second] = show.games

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      assert has_element?(
               view,
               ~s{#game-#{first.id}[aria-current="true"].ui-rail .ui-badge[data-status="progress"]}
             )
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

      view |> form("#preview-form", %{scene: "series"}) |> render_change()

      assert_patch(view, "/shows/#{show.slug}/control?scene=series")
      assert has_element?(view, ~s{#preview-series[src="/overlay/#{show.slug}/series"]})
    end

    test "keeps the previewed scene across a refresh", %{conn: conn, scope: scope} do
      show = show_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control?scene=credits")

      assert has_element?(view, ~s{#preview-credits[src="/overlay/#{show.slug}/credits"]})
    end

    test "falls back to a scene the sport offers", %{conn: conn, scope: scope} do
      show = show_fixture(scope, %{sport: "baseball"})

      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control?scene=series")

      assert has_element?(view, ~s{#preview-scorebug[src="/overlay/#{show.slug}/scorebug"]})
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
