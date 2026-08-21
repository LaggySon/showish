defmodule Showish.Baseball.LineupSpot do
  @moduledoc "A player's batting-order and defensive assignment for a baseball game."

  use Ecto.Schema
  import Ecto.Changeset

  schema "baseball_lineup_spots" do
    field :batting_order, :integer
    field :field_position, :string, default: ""
    field :starter, :boolean, default: true

    belongs_to :game, Showish.Baseball.Game
    belongs_to :team, Showish.Broadcasts.Team
    belongs_to :player, Showish.Baseball.Player
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(spot, attrs) do
    spot
    |> cast(attrs, [:batting_order, :field_position, :starter])
    |> validate_number(:batting_order, greater_than_or_equal_to: 1, less_than_or_equal_to: 20)
    |> validate_inclusion(:field_position, [
      "",
      "P",
      "C",
      "1B",
      "2B",
      "3B",
      "SS",
      "LF",
      "CF",
      "RF",
      "DH"
    ])
    |> unique_constraint([:game_id, :player_id])
    |> unique_constraint([:game_id, :team_id, :batting_order])
  end
end
