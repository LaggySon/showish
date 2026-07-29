defmodule Showish.BroadcastsTest do
  use Showish.DataCase, async: true

  import Showish.BroadcastsFixtures

  alias Showish.Broadcasts
  alias Showish.Broadcasts.Show

  doctest Showish.Broadcasts.Show

  describe "create_show/1" do
    test "seeds two teams so a show can go on air immediately" do
      show = show_fixture(%{title: "Cup Final", slug: "cup-final"})

      assert show.slug == "cup-final"
      assert [%{position: 1}, %{position: 2}] = show.teams
    end

    test "tidies a human-typed slug rather than rejecting it" do
      assert {:ok, show} = Broadcasts.create_show(%{"title" => "T", "slug" => "Not A Slug!"})
      assert show.slug == "not-a-slug"
    end

    test "rejects a slug with nothing usable in it" do
      assert {:error, changeset} = Broadcasts.create_show(%{"title" => "T", "slug" => "!!!"})
      assert %{slug: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires a unique slug" do
      show_fixture(%{slug: "taken"})

      assert {:error, changeset} = Broadcasts.create_show(%{"title" => "T", "slug" => "taken"})
      assert %{slug: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "update_show/2" do
    test "updates the show and keeps children ordered" do
      show = show_with_games_fixture(3)

      assert {:ok, updated} = Broadcasts.update_show(show, %{"stage" => "Semi Final"})
      assert updated.stage == "Semi Final"
      assert Enum.map(updated.games, & &1.position) == [0, 1, 2]
    end

    test "returns a changeset when the slug is invalid" do
      show = show_fixture()

      assert {:error, %Ecto.Changeset{}} = Broadcasts.update_show(show, %{"slug" => ""})
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
      show = show_fixture()
      :ok = Broadcasts.subscribe(show.slug)

      {:ok, _updated} = Broadcasts.update_show(show, %{"stage" => "Finals"})

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
      show =
        show_fixture(%{
          "status_center" => "Overtime",
          "show_status_center" => true
        })

      assert Show.center_line(show) == "Overtime"

      {:ok, show} = Broadcasts.update_show(show, %{"show_status_center" => false})
      {:ok, show} = Broadcasts.add_game(show)
      {:ok, show} = Broadcasts.update_show(show, %{"games" => game_params(show, "Old Harbour")})

      assert Show.center_line(show) == "Game 1 · Old Harbour"
    end
  end

  defp game_params(show, name) do
    Enum.map(show.games, fn game ->
      %{"id" => game.id, "name" => name}
    end)
  end
end
