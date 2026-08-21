defmodule Showish.Broadcasts.Sports.Baseball do
  @moduledoc "Validated live game state and operator actions for baseball."

  @behaviour Showish.Broadcasts.Sport

  @default %{
    "inning" => 1,
    "half" => "top",
    "balls" => 0,
    "strikes" => 0,
    "outs" => 0,
    "bases" => %{"first" => false, "second" => false, "third" => false},
    "hits" => %{"1" => 0, "2" => 0},
    "errors" => %{"1" => 0, "2" => 0},
    "lineups" => %{"1" => [], "2" => []},
    "active_batters" => %{"1" => 0, "2" => 0},
    "defense" => %{
      "1" => %{
        "P" => "",
        "C" => "",
        "1B" => "",
        "2B" => "",
        "3B" => "",
        "SS" => "",
        "LF" => "",
        "CF" => "",
        "RF" => ""
      },
      "2" => %{
        "P" => "",
        "C" => "",
        "1B" => "",
        "2B" => "",
        "3B" => "",
        "SS" => "",
        "LF" => "",
        "CF" => "",
        "RF" => ""
      }
    },
    "bullpens" => %{"1" => [], "2" => []},
    "pitchers" => %{
      "1" => %{"name" => "", "pitch_count" => 0},
      "2" => %{"name" => "", "pitch_count" => 0}
    },
    "graphics" => %{
      "single" => %{
        "kicker" => "PLAYER SPOTLIGHT",
        "name" => "",
        "detail" => "",
        "stats" => []
      },
      "comparison" => %{
        "title" => "PLAYER COMPARISON",
        "left_name" => "",
        "left_detail" => "",
        "right_name" => "",
        "right_detail" => "",
        "stats" => []
      }
    },
    "history" => []
  }

  @impl true
  def metadata do
    %{
      key: "baseball",
      name: "Baseball",
      summary: "Innings, live pitches, lineups, pitching, runners and line totals.",
      control_title: "Baseball game",
      control_summary: "Fast live controls for the current plate appearance."
    }
  end

  @impl true
  def default_state, do: @default

  @impl true
  def normalize_state(state) when is_map(state) do
    %{
      "inning" => integer(state, "inning", 1, 1),
      "half" => inclusion(state, "half", ~w(top bottom), "top"),
      "balls" => integer(state, "balls", 0, 0, 3),
      "strikes" => integer(state, "strikes", 0, 0, 2),
      "outs" => integer(state, "outs", 0, 0, 2),
      "bases" => booleans(state["bases"], ~w(first second third)),
      "hits" => counters(state["hits"]),
      "errors" => counters(state["errors"]),
      "lineups" => lineups(state["lineups"]),
      "active_batters" => active_batters(state["active_batters"], state["lineups"]),
      "defense" => defense(state["defense"]),
      "bullpens" => bullpens(state["bullpens"]),
      "pitchers" => pitchers(state["pitchers"]),
      "graphics" => graphics(state["graphics"]),
      "history" => history(state["history"])
    }
  end

  def normalize_state(_state), do: @default

  @impl true
  def transition(state, "adjust_count", %{"kind" => kind, "delta" => delta})
      when kind in ~w(balls strikes outs) do
    state = normalize_state(state)
    maximum = if kind == "balls", do: 3, else: 2
    value = state[kind] + to_integer(delta)
    {:ok, Map.put(state, kind, value |> max(0) |> min(maximum))}
  end

  def transition(state, "toggle_base", %{"base" => base}) when base in ~w(first second third) do
    state = normalize_state(state)
    {:ok, put_in(state, ["bases", base], !state["bases"][base])}
  end

  def transition(state, "adjust_stat", %{
        "stat" => stat,
        "position" => position,
        "delta" => delta
      })
      when stat in ~w(hits errors) and position in ~w(1 2) do
    state = normalize_state(state)
    value = max(state[stat][position] + to_integer(delta), 0)
    {:ok, put_in(state, [stat, position], value)}
  end

  def transition(state, "save_lineup", %{
        "lineup" => %{"position" => position, "names" => names}
      })
      when position in ~w(1 2) and is_binary(names) do
    state = normalize_state(state)
    existing = state["lineups"][position]

    lineup =
      names
      |> String.split(~r/\R/u)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.take(20)
      |> Enum.with_index()
      |> Enum.map(fn {name, index} ->
        previous = Enum.at(existing, index, %{})

        %{
          "name" => name,
          "at_bats" => if(previous["name"] == name, do: previous["at_bats"], else: 0),
          "hits" => if(previous["name"] == name, do: previous["hits"], else: 0)
        }
      end)

    active = clamp_active(state["active_batters"][position], lineup)

    {:ok,
     state
     |> put_in(["lineups", position], lineup)
     |> put_in(["active_batters", position], active)}
  end

  def transition(state, "set_batter", %{"position" => position, "index" => index})
      when position in ~w(1 2) do
    state = normalize_state(state)
    lineup = state["lineups"][position]
    {:ok, put_in(state, ["active_batters", position], clamp_active(to_integer(index), lineup))}
  end

  def transition(state, "next_batter", %{"position" => position}) when position in ~w(1 2) do
    state = normalize_state(state)
    lineup = state["lineups"][position]
    current = state["active_batters"][position]
    next = if lineup == [], do: 0, else: rem(current + 1, length(lineup))

    {:ok,
     state
     |> put_in(["active_batters", position], next)
     |> Map.merge(%{"balls" => 0, "strikes" => 0})}
  end

  def transition(state, "adjust_batter_stat", %{
        "position" => position,
        "stat" => stat,
        "delta" => delta
      })
      when position in ~w(1 2) and stat in ~w(hits at_bats) do
    state = normalize_state(state)
    index = state["active_batters"][position]

    case Enum.at(state["lineups"][position], index) do
      nil ->
        {:ok, state}

      player ->
        value = max(player[stat] + to_integer(delta), 0)
        player = Map.put(player, stat, value)
        lineup = List.replace_at(state["lineups"][position], index, player)
        {:ok, put_in(state, ["lineups", position], lineup)}
    end
  end

  def transition(state, "save_pitcher", %{
        "pitcher" => %{"position" => position, "name" => name}
      })
      when position in ~w(1 2) and is_binary(name) do
    state = normalize_state(state)
    {:ok, put_in(state, ["pitchers", position, "name"], String.trim(name))}
  end

  def transition(state, "save_defense", %{
        "defense" => %{"position" => position, "players" => players}
      })
      when position in ~w(1 2) and is_binary(players) do
    state = normalize_state(state)
    {:ok, put_in(state, ["defense", position], parse_defense(players))}
  end

  def transition(state, "save_bullpen", %{
        "bullpen" => %{"position" => position, "pitchers" => pitchers}
      })
      when position in ~w(1 2) and is_binary(pitchers) do
    state = normalize_state(state)
    {:ok, put_in(state, ["bullpens", position], parse_bullpen(pitchers))}
  end

  def transition(state, "save_single_stats", %{"single" => params}) when is_map(params) do
    state = normalize_state(state)

    single = %{
      "kicker" => clean_text(params["kicker"], "PLAYER SPOTLIGHT"),
      "name" => clean_text(params["name"]),
      "detail" => clean_text(params["detail"]),
      "stats" => parse_single_stats(params["stats"])
    }

    {:ok, put_in(state, ["graphics", "single"], single)}
  end

  def transition(state, "save_comparison_stats", %{"comparison" => params})
      when is_map(params) do
    state = normalize_state(state)

    comparison = %{
      "title" => clean_text(params["title"], "PLAYER COMPARISON"),
      "left_name" => clean_text(params["left_name"]),
      "left_detail" => clean_text(params["left_detail"]),
      "right_name" => clean_text(params["right_name"]),
      "right_detail" => clean_text(params["right_detail"]),
      "stats" => parse_comparison_stats(params["stats"])
    }

    {:ok, put_in(state, ["graphics", "comparison"], comparison)}
  end

  def transition(state, "adjust_pitch_count", %{"position" => position, "delta" => delta})
      when position in ~w(1 2) do
    state = normalize_state(state)
    count = max(state["pitchers"][position]["pitch_count"] + to_integer(delta), 0)
    {:ok, put_in(state, ["pitchers", position, "pitch_count"], count)}
  end

  def transition(state, "record_pitch", %{"result" => result})
      when result in ~w(ball strike foul in_play) do
    state = state |> normalize_state() |> remember()
    state = increment_pitch_count(state)

    state =
      case result do
        "ball" ->
          if state["balls"] == 3,
            do: complete_plate_appearance(state, "walk"),
            else: Map.update!(state, "balls", &(&1 + 1))

        "strike" ->
          if state["strikes"] == 2,
            do: complete_plate_appearance(state, "out"),
            else: Map.update!(state, "strikes", &(&1 + 1))

        "foul" ->
          if state["strikes"] < 2, do: Map.update!(state, "strikes", &(&1 + 1)), else: state

        "in_play" ->
          state
      end

    {:ok, state}
  end

  def transition(state, "record_play", %{"result" => result})
      when result in ~w(out reached walk home_run) do
    state = state |> normalize_state() |> remember()
    {:ok, complete_plate_appearance(state, result)}
  end

  def transition(state, "undo", _params) do
    state = normalize_state(state)

    case state["history"] do
      [previous | rest] ->
        {:ok, previous |> normalize_state() |> Map.put("history", rest)}

      [] ->
        {:ok, state}
    end
  end

  def transition(state, "next_half", _params), do: {:ok, advance_half(normalize_state(state))}
  def transition(state, "previous_half", _params), do: {:ok, rewind_half(normalize_state(state))}

  def transition(state, "clear_count", _params) do
    {:ok, state |> normalize_state() |> Map.merge(%{"balls" => 0, "strikes" => 0})}
  end

  def transition(state, "clear_bases", _params) do
    {:ok, put_in(normalize_state(state), ["bases"], @default["bases"])}
  end

  def transition(state, "reset", _params) do
    state = normalize_state(state)

    lineups =
      Map.new(state["lineups"], fn {position, lineup} ->
        {position, Enum.map(lineup, &Map.merge(&1, %{"at_bats" => 0, "hits" => 0}))}
      end)

    pitchers =
      Map.new(state["pitchers"], fn {position, pitcher} ->
        {position, Map.put(pitcher, "pitch_count", 0)}
      end)

    {:ok,
     Map.merge(@default, %{
       "lineups" => lineups,
       "pitchers" => pitchers,
       "defense" => state["defense"],
       "bullpens" => state["bullpens"],
       "graphics" => state["graphics"]
     })}
  end

  def transition(_state, _action, _params), do: {:error, :unsupported_sport_action}

  defp advance_half(%{"half" => "top"} = state),
    do: reset_half(Map.put(state, "half", "bottom"))

  defp advance_half(state) do
    state
    |> Map.put("half", "top")
    |> Map.update!("inning", &(&1 + 1))
    |> reset_half()
  end

  defp rewind_half(%{"half" => "bottom"} = state), do: reset_half(Map.put(state, "half", "top"))

  defp rewind_half(%{"inning" => 1} = state), do: reset_half(state)

  defp rewind_half(state) do
    state
    |> Map.put("half", "bottom")
    |> Map.update!("inning", &max(&1 - 1, 1))
    |> reset_half()
  end

  defp reset_half(state) do
    Map.merge(state, %{
      "balls" => 0,
      "strikes" => 0,
      "outs" => 0,
      "bases" => @default["bases"]
    })
  end

  defp integer(map, key, fallback, minimum, maximum \\ nil) do
    value = map |> Map.get(key, fallback) |> to_integer() |> max(minimum)
    if maximum, do: min(value, maximum), else: value
  end

  defp inclusion(map, key, allowed, fallback) do
    value = Map.get(map, key, fallback)
    if value in allowed, do: value, else: fallback
  end

  defp booleans(map, keys) when is_map(map) do
    Map.new(keys, &{&1, Map.get(map, &1, false) == true})
  end

  defp booleans(_map, keys), do: Map.new(keys, &{&1, false})

  defp counters(map) when is_map(map) do
    Map.new(~w(1 2), &{&1, integer(map, &1, 0, 0)})
  end

  defp counters(_map), do: %{"1" => 0, "2" => 0}

  defp lineups(map) when is_map(map) do
    Map.new(~w(1 2), fn position ->
      players =
        map
        |> Map.get(position, [])
        |> List.wrap()
        |> Enum.take(20)
        |> Enum.flat_map(fn
          %{"name" => name} = player when is_binary(name) ->
            name = String.trim(name)

            if name == "" do
              []
            else
              [
                %{
                  "name" => name,
                  "at_bats" => integer(player, "at_bats", 0, 0),
                  "hits" => integer(player, "hits", 0, 0)
                }
              ]
            end

          _ ->
            []
        end)

      {position, players}
    end)
  end

  defp lineups(_map), do: %{"1" => [], "2" => []}

  defp active_batters(map, raw_lineups) do
    normalized_lineups = lineups(raw_lineups)

    Map.new(~w(1 2), fn position ->
      value = if is_map(map), do: Map.get(map, position, 0), else: 0
      {position, clamp_active(to_integer(value), normalized_lineups[position])}
    end)
  end

  defp pitchers(map) when is_map(map) do
    Map.new(~w(1 2), fn position ->
      pitcher = Map.get(map, position, %{})

      {position,
       %{
         "name" => pitcher |> Map.get("name", "") |> to_string() |> String.trim(),
         "pitch_count" => integer(pitcher, "pitch_count", 0, 0)
       }}
    end)
  end

  defp pitchers(_map), do: @default["pitchers"]

  defp defense(map) when is_map(map) do
    Map.new(~w(1 2), fn position ->
      raw = Map.get(map, position, %{})

      players =
        Map.new(~w(P C 1B 2B 3B SS LF CF RF), fn field_position ->
          name = if is_map(raw), do: Map.get(raw, field_position, ""), else: ""
          {field_position, clean_text(name)}
        end)

      {position, players}
    end)
  end

  defp defense(_map), do: @default["defense"]

  defp bullpens(map) when is_map(map) do
    Map.new(~w(1 2), fn position ->
      entries =
        map
        |> Map.get(position, [])
        |> List.wrap()
        |> Enum.flat_map(fn
          %{"name" => name} = entry ->
            name = clean_text(name)

            if name == "" do
              []
            else
              [%{"name" => name, "status" => clean_text(entry["status"])}]
            end

          _ ->
            []
        end)
        |> Enum.take(12)

      {position, entries}
    end)
  end

  defp bullpens(_map), do: @default["bullpens"]

  defp graphics(map) when is_map(map) do
    single = map |> Map.get("single", %{}) |> map_or_empty()
    comparison = map |> Map.get("comparison", %{}) |> map_or_empty()

    %{
      "single" => %{
        "kicker" => clean_text(single["kicker"], "PLAYER SPOTLIGHT"),
        "name" => clean_text(single["name"]),
        "detail" => clean_text(single["detail"]),
        "stats" => normalize_single_stats(single["stats"])
      },
      "comparison" => %{
        "title" => clean_text(comparison["title"], "PLAYER COMPARISON"),
        "left_name" => clean_text(comparison["left_name"]),
        "left_detail" => clean_text(comparison["left_detail"]),
        "right_name" => clean_text(comparison["right_name"]),
        "right_detail" => clean_text(comparison["right_detail"]),
        "stats" => normalize_comparison_stats(comparison["stats"])
      }
    }
  end

  defp graphics(_map), do: @default["graphics"]

  defp parse_defense(text) do
    empty = @default["defense"]["1"]

    text
    |> lines()
    |> Enum.reduce(empty, fn line, players ->
      case String.split(line, ~r/\s*[:|]\s*/, parts: 2) do
        [position, name] ->
          position = String.upcase(String.trim(position))

          if Map.has_key?(players, position),
            do: Map.put(players, position, clean_text(name)),
            else: players

        _ ->
          players
      end
    end)
  end

  defp parse_bullpen(text) do
    text
    |> lines()
    |> Enum.map(fn line ->
      case String.split(line, ~r/\s*\|\s*/, parts: 2) do
        [name, status] -> %{"name" => clean_text(name), "status" => clean_text(status)}
        [name] -> %{"name" => clean_text(name), "status" => ""}
      end
    end)
    |> Enum.reject(&(&1["name"] == ""))
    |> Enum.take(12)
  end

  defp parse_single_stats(text) when is_binary(text) do
    text
    |> lines()
    |> Enum.flat_map(fn line ->
      case String.split(line, ~r/\s*\|\s*/, parts: 2) do
        [label, value] -> [%{"label" => clean_text(label), "value" => clean_text(value)}]
        _ -> []
      end
    end)
    |> normalize_single_stats()
  end

  defp parse_single_stats(_text), do: []

  defp normalize_single_stats(stats) do
    stats
    |> List.wrap()
    |> Enum.flat_map(fn
      %{"label" => label, "value" => value} ->
        label = clean_text(label)
        if label == "", do: [], else: [%{"label" => label, "value" => clean_text(value)}]

      _ ->
        []
    end)
    |> Enum.take(8)
  end

  defp parse_comparison_stats(text) when is_binary(text) do
    text
    |> lines()
    |> Enum.flat_map(fn line ->
      case String.split(line, ~r/\s*\|\s*/, parts: 3) do
        [label, left, right] ->
          [
            %{
              "label" => clean_text(label),
              "left" => clean_text(left),
              "right" => clean_text(right)
            }
          ]

        _ ->
          []
      end
    end)
    |> normalize_comparison_stats()
  end

  defp parse_comparison_stats(_text), do: []

  defp normalize_comparison_stats(stats) do
    stats
    |> List.wrap()
    |> Enum.flat_map(fn
      %{"label" => label, "left" => left, "right" => right} ->
        label = clean_text(label)

        if label == "" do
          []
        else
          [%{"label" => label, "left" => clean_text(left), "right" => clean_text(right)}]
        end

      _ ->
        []
    end)
    |> Enum.take(8)
  end

  defp lines(text) do
    text
    |> String.split(~r/\R/u)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp clean_text(value, fallback \\ "") do
    case value |> to_string() |> String.trim() |> String.slice(0, 100) do
      "" -> fallback
      text -> text
    end
  end

  defp map_or_empty(value) when is_map(value), do: value
  defp map_or_empty(_value), do: %{}

  defp history(value) when is_list(value), do: value |> Enum.filter(&is_map/1) |> Enum.take(25)
  defp history(_value), do: []

  defp remember(state) do
    snapshot = Map.delete(state, "history")
    Map.put(state, "history", [snapshot | state["history"]] |> Enum.take(25))
  end

  defp increment_pitch_count(state) do
    position = fielding_position(state)
    update_in(state, ["pitchers", position, "pitch_count"], &(&1 + 1))
  end

  defp complete_plate_appearance(state, result) do
    batting_position = batting_position(state)
    lineup = state["lineups"][batting_position]
    current = state["active_batters"][batting_position]
    next = if lineup == [], do: 0, else: rem(current + 1, length(lineup))

    state =
      state
      |> record_batter_result(batting_position, current, result)
      |> put_in(["active_batters", batting_position], next)
      |> Map.merge(%{"balls" => 0, "strikes" => 0})

    state =
      case result do
        "walk" -> put_in(state, ["bases", "first"], true)
        "reached" -> put_in(state, ["bases", "first"], true)
        "home_run" -> put_in(state, ["bases"], @default["bases"])
        _ -> state
      end

    if result == "out" do
      if state["outs"] == 2 do
        advance_half(state)
      else
        Map.update!(state, "outs", &(&1 + 1))
      end
    else
      state
    end
  end

  defp record_batter_result(state, batting_position, index, result) do
    case Enum.at(state["lineups"][batting_position], index) do
      nil ->
        state

      player ->
        player =
          case result do
            result when result in ~w(out reached) ->
              Map.update!(player, "at_bats", &(&1 + 1))

            "home_run" ->
              player
              |> Map.update!("at_bats", &(&1 + 1))
              |> Map.update!("hits", &(&1 + 1))

            "walk" ->
              player
          end

        lineup = List.replace_at(state["lineups"][batting_position], index, player)
        put_in(state, ["lineups", batting_position], lineup)
    end
  end

  defp batting_position(%{"half" => "top"}), do: "1"
  defp batting_position(_state), do: "2"
  defp fielding_position(%{"half" => "top"}), do: "2"
  defp fielding_position(_state), do: "1"

  defp clamp_active(_index, []), do: 0
  defp clamp_active(index, lineup), do: index |> max(0) |> min(length(lineup) - 1)

  defp to_integer(value) when is_integer(value), do: value

  defp to_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, _rest} -> integer
      :error -> 0
    end
  end

  defp to_integer(_value), do: 0
end
