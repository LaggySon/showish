defmodule Showish.Broadcasts do
  @moduledoc """
  The broadcast context: shows, their teams, their series of games and the
  people on air.

  Every write funnels through here so that a single `{:show_updated, show}`
  message can be pushed to every overlay watching the show. Overlays never poll;
  they subscribe once at mount and re-render when this module says so.

  ## Who can see what

  A show belongs to the account that created it, and there are exactly two ways
  to get hold of one:

    * the scoped reads — `list_shows/1`, `get_show!/2`, `get_show_by_slug!/2` —
      which only ever return that scope's own shows, and the scoped writes,
      which refuse a show belonging to anyone else; and
    * `get_public_show_by_slug!/1`, which deliberately checks nothing.

  The second exists because an overlay is loaded as a browser source inside
  broadcast software, which cannot log in. Anyone with the slug can *watch* a
  show — that is the point of an overlay URL — but only its owner can change it.
  So the operator actions further down take a `%Show{}` that one of the calls
  above has already vouched for.
  """

  import Ecto.Query, warn: false

  alias Showish.Accounts.Scope
  alias Showish.Accounts.User
  alias Showish.Baseball
  alias Showish.Baseball.Game, as: BaseballGame
  alias Showish.Broadcasts.Game
  alias Showish.Broadcasts.NotOwnerError
  alias Showish.Broadcasts.Show
  alias Showish.Broadcasts.Sport
  alias Showish.Broadcasts.Talent
  alias Showish.Broadcasts.Team
  alias Showish.Repo

  @pubsub Showish.PubSub

  ## Subscriptions

  @doc """
  Subscribes the calling process to updates for `slug`.

  Subscribers receive `{:show_updated, %Show{}}` with the show fully preloaded.
  """
  def subscribe(slug) when is_binary(slug) do
    Phoenix.PubSub.subscribe(@pubsub, topic(slug))
  end

  def unsubscribe(slug) when is_binary(slug) do
    Phoenix.PubSub.unsubscribe(@pubsub, topic(slug))
  end

  defp topic(slug), do: "show:#{slug}"

  @doc """
  Pushes `show` to every subscriber and returns it, so it can be piped.
  """
  def broadcast_show(%Show{} = show) do
    Phoenix.PubSub.broadcast(@pubsub, topic(show.slug), {:show_updated, show})
    show
  end

  ## Reading

  @doc "The scope's own shows, most recently updated first."
  def list_shows(%Scope{user: %User{id: user_id}}) do
    Show
    |> where(user_id: ^user_id)
    |> order_by(desc: :updated_at)
    |> Repo.all()
    |> Repo.preload(preloads())
    |> Enum.map(&hydrate_baseball/1)
  end

  @doc "Fetches one of the scope's shows by id, raising if there is no such show."
  def get_show!(%Scope{user: %User{id: user_id}}, id) do
    Show
    |> Repo.get_by!(id: id, user_id: user_id)
    |> Repo.preload(preloads())
    |> hydrate_baseball()
  end

  @doc """
  Fetches one of the scope's shows by its URL slug.

  Raises `Ecto.NoResultsError` for a slug that belongs to somebody else, which
  is deliberate: a stranger's control room should look exactly like a control
  room that does not exist.
  """
  def get_show_by_slug!(%Scope{user: %User{id: user_id}}, slug) do
    Show
    |> Repo.get_by!(slug: slug, user_id: user_id)
    |> Repo.preload(preloads())
    |> hydrate_baseball()
  end

  @doc """
  Fetches any show by its URL slug, with no owner check, raising if missing.

  For overlays and the JSON snapshot only — see "Who can see what" above.
  """
  def get_public_show_by_slug!(slug) when is_binary(slug) do
    Show |> Repo.get_by!(slug: slug) |> Repo.preload(preloads()) |> hydrate_baseball()
  end

  @doc "Like `get_public_show_by_slug!/1`, but `nil` rather than raising."
  def get_public_show_by_slug(slug) when is_binary(slug) do
    Show |> Repo.get_by(slug: slug) |> preload_maybe()
  end

  defp preload_maybe(nil), do: nil
  defp preload_maybe(%Show{} = show), do: show |> Repo.preload(preloads()) |> hydrate_baseball()

  defp preloads, do: [:teams, :games, :talents, baseball_game: Baseball.preloads()]

  @doc "Reloads a show along with all of its children."
  def reload(%Show{} = show) do
    Show |> Repo.get!(show.id) |> Repo.preload(preloads()) |> hydrate_baseball()
  end

  ## Writing

  @doc """
  Creates a show owned by the scope's user.

  Two teams are seeded automatically unless the caller supplies their own, since
  a show without competitors cannot be put on air.
  """
  def create_show(scope, attrs \\ %{})

  def create_show(%Scope{user: %User{id: user_id}}, attrs) do
    attrs =
      attrs
      |> stringify_keys()
      |> Map.put_new("teams", default_teams())

    %Show{user_id: user_id}
    |> Show.changeset(attrs)
    |> Repo.insert()
    |> after_write()
  end

  @doc "Updates a show and everything nested under it."
  def update_show(%Scope{} = scope, %Show{} = show, attrs) do
    show
    |> owned!(scope)
    |> write_show(attrs)
  end

  @doc "Deletes a show and, by way of the database, its children."
  def delete_show(%Scope{} = scope, %Show{} = show) do
    show
    |> owned!(scope)
    |> Repo.delete()
  end

  # The unguarded write. Private on purpose: the operator actions below reach it
  # with a show that a scoped read already vouched for.
  defp write_show(%Show{} = show, attrs) do
    show
    |> Show.changeset(stringify_keys(attrs))
    |> Repo.update()
    |> after_write()
  end

  defp owned!(%Show{user_id: user_id} = show, %Scope{user: %User{id: user_id}}), do: show
  defp owned!(%Show{} = show, %Scope{}), do: raise(NotOwnerError, slug: show.slug)

  @doc """
  Hands every ownerless show to the scope's user, returning how many moved.

  Shows created before accounts existed have no owner, which makes them
  invisible to everybody. This is the one-time migration for them; see
  `mix showish.claim_shows`.
  """
  def claim_unowned_shows(%Scope{user: %User{id: user_id}}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {count, _returned} =
      Show
      |> where([show], is_nil(show.user_id))
      |> Repo.update_all(set: [user_id: user_id, updated_at: now])

    count
  end

  @doc "Builds a changeset for the control panel forms."
  def change_show(%Show{} = show, attrs \\ %{}) do
    Show.changeset(show, stringify_keys(attrs))
  end

  ## Operator actions
  #
  # These are the buttons an operator hits mid-match, when there is no time to
  # tab through a form.
  #
  # Games and talent are edited the same way — appended, deleted, reordered — so
  # each of those actions is written once against a child collection, and the
  # public function names the collection it works on.

  @child_schemas %{games: Game, talents: Talent}

  @doc "Adds `delta` to a team's score, clamped at zero."
  def adjust_score(%Show{} = show, position, delta) when position in [1, 2] do
    case Show.team(show, position) do
      %Team{} = team ->
        team
        |> Team.changeset(%{"score" => max(team.score + delta, 0)})
        |> Repo.update()
        |> after_write(show)

      nil ->
        {:error, :not_found}
    end
  end

  @doc "Sets both teams back to zero."
  def reset_scores(%Show{} = show) do
    Enum.each(Show.teams(show), fn team ->
      team |> Team.changeset(%{"score" => 0}) |> Repo.update()
    end)

    {:ok, show |> reload() |> broadcast_show()}
  end

  @doc "Applies a sport-specific operator action and broadcasts the new state."
  def apply_sport_action(%Show{} = show, action, params \\ %{}) when is_binary(action) do
    if show.sport == "baseball" do
      case Baseball.apply_action(show, action, params) do
        {:ok, _game} -> {:ok, show |> reload() |> broadcast_show()}
        {:error, reason} -> {:error, reason}
      end
    else
      with {:ok, state} <- Sport.transition(show.sport, show.sport_state, action, params) do
        write_show(show, %{"sport_state" => state})
      end
    end
  end

  @doc "Resets sport state and both team scores as one operator action."
  def reset_sport(%Show{} = show) do
    if show.sport == "baseball" do
      reset_baseball(show)
    else
      reset_legacy_sport(show)
    end
  end

  defp reset_baseball(show) do
    result =
      Repo.transaction(fn ->
        Enum.each(List.wrap(show.teams), fn team ->
          team |> Team.changeset(%{"score" => 0}) |> Repo.update!()
        end)

        case Baseball.apply_action(show, "reset", %{}) do
          {:ok, game} -> game
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

    case result do
      {:ok, _game} -> {:ok, show |> reload() |> broadcast_show()}
      {:error, reason} -> {:error, reason}
    end
  end

  defp reset_legacy_sport(show) do
    result =
      Repo.transaction(fn ->
        Enum.each(List.wrap(show.teams), fn team ->
          team |> Team.changeset(%{"score" => 0}) |> Repo.update!()
        end)

        show
        |> Show.changeset(%{"sport_state" => Sport.default_state(show.sport)})
        |> Repo.update!()
      end)

    case result do
      {:ok, show} -> {:ok, show |> reload() |> broadcast_show()}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Flips which team is drawn on the left."
  def swap_sides(%Show{} = show) do
    write_show(show, %{"swap_sides" => !show.swap_sides})
  end

  @doc "Moves the series pointer, clamped to the games that exist."
  def move_current_game(%Show{} = show, delta) do
    count = max(length(Show.games(show)), 1)
    next = show.current_game + delta

    write_show(show, %{"current_game" => next |> max(1) |> min(count)})
  end

  @doc "Jumps the series pointer to a specific 1-indexed game."
  def set_current_game(%Show{} = show, number) do
    write_show(show, %{"current_game" => number})
  end

  @doc """
  Records the winner of a game and marks it complete.

  Passing the winner that is already set clears it, so the same button both sets
  and undoes a call.
  """
  def set_game_winner(%Show{} = show, game_id, winner) when winner in ["a", "b", "draw"] do
    with_child(show, :games, game_id, fn game ->
      game
      |> Game.changeset(winner_attrs(game, winner))
      |> Repo.update()
      |> after_write(show)
    end)
  end

  defp winner_attrs(%Game{winner: winner}, winner), do: %{"winner" => "", "completed" => false}
  defp winner_attrs(%Game{}, winner), do: %{"winner" => winner, "completed" => true}

  @doc "Appends an empty game to the series."
  def add_game(%Show{} = show), do: add_child(show, :games)

  @doc "Appends an empty talent row."
  def add_talent(%Show{} = show), do: add_child(show, :talents)

  @doc "Removes a game from the series and renumbers what is left."
  def delete_game(%Show{} = show, game_id), do: delete_child(show, :games, game_id)

  @doc "Removes a talent row and renumbers what is left."
  def delete_talent(%Show{} = show, talent_id), do: delete_child(show, :talents, talent_id)

  @doc """
  Moves a game up (`-1`) or down (`+1`) the running order.

  Moving past either end is a no-op rather than an error, so an operator can
  lean on the button without watching for the edge.
  """
  def move_game(%Show{} = show, game_id, delta), do: move_child(show, :games, game_id, delta)

  @doc "Moves a talent row up (`-1`) or down (`+1`)."
  def move_talent(%Show{} = show, talent_id, delta),
    do: move_child(show, :talents, talent_id, delta)

  defp add_child(%Show{} = show, key) do
    schema = schema_for(key)

    show
    |> Ecto.build_assoc(key)
    |> schema.changeset(%{"position" => length(Show.children(show, key))})
    |> Repo.insert()
    |> after_write(show)
  end

  defp delete_child(%Show{} = show, key, id) do
    with_child(show, key, id, fn row ->
      Repo.delete(row)
      renumber(schema_for(key), show.id)

      {:ok, show |> reload() |> broadcast_show()}
    end)
  end

  defp move_child(%Show{} = show, key, id, delta) do
    id = to_integer(id)
    rows = Show.children(show, key)
    index = Enum.find_index(rows, &(&1.id == id))
    target_index = index && index + delta

    cond do
      is_nil(index) ->
        {:error, :not_found}

      target_index < 0 or target_index >= length(rows) ->
        {:ok, show}

      true ->
        moved = Enum.at(rows, index)
        displaced = Enum.at(rows, target_index)

        Repo.transaction(fn ->
          moved |> Ecto.Changeset.change(position: target_index) |> Repo.update!()
          displaced |> Ecto.Changeset.change(position: index) |> Repo.update!()
        end)

        {:ok, show |> reload() |> broadcast_show()}
    end
  end

  # Every row action starts by finding the row on the show it was handed. A row
  # that is not there means a control room got ahead of itself — an operator who
  # hit remove twice — which is a stale click rather than something to raise on.
  defp with_child(%Show{} = show, key, id, action) do
    case find_child(show, key, id) do
      nil -> {:error, :not_found}
      row -> action.(row)
    end
  end

  defp find_child(%Show{} = show, key, id) do
    id = to_integer(id)

    show |> Show.children(key) |> Enum.find(&(&1.id == id))
  end

  defp schema_for(key), do: Map.fetch!(@child_schemas, key)

  defp to_integer(id) when is_integer(id), do: id

  defp to_integer(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, _rest} -> int
      :error -> nil
    end
  end

  defp renumber(schema, show_id) do
    schema
    |> where(show_id: ^show_id)
    |> order_by(asc: :position, asc: :id)
    |> Repo.all()
    |> Enum.with_index()
    |> Enum.each(fn {row, index} ->
      row |> Ecto.Changeset.change(position: index) |> Repo.update()
    end)
  end

  # A show write returns the reloaded, fully preloaded show so callers and
  # subscribers always see the same shape.
  defp after_write({:ok, %Show{} = show}), do: {:ok, show |> reload() |> broadcast_show()}
  defp after_write({:error, _changeset} = error), do: error

  defp after_write({:ok, _child}, %Show{} = show),
    do: {:ok, show |> reload() |> broadcast_show()}

  defp after_write({:error, _changeset} = error, %Show{}), do: error

  defp default_teams do
    [
      %{
        "position" => 1,
        "name" => "Team One",
        "short_name" => "ONE",
        "code" => "ONE",
        "primary_color" => "#2563eb",
        "secondary_color" => "#f8fafc"
      },
      %{
        "position" => 2,
        "name" => "Team Two",
        "short_name" => "TWO",
        "code" => "TWO",
        "primary_color" => "#dc2626",
        "secondary_color" => "#f8fafc"
      }
    ]
  end

  defp hydrate_baseball(%Show{sport: "baseball", baseball_game: %BaseballGame{}} = show) do
    %{show | sport_state: Baseball.project(show)}
  end

  defp hydrate_baseball(%Show{} = show), do: show

  # Forms hand us string keys and tests hand us atoms; Ecto insists on one or
  # the other, so normalise the top level (nested maps are cast on their own).
  defp stringify_keys(attrs) when is_map(attrs) and not is_struct(attrs) do
    Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
  end

  defp stringify_keys(attrs), do: attrs
end
