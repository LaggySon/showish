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

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "adjust_stat", %{
                 "stat" => "hits",
                 "position" => "2",
                 "delta" => "1"
               })

      assert show.sport_state["hits"]["2"] == 1
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
               Broadcasts.apply_sport_action(show, "adjust_batter_stat", %{
                 "position" => "1",
                 "stat" => "at_bats",
                 "delta" => "3"
               })

      assert Enum.at(show.sport_state["lineups"]["1"], 1)["at_bats"] == 3

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "save_pitcher", %{
                 "pitcher" => %{"position" => "2", "name" => "Phillips"}
               })

      assert {:ok, show} =
               Broadcasts.apply_sport_action(show, "adjust_pitch_count", %{
                 "position" => "2",
                 "delta" => "30"
               })

      assert show.sport_state["pitchers"]["2"] == %{
               "name" => "Phillips",
               "pitch_count" => 30
             }
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

    test "resetting a baseball game clears state and runs together" do
      show = show_fixture(%{sport: "baseball"})
      {:ok, show} = Broadcasts.adjust_score(show, 1, 4)

      {:ok, show} =
        Broadcasts.apply_sport_action(show, "adjust_stat", %{
          "stat" => "errors",
          "position" => "2",
          "delta" => "2"
        })

      assert {:ok, show} = Broadcasts.reset_sport(show)
      assert Enum.map(show.teams, & &1.score) == [0, 0]
      assert show.sport_state == Sport.default_state("baseball")
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
