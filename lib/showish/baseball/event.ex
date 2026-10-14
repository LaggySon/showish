defmodule Showish.Baseball.Event do
  @moduledoc "Auditable operator action with the live state needed for exact undo."

  use Ecto.Schema
  import Ecto.Changeset

  schema "baseball_game_events" do
    field :sequence, :integer
    field :action, :string
    field :params, :map, default: %{}
    field :state_before, :map, default: %{}

    belongs_to :game, Showish.Baseball.Game
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:sequence, :action, :params, :state_before])
    |> validate_required([:sequence, :action, :state_before])
    |> unique_constraint([:game_id, :sequence])
  end
end
