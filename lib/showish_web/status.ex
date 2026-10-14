defmodule ShowishWeb.Status do
  @moduledoc """
  The state words the control room shows, and the role each one maps to.

  Every page takes its words from here, so two pages that show the same state
  show the same word. The role sets the color through `data-status` (see
  DESIGN.md section 3.1); the word is always on screen too, so color is never
  the only signal.
  """

  alias Showish.Broadcasts.Show

  @doc """
  A game in the series, by its 1-indexed place.

  The game the scorebug describes is on air, whatever else is true of it. A
  completed game is played; the rest are upcoming.
  """
  def game(%Show{current_game: current}, number, _game) when number == current,
    do: {"On air", "progress"}

  def game(%Show{}, _number, %{completed: true}), do: {"Played", "success"}
  def game(%Show{}, _number, _game), do: {"Upcoming", "neutral"}
end
