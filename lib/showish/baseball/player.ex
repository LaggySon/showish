defmodule Showish.Baseball.Player do
  @moduledoc "A baseball player on a show's team roster."

  use Ecto.Schema
  import Ecto.Changeset

  schema "baseball_players" do
    field :name, :string
    field :jersey_number, :string, default: ""
    field :bats, :string, default: ""
    field :throws, :string, default: ""
    field :active, :boolean, default: true

    belongs_to :team, Showish.Broadcasts.Team
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(player, attrs) do
    player
    |> cast(attrs, [:name, :jersey_number, :bats, :throws, :active])
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name])
    |> unique_constraint([:team_id, :name])
  end
end
