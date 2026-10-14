defmodule ShowishWeb.StatusTest do
  use ExUnit.Case, async: true

  alias Showish.Broadcasts.Game
  alias Showish.Broadcasts.Show
  alias ShowishWeb.Status

  doctest ShowishWeb.Status

  describe "game/3" do
    test "the game on air outranks a played game" do
      show = %Show{current_game: 2}

      assert Status.game(show, 2, %Game{completed: true}) == {"On air", "progress"}
      assert Status.game(show, 1, %Game{completed: true}) == {"Played", "success"}
      assert Status.game(show, 3, %Game{completed: false}) == {"Upcoming", "neutral"}
    end
  end
end
