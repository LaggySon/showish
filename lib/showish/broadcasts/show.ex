defmodule Showish.Broadcasts.Show do
  @moduledoc """
  A single broadcast: the two competitors, the series of games, the on-air
  talent and the bits of copy an operator flips on and off during the stream.

  Everything an overlay renders hangs off this struct, so a show is loaded once
  and pushed to every connected overlay whenever it changes.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Showish.Broadcasts.Game
  alias Showish.Broadcasts.Talent
  alias Showish.Broadcasts.Team

  @type t :: %__MODULE__{}

  schema "shows" do
    field :slug, :string
    field :title, :string, default: ""
    field :subtitle, :string, default: ""
    field :stage, :string, default: ""
    field :starts_at, :utc_datetime
    field :ticker, :string, default: ""
    field :status_left, :string, default: ""
    field :status_center, :string, default: ""
    field :status_right, :string, default: ""
    field :show_status_left, :boolean, default: false
    field :show_status_center, :boolean, default: true
    field :show_status_right, :boolean, default: false
    field :current_game, :integer, default: 1
    field :best_of, :integer, default: 5
    field :show_sides, :boolean, default: false
    field :swap_sides, :boolean, default: false
    field :break_message, :string, default: "We'll be right back"
    field :accent_color, :string, default: "#22d3ee"

    has_many :teams, Team, on_replace: :delete, preload_order: [asc: :position]
    has_many :games, Game, on_replace: :delete, preload_order: [asc: :position]
    has_many :talents, Talent, on_replace: :delete, preload_order: [asc: :position]

    timestamps(type: :utc_datetime)
  end

  @castable ~w(slug title subtitle stage starts_at ticker status_left status_center
               status_right show_status_left show_status_center show_status_right
               current_game best_of show_sides swap_sides break_message accent_color)a

  def changeset(show, attrs) do
    show
    |> cast(pad_datetimes(attrs), @castable)
    |> update_change(:slug, &slugify/1)
    |> validate_required([:title, :slug])
    |> validate_format(:slug, ~r/^[a-z0-9][a-z0-9-]*$/,
      message: "may only contain lowercase letters, numbers and dashes"
    )
    |> validate_number(:current_game, greater_than_or_equal_to: 1)
    |> validate_number(:best_of, greater_than_or_equal_to: 1)
    |> Showish.Colors.validate_hex(:accent_color)
    |> unique_constraint(:slug)
    |> cast_assoc(:teams, with: &Team.changeset/2)
    |> cast_assoc(:games,
      with: &Game.changeset/2,
      sort_param: :games_sort,
      drop_param: :games_drop
    )
    |> cast_assoc(:talents,
      with: &Talent.changeset/2,
      sort_param: :talents_sort,
      drop_param: :talents_drop
    )
    |> renumber(:games)
    |> renumber(:talents)
  end

  @doc """
  Turns free text into a URL-safe slug.

      iex> Showish.Broadcasts.Show.slugify("Grand Finals — Week 5!")
      "grand-finals-week-5"
  """
  def slugify(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end

  def slugify(value), do: value

  @doc """
  The two teams in the order they should be drawn, honouring `swap_sides`.

  Returns `{left, right}`. Missing teams come back as `nil` so overlays can
  render a placeholder rather than crash mid-broadcast.
  """
  def sides(%__MODULE__{} = show) do
    teams = if is_list(show.teams), do: show.teams, else: []
    one = Enum.find(teams, &(&1.position == 1))
    two = Enum.find(teams, &(&1.position == 2))

    if show.swap_sides, do: {two, one}, else: {one, two}
  end

  @doc "Team one, i.e. the team labelled `a` on games."
  def team(%__MODULE__{} = show, position) when position in [1, 2] do
    show.teams |> List.wrap() |> Enum.find(&(&1.position == position))
  end

  @doc """
  The game currently being played, based on `current_game` (1-indexed).
  """
  def current_game(%__MODULE__{} = show) do
    show.games |> List.wrap() |> Enum.at(show.current_game - 1)
  end

  @doc """
  The line of copy shown in the middle of the scorebug.

  An explicit centre status wins; otherwise we describe the current game, which
  is what an operator wants nine times out of ten.
  """
  def center_line(%__MODULE__{} = show) do
    explicit = String.trim(show.status_center || "")

    cond do
      show.show_status_center and explicit != "" -> explicit
      game = current_game(show) -> describe_game(game)
      true -> ""
    end
  end

  defp describe_game(%Game{} = game) do
    [Game.label(game), game.name, game.mode]
    |> Enum.map(&String.trim(&1 || ""))
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" · ")
  end

  # `datetime-local` inputs omit seconds, which older Ecto versions refuse to
  # cast. Padding here keeps the control panel forgiving.
  defp pad_datetimes(attrs) when is_map(attrs) do
    Enum.into(attrs, %{}, fn
      {key, <<_::binary-16>> = value} when key in ["starts_at", :starts_at] ->
        {key, value <> ":00"}

      pair ->
        pair
    end)
  end

  defp pad_datetimes(attrs), do: attrs

  # Keeps `position` in sync with the order the rows arrive in from the form, so
  # drag-free reordering (the sort buttons) survives a round trip.
  defp renumber(changeset, key) do
    update_change(changeset, key, fn changesets ->
      {renumbered, _next} =
        Enum.map_reduce(changesets, 0, fn child, index ->
          if child.action in [:replace, :delete] do
            {child, index}
          else
            {put_change(child, :position, index), index + 1}
          end
        end)

      renumbered
    end)
  end
end
