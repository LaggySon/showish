defmodule Showish.Baseball do
  @moduledoc "Database-backed baseball scoring, rosters, events, and derived broadcast statistics."

  import Ecto.Query, warn: false

  alias Showish.Baseball.BullpenEntry
  alias Showish.Baseball.Event
  alias Showish.Baseball.Game
  alias Showish.Baseball.LineupSpot
  alias Showish.Baseball.Pitch
  alias Showish.Baseball.PlateAppearance
  alias Showish.Baseball.Player
  alias Showish.Broadcasts.Show
  alias Showish.Broadcasts.Team
  alias Showish.Repo

  @gameplay_actions ~w(record_pitch record_play)
  @positions ~w(P C 1B 2B 3B SS LF CF RF)
  @game_fields ~w(inning half balls strikes outs first_occupied second_occupied
                  third_occupied away_batter_order home_batter_order away_pitch_count
                  home_pitch_count away_pitcher_id home_pitcher_id first_runner_id
                  second_runner_id third_runner_id)a

  def preloads do
    [
      :away_pitcher,
      :home_pitcher,
      :spotlight_player,
      :comparison_left_player,
      :comparison_right_player,
      lineup_spots: :player,
      bullpen_entries: :player,
      plate_appearances: [:batter, :pitcher],
      pitches: [:batter, :pitcher],
      events: []
    ]
  end

  @doc "Applies an operator action to the normalized relational game model."
  def apply_action(%Show{} = show, action, params) when is_binary(action) do
    Repo.transaction(fn ->
      game = ensure_game!(show)

      case dispatch(game, show, action, params) do
        {:ok, result} -> result
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc "Builds the compatibility projection consumed by every baseball UI and overlay."
  def project(%Show{baseball_game: %Game{} = game} = show) do
    game = Repo.preload(game, preloads(), force: true)
    stats = player_stats(game)

    lineups =
      Map.new(~w(1 2), fn position ->
        team = Show.team(show, String.to_integer(position))

        players =
          game.lineup_spots
          |> Enum.filter(&(&1.team_id == team.id and not is_nil(&1.batting_order)))
          |> Enum.sort_by(& &1.batting_order)
          |> Enum.map(fn spot ->
            stat = Map.get(stats, spot.player_id, empty_stats())

            stat
            |> Map.take(
              ~w(at_bats hits doubles triples home_runs walks hit_by_pitch rbi runs strikeouts)a
            )
            |> stringify_stat_keys()
            |> Map.put("id", spot.player_id)
            |> Map.put("name", spot.player.name)
            |> Map.put("field_position", spot.field_position)
          end)

        {position, players}
      end)

    active_batters = %{
      "1" => max(game.away_batter_order - 1, 0),
      "2" => max(game.home_batter_order - 1, 0)
    }

    pitchers = %{
      "1" => pitcher_projection(game.away_pitcher, game.away_pitch_count),
      "2" => pitcher_projection(game.home_pitcher, game.home_pitch_count)
    }

    %{
      "inning" => game.inning,
      "half" => game.half,
      "balls" => game.balls,
      "strikes" => game.strikes,
      "outs" => game.outs,
      "bases" => %{
        "first" => game.first_occupied,
        "second" => game.second_occupied,
        "third" => game.third_occupied
      },
      "hits" => team_totals(game, show, :hits),
      "errors" => team_totals(game, show, :errors),
      "lineups" => lineups,
      "active_batters" => active_batters,
      "defense" => defense_projection(game, show),
      "bullpens" => bullpen_projection(game, show),
      "pitchers" => pitchers,
      "graphics" => graphics_projection(game, show, stats),
      "last_play" => last_play_projection(game),
      "history" =>
        game.events
        |> Enum.reject(&(&1.action == "legacy_import"))
        |> Enum.map(&%{"id" => &1.id, "action" => &1.action})
    }
  end

  def project(%Show{} = show), do: show.sport_state

  defp dispatch(game, show, "save_roster", %{
         "roster" => %{"position" => position, "entries" => entries}
       })
       when position in ~w(1 2) and is_binary(entries) do
    team = team!(show, position)

    LineupSpot
    |> where(game_id: ^game.id, team_id: ^team.id)
    |> Repo.update_all(set: [batting_order: nil, field_position: ""])

    entries
    |> parse_roster()
    |> Enum.each(fn entry ->
      player = player!(team.id, entry.name)

      upsert_spot!(game.id, team.id, player.id, %{
        batting_order: entry.batting_order,
        field_position: entry.field_position
      })
    end)

    max_order = max_lineup_order(game.id, team.id)
    order_field = batter_order_field(position)
    game = update_game!(game, %{order_field => min(Map.fetch!(game, order_field), max_order)})
    {:ok, game}
  end

  defp dispatch(game, show, "save_lineup", %{
         "lineup" => %{"position" => position, "names" => names}
       })
       when position in ~w(1 2) and is_binary(names) do
    team = team!(show, position)

    LineupSpot
    |> where(game_id: ^game.id, team_id: ^team.id)
    |> Repo.update_all(set: [batting_order: nil])

    names
    |> lines()
    |> Enum.take(20)
    |> Enum.with_index(1)
    |> Enum.each(fn {name, order} ->
      player = player!(team.id, name)
      upsert_spot!(game.id, team.id, player.id, %{batting_order: order})
    end)

    max_order = max_lineup_order(game.id, team.id)
    order_field = batter_order_field(position)
    game = update_game!(game, %{order_field => min(Map.fetch!(game, order_field), max_order)})
    {:ok, game}
  end

  defp dispatch(game, show, "save_defense", %{
         "defense" => %{"position" => position, "players" => players}
       })
       when position in ~w(1 2) and is_binary(players) do
    team = team!(show, position)

    LineupSpot
    |> where(game_id: ^game.id, team_id: ^team.id)
    |> Repo.update_all(set: [field_position: ""])

    players
    |> parse_pairs()
    |> Enum.filter(fn {field_position, _name} -> field_position in @positions end)
    |> Enum.each(fn {field_position, name} ->
      player = player!(team.id, name)
      upsert_spot!(game.id, team.id, player.id, %{field_position: field_position})
    end)

    {:ok, game}
  end

  defp dispatch(game, show, "save_bullpen", %{
         "bullpen" => %{"position" => position, "pitchers" => pitchers}
       })
       when position in ~w(1 2) and is_binary(pitchers) do
    team = team!(show, position)

    BullpenEntry
    |> where(game_id: ^game.id, team_id: ^team.id)
    |> Repo.delete_all()

    pitchers
    |> lines()
    |> Enum.take(12)
    |> Enum.with_index()
    |> Enum.each(fn {line, index} ->
      [name | status] = String.split(line, ~r/\s*\|\s*/, parts: 2)
      player = player!(team.id, name)

      %BullpenEntry{game_id: game.id, team_id: team.id, player_id: player.id}
      |> BullpenEntry.changeset(%{
        position: index,
        status: status |> List.first("Available") |> blank_default("Available")
      })
      |> Repo.insert!()
    end)

    {:ok, game}
  end

  defp dispatch(game, show, "save_pitcher", %{
         "pitcher" => %{"position" => position, "name" => name}
       })
       when position in ~w(1 2) and is_binary(name) do
    team = team!(show, position)
    player = if String.trim(name) == "", do: nil, else: player!(team.id, name)
    {:ok, update_game!(game, %{pitcher_field(position) => player && player.id})}
  end

  defp dispatch(game, _show, "set_batter", %{"position" => position, "index" => index})
       when position in ~w(1 2) do
    order = max(to_integer(index) + 1, 1)
    {:ok, update_game!(game, %{batter_order_field(position) => order})}
  end

  defp dispatch(game, show, "next_batter", %{"position" => position})
       when position in ~w(1 2) do
    team = team!(show, position)
    next = next_order(game, team.id, Map.fetch!(game, batter_order_field(position)))

    {:ok,
     update_game!(game, %{
       batter_order_field(position) => next,
       balls: 0,
       strikes: 0
     })}
  end

  defp dispatch(game, _show, "adjust_pitch_count", %{
         "position" => position,
         "delta" => delta
       })
       when position in ~w(1 2) do
    field = pitch_count_field(position)
    {:ok, update_game!(game, %{field => max(Map.fetch!(game, field) + to_integer(delta), 0)})}
  end

  defp dispatch(game, show, "select_highlights", %{"highlight" => params})
       when is_map(params) do
    {:ok,
     update_game!(game, %{
       spotlight_player_id: selected_player_id(game, params["spotlight_player_id"]),
       comparison_left_player_id:
         selected_player_id(game, params["comparison_left_player_id"], team!(show, "1").id),
       comparison_right_player_id:
         selected_player_id(game, params["comparison_right_player_id"], team!(show, "2").id)
     })}
  end

  defp dispatch(game, show, "record_pitch", %{"result" => result} = params)
       when result in ~w(ball strike foul in_play) do
    event = event!(game, "record_pitch", params, show)
    identities = current_identities(game, show)

    %Pitch{
      game_id: game.id,
      event_id: event.id,
      batter_id: identities.batter_id,
      pitcher_id: identities.pitcher_id
    }
    |> Pitch.changeset(%{
      sequence: next_sequence(Pitch, game.id),
      result: result,
      balls_before: game.balls,
      strikes_before: game.strikes
    })
    |> Repo.insert!()

    game = increment_current_pitch_count(game)

    case result do
      "ball" when game.balls == 3 ->
        complete_appearance(game, show, event, "walk", params)

      "strike" when game.strikes == 2 ->
        complete_appearance(game, show, event, "strikeout", params)

      "ball" ->
        {:ok, update_game!(game, %{balls: game.balls + 1})}

      "strike" ->
        {:ok, update_game!(game, %{strikes: game.strikes + 1})}

      "foul" when game.strikes < 2 ->
        {:ok, update_game!(game, %{strikes: game.strikes + 1})}

      _ ->
        {:ok, game}
    end
  end

  defp dispatch(game, show, "record_play", %{"result" => result} = params)
       when result in ~w(reached single double triple home_run walk hit_by_pitch
                         reached_on_error fielders_choice sacrifice sacrifice_fly
                         sacrifice_bunt double_play interference out strikeout
                         strikeout_reached) do
    result = if result == "reached", do: "single", else: result
    event = event!(game, "record_play", Map.put(params, "result", result), show)
    complete_appearance(game, show, event, result, params)
  end

  defp dispatch(game, show, "record_play", %{"play" => params}) when is_map(params),
    do: dispatch(game, show, "record_play", params)

  defp dispatch(game, _show, "adjust_count", %{"kind" => kind, "delta" => delta})
       when kind in ~w(balls strikes outs) do
    field = String.to_existing_atom(kind)
    maximum = if kind == "balls", do: 3, else: 2

    {:ok,
     update_game!(game, %{
       field => (Map.fetch!(game, field) + to_integer(delta)) |> max(0) |> min(maximum)
     })}
  end

  defp dispatch(game, _show, "toggle_base", %{"base" => base})
       when base in ~w(first second third) do
    field = String.to_existing_atom("#{base}_occupied")
    runner_field = String.to_existing_atom("#{base}_runner_id")
    occupied = !Map.fetch!(game, field)
    {:ok, update_game!(game, %{field => occupied, runner_field => nil})}
  end

  defp dispatch(game, _show, "clear_count", _params),
    do: {:ok, update_game!(game, %{balls: 0, strikes: 0})}

  defp dispatch(game, _show, "clear_bases", _params), do: {:ok, clear_bases(game)}

  defp dispatch(game, _show, "next_half", _params), do: {:ok, advance_half(game)}
  defp dispatch(game, _show, "previous_half", _params), do: {:ok, previous_half(game)}

  defp dispatch(game, show, "undo", _params) do
    event =
      Event
      |> where([event], event.game_id == ^game.id and event.action != "legacy_import")
      |> order_by(desc: :sequence)
      |> limit(1)
      |> Repo.one()

    case event do
      nil ->
        {:ok, game}

      event ->
        game = update_game!(game, atomize_game_state(event.state_before))
        restore_scores!(show, event.state_before)
        Repo.delete!(event)
        {:ok, game}
    end
  end

  defp dispatch(game, _show, "reset", _params) do
    Repo.delete_all(from event in Event, where: event.game_id == ^game.id)

    {:ok,
     update_game!(game, %{
       inning: 1,
       half: "top",
       balls: 0,
       strikes: 0,
       outs: 0,
       first_occupied: false,
       second_occupied: false,
       third_occupied: false,
       first_runner_id: nil,
       second_runner_id: nil,
       third_runner_id: nil,
       away_batter_order: 1,
       home_batter_order: 1,
       away_pitch_count: 0,
       home_pitch_count: 0
     })}
  end

  defp dispatch(_game, _show, action, _params) when action in @gameplay_actions,
    do: {:error, :invalid_baseball_action}

  defp dispatch(_game, _show, _action, _params), do: {:error, :unsupported_baseball_action}

  defp complete_appearance(game, show, event, result, params) do
    identities = current_identities(game, show)
    scoring = scoring(result)
    automatic_runs = automatic_runs(game, result)
    runs_on_play = max(to_integer(Map.get(params, "runs", automatic_runs)), 0)
    rbi = max(to_integer(Map.get(params, "rbi", runs_on_play)), 0)
    outs_recorded = min(scoring.outs, 3 - game.outs)

    %PlateAppearance{
      game_id: game.id,
      event_id: event.id,
      batter_id: identities.batter_id,
      pitcher_id: identities.pitcher_id,
      batting_team_id: identities.batting_team.id
    }
    |> PlateAppearance.changeset(%{
      sequence: next_sequence(PlateAppearance, game.id),
      inning: game.inning,
      half: game.half,
      result: result,
      notation: normalize_notation(Map.get(params, "notation", "")),
      at_bat: scoring.at_bat,
      hit_value: scoring.hit_value,
      rbi: rbi,
      runs_scored: max(to_integer(Map.get(params, "runs_scored", scoring.runs_scored)), 0),
      outs_recorded: outs_recorded
    })
    |> Repo.insert!()

    if runs_on_play > 0 do
      identities.batting_team
      |> Team.changeset(%{score: identities.batting_team.score + runs_on_play})
      |> Repo.update!()
    end

    next = next_order(game, identities.batting_team.id, identities.batter_order)
    game = update_game!(game, %{identities.batter_order_field => next, balls: 0, strikes: 0})
    game = place_batter(game, identities.batter_id, result)

    if outs_recorded > 0 do
      if game.outs + outs_recorded >= 3,
        do: {:ok, advance_half(game)},
        else: {:ok, update_game!(game, %{outs: game.outs + outs_recorded})}
    else
      {:ok, game}
    end
  end

  defp scoring("single"), do: %{at_bat: true, hit_value: 1, outs: 0, rbi: 0, runs_scored: 0}
  defp scoring("double"), do: %{at_bat: true, hit_value: 2, outs: 0, rbi: 0, runs_scored: 0}
  defp scoring("triple"), do: %{at_bat: true, hit_value: 3, outs: 0, rbi: 0, runs_scored: 0}
  defp scoring("home_run"), do: %{at_bat: true, hit_value: 4, outs: 0, rbi: 1, runs_scored: 1}

  defp scoring(result) when result in ~w(walk hit_by_pitch),
    do: %{at_bat: false, hit_value: 0, outs: 0, rbi: 0, runs_scored: 0}

  defp scoring(result) when result in ~w(sacrifice sacrifice_fly sacrifice_bunt),
    do: %{at_bat: false, hit_value: 0, outs: 1, rbi: 0, runs_scored: 0}

  defp scoring(result) when result in ~w(out strikeout fielders_choice),
    do: %{at_bat: true, hit_value: 0, outs: 1, rbi: 0, runs_scored: 0}

  defp scoring("double_play"),
    do: %{at_bat: true, hit_value: 0, outs: 2, rbi: 0, runs_scored: 0}

  defp scoring(result) when result in ~w(reached_on_error strikeout_reached),
    do: %{at_bat: true, hit_value: 0, outs: 0, rbi: 0, runs_scored: 0}

  defp scoring("interference"),
    do: %{at_bat: false, hit_value: 0, outs: 0, rbi: 0, runs_scored: 0}

  defp automatic_runs(game, "home_run"), do: occupied_bases(game) + 1

  defp automatic_runs(game, "double"),
    do: Enum.count([game.second_occupied, game.third_occupied], & &1)

  defp automatic_runs(game, "triple"), do: occupied_bases(game)
  defp automatic_runs(game, "sacrifice_fly"), do: if(game.third_occupied, do: 1, else: 0)

  defp automatic_runs(game, result) when result in ~w(walk hit_by_pitch interference),
    do: if(game.first_occupied and game.second_occupied and game.third_occupied, do: 1, else: 0)

  defp automatic_runs(_game, _result), do: 0

  defp place_batter(game, batter_id, result) do
    case result do
      "single" ->
        force_batter_to_first(game, batter_id)

      "reached_on_error" ->
        force_batter_to_first(game, batter_id)

      "fielders_choice" ->
        update_game!(game, %{first_occupied: true, first_runner_id: batter_id})

      "walk" ->
        force_batter_to_first(game, batter_id)

      "hit_by_pitch" ->
        force_batter_to_first(game, batter_id)

      "interference" ->
        force_batter_to_first(game, batter_id)

      "strikeout_reached" ->
        force_batter_to_first(game, batter_id)

      "double" ->
        update_game!(game, %{
          first_occupied: false,
          first_runner_id: nil,
          second_occupied: true,
          second_runner_id: batter_id,
          third_occupied: game.first_occupied,
          third_runner_id: if(game.first_occupied, do: game.first_runner_id, else: nil)
        })

      "triple" ->
        update_game!(game, %{
          first_occupied: false,
          first_runner_id: nil,
          second_occupied: false,
          second_runner_id: nil,
          third_occupied: true,
          third_runner_id: batter_id
        })

      "home_run" ->
        clear_bases(game)

      "sacrifice_fly" when game.third_occupied ->
        update_game!(game, %{third_occupied: false, third_runner_id: nil})

      "double_play" ->
        update_game!(game, %{first_occupied: false, first_runner_id: nil})

      _ ->
        game
    end
  end

  defp force_batter_to_first(game, batter_id) do
    if game.first_occupied do
      update_game!(game, %{
        first_occupied: true,
        first_runner_id: batter_id,
        second_occupied: true,
        second_runner_id: game.first_runner_id,
        third_occupied: game.second_occupied || game.third_occupied,
        third_runner_id:
          if(game.second_occupied, do: game.second_runner_id, else: game.third_runner_id)
      })
    else
      update_game!(game, %{first_occupied: true, first_runner_id: batter_id})
    end
  end

  defp ensure_game!(show) do
    case Repo.get_by(Game, show_id: show.id) do
      nil ->
        game = Repo.insert!(%Game{show_id: show.id})
        import_legacy_state!(game, show)

      game ->
        game
    end
  end

  defp import_legacy_state!(game, show) do
    state = Showish.Broadcasts.Sports.Baseball.normalize_state(show.sport_state)

    import_event =
      %Event{game_id: game.id}
      |> Event.changeset(%{
        sequence: 1,
        action: "legacy_import",
        params: %{},
        state_before: game_state(game)
      })
      |> Repo.insert!()

    Enum.each(~w(1 2), fn position ->
      team = team!(show, position)

      state["lineups"][position]
      |> Enum.with_index(1)
      |> Enum.each(fn {legacy_player, order} ->
        player = player!(team.id, legacy_player["name"])
        upsert_spot!(game.id, team.id, player.id, %{batting_order: order})
        import_legacy_stats!(game, import_event, team.id, player.id, position, legacy_player)
      end)

      state["defense"][position]
      |> Enum.reject(fn {_field_position, name} -> name == "" end)
      |> Enum.each(fn {field_position, name} ->
        player = player!(team.id, name)
        upsert_spot!(game.id, team.id, player.id, %{field_position: field_position})
      end)

      state["bullpens"][position]
      |> Enum.with_index()
      |> Enum.each(fn {legacy_pitcher, index} ->
        player = player!(team.id, legacy_pitcher["name"])

        Repo.insert!(%BullpenEntry{
          game_id: game.id,
          team_id: team.id,
          player_id: player.id,
          position: index,
          status: blank_default(legacy_pitcher["status"], "Available")
        })
      end)
    end)

    away_pitcher = import_pitcher(state, show, "1")
    home_pitcher = import_pitcher(state, show, "2")

    update_game!(game, %{
      inning: state["inning"],
      half: state["half"],
      balls: state["balls"],
      strikes: state["strikes"],
      outs: state["outs"],
      first_occupied: state["bases"]["first"],
      second_occupied: state["bases"]["second"],
      third_occupied: state["bases"]["third"],
      away_batter_order: state["active_batters"]["1"] + 1,
      home_batter_order: state["active_batters"]["2"] + 1,
      away_pitch_count: state["pitchers"]["1"]["pitch_count"],
      home_pitch_count: state["pitchers"]["2"]["pitch_count"],
      away_pitcher_id: away_pitcher && away_pitcher.id,
      home_pitcher_id: home_pitcher && home_pitcher.id
    })
  end

  defp import_pitcher(state, show, position) do
    name = state["pitchers"][position]["name"]
    if name == "", do: nil, else: player!(team!(show, position).id, name)
  end

  defp import_legacy_stats!(game, event, team_id, player_id, position, legacy_player) do
    hits = max(to_integer(legacy_player["hits"]), 0)
    at_bats = max(to_integer(legacy_player["at_bats"]), hits)

    results = List.duplicate("single", hits) ++ List.duplicate("out", at_bats - hits)

    Enum.each(results, fn result ->
      scoring = scoring(result)

      %PlateAppearance{
        game_id: game.id,
        event_id: event.id,
        batter_id: player_id,
        batting_team_id: team_id
      }
      |> PlateAppearance.changeset(%{
        sequence: next_sequence(PlateAppearance, game.id),
        inning: 1,
        half: if(position == "1", do: "top", else: "bottom"),
        result: result,
        at_bat: scoring.at_bat,
        hit_value: scoring.hit_value,
        rbi: 0,
        runs_scored: 0,
        outs_recorded: 0
      })
      |> Repo.insert!()
    end)
  end

  defp event!(game, action, params, show) do
    state_before =
      Map.merge(game_state(game), %{
        "away_score" => team!(show, "1").score,
        "home_score" => team!(show, "2").score
      })

    %Event{game_id: game.id}
    |> Event.changeset(%{
      sequence: next_sequence(Event, game.id),
      action: action,
      params: params,
      state_before: state_before
    })
    |> Repo.insert!()
  end

  defp restore_scores!(show, state) do
    Enum.each([{"1", "away_score"}, {"2", "home_score"}], fn {position, key} ->
      case Map.fetch(state, key) do
        {:ok, score} ->
          show
          |> team!(position)
          |> Team.changeset(%{score: score})
          |> Repo.update!()

        :error ->
          :ok
      end
    end)
  end

  defp current_identities(game, show) do
    batting_position = if game.half == "top", do: "1", else: "2"
    fielding_position = if batting_position == "1", do: "2", else: "1"
    batting_team = team!(show, batting_position)
    batter_order_field = batter_order_field(batting_position)
    batter_order = Map.fetch!(game, batter_order_field)

    batter_id =
      LineupSpot
      |> where(game_id: ^game.id, team_id: ^batting_team.id, batting_order: ^batter_order)
      |> select([spot], spot.player_id)
      |> Repo.one()

    %{
      batting_team: batting_team,
      batter_id: batter_id,
      batter_order: batter_order,
      batter_order_field: batter_order_field,
      pitcher_id: Map.fetch!(game, pitcher_field(fielding_position))
    }
  end

  defp player_stats(game) do
    Enum.reduce(game.plate_appearances, %{}, fn appearance, stats ->
      if appearance.batter_id do
        Map.update(stats, appearance.batter_id, stats_for(appearance), fn current ->
          merge_stats(current, stats_for(appearance))
        end)
      else
        stats
      end
    end)
  end

  defp stats_for(appearance) do
    %{
      at_bats: if(appearance.at_bat, do: 1, else: 0),
      hits: if(appearance.hit_value > 0, do: 1, else: 0),
      doubles: if(appearance.hit_value == 2, do: 1, else: 0),
      triples: if(appearance.hit_value == 3, do: 1, else: 0),
      home_runs: if(appearance.hit_value == 4, do: 1, else: 0),
      walks: if(appearance.result == "walk", do: 1, else: 0),
      hit_by_pitch: if(appearance.result == "hit_by_pitch", do: 1, else: 0),
      rbi: appearance.rbi,
      runs: appearance.runs_scored,
      strikeouts: if(appearance.result in ~w(strikeout strikeout_reached), do: 1, else: 0)
    }
  end

  defp empty_stats do
    %{
      at_bats: 0,
      hits: 0,
      doubles: 0,
      triples: 0,
      home_runs: 0,
      walks: 0,
      hit_by_pitch: 0,
      rbi: 0,
      runs: 0,
      strikeouts: 0
    }
  end

  defp merge_stats(left, right), do: Map.merge(left, right, fn _key, a, b -> a + b end)

  defp team_totals(game, show, :hits) do
    totals =
      game.plate_appearances
      |> Enum.filter(&(&1.hit_value > 0))
      |> Enum.frequencies_by(& &1.batting_team_id)

    team_total_map(show, totals)
  end

  defp team_totals(game, show, :errors) do
    totals =
      game.plate_appearances
      |> Enum.filter(&(&1.result == "reached_on_error"))
      |> Enum.frequencies_by(fn appearance ->
        away = Show.team(show, 1)
        home = Show.team(show, 2)
        if appearance.batting_team_id == away.id, do: home.id, else: away.id
      end)

    team_total_map(show, totals)
  end

  defp team_total_map(show, totals) do
    %{
      "1" => Map.get(totals, Show.team(show, 1).id, 0),
      "2" => Map.get(totals, Show.team(show, 2).id, 0)
    }
  end

  defp last_play_projection(game) do
    case Enum.max_by(game.plate_appearances, & &1.sequence, fn -> nil end) do
      nil -> %{"result" => "", "notation" => ""}
      appearance -> %{"result" => appearance.result, "notation" => appearance.notation}
    end
  end

  defp defense_projection(game, show) do
    Map.new(~w(1 2), fn position ->
      team = team!(show, position)

      defense =
        game.lineup_spots
        |> Enum.filter(&(&1.team_id == team.id and &1.field_position in @positions))
        |> Map.new(&{&1.field_position, &1.player.name})

      {position, Map.merge(Map.new(@positions, &{&1, ""}), defense)}
    end)
  end

  defp bullpen_projection(game, show) do
    Map.new(~w(1 2), fn position ->
      team = team!(show, position)

      entries =
        game.bullpen_entries
        |> Enum.filter(&(&1.team_id == team.id))
        |> Enum.sort_by(& &1.position)
        |> Enum.map(&%{"id" => &1.player_id, "name" => &1.player.name, "status" => &1.status})

      {position, entries}
    end)
  end

  defp graphics_projection(game, show, stats) do
    leaders =
      game.lineup_spots
      |> Enum.filter(&(not is_nil(&1.batting_order)))
      |> Enum.uniq_by(& &1.player_id)
      |> Enum.map(fn spot -> {spot, Map.get(stats, spot.player_id, empty_stats())} end)

    overall = selected_or_leader(leaders, game.spotlight_player_id)

    team_leaders =
      Map.new(~w(1 2), fn position ->
        team = team!(show, position)

        automatic =
          leaders
          |> Enum.filter(fn {spot, _} -> spot.team_id == team.id end)
          |> Enum.max_by(&leader_score/1, fn -> nil end)

        selected_id =
          if position == "1",
            do: game.comparison_left_player_id,
            else: game.comparison_right_player_id

        selected = Enum.find(leaders, fn {spot, _stats} -> spot.player_id == selected_id end)
        {position, selected || automatic}
      end)

    %{
      "single" =>
        overall |> single_graphic() |> Map.put("selected_player_id", game.spotlight_player_id),
      "comparison" =>
        team_leaders["1"]
        |> comparison_graphic(team_leaders["2"])
        |> Map.put("selected_left_player_id", game.comparison_left_player_id)
        |> Map.put("selected_right_player_id", game.comparison_right_player_id)
    }
  end

  defp single_graphic(nil),
    do: %{"kicker" => "PLAYER SPOTLIGHT", "name" => "", "detail" => "", "stats" => []}

  defp single_graphic({spot, stats}) do
    %{
      "player_id" => spot.player_id,
      "kicker" => "PLAYER SPOTLIGHT",
      "name" => spot.player.name,
      "detail" => spot.field_position,
      "stats" => graphic_stats(stats)
    }
  end

  defp comparison_graphic(left, right) do
    left_stats = if left, do: elem(left, 1), else: empty_stats()
    right_stats = if right, do: elem(right, 1), else: empty_stats()

    %{
      "title" => "PLAYER COMPARISON",
      "left_name" => if(left, do: elem(left, 0).player.name, else: ""),
      "left_player_id" => if(left, do: elem(left, 0).player_id, else: nil),
      "left_detail" => if(left, do: elem(left, 0).field_position, else: ""),
      "right_name" => if(right, do: elem(right, 0).player.name, else: ""),
      "right_player_id" => if(right, do: elem(right, 0).player_id, else: nil),
      "right_detail" => if(right, do: elem(right, 0).field_position, else: ""),
      "stats" => [
        comparison_stat(
          "H-AB",
          "#{left_stats.hits}-#{left_stats.at_bats}",
          "#{right_stats.hits}-#{right_stats.at_bats}"
        ),
        comparison_stat("AVG", average(left_stats), average(right_stats)),
        comparison_stat("HR", left_stats.home_runs, right_stats.home_runs),
        comparison_stat("RBI", left_stats.rbi, right_stats.rbi),
        comparison_stat("BB", left_stats.walks, right_stats.walks)
      ]
    }
  end

  defp graphic_stats(stats) do
    [
      %{"label" => "H-AB", "value" => "#{stats.hits}-#{stats.at_bats}"},
      %{"label" => "AVG", "value" => average(stats)},
      %{"label" => "HR", "value" => to_string(stats.home_runs)},
      %{"label" => "RBI", "value" => to_string(stats.rbi)},
      %{"label" => "BB", "value" => to_string(stats.walks)},
      %{"label" => "SO", "value" => to_string(stats.strikeouts)}
    ]
  end

  defp comparison_stat(label, left, right),
    do: %{"label" => label, "left" => to_string(left), "right" => to_string(right)}

  defp average(%{at_bats: 0}), do: ".000"

  defp average(stats),
    do:
      :erlang.float_to_binary(stats.hits / stats.at_bats, decimals: 3) |> String.trim_leading("0")

  defp leader_score({_spot, stats}), do: {stats.hits, stats.home_runs, stats.rbi, stats.walks}

  defp selected_or_leader(leaders, player_id) do
    Enum.find(leaders, fn {spot, _stats} -> spot.player_id == player_id end) ||
      Enum.max_by(leaders, &leader_score/1, fn -> nil end)
  end

  defp pitcher_projection(nil, count), do: %{"id" => nil, "name" => "", "pitch_count" => count}

  defp pitcher_projection(player, count),
    do: %{"id" => player.id, "name" => player.name, "pitch_count" => count}

  defp increment_current_pitch_count(%Game{half: "top"} = game),
    do: update_game!(game, %{home_pitch_count: game.home_pitch_count + 1})

  defp increment_current_pitch_count(game),
    do: update_game!(game, %{away_pitch_count: game.away_pitch_count + 1})

  defp advance_half(%Game{half: "top"} = game),
    do: game |> update_game!(%{half: "bottom"}) |> reset_half()

  defp advance_half(game),
    do: game |> update_game!(%{half: "top", inning: game.inning + 1}) |> reset_half()

  defp previous_half(%Game{half: "bottom"} = game),
    do: game |> update_game!(%{half: "top"}) |> reset_half()

  defp previous_half(%Game{inning: 1} = game), do: reset_half(game)

  defp previous_half(game),
    do: game |> update_game!(%{half: "bottom", inning: game.inning - 1}) |> reset_half()

  defp reset_half(game),
    do: game |> clear_bases() |> update_game!(%{balls: 0, strikes: 0, outs: 0})

  defp clear_bases(game) do
    update_game!(game, %{
      first_occupied: false,
      second_occupied: false,
      third_occupied: false,
      first_runner_id: nil,
      second_runner_id: nil,
      third_runner_id: nil
    })
  end

  defp occupied_bases(game) do
    Enum.count([game.first_occupied, game.second_occupied, game.third_occupied], & &1)
  end

  defp upsert_spot!(game_id, team_id, player_id, attrs) do
    case Repo.get_by(LineupSpot, game_id: game_id, player_id: player_id) do
      nil ->
        %LineupSpot{game_id: game_id, team_id: team_id, player_id: player_id}
        |> LineupSpot.changeset(attrs)
        |> Repo.insert!()

      spot ->
        spot |> LineupSpot.changeset(attrs) |> Repo.update!()
    end
  end

  defp player!(team_id, name) do
    name = name |> to_string() |> String.trim() |> String.slice(0, 100)

    Repo.get_by(Player, team_id: team_id, name: name) ||
      %Player{team_id: team_id} |> Player.changeset(%{name: name}) |> Repo.insert!()
  end

  defp team!(show, position), do: Show.team(show, String.to_integer(position))

  defp next_order(game, team_id, current) do
    maximum = max_lineup_order(game.id, team_id)
    if maximum <= 1, do: 1, else: if(current >= maximum, do: 1, else: current + 1)
  end

  defp max_lineup_order(game_id, team_id) do
    LineupSpot
    |> where(game_id: ^game_id, team_id: ^team_id)
    |> select([spot], max(spot.batting_order))
    |> Repo.one()
    |> case do
      nil -> 1
      value -> value
    end
  end

  defp next_sequence(schema, game_id) do
    schema
    |> where(game_id: ^game_id)
    |> select([row], max(row.sequence))
    |> Repo.one()
    |> Kernel.||(0)
    |> Kernel.+(1)
  end

  defp update_game!(game, attrs), do: game |> Game.changeset(attrs) |> Repo.update!()

  defp game_state(game) do
    Map.new(@game_fields, &{to_string(&1), Map.get(game, &1)})
  end

  defp atomize_game_state(state) do
    Map.new(@game_fields, &{&1, Map.get(state, to_string(&1))})
  end

  defp pitcher_field("1"), do: :away_pitcher_id
  defp pitcher_field("2"), do: :home_pitcher_id
  defp pitch_count_field("1"), do: :away_pitch_count
  defp pitch_count_field("2"), do: :home_pitch_count
  defp batter_order_field("1"), do: :away_batter_order
  defp batter_order_field("2"), do: :home_batter_order

  defp lines(text),
    do: text |> String.split(~r/\R/u) |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

  defp parse_pairs(text) do
    text
    |> lines()
    |> Enum.flat_map(fn line ->
      case String.split(line, ~r/\s*[:|]\s*/, parts: 2) do
        [key, value] when value != "" -> [{String.upcase(String.trim(key)), String.trim(value)}]
        _ -> []
      end
    end)
  end

  defp parse_roster(text) do
    {entries, _next_order} =
      text
      |> lines()
      |> Enum.reduce({[], 1}, fn line, {entries, next_order} ->
        case defense_only_entry(line) do
          {:ok, field_position, name} ->
            entry = %{name: name, batting_order: nil, field_position: field_position}
            {[entry | entries], next_order}

          :error ->
            {name, field_position} = batting_entry(line)

            if name == "" do
              {entries, next_order}
            else
              entry = %{
                name: name,
                batting_order: next_order,
                field_position: field_position
              }

              {[entry | entries], next_order + 1}
            end
        end
      end)

    entries |> Enum.reverse() |> Enum.take(30)
  end

  defp defense_only_entry(line) do
    case Regex.run(~r/^\s*([A-Z0-9]+)\s*:\s*(.+)$/iu, line, capture: :all_but_first) do
      [field_position, name] ->
        field_position = String.upcase(field_position)

        if field_position in @positions and String.trim(name) != "" do
          {:ok, field_position, String.trim(name)}
        else
          :error
        end

      _ ->
        :error
    end
  end

  defp batting_entry(line) do
    line = String.replace(line, ~r/^\s*\d+\s*[.)-]?\s*/u, "")

    case Regex.run(
           ~r/^(.*?)\s*(?:\||\t|\s+-\s+|,)\s*(P|C|1B|2B|3B|SS|LF|CF|RF|DH)\s*$/iu,
           line,
           capture: :all_but_first
         ) do
      [name, field_position] -> {String.trim(name), String.upcase(field_position)}
      _ -> {String.trim(line), ""}
    end
  end

  defp blank_default(value, fallback) do
    case String.trim(to_string(value || "")) do
      "" -> fallback
      text -> text
    end
  end

  defp normalize_notation(value) do
    notation = value |> to_string() |> String.trim() |> String.upcase() |> String.slice(0, 40)

    if Regex.match?(~r/^\d{2,6}$/u, notation) do
      notation |> String.graphemes() |> Enum.join("-")
    else
      notation
    end
  end

  defp stringify_stat_keys(map), do: Map.new(map, fn {key, value} -> {to_string(key), value} end)

  defp to_integer(value) when is_integer(value), do: value

  defp to_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, _} -> number
      :error -> 0
    end
  end

  defp to_integer(_value), do: 0

  defp optional_integer(value) do
    case to_integer(value) do
      number when number > 0 -> number
      _ -> nil
    end
  end

  defp selected_player_id(game, value, team_id \\ nil) do
    player_id = optional_integer(value)

    query =
      LineupSpot
      |> where(game_id: ^game.id, player_id: ^player_id)
      |> then(fn query -> if team_id, do: where(query, team_id: ^team_id), else: query end)
      |> select([spot], spot.player_id)

    if player_id, do: Repo.one(query), else: nil
  end
end
