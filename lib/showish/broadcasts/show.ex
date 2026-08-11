defmodule Showish.Broadcasts.Show do
  @moduledoc """
  A single broadcast: the two competitors, the series of games, the on-air
  talent and the bits of copy an operator flips on and off during the stream.

  Everything an overlay renders hangs off this struct, so a show is loaded once
  and pushed to every connected overlay whenever it changes.

  A show belongs to the account that created it. `user_id` is set by
  `Showish.Broadcasts.create_show/2` and never cast from form params, so no
  amount of poking at a form can move a show between accounts.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Showish.Accounts.User
  alias Showish.Broadcasts.Game
  alias Showish.Broadcasts.Preset
  alias Showish.Broadcasts.Talent
  alias Showish.Broadcasts.Team
  alias Showish.Text

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
    field :preset, :string, default: "broadcast"

    belongs_to :user, User

    has_many :teams, Team, on_replace: :delete, preload_order: [asc: :position]
    has_many :games, Game, on_replace: :delete, preload_order: [asc: :position]
    has_many :talents, Talent, on_replace: :delete, preload_order: [asc: :position]

    timestamps(type: :utc_datetime)
  end

  @castable ~w(slug title subtitle stage starts_at ticker status_left status_center
               status_right show_status_left show_status_center show_status_right
               current_game best_of show_sides swap_sides break_message accent_color
               preset)a

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
    |> validate_inclusion(:preset, Preset.keys())
    |> Showish.Colors.validate_hex(:accent_color)
    # Overlay URLs live in one namespace across every account, because a
    # browser source is just a URL — so slugs are unique globally, not per user.
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
  The show's teams, in position order.

  Along with `games/1` and `talents/1`, this is how everything else reaches a
  show's children: it answers with a list whether the association is loaded,
  empty or `nil`, so a caller never has to decide what an unloaded show means
  half way through a broadcast.
  """
  def teams(%__MODULE__{} = show), do: children(show, :teams)

  @doc "The show's games, in running order."
  def games(%__MODULE__{} = show), do: children(show, :games)

  @doc "The show's talent, in the order the operator arranged them."
  def talents(%__MODULE__{} = show), do: children(show, :talents)

  @doc "One of the child associations above, named by its field."
  def children(%__MODULE__{} = show, key) when key in [:teams, :games, :talents] do
    case Map.fetch!(show, key) do
      rows when is_list(rows) -> rows
      _not_loaded -> []
    end
  end

  @doc """
  The two teams in the order they should be drawn, honouring `swap_sides`.

  Returns `{left, right}`. Missing teams come back as `nil` so overlays can
  render a placeholder rather than crash mid-broadcast.
  """
  def sides(%__MODULE__{} = show) do
    one = team(show, 1)
    two = team(show, 2)

    if show.swap_sides, do: {two, one}, else: {one, two}
  end

  @doc "Team one or team two, by position, or `nil` for an unfilled slot."
  def team(%__MODULE__{} = show, position) when position in [1, 2] do
    show |> teams() |> Enum.find(&(&1.position == position))
  end

  @doc """
  The game currently being played, based on `current_game` (1-indexed).
  """
  def current_game(%__MODULE__{} = show) do
    show |> games() |> Enum.at(show.current_game - 1)
  end

  @doc """
  The line of copy shown in the middle of the scorebug.

  An explicit centre status wins; otherwise we describe the current game, which
  is what an operator wants nine times out of ten.
  """
  def center_line(%__MODULE__{show_status_center: true} = show) do
    Text.presence(show.status_center, current_game_line(show))
  end

  def center_line(%__MODULE__{} = show), do: current_game_line(show)

  defp current_game_line(show) do
    case current_game(show) do
      %Game{} = game -> Text.join_present([Game.label(game), game.name, game.mode])
      nil -> ""
    end
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
