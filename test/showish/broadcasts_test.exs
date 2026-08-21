defmodule Showish.BroadcastsTest do
  use Showish.DataCase, async: true

  import Showish.AccountsFixtures
  import Showish.BroadcastsFixtures

  alias Showish.Broadcasts
  alias Showish.Broadcasts.NotOwnerError
  alias Showish.Broadcasts.Show
  alias Showish.Broadcasts.Sport

  doctest Showish.Broadcasts.Show

  describe "create_show/2" do
    setup do
      %{scope: user_scope_fixture()}
    end

    test "seeds two teams so a show can go on air immediately", %{scope: scope} do
      show = show_fixture(scope, %{title: "Cup Final", slug: "cup-final"})

      assert show.slug == "cup-final"
      assert [%{position: 1}, %{position: 2}] = show.teams
      assert show.sport == "esports"
      assert show.sport_state == %{}
    end

    test "initializes state through the selected sport handler", %{scope: scope} do
      show = show_fixture(scope, %{sport: "baseball"})

      assert show.sport == "baseball"
      assert show.sport_state["inning"] == 1
      assert show.sport_state["half"] == "top"

      assert show.sport_state["bases"] == %{
               "first" => false,
               "second" => false,
               "third" => false
             }
    end

    test "rejects a sport that is not in the catalogue", %{scope: scope} do
      assert {:error, changeset} =
               Broadcasts.create_show(scope, %{
                 "title" => "Mystery",
                 "slug" => "mystery-sport",
                 "sport" => "quidditch"
               })

      assert %{sport: ["is invalid"]} = errors_on(changeset)
    end

    test "gives the show to the account that created it", %{scope: scope} do
      show = show_fixture(scope)

      assert show.user_id == scope.user.id
    end

    test "ignores an owner smuggled in through the attributes", %{scope: scope} do
      other = user_scope_fixture()

      show = show_fixture(scope, %{"user_id" => other.user.id})

      assert show.user_id == scope.user.id
    end

    test "tidies a human-typed slug rather than rejecting it", %{scope: scope} do
      assert {:ok, show} =
               Broadcasts.create_show(scope, %{"title" => "T", "slug" => "Not A Slug!"})

      assert show.slug == "not-a-slug"
    end

    test "rejects a slug with nothing usable in it", %{scope: scope} do
      assert {:error, changeset} =
               Broadcasts.create_show(scope, %{"title" => "T", "slug" => "!!!"})

      assert %{slug: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires a slug that no account has taken", %{scope: scope} do
      show_fixture(%{slug: "taken"})

      assert {:error, changeset} =
               Broadcasts.create_show(scope, %{"title" => "T", "slug" => "taken"})

      assert %{slug: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "update_show/3" do
    test "updates the show and keeps children ordered" do
      scope = user_scope_fixture()
      show = show_with_games_fixture(3, scope)

      assert {:ok, updated} = Broadcasts.update_show(scope, show, %{"stage" => "Semi Final"})
      assert updated.stage == "Semi Final"
      assert Enum.map(updated.games, & &1.position) == [0, 1, 2]
    end

    test "returns a changeset when the slug is invalid" do
      scope = user_scope_fixture()
      show = show_fixture(scope)

      assert {:error, %Ecto.Changeset{}} = Broadcasts.update_show(scope, show, %{"slug" => ""})
    end
  end

  describe "ownership" do
    test "list_shows/1 only returns the scope's own shows" do
      scope = user_scope_fixture()
      other = user_scope_fixture()

      mine = show_fixture(scope, %{title: "Mine"})
      _theirs = show_fixture(other, %{title: "Theirs"})

      assert [%Show{id: id}] = Broadcasts.list_shows(scope)
      assert id == mine.id
    end

    test "the scoped reads cannot reach somebody else's show" do
      scope = user_scope_fixture()
      theirs = show_fixture(user_scope_fixture())

      assert_raise Ecto.NoResultsError, fn -> Broadcasts.get_show!(scope, theirs.id) end
      assert_raise Ecto.NoResultsError, fn -> Broadcasts.get_show_by_slug!(scope, theirs.slug) end
    end

    test "the public read reaches any show, because overlays cannot log in" do
      theirs = show_fixture(user_scope_fixture(), %{title: "On Air"})

      assert Broadcasts.get_public_show_by_slug!(theirs.slug).title == "On Air"
    end

    test "writing to somebody else's show raises" do
      scope = user_scope_fixture()
      theirs = show_fixture(user_scope_fixture())

      assert_raise NotOwnerError, fn ->
        Broadcasts.update_show(scope, theirs, %{"stage" => "Hijacked"})
      end

      assert_raise NotOwnerError, fn -> Broadcasts.delete_show(scope, theirs) end
      assert Broadcasts.get_public_show_by_slug!(theirs.slug).stage == ""
    end

    test "claim_unowned_shows/1 adopts shows that pre-date accounts" do
      scope = user_scope_fixture()
      orphan = show_fixture(user_scope_fixture())

      Showish.Repo.update_all(
        from(show in Show, where: show.id == ^orphan.id),
        set: [user_id: nil]
      )

      assert Broadcasts.claim_unowned_shows(scope) == 1
      assert Broadcasts.get_show!(scope, orphan.id).user_id == scope.user.id
    end
  end

  describe "scores" do
    test "adjust_score/3 moves one team and clamps at zero" do
      show = show_fixture()

      assert {:ok, show} = Broadcasts.adjust_score(show, 1, 1)
      assert Show.team(show, 1).score == 1
      assert Show.team(show, 2).score == 0

      assert {:ok, show} = Broadcasts.adjust_score(show, 1, -5)
      assert Show.team(show, 1).score == 0
    end

    test "reset_scores/1 zeroes both teams" do
      show = show_fixture()
      {:ok, show} = Broadcasts.adjust_score(show, 1, 3)
      {:ok, show} = Broadcasts.adjust_score(show, 2, 2)

      assert {:ok, show} = Broadcasts.reset_scores(show)
      assert Enum.map(show.teams, & &1.score) == [0, 0]
    end
  end

  describe "sports" do
    test "the catalogue exposes baseball through the same API as other sports" do
      assert {"Baseball", "baseball"} in Sport.options()
      assert Sport.fetch("baseball").summary =~ "Innings"
      assert Sport.fetch("unknown").key == Sport.default()
    end

    test "baseball actions normalize and clamp live state" do
      show = show_fixture(%{sport: "baseball"})

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "adjust_count", %{
                 "kind" => "balls",
                 "delta" => "9"
               })

      assert show.sport_state["balls"] == 3

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "toggle_base", %{"base" => "first"})

      assert show.sport_state["bases"]["first"]

      assert show.baseball_game
    end

    test "advancing a half inning clears transient game state" do
      show = show_fixture(%{sport: "baseball"})
      {:ok, show} = Broadcasts.apply_sport_action(show, "toggle_base", %{"base" => "third"})

      {:ok, show} =
        Broadcasts.apply_sport_action(show, "adjust_count", %{
          "kind" => "outs",
          "delta" => "2"
        })

      assert {:ok, show} = Broadcasts.apply_sport_action(show, "next_half")
      assert show.sport_state["half"] == "bottom"
      assert show.sport_state["inning"] == 1
      assert show.sport_state["outs"] == 0
      refute show.sport_state["bases"]["third"]

      assert {:ok, show} = Broadcasts.apply_sport_action(show, "next_half")
      assert show.sport_state["half"] == "top"
      assert show.sport_state["inning"] == 2
    end

    test "baseball lineups and pitchers retain validated live stats" do
      show = show_fixture(%{sport: "baseball"})

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "save_lineup", %{
                 "lineup" => %{"position" => "1", "names" => "A. Leadoff\nB. Slugger"}
               })

      assert Enum.map(show.sport_state["lineups"]["1"], & &1["name"]) == [
               "A. Leadoff",
               "B. Slugger"
             ]

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "set_batter", %{
                 "position" => "1",
                 "index" => "1"
               })

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "record_play", %{"result" => "single"})

      assert Enum.at(show.sport_state["lineups"]["1"], 1)["at_bats"] == 1
      assert Enum.at(show.sport_state["lineups"]["1"], 1)["hits"] == 1

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "save_pitcher", %{
                 "pitcher" => %{"position" => "2", "name" => "Phillips"}
               })

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "adjust_pitch_count", %{
                 "position" => "2",
                 "delta" => "30"
               })

      assert Map.take(show.sport_state["pitchers"]["2"], ~w(name pitch_count)) == %{
               "name" => "Phillips",
               "pitch_count" => 30
             }
    end

    test "a combined roster paste saves batting order and defensive alignment" do
      show = show_fixture(%{sport: "baseball"})

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "save_roster", %{
                 "roster" => %{
                   "position" => "1",
                   "entries" =>
                     "1. A. Leadoff | CF\n2) B. Slugger, 1B\nC. Shortstop - SS\nP: D. Pitcher"
                 }
               })

      assert Enum.map(show.sport_state["lineups"]["1"], & &1["name"]) == [
               "A. Leadoff",
               "B. Slugger",
               "C. Shortstop"
             ]

      assert show.sport_state["defense"]["1"]["CF"] == "A. Leadoff"
      assert show.sport_state["defense"]["1"]["1B"] == "B. Slugger"
      assert show.sport_state["defense"]["1"]["SS"] == "C. Shortstop"
      assert show.sport_state["defense"]["1"]["P"] == "D. Pitcher"
      assert Enum.at(show.sport_state["lineups"]["1"], 0)["field_position"] == "CF"
    end

    test "live pitch actions advance the count, pitcher and inning and can be undone" do
      show = show_fixture(%{sport: "baseball"})

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "record_pitch", %{"result" => "ball"})

      assert show.sport_state["balls"] == 1
      assert show.sport_state["pitchers"]["2"]["pitch_count"] == 1

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "record_pitch", %{"result" => "strike"})

      assert show.sport_state["strikes"] == 1
      assert show.sport_state["pitchers"]["2"]["pitch_count"] == 2

      assert {:ok, show} = Broadcasts.apply_sport_action(show, "undo")
      assert show.sport_state["strikes"] == 0
      assert show.sport_state["pitchers"]["2"]["pitch_count"] == 1

      show =
        Enum.reduce(1..3, show, fn _out, current_show ->
          assert {:ok, updated_show} =
                   Broadcasts.apply_sport_action(current_show, "record_play", %{
                     "result" => "out"
                   })

          updated_show
        end)

      assert show.sport_state["half"] == "bottom"
      assert show.sport_state["outs"] == 0
      assert show.sport_state["pitchers"]["2"]["pitch_count"] == 1
    end

    test "baseball scene data is parsed into safe structured fields" do
      show = show_fixture(%{sport: "baseball"})

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "save_defense", %{
                 "defense" => %{
                   "position" => "1",
                   "players" => "P: Jordan Lee\nSS: Morgan Ellis\nNOPE: Ignored"
                 }
               })

      assert show.sport_state["defense"]["1"]["P"] == "Jordan Lee"
      assert show.sport_state["defense"]["1"]["SS"] == "Morgan Ellis"
      refute Map.has_key?(show.sport_state["defense"]["1"], "NOPE")

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "save_bullpen", %{
                 "bullpen" => %{
                   "position" => "2",
                   "pitchers" => "Taylor Reed | Warming\nCasey Park"
                 }
               })

      assert Enum.map(show.sport_state["bullpens"]["2"], &Map.take(&1, ~w(name status))) == [
               %{"name" => "Taylor Reed", "status" => "Warming"},
               %{"name" => "Casey Park", "status" => "Available"}
             ]
    end

    test "current pitchers can drive database-backed spotlight graphics" do
      show = show_fixture(%{sport: "baseball"})

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "save_lineup", %{
                 "lineup" => %{"position" => "1", "names" => "Test Batter"}
               })

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "save_pitcher", %{
                 "pitcher" => %{"position" => "2", "name" => "Phillips"}
               })

      show =
        Enum.reduce(1..3, show, fn _pitch, current ->
          assert {:ok, updated} =
                   Broadcasts.apply_sport_action(current, "record_pitch", %{
                     "result" => "strike"
                   })

          updated
        end)

      pitcher_id = show.sport_state["pitchers"]["2"]["id"]

      assert {:ok, selected} =
               Broadcasts.apply_sport_action(show, "select_highlights", %{
                 "highlight" => %{"spotlight_player_id" => to_string(pitcher_id)}
               })

      graphic = selected.sport_state["graphics"]["single"]
      assert graphic["name"] == "Phillips"
      assert graphic["detail"] == "PITCHER"
      assert graphic["selected_player_id"] == pitcher_id

      assert graphic["stats"] == [
               %{"label" => "IP", "value" => "0.1"},
               %{"label" => "P", "value" => "3"},
               %{"label" => "BF", "value" => "1"},
               %{"label" => "H", "value" => "0"},
               %{"label" => "BB", "value" => "0"},
               %{"label" => "SO", "value" => "1"}
             ]
    end

    test "a strikeout records an at-bat before advancing the lineup" do
      show = show_fixture(%{sport: "baseball"})

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "save_lineup", %{
                 "lineup" => %{"position" => "1", "names" => "A. Leadoff\nB. Slugger"}
               })

      show =
        Enum.reduce(1..3, show, fn _pitch, current_show ->
          assert {:ok, updated_show} =
                   Broadcasts.apply_sport_action(current_show, "record_pitch", %{
                     "result" => "strike"
                   })

          updated_show
        end)

      assert Map.take(Enum.at(show.sport_state["lineups"]["1"], 0), ~w(name hits at_bats)) == %{
               "name" => "A. Leadoff",
               "hits" => 0,
               "at_bats" => 1
             }

      assert show.sport_state["active_batters"]["1"] == 1
      assert show.sport_state["outs"] == 1
    end

    test "special plate appearance outcomes preserve official at-bat semantics" do
      show = show_fixture(%{sport: "baseball"})

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "save_lineup", %{
                 "lineup" => %{"position" => "1", "names" => "Test Batter"}
               })

      for {result, expected} <- [
            {"sacrifice_bunt", %{at_bats: 0, strikeouts: 0, outs: 1, first: false}},
            {"interference", %{at_bats: 0, strikeouts: 0, outs: 0, first: true}},
            {"strikeout_reached", %{at_bats: 1, strikeouts: 1, outs: 0, first: true}},
            {"strikeout", %{at_bats: 1, strikeouts: 1, outs: 1, first: false}}
          ] do
        assert {:ok, played} =
                 Broadcasts.apply_sport_action(show, "record_play", %{"result" => result})

        [batter] = played.sport_state["lineups"]["1"]
        assert batter["at_bats"] == expected.at_bats
        assert batter["strikeouts"] == expected.strikeouts
        assert played.sport_state["outs"] == expected.outs
        assert played.sport_state["bases"]["first"] == expected.first

        assert {:ok, undone} = Broadcasts.apply_sport_action(played, "undo")
        [batter] = undone.sport_state["lineups"]["1"]
        assert batter["at_bats"] == 0
        assert batter["strikeouts"] == 0
        assert undone.sport_state["outs"] == 0
        refute undone.sport_state["bases"]["first"]
      end
    end

    test "sacrifice flies and home runs update scores and undo atomically" do
      show = show_fixture(%{sport: "baseball"})

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "save_lineup", %{
                 "lineup" => %{"position" => "1", "names" => "Test Batter"}
               })

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "toggle_base", %{"base" => "third"})

      assert {:ok, sacrifice} =
               Broadcasts.apply_sport_action(show, "record_play", %{
                 "result" => "sacrifice_fly"
               })

      [batter] = sacrifice.sport_state["lineups"]["1"]
      assert batter["at_bats"] == 0
      assert batter["rbi"] == 1
      assert Show.team(sacrifice, 1).score == 1
      assert sacrifice.sport_state["outs"] == 1
      refute sacrifice.sport_state["bases"]["third"]

      assert {:ok, undone} = Broadcasts.apply_sport_action(sacrifice, "undo")
      assert Show.team(undone, 1).score == 0
      assert undone.sport_state["outs"] == 0
      assert undone.sport_state["bases"]["third"]
      assert undone.baseball_game.plate_appearances == []

      assert {:ok, homer} =
               Broadcasts.apply_sport_action(undone, "record_play", %{
                 "result" => "home_run"
               })

      assert Show.team(homer, 1).score == 2
      assert {:ok, homer_undone} = Broadcasts.apply_sport_action(homer, "undo")
      assert Show.team(homer_undone, 1).score == 0
      assert homer_undone.sport_state["bases"]["third"]
    end

    test "walks force occupied runners and double plays record two outs" do
      show = show_fixture(%{sport: "baseball"})

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "save_lineup", %{
                 "lineup" => %{"position" => "1", "names" => "Test Batter"}
               })

      show =
        Enum.reduce(~w(first second third), show, fn base, current ->
          assert {:ok, updated} =
                   Broadcasts.apply_sport_action(current, "toggle_base", %{"base" => base})

          updated
        end)

      assert {:ok, walked} =
               Broadcasts.apply_sport_action(show, "record_play", %{"result" => "walk"})

      assert Show.team(walked, 1).score == 1
      assert Enum.all?(Map.values(walked.sport_state["bases"]))

      assert {:ok, reset} = Broadcasts.apply_sport_action(walked, "undo")

      assert {:ok, doubled_up} =
               Broadcasts.apply_sport_action(reset, "record_play", %{
                 "result" => "double_play",
                 "notation" => "463"
               })

      assert doubled_up.sport_state["outs"] == 2
      refute doubled_up.sport_state["bases"]["first"]

      assert doubled_up.sport_state["last_play"] == %{
               "result" => "double_play",
               "notation" => "4-6-3"
             }

      assert List.last(doubled_up.baseball_game.plate_appearances).notation == "4-6-3"
    end

    test "bases-loaded reaches score the forced runner and preserve a loaded diamond" do
      show = show_fixture(%{sport: "baseball"})

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "save_lineup", %{
                 "lineup" => %{"position" => "1", "names" => "Test Batter"}
               })

      loaded =
        Enum.reduce(~w(first second third), show, fn base, current ->
          assert {:ok, updated} =
                   Broadcasts.apply_sport_action(current, "toggle_base", %{"base" => base})

          updated
        end)

      for {result, expected_rbi} <- [
            {"single", 1},
            {"walk", 1},
            {"hit_by_pitch", 1},
            {"interference", 1},
            {"reached_on_error", 0},
            {"strikeout_reached", 0}
          ] do
        assert {:ok, played} =
                 Broadcasts.apply_sport_action(loaded, "record_play", %{"result" => result})

        [batter] = played.sport_state["lineups"]["1"]
        assert Show.team(played, 1).score == 1
        assert batter["rbi"] == expected_rbi
        assert played.sport_state["outs"] == 0
        assert Enum.all?(Map.values(played.sport_state["bases"]))

        assert {:ok, undone} = Broadcasts.apply_sport_action(played, "undo")
        assert Show.team(undone, 1).score == 0
        assert Enum.all?(Map.values(undone.sport_state["bases"]))
      end
    end

    test "a single advances existing runners one base when no notation overrides it" do
      show = show_fixture(%{sport: "baseball"})

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "save_lineup", %{
                 "lineup" => %{"position" => "1", "names" => "Test Batter"}
               })

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "toggle_base", %{"base" => "third"})

      assert {:ok, played} =
               Broadcasts.apply_sport_action(show, "record_play", %{"result" => "single"})

      assert Show.team(played, 1).score == 1

      assert played.sport_state["bases"] == %{
               "first" => true,
               "second" => false,
               "third" => false
             }
    end

    test "explicit single advances do not move the same runner twice" do
      show = show_fixture(%{sport: "baseball"})

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "save_lineup", %{
                 "lineup" => %{"position" => "1", "names" => "Test Batter"}
               })

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "toggle_base", %{"base" => "first"})

      assert {:ok, played} =
               Broadcasts.apply_sport_action(show, "record_play", %{
                 "play" => %{"result" => "out", "notation" => "1B.1-3"}
               })

      [batter] = played.sport_state["lineups"]["1"]
      assert {batter["hits"], batter["at_bats"], batter["rbi"]} == {1, 1, 0}
      assert Show.team(played, 1).score == 0

      assert played.sport_state["bases"] == %{
               "first" => true,
               "second" => false,
               "third" => true
             }
    end

    test "unspecified runners still take their normal advance on an explicit single" do
      show = show_fixture(%{sport: "baseball"})

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "save_lineup", %{
                 "lineup" => %{"position" => "1", "names" => "Test Batter"}
               })

      show =
        Enum.reduce(~w(first third), show, fn base, current ->
          assert {:ok, updated} =
                   Broadcasts.apply_sport_action(current, "toggle_base", %{"base" => base})

          updated
        end)

      assert {:ok, played} =
               Broadcasts.apply_sport_action(show, "record_play", %{
                 "play" => %{"result" => "out", "notation" => "1B.1-3"}
               })

      assert Show.team(played, 1).score == 1

      assert Enum.all?([
               played.sport_state["bases"]["first"],
               played.sport_state["bases"]["third"]
             ])

      refute played.sport_state["bases"]["second"]
    end

    test "scorebook notation overrides a mismatched quick-result button" do
      show = show_fixture(%{sport: "baseball"})

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "save_lineup", %{
                 "lineup" => %{"position" => "1", "names" => "Error Batter"}
               })

      assert {:ok, played} =
               Broadcasts.apply_sport_action(show, "record_play", %{
                 "play" => %{"result" => "out", "notation" => "E1"}
               })

      [batter] = played.sport_state["lineups"]["1"]
      assert {batter["hits"], batter["at_bats"]} == {0, 1}
      assert played.sport_state["outs"] == 0
      assert played.sport_state["bases"]["first"]
      assert played.sport_state["errors"]["2"] == 1

      assert played.sport_state["last_play"] == %{
               "result" => "reached_on_error",
               "notation" => "E1"
             }
    end

    test "scorebook advance clauses move existing runners without overwriting them" do
      show = show_fixture(%{sport: "baseball"})

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "save_lineup", %{
                 "lineup" => %{"position" => "1", "names" => "Runner\nError Batter"}
               })

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "record_play", %{"result" => "single"})

      assert {:ok, played} =
               Broadcasts.apply_sport_action(show, "record_play", %{
                 "play" => %{"result" => "out", "notation" => "E1.1-3"}
               })

      assert played.sport_state["outs"] == 0

      assert played.sport_state["bases"] == %{
               "first" => true,
               "second" => false,
               "third" => true
             }

      assert played.sport_state["last_play"] == %{
               "result" => "reached_on_error",
               "notation" => "E1.1-3"
             }
    end

    test "scorebook advance clauses score runners without crediting an RBI on an error" do
      show = show_fixture(%{sport: "baseball"})

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "save_lineup", %{
                 "lineup" => %{"position" => "1", "names" => "Error Batter"}
               })

      show =
        Enum.reduce(~w(first second), show, fn base, current ->
          assert {:ok, updated} =
                   Broadcasts.apply_sport_action(current, "toggle_base", %{"base" => base})

          updated
        end)

      assert {:ok, played} =
               Broadcasts.apply_sport_action(show, "record_play", %{
                 "play" => %{"result" => "out", "notation" => "E1.1-3;2-H"}
               })

      [batter] = played.sport_state["lineups"]["1"]
      assert Show.team(played, 1).score == 1
      assert batter["rbi"] == 0

      assert played.sport_state["bases"] == %{
               "first" => true,
               "second" => false,
               "third" => true
             }
    end

    test "scorebook batter advances can place an error batter directly on second" do
      show = show_fixture(%{sport: "baseball"})

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "save_lineup", %{
                 "lineup" => %{"position" => "1", "names" => "Error Batter"}
               })

      assert {:ok, played} =
               Broadcasts.apply_sport_action(show, "record_play", %{
                 "play" => %{"result" => "out", "notation" => "E1.B-2"}
               })

      [batter] = played.sport_state["lineups"]["1"]
      assert {batter["hits"], batter["at_bats"], batter["rbi"]} == {0, 1, 0}
      assert played.sport_state["outs"] == 0

      assert played.sport_state["bases"] == %{
               "first" => false,
               "second" => true,
               "third" => false
             }
    end

    test "notation-only submissions infer a complete plate appearance" do
      show = show_fixture(%{sport: "baseball"})

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "save_lineup", %{
                 "lineup" => %{"position" => "1", "names" => "Batter"}
               })

      assert {:ok, played} =
               Broadcasts.apply_sport_action(show, "record_play", %{
                 "play" => %{"result" => "auto", "notation" => "F8"}
               })

      assert played.sport_state["outs"] == 1
      assert played.sport_state["last_play"] == %{"result" => "out", "notation" => "F8"}
    end

    test "hits, errors and walks derive different batting lines from plate appearances" do
      show = show_fixture(%{sport: "baseball"})

      {:ok, show} =
        Broadcasts.apply_sport_action(show, "save_lineup", %{
          "lineup" => %{"position" => "1", "names" => "Hit Batter\nError Batter\nWalk Batter"}
        })

      {:ok, show} = Broadcasts.apply_sport_action(show, "record_play", %{"result" => "single"})

      {:ok, show} =
        Broadcasts.apply_sport_action(show, "record_play", %{"result" => "reached_on_error"})

      {:ok, show} = Broadcasts.apply_sport_action(show, "record_play", %{"result" => "walk"})

      [hit, error, walk] = show.sport_state["lineups"]["1"]
      assert {hit["hits"], hit["at_bats"]} == {1, 1}
      assert {error["hits"], error["at_bats"]} == {0, 1}
      assert {walk["hits"], walk["at_bats"]} == {0, 0}
      assert show.sport_state["hits"]["1"] == 1
      assert show.sport_state["errors"]["2"] == 1
      assert show.sport_state["graphics"]["single"]["name"] == "Hit Batter"
      assert length(show.baseball_game.plate_appearances) == 3
    end

    test "resetting a baseball game clears state and runs together" do
      show = show_fixture(%{sport: "baseball"})
      {:ok, show} = Broadcasts.adjust_score(show, 1, 4)

      assert {:ok, show} = Broadcasts.reset_sport(show)
      assert Enum.map(show.teams, & &1.score) == [0, 0]
      assert show.sport_state["inning"] == 1
      assert show.sport_state["hits"] == %{"1" => 0, "2" => 0}
      assert show.sport_state["errors"] == %{"1" => 0, "2" => 0}
      assert show.baseball_game.plate_appearances == []
    end
  end

  describe "the series" do
    test "move_current_game/2 clamps to the games that exist" do
      show = show_with_games_fixture(2)

      assert {:ok, show} = Broadcasts.move_current_game(show, 1)
      assert show.current_game == 2

      assert {:ok, show} = Broadcasts.move_current_game(show, 1)
      assert show.current_game == 2

      assert {:ok, show} = Broadcasts.move_current_game(show, -5)
      assert show.current_game == 1
    end

    test "set_game_winner/3 toggles the same call off again" do
      show = show_with_games_fixture(1)
      [game] = show.games

      assert {:ok, show} = Broadcasts.set_game_winner(show, game.id, "a")
      assert [%{winner: "a", completed: true}] = show.games

      assert {:ok, show} = Broadcasts.set_game_winner(show, game.id, "a")
      assert [%{winner: "", completed: false}] = show.games
    end

    test "add_game/1 appends and delete_game/2 renumbers" do
      show = show_with_games_fixture(3)
      assert Enum.map(show.games, & &1.position) == [0, 1, 2]

      [_first, second, _third] = show.games
      assert {:ok, show} = Broadcasts.delete_game(show, second.id)

      assert length(show.games) == 2
      assert Enum.map(show.games, & &1.position) == [0, 1]
    end

    test "move_game/3 swaps neighbours and no-ops at the edges" do
      show = show_with_games_fixture(2)
      [first, second] = show.games

      assert {:ok, show} = Broadcasts.move_game(show, first.id, 1)
      assert Enum.map(show.games, & &1.id) == [second.id, first.id]

      assert {:ok, show} = Broadcasts.move_game(show, second.id, -1)
      assert Enum.map(show.games, & &1.id) == [second.id, first.id]
    end
  end

  describe "talent" do
    test "add_talent/1 and delete_talent/2 keep positions dense" do
      show = show_fixture()

      show = Enum.reduce(1..3, show, fn _i, acc -> elem(Broadcasts.add_talent(acc), 1) end)
      assert Enum.map(show.talents, & &1.position) == [0, 1, 2]

      [_first, second, _third] = show.talents
      assert {:ok, show} = Broadcasts.delete_talent(show, second.id)
      assert Enum.map(show.talents, & &1.position) == [0, 1]
    end
  end

  describe "pubsub" do
    test "subscribers are pushed the whole show on every write" do
      scope = user_scope_fixture()
      show = show_fixture(scope)
      :ok = Broadcasts.subscribe(show.slug)

      {:ok, _updated} = Broadcasts.update_show(scope, show, %{"stage" => "Finals"})

      assert_receive {:show_updated, %Show{stage: "Finals", teams: [_, _]}}
    end

    test "operator actions broadcast too" do
      show = show_fixture()
      :ok = Broadcasts.subscribe(show.slug)

      {:ok, _updated} = Broadcasts.adjust_score(show, 2, 1)

      assert_receive {:show_updated, %Show{} = pushed}
      assert Show.team(pushed, 2).score == 1
    end
  end

  describe "Show helpers" do
    test "sides/1 honours swap_sides" do
      show = show_fixture()
      {left, right} = Show.sides(show)
      assert left.position == 1
      assert right.position == 2

      {:ok, show} = Broadcasts.swap_sides(show)
      {left, right} = Show.sides(show)
      assert left.position == 2
      assert right.position == 1
    end

    test "center_line/1 prefers the explicit status, then the current game" do
      scope = user_scope_fixture()

      show =
        show_fixture(scope, %{
          "status_center" => "Overtime",
          "show_status_center" => true
        })

      assert Show.center_line(show) == "Overtime"

      {:ok, show} = Broadcasts.update_show(scope, show, %{"show_status_center" => false})
      {:ok, show} = Broadcasts.add_game(show)

      {:ok, show} =
        Broadcasts.update_show(scope, show, %{"games" => game_params(show, "Old Harbour")})

      assert Show.center_line(show) == "Game 1 · Old Harbour"
    end
  end

  defp game_params(show, name) do
    Enum.map(show.games, fn game ->
      %{"id" => game.id, "name" => name}
    end)
  end
end
