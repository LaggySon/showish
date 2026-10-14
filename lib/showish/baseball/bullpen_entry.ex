defmodule Showish.Baseball.BullpenEntry do
  @moduledoc "A pitcher's ordered bullpen availability for one game."

  use Ecto.Schema
  import Ecto.Changeset

  schema "baseball_bullpen_entries" do
    field :position, :integer, default: 0
    field :status, :string, default: "Available"

    belongs_to :game, Showish.Baseball.Game
    belongs_to :team, Showish.Broadcasts.Team
    belongs_to :player, Showish.Baseball.Player
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:position, :status])
    |> validate_required([:position, :status])
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> unique_constraint([:game_id, :player_id])
  end
end
