defmodule Showish.BroadcastsFixtures do
  @moduledoc """
  Test helpers for creating shows.

  Every show needs an owner, so a scope may be passed in. Tests that do not care
  who owns the show can leave it out and get a throwaway account.
  """

  import Showish.AccountsFixtures

  alias Showish.Accounts.Scope
  alias Showish.Broadcasts

  @doc """
  Creates a show with the two default teams, plus whatever the caller overrides.

  Takes a `Showish.Accounts.Scope`, a map of attributes, or both.
  """
  def show_fixture(scope_or_attrs \\ %{})

  def show_fixture(%Scope{} = scope), do: show_fixture(scope, %{})

  def show_fixture(attrs) when is_map(attrs), do: show_fixture(user_scope_fixture(), attrs)

  def show_fixture(%Scope{} = scope, attrs) do
    attrs = Map.new(attrs, fn {key, value} -> {to_string(key), value} end)

    {:ok, show} =
      %{
        "slug" => "show-#{System.unique_integer([:positive])}",
        "title" => "Test Show"
      }
      |> Map.merge(attrs)
      |> then(&Broadcasts.create_show(scope, &1))

    show
  end

  @doc "Creates a show with `count` empty games in its series."
  def show_with_games_fixture(count \\ 3, scope_or_attrs \\ %{}) do
    show = show_fixture(scope_or_attrs)

    Enum.reduce(1..count, show, fn _index, acc ->
      {:ok, show} = Broadcasts.add_game(acc)
      show
    end)
  end
end
