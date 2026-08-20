defmodule ShowishWeb.SportControls do
  @moduledoc """
  Sport-specific live controls rendered inside the shared control room.

  Event handling stays in the parent LiveView, so these remain lightweight
  function components. Add one `panel/1` clause when a new sport needs controls
  that differ from the generic esports series.
  """

  use ShowishWeb, :html

  alias Showish.Broadcasts.Sports.Baseball
  alias Showish.Broadcasts.Team

  attr :show, :any, required: true

  def panel(%{show: %{sport: "baseball"}} = assigns) do
    state = Baseball.normalize_state(assigns.show.sport_state)
    teams = sorted_teams(assigns.show)
    batting_position = if state["half"] == "top", do: 1, else: 2

    assigns =
      assigns
      |> assign(:state, state)
      |> assign(:teams, teams)
      |> assign(:batting_position, batting_position)
      |> assign(:batting_team, Enum.find(teams, &(&1.position == batting_position)))

    ~H"""
    <div id="baseball-controls" class="space-y-4">
      <div
        id="baseball-live-state"
        class="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-slate-700 bg-slate-950 px-4 py-3 text-white shadow-sm"
      >
        <div class="flex items-center gap-3">
          <span class="relative flex size-2.5">
            <span class="absolute inline-flex size-full animate-ping rounded-full bg-emerald-400 opacity-50">
            </span>
            <span class="relative inline-flex size-2.5 rounded-full bg-emerald-400"></span>
          </span>
          <div>
            <p class="text-[10px] font-bold uppercase tracking-[0.18em] text-slate-400">
              Live game state
            </p>
            <p class="font-black uppercase tracking-wide">
              {if(@state["half"] == "top", do: "Top", else: "Bottom")} {@state["inning"]}
              <span class="px-1.5 text-slate-600">/</span>
              {if(@batting_team, do: Team.full_name(@batting_team), else: "Away")} batting
            </p>
          </div>
        </div>
        <div class="flex items-center gap-2 font-mono text-sm font-bold tabular-nums">
          <span class="rounded bg-white/8 px-2.5 py-1">{@state["balls"]}-{@state["strikes"]}</span>
          <span class="rounded bg-white/8 px-2.5 py-1">
            {@state["outs"]} {if(@state["outs"] == 1, do: "out", else: "outs")}
          </span>
        </div>
      </div>

      <div class="grid gap-3 sm:grid-cols-2">
        <.baseball_score_control
          :for={team <- @teams}
          team={team}
          role={if(team.position == 1, do: "Away", else: "Home")}
          batting?={team.position == @batting_position}
        />
      </div>

      <div class="grid gap-3 lg:grid-cols-[0.85fr_1.45fr_1fr]">
        <section class="rounded-lg border border-base-300 bg-base-200/45 p-4">
          <div class="flex items-center justify-between">
            <p class="text-[11px] font-black uppercase tracking-[0.18em] text-base-content/55">
              Inning
            </p>
            <span class="rounded bg-primary/10 px-2 py-1 text-[10px] font-black uppercase tracking-wider text-primary">
              {if(@state["half"] == "top", do: "Away batting", else: "Home batting")}
            </span>
          </div>
          <div class="mt-4 flex items-center justify-between gap-3">
            <button
              id="baseball-previous-half"
              type="button"
              class="grid size-11 place-items-center rounded-md border border-base-300 bg-base-100 transition hover:-translate-y-0.5 hover:border-base-content/35 hover:shadow-md active:translate-y-0"
              phx-click="sport_action"
              phx-value-action="previous_half"
              aria-label="Previous half inning"
            >
              <.icon name="hero-chevron-left-mini" class="size-5" />
            </button>
            <div class="text-center">
              <div id="baseball-inning" class="text-5xl font-black leading-none tabular-nums">
                {@state["inning"]}
              </div>
              <div class="mt-1 text-xs font-black uppercase tracking-[0.18em] text-primary">
                {if(@state["half"] == "top", do: "Top", else: "Bottom")}
              </div>
            </div>
            <button
              id="baseball-next-half"
              type="button"
              class="grid size-11 place-items-center rounded-md bg-primary text-primary-content shadow-sm transition hover:-translate-y-0.5 hover:brightness-110 hover:shadow-md active:translate-y-0"
              phx-click="sport_action"
              phx-value-action="next_half"
              aria-label="Next half inning"
            >
              <.icon name="hero-chevron-right-mini" class="size-5" />
            </button>
          </div>
          <button
            id="baseball-advance-half"
            type="button"
            class="mt-4 flex w-full items-center justify-center gap-2 rounded-md bg-slate-900 px-3 py-2.5 text-xs font-black uppercase tracking-[0.12em] text-white transition hover:bg-slate-800 active:scale-[0.99] dark:bg-slate-100 dark:text-slate-950 dark:hover:bg-white"
            phx-click="sport_action"
            phx-value-action="next_half"
          >
            Advance half inning <.icon name="hero-arrow-right-mini" class="size-4" />
          </button>
        </section>

        <section class="rounded-lg border border-base-300 bg-base-200/45 p-4">
          <div class="flex items-center justify-between">
            <p class="text-[11px] font-black uppercase tracking-[0.18em] text-base-content/55">
              Pitch & out count
            </p>
            <button
              id="baseball-clear-count"
              type="button"
              class="rounded px-2 py-1 text-[10px] font-black uppercase tracking-wider text-base-content/55 transition hover:bg-base-300 hover:text-base-content"
              phx-click="sport_action"
              phx-value-action="clear_count"
            >
              New batter
            </button>
          </div>
          <div class="mt-3 grid grid-cols-3 gap-2">
            <.count_control label="Balls" kind="balls" value={@state["balls"]} maximum={3} />
            <.count_control label="Strikes" kind="strikes" value={@state["strikes"]} maximum={2} />
            <.count_control label="Outs" kind="outs" value={@state["outs"]} maximum={2} />
          </div>
        </section>

        <section class="rounded-lg border border-base-300 bg-base-200/45 p-4">
          <div class="flex items-center justify-between">
            <p class="text-[11px] font-black uppercase tracking-[0.18em] text-base-content/55">
              Runners
            </p>
            <button
              id="baseball-clear-bases"
              type="button"
              class="rounded px-2 py-1 text-[10px] font-black uppercase tracking-wider text-base-content/55 transition hover:bg-base-300 hover:text-base-content"
              phx-click="sport_action"
              phx-value-action="clear_bases"
            >
              Clear
            </button>
          </div>
          <div class="mx-auto mt-5 grid w-36 grid-cols-3 grid-rows-2 gap-3">
            <.base_button base="second" occupied={@state["bases"]["second"]} class="col-start-2" />
            <.base_button
              base="third"
              occupied={@state["bases"]["third"]}
              class="col-start-1 row-start-2"
            />
            <.base_button
              base="first"
              occupied={@state["bases"]["first"]}
              class="col-start-3 row-start-2"
            />
          </div>
          <p class="mt-5 text-center text-[10px] font-bold uppercase tracking-wider text-base-content/45">
            Tap a base to toggle
          </p>
        </section>
      </div>

      <section class="overflow-hidden rounded-lg border border-base-300">
        <div class="grid grid-cols-[minmax(0,1fr)_96px_96px] border-b border-base-300 bg-base-200/70 px-4 py-2 text-[10px] font-black uppercase tracking-[0.16em] text-base-content/50">
          <span>Line totals</span><span class="text-center">Hits</span><span class="text-center">Errors</span>
        </div>
        <div
          :for={team <- @teams}
          class="grid grid-cols-[minmax(0,1fr)_96px_96px] items-center bg-base-100 px-4 py-2.5 not-last:border-b not-last:border-base-300"
        >
          <span class="flex min-w-0 items-center gap-2 truncate font-bold">
            <span class="size-2 shrink-0 rounded-full" style={"background: #{team.primary_color}"}>
            </span>
            {Team.full_name(team)}
          </span>
          <.stat_control
            stat="hits"
            position={team.position}
            value={@state["hits"][to_string(team.position)]}
          />
          <.stat_control
            stat="errors"
            position={team.position}
            value={@state["errors"][to_string(team.position)]}
          />
        </div>
      </section>

      <div class="flex justify-end border-t border-base-300 pt-3">
        <button
          id="baseball-reset-game"
          type="button"
          class="rounded px-3 py-2 text-xs font-bold text-error transition hover:bg-error/10"
          phx-click="reset_sport"
          data-confirm="Reset the inning, count, bases, runs, hits and errors?"
        >
          Reset game
        </button>
      </div>
    </div>
    """
  end

  def panel(assigns) do
    assigns = assign(assigns, :teams, sorted_teams(assigns.show))

    ~H"""
    <div id="esports-controls">
      <div class="grid gap-4 sm:grid-cols-2">
        <.score_control :for={team <- @teams} team={team} label={"Team #{team.position}"} />
      </div>

      <div class="mt-4 flex flex-wrap gap-2">
        <button id="swap-sides" type="button" class="btn btn-sm" phx-click="swap_sides">
          <.icon name="hero-arrows-right-left-mini" class="size-4" />
          {if @show.swap_sides, do: "Sides swapped", else: "Swap sides"}
        </button>
        <button
          id="previous-game"
          type="button"
          class="btn btn-sm"
          phx-click="step_game"
          phx-value-delta="-1"
        >
          Previous game
        </button>
        <span class="btn btn-sm btn-ghost pointer-events-none">
          Game {@show.current_game} of {max(length(@show.games), 1)}
        </span>
        <button
          id="next-game"
          type="button"
          class="btn btn-sm"
          phx-click="step_game"
          phx-value-delta="1"
        >
          Next game
        </button>
        <button
          id="reset-scores"
          type="button"
          class="btn btn-sm btn-ghost text-error"
          phx-click="reset_scores"
          data-confirm="Set both series scores back to zero?"
        >
          Reset scores
        </button>
      </div>
    </div>
    """
  end

  attr :team, :any, required: true
  attr :role, :string, required: true
  attr :batting?, :boolean, required: true

  defp baseball_score_control(assigns) do
    ~H"""
    <section class={[
      "relative overflow-hidden rounded-lg border bg-base-100 p-3 transition",
      @batting? &&
        "border-primary/60 shadow-[0_0_0_1px_color-mix(in_oklab,var(--color-primary)_22%,transparent)]",
      !@batting? && "border-base-300"
    ]}>
      <span class="absolute inset-y-0 left-0 w-1" style={"background: #{@team.primary_color}"}></span>
      <div class="flex items-center gap-3 pl-1">
        <div class="min-w-0 flex-1">
          <div class="flex items-center gap-2">
            <span class="text-[10px] font-black uppercase tracking-[0.16em] text-base-content/45">
              {@role}
            </span>
            <span
              :if={@batting?}
              class="rounded bg-primary/12 px-1.5 py-0.5 text-[9px] font-black uppercase tracking-wider text-primary"
            >
              At bat
            </span>
          </div>
          <div class="truncate text-lg font-black">{Team.full_name(@team)}</div>
        </div>
        <button
          id={"run-down-#{@team.position}"}
          type="button"
          class="grid size-10 place-items-center rounded-md border border-base-300 bg-base-200 text-xl font-bold transition hover:border-base-content/30 hover:bg-base-300 active:scale-95"
          phx-click="score"
          phx-value-position={@team.position}
          phx-value-delta="-1"
          aria-label={"Decrease #{@role} runs"}
        >
          −
        </button>
        <span class="w-12 text-center text-4xl font-black leading-none tabular-nums">
          {@team.score}
        </span>
        <button
          id={"run-up-#{@team.position}"}
          type="button"
          class="grid size-10 place-items-center rounded-md bg-primary text-xl font-bold text-primary-content shadow-sm transition hover:brightness-110 active:scale-95 disabled:opacity-45"
          phx-click="score"
          phx-value-position={@team.position}
          phx-value-delta="1"
          aria-label={"Increase #{@role} runs"}
        >
          +
        </button>
      </div>
    </section>
    """
  end

  attr :team, :any, required: true
  attr :label, :string, required: true
  attr :id_prefix, :string, default: "score"

  defp score_control(assigns) do
    ~H"""
    <div class="rounded-box flex items-center gap-3 border border-base-300 p-3">
      <span class="size-8 shrink-0 rounded" style={"background: #{@team.primary_color}"}></span>
      <div class="min-w-0 flex-1">
        <div class="truncate font-bold">{Team.full_name(@team)}</div>
        <div class="text-xs text-base-content/60">{@label}</div>
      </div>
      <button
        type="button"
        id={"#{@id_prefix}-down-#{@team.position}"}
        class="btn btn-sm btn-circle"
        phx-click="score"
        phx-value-position={@team.position}
        phx-value-delta="-1"
        aria-label={"Decrease #{@label}"}
      >
        −
      </button>
      <span class="w-10 text-center text-2xl font-black tabular-nums">{@team.score}</span>
      <button
        type="button"
        id={"#{@id_prefix}-up-#{@team.position}"}
        class="btn btn-sm btn-circle btn-primary"
        phx-click="score"
        phx-value-position={@team.position}
        phx-value-delta="1"
        aria-label={"Increase #{@label}"}
      >
        +
      </button>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :kind, :string, required: true
  attr :value, :integer, required: true
  attr :maximum, :integer, required: true

  defp count_control(assigns) do
    ~H"""
    <div class="flex min-w-0 flex-col items-center rounded-md border border-base-300 bg-base-100 p-2">
      <span class="text-[10px] font-black uppercase tracking-[0.12em] text-base-content/50">
        {@label}
      </span>
      <span id={"baseball-#{@kind}"} class="my-1 text-3xl font-black leading-none tabular-nums">
        {@value}
      </span>
      <div class="grid w-full grid-cols-2 gap-1.5">
        <button
          id={"baseball-#{@kind}-down"}
          type="button"
          class="grid h-8 place-items-center rounded border border-base-300 bg-base-200 font-black transition hover:bg-base-300 active:scale-95"
          phx-click="sport_action"
          phx-value-action="adjust_count"
          phx-value-kind={@kind}
          phx-value-delta="-1"
          aria-label={"Decrease #{@label}"}
        >
          −
        </button>
        <button
          id={"baseball-#{@kind}-up"}
          type="button"
          class="grid h-8 place-items-center rounded bg-primary font-black text-primary-content transition hover:brightness-110 active:scale-95 disabled:cursor-not-allowed disabled:opacity-30"
          disabled={@value >= @maximum}
          phx-click="sport_action"
          phx-value-action="adjust_count"
          phx-value-kind={@kind}
          phx-value-delta="1"
          aria-label={"Increase #{@label}"}
        >
          +
        </button>
      </div>
    </div>
    """
  end

  attr :base, :string, required: true
  attr :occupied, :boolean, required: true
  attr :class, :string, default: nil

  defp base_button(assigns) do
    ~H"""
    <button
      id={"baseball-base-#{@base}"}
      type="button"
      class={[
        "size-10 rotate-45 rounded-sm border-2 transition duration-150 hover:scale-105 active:scale-95",
        @occupied &&
          "border-warning bg-warning shadow-[0_0_16px_color-mix(in_oklab,var(--color-warning)_55%,transparent)]",
        !@occupied && "border-base-content/25 bg-base-100 hover:border-base-content/50",
        @class
      ]}
      phx-click="sport_action"
      phx-value-action="toggle_base"
      phx-value-base={@base}
      aria-label={"Toggle runner on #{@base} base"}
      aria-pressed={to_string(@occupied)}
    >
      <span class="sr-only">{@base} base</span>
    </button>
    """
  end

  attr :stat, :string, required: true
  attr :position, :integer, required: true
  attr :value, :integer, required: true

  defp stat_control(assigns) do
    ~H"""
    <div class="flex items-center justify-center gap-1.5">
      <button
        id={"baseball-#{@stat}-down-#{@position}"}
        type="button"
        class="grid size-7 place-items-center rounded border border-base-300 text-sm font-bold transition hover:bg-base-200"
        phx-click="sport_action"
        phx-value-action="adjust_stat"
        phx-value-stat={@stat}
        phx-value-position={@position}
        phx-value-delta="-1"
      >
        −
      </button>
      <span id={"baseball-#{@stat}-#{@position}"} class="w-6 text-center font-black tabular-nums">
        {@value}
      </span>
      <button
        id={"baseball-#{@stat}-up-#{@position}"}
        type="button"
        class="grid size-7 place-items-center rounded border border-base-300 text-sm font-bold transition hover:bg-base-200"
        phx-click="sport_action"
        phx-value-action="adjust_stat"
        phx-value-stat={@stat}
        phx-value-position={@position}
        phx-value-delta="1"
      >
        +
      </button>
    </div>
    """
  end

  defp sorted_teams(show), do: show.teams |> List.wrap() |> Enum.sort_by(& &1.position)
end
