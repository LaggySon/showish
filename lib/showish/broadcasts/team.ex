defmodule Showish.Broadcasts.Team do
  @moduledoc """
  One of the two competitors in a show.

  `position` is 1 or 2 and is the *canonical* identity of the team (team one and
  team two). Which side of an overlay a team is drawn on is a presentation
  concern driven by `Showish.Broadcasts.Show.swap_sides`.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "teams" do
    field :position, :integer, default: 1
    field :name, :string, default: ""
    field :short_name, :string, default: ""
    field :code, :string, default: ""
    field :logo_url, :string, default: ""
    field :record, :string, default: ""
    field :score, :integer, default: 0
    field :primary_color, :string, default: "#1f2937"
    field :secondary_color, :string, default: "#f8fafc"
    field :side, :string, default: ""

    belongs_to :show, Showish.Broadcasts.Show
    has_many :baseball_players, Showish.Baseball.Player

    timestamps(type: :utc_datetime)
  end

  @castable ~w(position name short_name code logo_url record score primary_color
               secondary_color side)a

  def changeset(team, attrs) do
    team
    |> cast(attrs, @castable)
    |> validate_number(:score, greater_than_or_equal_to: 0)
    |> validate_inclusion(:position, 1..2)
    |> Showish.Colors.validate_hex(:primary_color)
    |> Showish.Colors.validate_hex(:secondary_color)
  end

  @doc """
  The label to show on a scorebug, falling back through the fields an operator
  is most likely to have filled in.
  """
  def display_name(%__MODULE__{} = team) do
    [team.short_name, team.code, team.name]
    |> Enum.map(&String.trim(&1 || ""))
    |> Enum.find("TBD", &(&1 != ""))
  end

  @doc """
  The full name, used where there is room for it (standby, series, credits).
  """
  def full_name(%__MODULE__{} = team) do
    [team.name, team.short_name, team.code]
    |> Enum.map(&String.trim(&1 || ""))
    |> Enum.find("TBD", &(&1 != ""))
  end
end
