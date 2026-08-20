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
    "errors" => %{"1" => 0, "2" => 0}
  }

  @impl true
  def metadata do
    %{
      key: "baseball",
      name: "Baseball",
      summary: "Innings, count, outs, occupied bases, runs, hits and errors.",
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
      "errors" => counters(state["errors"])
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

  def transition(state, "next_half", _params), do: {:ok, advance_half(normalize_state(state))}
  def transition(state, "previous_half", _params), do: {:ok, rewind_half(normalize_state(state))}

  def transition(state, "clear_count", _params) do
    {:ok, state |> normalize_state() |> Map.merge(%{"balls" => 0, "strikes" => 0})}
  end

  def transition(state, "clear_bases", _params) do
    {:ok, put_in(normalize_state(state), ["bases"], @default["bases"])}
  end

  def transition(_state, "reset", _params), do: {:ok, @default}
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

  defp to_integer(value) when is_integer(value), do: value

  defp to_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, _rest} -> integer
      :error -> 0
    end
  end

  defp to_integer(_value), do: 0
end
