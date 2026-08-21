defmodule Showish.Baseball.Game do
  @moduledoc "Persisted live state for one baseball game attached to a show."

  use Ecto.Schema
  import Ecto.Changeset

  schema "baseball_games" do
    field :inning, :integer, default: 1
    field :half, :string, default: "top"
    field :balls, :integer, default: 0
    field :strikes, :integer, default: 0
    field :outs, :integer, default: 0
    field :first_occupied, :boolean, default: false
    field :second_occupied, :boolean, default: false
    field :third_occupied, :boolean, default: false
    field :away_batter_order, :integer, default: 1
    field :home_batter_order, :integer, default: 1
    field :away_pitch_count, :integer, default: 0
    field :home_pitch_count, :integer, default: 0

    belongs_to :show, Showish.Broadcasts.Show
    belongs_to :away_pitcher, Showish.Baseball.Player
    belongs_to :home_pitcher, Showish.Baseball.Player
    belongs_to :first_runner, Showish.Baseball.Player
    belongs_to :second_runner, Showish.Baseball.Player
    belongs_to :third_runner, Showish.Baseball.Player
    belongs_to :spotlight_player, Showish.Baseball.Player
    belongs_to :comparison_left_player, Showish.Baseball.Player
    belongs_to :comparison_right_player, Showish.Baseball.Player

    has_many :lineup_spots, Showish.Baseball.LineupSpot, preload_order: [asc: :batting_order]
    has_many :plate_appearances, Showish.Baseball.PlateAppearance, preload_order: [asc: :sequence]
    has_many :pitches, Showish.Baseball.Pitch, preload_order: [asc: :sequence]
    has_many :bullpen_entries, Showish.Baseball.BullpenEntry, preload_order: [asc: :position]
    has_many :events, Showish.Baseball.Event, preload_order: [asc: :sequence]

    timestamps(type: :utc_datetime_usec)
  end

  @fields ~w(inning half balls strikes outs first_occupied second_occupied third_occupied
             away_batter_order home_batter_order away_pitch_count home_pitch_count
             away_pitcher_id home_pitcher_id first_runner_id second_runner_id third_runner_id
             spotlight_player_id comparison_left_player_id comparison_right_player_id)a

  def changeset(game, attrs) do
    game
    |> cast(attrs, @fields)
    |> validate_required([:inning, :half, :balls, :strikes, :outs])
    |> validate_inclusion(:half, ~w(top bottom))
    |> validate_number(:inning, greater_than_or_equal_to: 1)
    |> validate_number(:balls, greater_than_or_equal_to: 0, less_than_or_equal_to: 3)
    |> validate_number(:strikes, greater_than_or_equal_to: 0, less_than_or_equal_to: 2)
    |> validate_number(:outs, greater_than_or_equal_to: 0, less_than_or_equal_to: 2)
  end
end
