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
    state = baseball_state(assigns.show)
    teams = sorted_teams(assigns.show)
    batting_position = if state["half"] == "top", do: 1, else: 2
    fielding_position = if batting_position == 1, do: 2, else: 1
    batting_key = to_string(batting_position)
    fielding_key = to_string(fielding_position)
    active_batter = Enum.at(state["lineups"][batting_key], state["active_batters"][batting_key])

    assigns =
      assigns
      |> assign(:state, state)
      |> assign(:teams, teams)
      |> assign(:batting_position, batting_position)
      |> assign(:batting_team, Enum.find(teams, &(&1.position == batting_position)))
      |> assign(:active_batter, active_batter)
      |> assign(:current_pitcher, state["pitchers"][fielding_key])
      |> assign(:roster_forms, roster_forms(teams, state))
      |> assign(:pitcher_forms, pitcher_forms(teams, state))
      |> assign(:bullpen_forms, bullpen_forms(teams, state))
      |> assign(:play_form, play_form())
      |> assign(:highlight_form, highlight_form(state))
      |> assign(:highlight_options, highlight_options(state))

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

      <section
        id="baseball-live-actions"
        class="overflow-hidden rounded-lg border border-slate-700 bg-slate-950 text-white shadow-sm"
      >
        <div class="flex flex-wrap items-center justify-between gap-3 border-b border-white/10 px-4 py-3">
          <div>
            <p class="text-[10px] font-black uppercase tracking-[0.18em] text-cyan-300">
              Live actions
            </p>
            <p class="mt-0.5 font-bold">
              {if(@active_batter, do: @active_batter["name"], else: "Batter not set")}
              <span class="px-1 text-slate-600">vs.</span>
              {if(@current_pitcher["name"] == "",
                do: "Pitcher not set",
                else: @current_pitcher["name"]
              )}
            </p>
          </div>
          <button
            id="baseball-undo"
            type="button"
            class="flex items-center gap-1.5 rounded-md border border-white/15 bg-white/8 px-3 py-2 text-xs font-black uppercase tracking-wider transition hover:bg-white/15 disabled:cursor-not-allowed disabled:opacity-35"
            phx-click="sport_action"
            phx-value-action="undo"
            disabled={@state["history"] == []}
          >
            <.icon name="hero-arrow-uturn-left-mini" class="size-4" /> Undo
          </button>
        </div>

        <div class="grid gap-px bg-white/10 lg:grid-cols-[0.8fr_1.2fr]">
          <div class="bg-slate-950 p-4">
            <div class="flex items-center justify-between gap-2">
              <p class="text-[10px] font-black uppercase tracking-[0.16em] text-slate-400">
                Record pitch · optional
              </p>
              <span class="font-mono text-xs font-bold text-slate-400 tabular-nums">
                Count {@state["balls"]}-{@state["strikes"]}
              </span>
            </div>
            <div class="mt-3 grid grid-cols-2 gap-2 sm:grid-cols-4 lg:grid-cols-2 xl:grid-cols-4">
              <.game_action
                id="baseball-pitch-ball"
                action="record_pitch"
                result="ball"
                label="Ball"
                tone="green"
              />
              <.game_action
                id="baseball-pitch-strike"
                action="record_pitch"
                result="strike"
                label="Strike"
                tone="red"
              />
              <.game_action
                id="baseball-pitch-foul"
                action="record_pitch"
                result="foul"
                label="Foul"
                tone="amber"
              />
              <.game_action
                id="baseball-pitch-in-play"
                action="record_pitch"
                result="in_play"
                label="In play"
                tone="blue"
              />
            </div>
            <p class="mt-2 text-[10px] leading-relaxed text-slate-500">
              Every pitch increments the fielding pitcher's count. Ball four and strike three close the plate appearance automatically.
            </p>
          </div>

          <div class="bg-slate-950 p-4">
            <div class="flex items-center justify-between gap-2">
              <p class="text-[10px] font-black uppercase tracking-[0.16em] text-slate-400">
                Finish plate appearance
              </p>
              <div class="text-right">
                <span class="block font-mono text-xs font-bold text-slate-400 tabular-nums">
                  {@state["outs"]} {if(@state["outs"] == 1, do: "out", else: "outs")}
                </span>
                <span
                  :if={@state["last_play"]["result"] != ""}
                  id="baseball-last-play"
                  class="mt-0.5 block text-[10px] font-bold uppercase tracking-wider text-cyan-300"
                >
                  Last · {last_play_text(@state["last_play"])}
                </span>
              </div>
            </div>
            <.form
              for={@play_form}
              id="baseball-play-form"
              phx-submit="sport_action"
              phx-value-action="record_play"
            >
              <label
                for="baseball-play-notation"
                class="mt-3 block text-[10px] font-black uppercase tracking-[0.14em] text-slate-400"
              >
                Scorebook notation
                <span class="font-medium normal-case tracking-normal text-slate-600">· optional</span>
              </label>
              <.input
                field={@play_form[:notation]}
                id="baseball-play-notation"
                type="text"
                placeholder="E1.1-3 advances first to third · also accepts 463, F8, K"
                class="mt-1 w-full rounded-md border border-white/15 bg-white/[0.06] px-3 py-2 text-sm font-bold text-white outline-none transition placeholder:text-slate-600 focus:border-cyan-400 focus:ring-2 focus:ring-cyan-400/20"
              />
              <button
                id="baseball-record-notation"
                type="submit"
                name="play[result]"
                value="auto"
                class="mt-2 inline-flex w-full items-center justify-center gap-2 rounded-md border border-cyan-400/30 bg-cyan-400/10 px-3 py-2 text-xs font-black uppercase tracking-[0.12em] text-cyan-200 transition hover:border-cyan-300/60 hover:bg-cyan-400/20 active:scale-[0.99]"
              >
                <.icon name="hero-pencil-square-mini" class="size-4" /> Record notation
              </button>
              <p class="mt-3 text-[10px] font-bold uppercase tracking-[0.14em] text-slate-500">
                Most common · one tap
              </p>
              <div class="mt-2 grid grid-cols-2 gap-2 sm:grid-cols-3">
                <.game_action
                  id="baseball-play-out"
                  action="record_play"
                  result="out"
                  label="Out"
                  tone="red"
                  size="primary"
                />
                <.game_action
                  id="baseball-play-strikeout"
                  action="record_play"
                  result="strikeout"
                  label="Strikeout"
                  tone="red"
                  size="primary"
                />
                <.game_action
                  id="baseball-play-single"
                  action="record_play"
                  result="single"
                  label="Single"
                  tone="blue"
                  size="primary"
                />
                <.game_action
                  id="baseball-play-walk"
                  action="record_play"
                  result="walk"
                  label="Walk"
                  tone="green"
                  size="primary"
                />
                <.game_action
                  id="baseball-play-double"
                  action="record_play"
                  result="double"
                  label="Double"
                  tone="blue"
                  size="primary"
                />
                <.game_action
                  id="baseball-play-home-run"
                  action="record_play"
                  result="home_run"
                  label="Home run"
                  tone="amber"
                  size="primary"
                />
              </div>

              <details
                id="baseball-more-results"
                class="group mt-3 rounded-md border border-white/10 bg-white/[0.03]"
              >
                <summary class="flex cursor-pointer list-none items-center justify-between gap-3 px-3 py-2.5 text-xs font-black uppercase tracking-[0.12em] text-slate-300 transition hover:bg-white/[0.05]">
                  More results
                  <.icon
                    name="hero-chevron-down-mini"
                    class="size-4 transition group-open:rotate-180"
                  />
                </summary>
                <div class="grid grid-cols-2 gap-2 border-t border-white/10 p-3 sm:grid-cols-3">
                  <.game_action
                    id="baseball-play-triple"
                    action="record_play"
                    result="triple"
                    label="Triple"
                    tone="blue"
                  />
                  <.game_action
                    id="baseball-play-hit-by-pitch"
                    action="record_play"
                    result="hit_by_pitch"
                    label="Hit by pitch"
                    tone="green"
                  />
                  <.game_action
                    id="baseball-play-error"
                    action="record_play"
                    result="reached_on_error"
                    label="Reached on error"
                    tone="amber"
                  />
                  <.game_action
                    id="baseball-play-fielders-choice"
                    action="record_play"
                    result="fielders_choice"
                    label="Fielder's choice"
                    tone="red"
                    disabled={!Enum.any?(Map.values(@state["bases"]))}
                  />
                  <.game_action
                    id="baseball-play-sac-fly"
                    action="record_play"
                    result="sacrifice_fly"
                    label="Sac fly"
                    tone="green"
                    disabled={@state["outs"] == 2 or not @state["bases"]["third"]}
                  />
                  <.game_action
                    id="baseball-play-sac-bunt"
                    action="record_play"
                    result="sacrifice_bunt"
                    label="Sac bunt"
                    tone="green"
                    disabled={@state["outs"] == 2 or not Enum.any?(Map.values(@state["bases"]))}
                  />
                  <.game_action
                    id="baseball-play-double-play"
                    action="record_play"
                    result="double_play"
                    label="Double play"
                    tone="red"
                    disabled={@state["outs"] == 2 or not Enum.any?(Map.values(@state["bases"]))}
                  />
                  <.game_action
                    id="baseball-play-triple-play"
                    action="record_play"
                    result="triple_play"
                    label="Triple play"
                    tone="red"
                    disabled={@state["outs"] > 0 or Enum.count(Map.values(@state["bases"]), & &1) < 2}
                  />
                  <.game_action
                    id="baseball-play-interference"
                    action="record_play"
                    result="interference"
                    label="Interference"
                    tone="amber"
                  />
                  <.game_action
                    id="baseball-play-strikeout-reached"
                    action="record_play"
                    result="strikeout_reached"
                    label="K · reached"
                    tone="amber"
                    disabled={@state["bases"]["first"] and @state["outs"] < 2}
                  />
                </div>
              </details>
              <p class="mt-2 text-[10px] leading-relaxed text-slate-500">
                Add runner advances after a period: 1-3 moves first to third, 2-H scores second, and semicolons combine moves. Undo reverses the entire last pitch or play.
              </p>
            </.form>
          </div>
        </div>
      </section>

      <section id="baseball-rosters" class="overflow-hidden rounded-lg border border-base-300">
        <div class="border-b border-base-300 bg-base-200/70 px-4 py-3">
          <p class="text-[11px] font-black uppercase tracking-[0.18em] text-base-content/55">
            Lineups & pitching
          </p>
          <p class="mt-1 text-xs text-base-content/55">
            Paste each batting order with defensive positions, choose who is at bat, and set each team's current pitcher.
          </p>
        </div>
        <div class="grid gap-px bg-base-300 lg:grid-cols-2">
          <.roster_control
            :for={team <- @teams}
            team={team}
            lineup={@state["lineups"][to_string(team.position)]}
            active_index={@state["active_batters"][to_string(team.position)]}
            pitcher={@state["pitchers"][to_string(team.position)]}
            batting?={team.position == @batting_position}
            roster_form={@roster_forms[team.position]}
            pitcher_form={@pitcher_forms[team.position]}
          />
        </div>
      </section>

      <section
        id="baseball-graphics-controls"
        class="overflow-hidden rounded-lg border border-base-300"
      >
        <div class="border-b border-base-300 bg-base-200/70 px-4 py-3">
          <p class="text-[11px] font-black uppercase tracking-[0.18em] text-base-content/55">
            Full-screen baseball graphics
          </p>
          <p class="mt-1 text-xs text-base-content/55">
            Defensive alignments come from the combined roster above. Manage bullpen, spotlight, and comparison browser sources here.
          </p>
        </div>

        <div class="grid gap-px bg-base-300 lg:grid-cols-2">
          <.team_graphics_control
            :for={team <- @teams}
            team={team}
            bullpen_form={@bullpen_forms[team.position]}
          />
        </div>

        <div class="border-t border-base-300 bg-base-100 p-4">
          <.form
            for={@highlight_form}
            id="baseball-highlight-selection-form"
            phx-submit="sport_action"
            phx-value-action="select_highlights"
          >
            <div class="grid gap-3 lg:grid-cols-3">
              <.input
                field={@highlight_form[:spotlight_player_id]}
                type="select"
                label="Spotlight player"
                options={[{"Automatic game leader", ""} | @highlight_options.all]}
              />
              <.input
                field={@highlight_form[:comparison_left_player_id]}
                type="select"
                label="Away comparison player"
                options={[{"Automatic away leader", ""} | @highlight_options.away]}
              />
              <.input
                field={@highlight_form[:comparison_right_player_id]}
                type="select"
                label="Home comparison player"
                options={[{"Automatic home leader", ""} | @highlight_options.home]}
              />
            </div>
            <button
              id="baseball-save-highlight-selection"
              type="submit"
              class="mt-3 rounded-md bg-primary px-4 py-2 text-xs font-black uppercase tracking-[0.12em] text-primary-content transition hover:brightness-110"
            >
              Update highlight players
            </button>
          </.form>
        </div>

        <div class="grid gap-px border-t border-base-300 bg-base-300 lg:grid-cols-2">
          <div class="bg-base-100 p-4">
            <p class="text-[10px] font-black uppercase tracking-[0.16em] text-primary">
              Player spotlight · automatic
            </p>
            <p class="mt-2 text-sm font-black">
              {display_name(@state["graphics"]["single"]["name"])}
            </p>
            <p class="mt-1 text-xs leading-relaxed text-base-content/55">
              Selected from the game ledger using hits, home runs, RBI, and walks. Its H–AB, AVG, HR, RBI, BB, and SO rows update after every plate appearance.
            </p>
          </div>
          <div class="bg-base-100 p-4">
            <p class="text-[10px] font-black uppercase tracking-[0.16em] text-primary">
              Player comparison · automatic
            </p>
            <p class="mt-2 text-sm font-black">
              {display_name(@state["graphics"]["comparison"]["left_name"])}
              <span class="px-1 text-base-content/35">vs.</span>
              {display_name(@state["graphics"]["comparison"]["right_name"])}
            </p>
            <p class="mt-1 text-xs leading-relaxed text-base-content/55">
              The current statistical leader from each team is compared directly from recorded plate appearances.
            </p>
          </div>
        </div>
      </section>

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
          data-confirm="Reset the game stats and scores? Saved lineups and pitcher names will remain."
        >
          Reset game
        </button>
      </div>
    </div>
    """
  end

  def panel(assigns), do: fallback_panel(assigns)

  attr :team, :any, required: true
  attr :bullpen_form, :any, required: true

  defp team_graphics_control(assigns) do
    ~H"""
    <div class="bg-base-100 p-4">
      <div class="flex items-center gap-2">
        <span class="size-2.5 rounded-full" style={"background: #{@team.primary_color}"}></span>
        <p class="font-black">{Team.full_name(@team)}</p>
      </div>

      <.form
        for={@bullpen_form}
        id={"baseball-bullpen-form-#{@team.position}"}
        phx-submit="sport_action"
        phx-value-action="save_bullpen"
        class="mt-4"
      >
        <.input
          field={@bullpen_form[:position]}
          id={"baseball-bullpen-position-#{@team.position}"}
          type="hidden"
        />
        <.input
          field={@bullpen_form[:pitchers]}
          id={"baseball-bullpen-pitchers-#{@team.position}"}
          type="textarea"
          rows="4"
          label="Bullpen — Pitcher | Status"
          placeholder="Taylor Reed | Warming\nCasey Park | Ready"
        />
        <button
          id={"baseball-save-bullpen-#{@team.position}"}
          type="submit"
          class="mt-2 w-full rounded-md border border-base-300 bg-base-200 px-3 py-2 text-xs font-black uppercase tracking-[0.12em] transition hover:bg-base-300"
        >
          Save bullpen
        </button>
      </.form>
    </div>
    """
  end

  defp fallback_panel(assigns) do
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

  attr :id, :string, required: true
  attr :action, :string, required: true
  attr :result, :string, required: true
  attr :label, :string, required: true
  attr :tone, :string, required: true, values: ~w(green red amber blue)
  attr :size, :string, default: "regular", values: ~w(regular primary)
  attr :submit, :boolean, default: false
  attr :disabled, :boolean, default: false

  defp game_action(assigns) do
    assigns = assign(assigns, :submit, assigns.submit || assigns.action == "record_play")

    ~H"""
    <button
      id={@id}
      type={if(@submit, do: "submit", else: "button")}
      name={if(@submit, do: "play[result]")}
      value={if(@submit, do: @result)}
      disabled={@disabled}
      class={[
        "rounded-md border px-2 font-black uppercase tracking-[0.08em] shadow-sm transition hover:-translate-y-0.5 hover:brightness-110 active:translate-y-0 active:scale-[0.98]",
        "disabled:cursor-not-allowed disabled:opacity-30 disabled:hover:translate-y-0 disabled:hover:brightness-100",
        if(@size == "primary", do: "min-h-14 py-3 text-sm", else: "min-h-11 py-2 text-xs"),
        game_action_tone(@tone)
      ]}
      phx-click={if(!@submit, do: "sport_action")}
      phx-value-action={if(!@submit, do: @action)}
      phx-value-result={if(!@submit, do: @result)}
    >
      {@label}
    </button>
    """
  end

  defp game_action_tone("green"), do: "border-emerald-400/30 bg-emerald-500/18 text-emerald-200"
  defp game_action_tone("red"), do: "border-rose-400/30 bg-rose-500/18 text-rose-200"
  defp game_action_tone("amber"), do: "border-amber-400/30 bg-amber-500/18 text-amber-200"
  defp game_action_tone("blue"), do: "border-sky-400/30 bg-sky-500/18 text-sky-200"

  attr :team, :any, required: true
  attr :lineup, :list, required: true
  attr :active_index, :integer, required: true
  attr :pitcher, :map, required: true
  attr :batting?, :boolean, required: true
  attr :roster_form, :any, required: true
  attr :pitcher_form, :any, required: true

  defp roster_control(assigns) do
    assigns = assign(assigns, :active_batter, Enum.at(assigns.lineup, assigns.active_index))

    ~H"""
    <div class="bg-base-100 p-4">
      <div class="flex items-center justify-between gap-3">
        <div class="min-w-0">
          <p class="truncate font-black">{Team.full_name(@team)}</p>
          <p class="text-[10px] font-black uppercase tracking-[0.14em] text-base-content/45">
            {if(@batting?, do: "Batting", else: "Fielding")}
          </p>
        </div>
        <span class="size-3 shrink-0 rounded-full" style={"background: #{@team.primary_color}"}>
        </span>
      </div>

      <.form
        for={@roster_form}
        id={"baseball-roster-form-#{@team.position}"}
        phx-submit="sport_action"
        phx-value-action="save_roster"
        class="mt-3"
      >
        <.input
          field={@roster_form[:position]}
          id={"baseball-roster-position-#{@team.position}"}
          type="hidden"
        />
        <.input
          field={@roster_form[:entries]}
          id={"baseball-roster-entries-#{@team.position}"}
          type="textarea"
          rows="9"
          label="Lineup & defense — BATTER | POSITION"
          placeholder="1. Alex Cruz | SS\n2. Morgan Ellis | CF\n3. Sam Rivera | 1B\nP: Jordan Lee"
        />
        <p class="mt-1.5 text-[10px] leading-relaxed text-base-content/50">
          Line order sets the batting order. Position is optional. Use
          <span class="font-bold">P: Name</span>
          for a defense-only player when using a DH.
        </p>
        <button
          id={"baseball-save-roster-#{@team.position}"}
          type="submit"
          class="mt-2 w-full rounded-md bg-primary px-3 py-2 text-xs font-black uppercase tracking-[0.12em] text-primary-content transition hover:brightness-110 active:scale-[0.99]"
        >
          Save lineup & defense
        </button>
      </.form>

      <div id={"baseball-lineup-#{@team.position}"} class="mt-3 space-y-1.5">
        <p
          :if={@lineup == []}
          class="rounded-md border border-dashed border-base-300 p-3 text-center text-xs text-base-content/45"
        >
          No lineup entered yet
        </p>
        <button
          :for={{player, index} <- Enum.with_index(@lineup)}
          id={"baseball-batter-#{@team.position}-#{index}"}
          type="button"
          class={[
            "grid w-full grid-cols-[24px_minmax(0,1fr)_32px_auto] items-center gap-2 rounded-md border px-2.5 py-2 text-left text-sm transition",
            index == @active_index && "border-primary bg-primary/10",
            index != @active_index &&
              "border-base-300 hover:border-base-content/30 hover:bg-base-200/60"
          ]}
          phx-click="sport_action"
          phx-value-action="set_batter"
          phx-value-position={@team.position}
          phx-value-index={index}
        >
          <span class="text-center text-xs font-black text-base-content/40">{index + 1}</span>
          <span class="truncate font-bold">{player["name"]}</span>
          <span class="text-center text-[10px] font-black uppercase text-primary">
            {player["field_position"]}
          </span>
          <span class="font-mono text-xs font-bold tabular-nums">
            {player["hits"]}-{player["at_bats"]}
          </span>
        </button>
      </div>

      <div :if={@active_batter} class="mt-3 rounded-md border border-base-300 bg-base-200/45 p-3">
        <div class="flex items-center justify-between gap-2">
          <div class="min-w-0">
            <p class="text-[9px] font-black uppercase tracking-[0.14em] text-primary">
              Selected batter
            </p>
            <p class="truncate text-sm font-black">{@active_batter["name"]}</p>
          </div>
          <button
            id={"baseball-next-batter-#{@team.position}"}
            type="button"
            class="rounded px-2 py-1 text-[10px] font-black uppercase tracking-wider text-primary transition hover:bg-primary/10"
            phx-click="sport_action"
            phx-value-action="next_batter"
            phx-value-position={@team.position}
          >
            Next batter
          </button>
        </div>
        <div class="mt-2 grid grid-cols-2 gap-2">
          <.player_stat_control
            label="Hits"
            stat="hits"
            position={@team.position}
            value={@active_batter["hits"]}
          />
          <.player_stat_control
            label="At bats"
            stat="at_bats"
            position={@team.position}
            value={@active_batter["at_bats"]}
          />
        </div>
      </div>

      <.form
        for={@pitcher_form}
        id={"baseball-pitcher-form-#{@team.position}"}
        phx-submit="sport_action"
        phx-value-action="save_pitcher"
        class="mt-4 border-t border-base-300 pt-4"
      >
        <.input
          field={@pitcher_form[:position]}
          id={"baseball-pitcher-position-#{@team.position}"}
          type="hidden"
        />
        <.input
          field={@pitcher_form[:name]}
          id={"baseball-pitcher-name-#{@team.position}"}
          label="Current pitcher"
          placeholder="Pitcher name"
        />
        <button
          id={"baseball-save-pitcher-#{@team.position}"}
          type="submit"
          class="mt-2 w-full rounded-md border border-base-300 bg-base-200 px-3 py-2 text-xs font-black uppercase tracking-[0.12em] transition hover:bg-base-300 active:scale-[0.99]"
        >
          Update pitcher
        </button>
      </.form>

      <div class="mt-2 flex items-center justify-between rounded-md bg-slate-950 px-3 py-2 text-white">
        <span class="text-[10px] font-black uppercase tracking-[0.14em] text-slate-400">Pitches</span>
        <div class="flex items-center gap-2">
          <button
            id={"baseball-pitches-down-#{@team.position}"}
            type="button"
            class="grid size-7 place-items-center rounded bg-white/10 font-black transition hover:bg-white/20"
            phx-click="sport_action"
            phx-value-action="adjust_pitch_count"
            phx-value-position={@team.position}
            phx-value-delta="-1"
          >
            −
          </button>
          <span
            id={"baseball-pitches-#{@team.position}"}
            class="w-8 text-center text-lg font-black tabular-nums"
          >
            {@pitcher["pitch_count"]}
          </span>
          <button
            id={"baseball-pitches-up-#{@team.position}"}
            type="button"
            class="grid size-7 place-items-center rounded bg-primary font-black text-primary-content transition hover:brightness-110"
            phx-click="sport_action"
            phx-value-action="adjust_pitch_count"
            phx-value-position={@team.position}
            phx-value-delta="1"
          >
            +
          </button>
        </div>
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
    <div class="flex items-center justify-center">
      <span
        id={"baseball-#{@stat}-#{@position}"}
        class="rounded bg-base-200 px-3 py-1 text-center font-black tabular-nums"
      >
        {@value}
      </span>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :stat, :string, required: true
  attr :position, :integer, required: true
  attr :value, :integer, required: true

  defp player_stat_control(assigns) do
    ~H"""
    <div class="rounded border border-base-300 bg-base-100 p-2">
      <span class="block text-center text-[9px] font-black uppercase tracking-wider text-base-content/45">
        {@label}
      </span>
      <div class="mt-1 flex items-center justify-center">
        <span
          id={"baseball-batter-#{@stat}-#{@position}"}
          class="text-lg font-black tabular-nums"
        >
          {@value}
        </span>
      </div>
    </div>
    """
  end

  defp play_form, do: to_form(%{"notation" => ""}, as: :play)

  defp last_play_text(%{"result" => result, "notation" => notation}) do
    label = result_label(result)
    if notation == "", do: label, else: "#{notation} · #{label}"
  end

  defp result_label("reached_on_error"), do: "Error"
  defp result_label("fielders_choice"), do: "Fielder's choice"
  defp result_label("sacrifice_fly"), do: "Sac fly"
  defp result_label("sacrifice_bunt"), do: "Sac bunt"
  defp result_label("double_play"), do: "Double play"
  defp result_label("strikeout_reached"), do: "K reached"
  defp result_label(result), do: result |> String.replace("_", " ") |> String.capitalize()

  defp roster_forms(teams, state) do
    Map.new(teams, fn team ->
      position = to_string(team.position)
      lineup = state["lineups"][position]
      lineup_names = MapSet.new(lineup, & &1["name"])

      batting_entries =
        lineup
        |> Enum.with_index(1)
        |> Enum.map(fn {player, order} ->
          ["#{order}. #{player["name"]}", player["field_position"]]
          |> Enum.reject(&(&1 in [nil, ""]))
          |> Enum.join(" | ")
        end)

      defense_only_entries =
        ~w(P C 1B 2B 3B SS LF CF RF)
        |> Enum.flat_map(fn field_position ->
          name = state["defense"][position][field_position]

          if name in [nil, ""] or MapSet.member?(lineup_names, name) do
            []
          else
            ["#{field_position}: #{name}"]
          end
        end)

      entries = Enum.join(batting_entries ++ defense_only_entries, "\n")

      {team.position, to_form(%{"position" => position, "entries" => entries}, as: :roster)}
    end)
  end

  defp pitcher_forms(teams, state) do
    Map.new(teams, fn team ->
      position = to_string(team.position)

      {team.position,
       to_form(%{"position" => position, "name" => state["pitchers"][position]["name"]},
         as: :pitcher
       )}
    end)
  end

  defp bullpen_forms(teams, state) do
    Map.new(teams, fn team ->
      position = to_string(team.position)

      pitchers =
        Enum.map_join(state["bullpens"][position], "\n", fn pitcher ->
          [pitcher["name"], pitcher["status"]]
          |> Enum.reject(&(&1 == ""))
          |> Enum.join(" | ")
        end)

      {team.position, to_form(%{"position" => position, "pitchers" => pitchers}, as: :bullpen)}
    end)
  end

  defp highlight_form(state) do
    single = state["graphics"]["single"]
    comparison = state["graphics"]["comparison"]

    to_form(
      %{
        "spotlight_player_id" => Map.get(single, "selected_player_id"),
        "comparison_left_player_id" => Map.get(comparison, "selected_left_player_id"),
        "comparison_right_player_id" => Map.get(comparison, "selected_right_player_id")
      },
      as: :highlight
    )
  end

  defp highlight_options(state) do
    away = player_options(state["lineups"]["1"])
    home = player_options(state["lineups"]["2"])
    %{away: away, home: home, all: away ++ home}
  end

  defp player_options(players) do
    players
    |> Enum.filter(&Map.get(&1, "id"))
    |> Enum.map(&{&1["name"], &1["id"]})
  end

  defp sorted_teams(show), do: show.teams |> List.wrap() |> Enum.sort_by(& &1.position)

  defp display_name(""), do: "Waiting for game events"
  defp display_name(name), do: name

  defp baseball_state(%{baseball_game: %Showish.Baseball.Game{}} = show), do: show.sport_state
  defp baseball_state(show), do: Baseball.normalize_state(show.sport_state)
end
