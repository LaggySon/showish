defmodule Showish.Broadcasts.Sports.Esports do
  @moduledoc "The existing best-of-games Showish workflow."

  @behaviour Showish.Broadcasts.Sport

  @impl true
  def metadata do
    %{
      key: "esports",
      name: "Esports / series",
      summary: "Best-of series with maps, modes and per-game results.",
      control_title: "On air",
      control_summary: "The controls you reach for during a match."
    }
  end

  @impl true
  def default_state, do: %{}

  @impl true
  def normalize_state(_state), do: %{}

  @impl true
  def transition(_state, _action, _params), do: {:error, :unsupported_sport_action}
end
