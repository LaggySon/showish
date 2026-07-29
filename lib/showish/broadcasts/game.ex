defmodule Showish.Broadcasts.Game do
  @moduledoc """
  A single game/map/set within a show's series.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @winners ~w(a b draw)

  schema "games" do
    field :position, :integer, default: 0
    field :name, :string, default: ""
    field :mode, :string, default: ""
    field :image_url, :string, default: ""
    field :score_a, :integer, default: 0
    field :score_b, :integer, default: 0
    field :winner, :string, default: ""
    field :completed, :boolean, default: false
    field :info, :string, default: ""

    belongs_to :show, Showish.Broadcasts.Show

    timestamps(type: :utc_datetime)
  end

  @castable ~w(position name mode image_url score_a score_b winner completed info)a

  def changeset(game, attrs) do
    game
    |> cast(attrs, @castable)
    |> validate_inclusion(:winner, ["" | @winners])
  end

  @doc "Valid values for the `winner` field, excluding \"not decided\"."
  def winners, do: @winners

  @doc "Human label for a game, e.g. `Game 3`."
  def label(%__MODULE__{position: position}), do: "Game #{position + 1}"
end
