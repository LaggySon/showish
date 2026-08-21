defmodule Showish.Baseball.PlateAppearance do
  @moduledoc "One completed trip to the plate, from which batting statistics are derived."

  use Ecto.Schema
  import Ecto.Changeset

  schema "baseball_plate_appearances" do
    field :sequence, :integer
    field :inning, :integer
    field :half, :string
    field :result, :string
    field :at_bat, :boolean, default: true
    field :hit_value, :integer, default: 0
    field :rbi, :integer, default: 0
    field :runs_scored, :integer, default: 0
    field :outs_recorded, :integer, default: 0

    belongs_to :game, Showish.Baseball.Game
    belongs_to :event, Showish.Baseball.Event
    belongs_to :batter, Showish.Baseball.Player
    belongs_to :pitcher, Showish.Baseball.Player
    belongs_to :batting_team, Showish.Broadcasts.Team
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @results ~w(single double triple home_run walk hit_by_pitch reached_on_error
              fielders_choice sacrifice out strikeout)

  def changeset(appearance, attrs) do
    appearance
    |> cast(attrs, [
      :sequence,
      :inning,
      :half,
      :result,
      :at_bat,
      :hit_value,
      :rbi,
      :runs_scored,
      :outs_recorded
    ])
    |> validate_required([:sequence, :inning, :half, :result])
    |> validate_inclusion(:half, ~w(top bottom))
    |> validate_inclusion(:result, @results)
    |> validate_number(:hit_value, greater_than_or_equal_to: 0, less_than_or_equal_to: 4)
    |> validate_number(:rbi, greater_than_or_equal_to: 0)
    |> validate_number(:runs_scored, greater_than_or_equal_to: 0)
    |> validate_number(:outs_recorded, greater_than_or_equal_to: 0, less_than_or_equal_to: 3)
    |> unique_constraint([:game_id, :sequence])
  end
end
