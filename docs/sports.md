# Sports: adding game rules and controls

A **sport** tells Showish how an operator tracks the live competition. It is
independent of the two overlay axes documented in [Overlays](overlays.md):

- a **scene** decides what is on screen;
- a **preset** (theme) decides how scenes look; and
- a **sport** decides which game state exists, how operators change it, and
  which scenes make sense for that show.

Teams, branding, talent, overlay URLs, PubSub updates, and the public JSON API
are shared. A sport only owns the rules and UI that genuinely differ.

## How it fits together

```text
lib/showish/broadcasts/sport.ex
    The catalogue and behaviour. One handler module is registered per sport.

lib/showish/broadcasts/sports/<sport>.ex
    Defaults, normalization, and allowed state transitions for one sport.

lib/showish_web/components/sport_controls.ex
    Function-component clauses for sport-specific live controls.

lib/showish_web/live/overlays/scorebug.ex
    Sport-specific scorebug markup only when the generic geometry is not enough.

lib/showish_web/scenes.ex
    The scene catalogue, including optional sport restrictions.
```

Each show stores two fields:

- `sport` is the registered string key, such as `"esports"` or `"baseball"`;
- `sport_state` is a JSON-compatible map validated by that sport's handler.

Because sport state is a map, adding the next sport does **not** require another
database migration. The original migration only establishes this shared
container.

## Add a sport

Worked example: a basketball sport with a period and possession arrow.

### Step 1 — implement the sport handler

Create `lib/showish/broadcasts/sports/basketball.ex` and implement the
`Showish.Broadcasts.Sport` callbacks:

```elixir
defmodule Showish.Broadcasts.Sports.Basketball do
  @behaviour Showish.Broadcasts.Sport

  @default %{"period" => 1, "possession" => "none"}

  @impl true
  def metadata do
    %{
      key: "basketball",
      name: "Basketball",
      summary: "Periods, possession and team scores.",
      control_title: "Basketball game",
      control_summary: "Live controls for the current period."
    }
  end

  @impl true
  def default_state, do: @default

  @impl true
  def normalize_state(state) when is_map(state) do
    %{
      "period" => period(Map.get(state, "period")),
      "possession" => possession(Map.get(state, "possession"))
    }
  end

  def normalize_state(_state), do: @default

  @impl true
  def transition(state, "next_period", _params) do
    state = normalize_state(state)
    {:ok, Map.update!(state, "period", &(&1 + 1))}
  end

  def transition(state, "set_possession", %{"position" => position})
      when position in ~w(1 2 none) do
    {:ok, Map.put(normalize_state(state), "possession", position)}
  end

  def transition(_state, _action, _params),
    do: {:error, :unsupported_sport_action}

  defp possession(value) when value in ~w(1 2 none), do: value
  defp possession(_value), do: "none"

  defp period(value) when is_integer(value), do: max(value, 1)
  defp period(_value), do: 1
end
```

The handler has four responsibilities:

1. `metadata/0` supplies catalogue and control-room copy.
2. `default_state/0` returns a complete fresh state.
3. `normalize_state/1` turns old, partial, or malformed persisted data into a
   complete valid state.
4. `transition/3` accepts a small, explicit set of operator actions and returns
   either `{:ok, state}` or `{:error, reason}`.

### Step 2 — register the handler

In `Showish.Broadcasts.Sport`, alias the module and add it to `@sports`:

```elixir
alias Showish.Broadcasts.Sports.Basketball

@sports [Esports, Baseball, Basketball]
```

That one entry automatically provides:

- the new-show and control-room select option;
- changeset validation;
- metadata lookup and fallback behavior; and
- dispatch for normalization, transitions, and resets.

### Step 3 — add the live controls

Add a `panel/1` clause above the generic fallback in
`ShowishWeb.SportControls`:

```elixir
def panel(%{show: %{sport: "basketball"}} = assigns) do
  state = Basketball.normalize_state(assigns.show.sport_state)
  assigns = assign(assigns, :state, state)

  ~H"""
  <div id="basketball-controls">
    <span id="basketball-period">Period {@state["period"]}</span>
    <button
      id="basketball-next-period"
      type="button"
      phx-click="sport_action"
      phx-value-action="next_period"
    >
      Next period
    </button>
  </div>
  """
end
```

Buttons push the shared `sport_action` event. The parent control LiveView sends
the action and remaining `phx-value-*` parameters through
`Broadcasts.apply_sport_action/3`, reloads the show, and broadcasts it. A new
sport does not need another LiveView event handler.

Team score controls may continue to use the shared `score` event. A sport whose
primary score is not a simple non-negative team total can keep that value in
`sport_state` and expose its own transition instead.

### Step 4 — specialize the scorebug only when needed

If the existing scorebug geometry fits, no sport-specific clause is required.
When the sport needs different information or layout, add a clause before the
generic clause in `ShowishWeb.Overlays.Scorebug`:

```elixir
@impl Phoenix.LiveView
def render(%{show: %{sport: "basketball"}} = assigns) do
  assigns = assign(assigns, :state, Basketball.normalize_state(assigns.show.sport_state))
  basketball(assigns)
end
```

The specialized markup must still begin with `<.stage preset={@show.preset}
...>`, reuse overlay tokens and shared components, and avoid theme-specific
paint. That lets every preset continue to skin it. Only add a preset-specific
markup fork when the preset also changes the geometry, following the structural
preset rules in [Overlays](overlays.md#2b-a-structural-preset).

### Step 5 — decide which scenes apply

Scenes without a `:sports` key are shared by every sport. Add a restriction only
when a scene is meaningless outside a known set of sports:

```elixir
%{
  key: "shot-chart",
  name: "Shot chart",
  summary: "Makes and misses by floor location.",
  sports: ["basketball"]
}
```

Multiple sports can share a restricted scene:

```elixir
sports: ["basketball", "wheelchair-basketball"]
```

`Scenes.for_sport/1` drives both preview tabs and the browser-source URL list,
so unavailable scenes disappear from operator workflows automatically. The
route may remain mounted; the catalogue controls discoverability, not access.

## State and transition rules

Treat `sport_state` as persisted, user-influenced data:

- Use **string keys** throughout so values round-trip through JSON unchanged.
- Normalize every field. Supply defaults, constrain enum values, clamp numeric
  ranges, and rebuild nested maps from known keys.
- Match transitions on a finite set of action strings and parameter shapes.
- Never call `String.to_atom/1` on action names or parameters.
- Return an error for unknown actions instead of silently accepting them.
- Keep a transition deterministic: the same state and parameters should produce
  the same result.
- Clear transient state explicitly when the game advances. Baseball, for
  example, clears count, outs, and bases between half innings.

Normalization is deliberately run on both reads and writes. This allows a
handler to add a new optional field later while old shows continue to work with
the new default.

## What is inherited automatically

Once a handler is registered, the shared system already handles:

- storing `sport` and normalized `sport_state`;
- live PubSub fan-out after every operator action;
- the public JSON fields `sport` and `sport_state`;
- team names, colors, logos, records, and scores;
- shared standby, break, ticker, talent, credits, and camera scenes; and
- visual presets through the stage token contract.

Only add sport-specific code where the rules, controls, or geometry truly
differ.

## Tests

Add focused coverage at each boundary:

1. **Handler/context tests** in `test/showish/broadcasts_test.exs`: defaults,
   malformed-state normalization, bounds, every transition, reset behavior,
   and PubSub delivery.
2. **Control tests** in `test/showish_web/live/control_live_test.exs`: select the
   sport, assert key element IDs, click controls, and verify persisted outcomes.
3. **Overlay tests** in `test/showish_web/live/overlays_test.exs`: assert the
   specialized scorebug and confirm connected overlays receive live changes.
4. **JSON tests** when the sport adds externally important state expectations.

Use element IDs and `Phoenix.LiveViewTest` selectors rather than assertions
against raw HTML. Finish with:

```bash
mix precommit
```

## Removing a sport

Do not remove a registered key while shows still use it. First migrate those
shows to another sport and normalize or clear their state; then remove the
handler, its catalogue entry, controls, specialized overlay markup, and tests.
The shared `sport` and `sport_state` columns remain for every other sport.
