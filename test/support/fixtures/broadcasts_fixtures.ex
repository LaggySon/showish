defmodule Showish.BroadcastsFixtures do
  @moduledoc """
  Test helpers for creating shows.
  """

  alias Showish.Broadcasts

  @doc """
  Creates a show with the two default teams, plus whatever the caller overrides.
  """
  def show_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs, fn {key, value} -> {to_string(key), value} end)

    {:ok, show} =
      %{
        "slug" => "show-#{System.unique_integer([:positive])}",
        "title" => "Test Show"
      }
      |> Map.merge(attrs)
      |> Broadcasts.create_show()

    show
  end

  @doc "Creates a show with `count` empty games in its series."
  def show_with_games_fixture(count \\ 3, attrs \\ %{}) do
    show = show_fixture(attrs)

    Enum.reduce(1..count, show, fn _index, acc ->
      {:ok, show} = Broadcasts.add_game(acc)
      show
    end)
  end
end
