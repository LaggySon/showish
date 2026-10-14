defmodule Showish.Baseball.Pitch do
  @moduledoc "One recorded pitch in a baseball game's pitch log."

  use Ecto.Schema
  import Ecto.Changeset

  schema "baseball_pitches" do
    field :sequence, :integer
    field :result, :string
    field :balls_before, :integer
    field :strikes_before, :integer

    belongs_to :game, Showish.Baseball.Game
    belongs_to :event, Showish.Baseball.Event
    belongs_to :batter, Showish.Baseball.Player
    belongs_to :pitcher, Showish.Baseball.Player
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(pitch, attrs) do
    pitch
    |> cast(attrs, [:sequence, :result, :balls_before, :strikes_before])
    |> validate_required([:sequence, :result, :balls_before, :strikes_before])
    |> validate_inclusion(:result, ~w(ball strike foul in_play))
    |> unique_constraint([:game_id, :sequence])
  end
end
