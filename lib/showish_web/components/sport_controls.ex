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

    assigns =
      assigns
      |> assign(:state, state)
      |> assign(:teams, sorted_teams(assigns.show))

    ~H"""
    <div id="baseball-controls" class="space-y-5">
      <div class="grid gap-3 sm:grid-cols-2">
        <.score_control
          :for={team <- @teams}
          team={team}
          label={if(team.position == 1, do: "Away runs", else: "Home runs")}
          id_prefix="run"
        />
      </div>

      <div class="grid gap-4 lg:grid-cols-[1.1fr_1fr_1fr]">
        <section class="rounded-box border border-base-300 bg-base-200/50 p-4">
          <p class="text-xs font-bold uppercase tracking-[0.16em] text-base-content/55">Inning</p>
          <div class="mt-3 flex items-center justify-between gap-3">
            <button
              id="baseball-previous-half"
              type="button"
              class="btn btn-sm btn-circle"
              phx-click="sport_action"
              phx-value-action="previous_half"
              aria-label="Previous half inning"
            >
              <.icon name="hero-chevron-left-mini" class="size-4" />
            </button>
            <div class="text-center">
              <div id="baseball-inning" class="text-3xl font-black tabular-nums">
                {@state["inning"]}
              </div>
              <div class="text-sm font-bold uppercase tracking-[0.14em] text-primary">
                {if(@state["half"] == "top", do: "Top", else: "Bottom")}
              </div>
            </div>
            <button
              id="baseball-next-half"
              type="button"
              class="btn btn-sm btn-circle btn-primary"
              phx-click="sport_action"
              phx-value-action="next_half"
              aria-label="Next half inning"
            >
              <.icon name="hero-chevron-right-mini" class="size-4" />
            </button>
          </div>
        </section>

        <section class="rounded-box border border-base-300 bg-base-200/50 p-4">
          <p class="text-xs font-bold uppercase tracking-[0.16em] text-base-content/55">Count</p>
          <div class="mt-2 space-y-2">
            <.count_control label="Balls" kind="balls" value={@state["balls"]} maximum={3} />
            <.count_control label="Strikes" kind="strikes" value={@state["strikes"]} maximum={2} />
            <.count_control label="Outs" kind="outs" value={@state["outs"]} maximum={2} />
          </div>
        </section>

        <section class="rounded-box border border-base-300 bg-base-200/50 p-4">
          <p class="text-xs font-bold uppercase tracking-[0.16em] text-base-content/55">Bases</p>
          <div class="mx-auto mt-3 grid w-32 grid-cols-3 grid-rows-2 gap-2">
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
          <p class="mt-3 text-center text-xs text-base-content/50">
            Click a base to toggle its runner.
          </p>
        </section>
      </div>

      <section class="rounded-box border border-base-300">
        <div class="grid grid-cols-[minmax(0,1fr)_88px_88px] border-b border-base-300 bg-base-200/60 px-4 py-2 text-xs font-bold uppercase tracking-[0.14em] text-base-content/55">
          <span>Team</span><span class="text-center">Hits</span><span class="text-center">Errors</span>
        </div>
        <div
          :for={team <- @teams}
          class="grid grid-cols-[minmax(0,1fr)_88px_88px] items-center px-4 py-3 not-last:border-b not-last:border-base-300"
        >
          <span class="truncate font-bold">{Team.full_name(team)}</span>
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

      <div class="flex flex-wrap gap-2">
        <button
          id="baseball-clear-count"
          type="button"
          class="btn btn-sm"
          phx-click="sport_action"
          phx-value-action="clear_count"
        >
          Clear count
        </button>
        <button
          id="baseball-clear-bases"
          type="button"
          class="btn btn-sm"
          phx-click="sport_action"
          phx-value-action="clear_bases"
        >
          Clear bases
        </button>
        <button
          id="baseball-reset-game"
          type="button"
          class="btn btn-sm btn-ghost text-error"
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
    <div class="flex items-center gap-2">
      <span class="min-w-14 flex-1 text-sm font-semibold">{@label}</span>
      <button
        id={"baseball-#{@kind}-down"}
        type="button"
        class="btn btn-xs btn-circle"
        phx-click="sport_action"
        phx-value-action="adjust_count"
        phx-value-kind={@kind}
        phx-value-delta="-1"
        aria-label={"Decrease #{@label}"}
      >
        −
      </button>
      <span id={"baseball-#{@kind}"} class="w-5 text-center font-black tabular-nums">{@value}</span>
      <button
        id={"baseball-#{@kind}-up"}
        type="button"
        class="btn btn-xs btn-circle"
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
        "size-9 rotate-45 rounded-sm border-2 transition duration-150 hover:scale-105",
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
    <div class="flex items-center justify-center gap-1">
      <button
        id={"baseball-#{@stat}-down-#{@position}"}
        type="button"
        class="btn btn-xs btn-ghost btn-circle"
        phx-click="sport_action"
        phx-value-action="adjust_stat"
        phx-value-stat={@stat}
        phx-value-position={@position}
        phx-value-delta="-1"
      >
        −
      </button>
      <span id={"baseball-#{@stat}-#{@position}"} class="w-5 text-center font-bold tabular-nums">
        {@value}
      </span>
      <button
        id={"baseball-#{@stat}-up-#{@position}"}
        type="button"
        class="btn btn-xs btn-ghost btn-circle"
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
