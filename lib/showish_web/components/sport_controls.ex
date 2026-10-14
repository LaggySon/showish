defmodule ShowishWeb.SportControls do
  @moduledoc """
  Sport-specific live controls rendered inside the shared control room.

  Event handling stays in the parent LiveView, so these remain lightweight
  function components. Add one `panel/1` clause when a new sport needs controls
  that differ from the generic esports series.

  Both follow the Laggish design guide (DESIGN.md): the series gets the sticky
  live controls strip (section 7.27); baseball, which has far more to drive,
  gets a console of disclosures built from the same buttons, steppers and
  fields. Buttons are grayscale; a hue only marks a state.
  """

  use ShowishWeb, :html

  alias Showish.Broadcasts.Sports.Baseball
  alias Showish.Broadcasts.Team

  attr :show, :any, required: true

  def panel(%{show: %{sport: "baseball"}} = assigns) do
    state = assigns.show |> baseball_state() |> with_rosters()
    teams = sorted_teams(assigns.show)
    batting_position = if state["half"] == "top", do: 1, else: 2
    fielding_position = if batting_position == 1, do: 2, else: 1
    batting_key = to_string(batting_position)
    fielding_key = to_string(fielding_position)
    active_batter = Enum.at(state["lineups"][batting_key], state["active_batters"][batting_key])
    bases = state["bases"]
    runners = Enum.count(Map.values(bases), & &1)

    assigns =
      assigns
      |> assign(:state, state)
      |> assign(:teams, teams)
      |> assign(:batting_position, batting_position)
      |> assign(:batting_team, Enum.find(teams, &(&1.position == batting_position)))
      |> assign(:active_batter, active_batter)
      |> assign(:current_pitcher, state["pitchers"][fielding_key])
      |> assign(:runners, runners)
      |> assign(:game_rosters_form, game_rosters_form(teams, state))
      |> assign(:substitution_forms, substitution_forms(teams))
      |> assign(:play_form, play_form())
      |> assign(:highlight_form, highlight_form(state))
      |> assign(:highlight_options, highlight_options(state))

    ~H"""
    <div id="baseball-controls" class="app-baseball">
      <div
        id="baseball-live-state"
        data-fielding-position={if(@batting_position == 1, do: 2, else: 1)}
        class="app-band"
      >
        <span class="app-band-main">
          <span class="ui-row-name">
            {if(@state["half"] == "top", do: "Top", else: "Bottom")} {@state["inning"]}
          </span>
          <span class="ui-sep" aria-hidden="true">·</span>
          <span>
            {if(@batting_team, do: Team.full_name(@batting_team), else: "Away")} batting
          </span>
        </span>
        <span class="app-band-values">
          <span class="ui-label">Count</span>
          <span class="ui-mono app-band-value">{@state["balls"]}-{@state["strikes"]}</span>
          <span class="ui-label">Outs</span>
          <span class="ui-mono app-band-value">{@state["outs"]}</span>
        </span>
      </div>

      <details
        phx-mounted={JS.ignore_attributes(["open"])}
        id="baseball-live-actions"
        open
        class="app-section"
      >
        <summary class="app-section-title">
          <span class="app-collapsible-name">Live actions</span>
          <span class="ui-panel-title-aside app-matchup">
            {if(@active_batter, do: @active_batter["name"], else: "Batter not set")}
            <span class="ui-muted">vs.</span>
            {if(@current_pitcher["name"] == "",
              do: "Pitcher not set",
              else: @current_pitcher["name"]
            )}
          </span>
        </summary>

        <div class="app-section-body">
          <div class="app-section-tools">
            <button
              id="baseball-undo"
              type="button"
              class="ui-button ui-button--small"
              phx-click="sport_action"
              phx-value-action="undo"
              disabled={@state["history"] == []}
              title={@state["history"] == [] && "Nothing to undo yet"}
            >
              Undo last pitch or play
            </button>
          </div>

          <div class="app-columns">
            <div>
              <div class="app-subhead">
                <span class="ui-label">Record pitch · optional</span>
                <span class="ui-mono ui-muted">Count {@state["balls"]}-{@state["strikes"]}</span>
              </div>
              <div class="app-action-grid app-action-grid--row">
                <.game_action
                  id="baseball-pitch-ball"
                  action="record_pitch"
                  result="ball"
                  label="Ball"
                />
                <.game_action
                  id="baseball-pitch-strike"
                  action="record_pitch"
                  result="strike"
                  label="Strike"
                />
                <.game_action
                  id="baseball-pitch-foul"
                  action="record_pitch"
                  result="foul"
                  label="Foul"
                />
                <.game_action
                  id="baseball-pitch-in-play"
                  action="record_pitch"
                  result="in_play"
                  label="In play"
                />
              </div>
              <p class="ui-hint app-after-fields">
                Every pitch adds to the fielding pitcher's count. Ball four and strike three end the plate appearance.
              </p>
            </div>

            <div>
              <div class="app-subhead">
                <span class="ui-label">Finish plate appearance</span>
                <span class="ui-mono ui-muted">
                  {@state["outs"]} {if(@state["outs"] == 1, do: "out", else: "outs")}
                </span>
              </div>
              <p
                :if={@state["last_play"]["result"] != ""}
                id="baseball-last-play"
                class="ui-hint app-last-play"
              >
                Last play · {last_play_text(@state["last_play"])}
              </p>

              <.form
                for={@play_form}
                id="baseball-play-form"
                phx-submit="sport_action"
                phx-value-action="record_play"
              >
                <div class="app-notation">
                  <.input
                    field={@play_form[:notation]}
                    id="baseball-play-notation"
                    type="text"
                    label="Scorebook notation · optional"
                    placeholder="E1.1-3"
                    hint="Also takes 463, F8 or K. After a period, 1-3 moves first to third, 2-H scores second; semicolons combine moves."
                  />
                  <button
                    id="baseball-record-notation"
                    type="submit"
                    name="play[result]"
                    value="auto"
                    class="ui-button ui-button--primary"
                  >
                    Record notation
                  </button>
                </div>

                <p class="ui-label app-after-fields">Most common · one tap</p>
                <div class="app-action-grid app-action-grid--tap">
                  <.game_action id="baseball-play-out" action="record_play" result="out" label="Out" />
                  <.game_action
                    id="baseball-play-strikeout"
                    action="record_play"
                    result="strikeout"
                    label="Strikeout"
                  />
                  <.game_action
                    id="baseball-play-single"
                    action="record_play"
                    result="single"
                    label="Single"
                  />
                  <.game_action
                    id="baseball-play-walk"
                    action="record_play"
                    result="walk"
                    label="Walk"
                  />
                  <.game_action
                    id="baseball-play-double"
                    action="record_play"
                    result="double"
                    label="Double"
                  />
                  <.game_action
                    id="baseball-play-home-run"
                    action="record_play"
                    result="home_run"
                    label="Home run"
                  />
                </div>

                <div id="baseball-more-results" class="app-after-fields">
                  <p class="ui-label">All other outcomes</p>
                  <div class="app-action-grid app-after-label">
                    <.game_action
                      id="baseball-play-triple"
                      action="record_play"
                      result="triple"
                      label="Triple"
                    />
                    <.game_action
                      id="baseball-play-hit-by-pitch"
                      action="record_play"
                      result="hit_by_pitch"
                      label="Hit by pitch"
                    />
                    <.game_action
                      id="baseball-play-error"
                      action="record_play"
                      result="reached_on_error"
                      label="Reached on error"
                    />
                    <.game_action
                      id="baseball-play-fielders-choice"
                      action="record_play"
                      result="fielders_choice"
                      label="Fielder's choice"
                      disabled={@runners == 0}
                      reason="Needs a runner on base"
                    />
                    <.game_action
                      id="baseball-play-sac-fly"
                      action="record_play"
                      result="sacrifice_fly"
                      label="Sac fly"
                      disabled={@state["outs"] == 2 or not @state["bases"]["third"]}
                      reason="Needs a runner on third and fewer than 2 outs"
                    />
                    <.game_action
                      id="baseball-play-sac-bunt"
                      action="record_play"
                      result="sacrifice_bunt"
                      label="Sac bunt"
                      disabled={@state["outs"] == 2 or @runners == 0}
                      reason="Needs a runner on base and fewer than 2 outs"
                    />
                    <.game_action
                      id="baseball-play-double-play"
                      action="record_play"
                      result="double_play"
                      label="Double play"
                      disabled={@state["outs"] == 2 or @runners == 0}
                      reason="Needs a runner on base and fewer than 2 outs"
                    />
                    <.game_action
                      id="baseball-play-triple-play"
                      action="record_play"
                      result="triple_play"
                      label="Triple play"
                      disabled={@state["outs"] > 0 or @runners < 2}
                      reason="Needs 2 runners on base and no outs"
                    />
                    <.game_action
                      id="baseball-play-interference"
                      action="record_play"
                      result="interference"
                      label="Interference"
                    />
                    <.game_action
                      id="baseball-play-strikeout-reached"
                      action="record_play"
                      result="strikeout_reached"
                      label="K · reached"
                      disabled={@state["bases"]["first"] and @state["outs"] < 2}
                      reason="Only with first base open, or with 2 outs"
                    />
                  </div>
                </div>
              </.form>
            </div>
          </div>
        </div>
      </details>

      <details
        phx-mounted={JS.ignore_attributes(["open"])}
        id="baseball-scoreboard"
        open
        class="app-section"
      >
        <summary class="app-section-title">
          <span class="app-collapsible-name">Scoreboard</span>
        </summary>

        <div class="app-section-body">
          <div class="app-columns">
            <.baseball_score_control
              :for={team <- @teams}
              team={team}
              role={if(team.position == 1, do: "Away", else: "Home")}
              batting?={team.position == @batting_position}
            />
          </div>

          <div class="app-columns app-columns--3 app-after-fields">
            <section class="app-cell" aria-labelledby="baseball-inning-title">
              <div class="app-subhead">
                <span id="baseball-inning-title" class="ui-label">Inning</span>
              </div>
              <div class="ui-stepper app-stepper-wide">
                <button
                  id="baseball-previous-half"
                  type="button"
                  class="ui-button"
                  phx-click="sport_action"
                  phx-value-action="previous_half"
                  aria-label="Previous half inning"
                >
                  ‹
                </button>
                <span class="app-inning">
                  <span id="baseball-inning" class="ui-stepper-value">{@state["inning"]}</span>
                  <span class="ui-label">
                    {if(@state["half"] == "top", do: "Top", else: "Bottom")}
                  </span>
                </span>
                <button
                  id="baseball-next-half"
                  type="button"
                  class="ui-button"
                  phx-click="sport_action"
                  phx-value-action="next_half"
                  aria-label="Next half inning"
                >
                  ›
                </button>
              </div>
              <button
                id="baseball-advance-half"
                type="button"
                class="ui-button ui-button--primary app-full-width app-after-fields"
                phx-click="sport_action"
                phx-value-action="next_half"
              >
                Advance half inning ›
              </button>
            </section>

            <section class="app-cell" aria-labelledby="baseball-count-title">
              <div class="app-subhead">
                <span id="baseball-count-title" class="ui-label">Count</span>
                <button
                  id="baseball-clear-count"
                  type="button"
                  aria-label="Start a new batter"
                  class="ui-button ui-button--ghost ui-button--small"
                  phx-click="sport_action"
                  phx-value-action="clear_count"
                >
                  ↻ New batter
                </button>
              </div>
              <div class="app-counts">
                <.count_control label="Balls" kind="balls" value={@state["balls"]} maximum={3} />
                <.count_control label="Strikes" kind="strikes" value={@state["strikes"]} maximum={2} />
                <.count_control label="Outs" kind="outs" value={@state["outs"]} maximum={2} />
              </div>
            </section>

            <section class="app-cell" aria-labelledby="baseball-runners-title">
              <div class="app-subhead">
                <span id="baseball-runners-title" class="ui-label">Runners</span>
                <button
                  id="baseball-clear-bases"
                  type="button"
                  aria-label="Clear bases"
                  class="ui-button ui-button--ghost ui-button--small"
                  phx-click="sport_action"
                  phx-value-action="clear_bases"
                  disabled={@runners == 0}
                  title={@runners == 0 && "The bases are already empty"}
                >
                  ✕ Clear
                </button>
              </div>
              <div class="app-diamond">
                <.base_button
                  base="second"
                  occupied={@state["bases"]["second"]}
                  class="app-base--second"
                />
                <.base_button
                  base="third"
                  occupied={@state["bases"]["third"]}
                  class="app-base--third"
                />
                <.base_button
                  base="first"
                  occupied={@state["bases"]["first"]}
                  class="app-base--first"
                />
              </div>
              <p class="ui-hint app-center">Press a base to put a runner on it or take one off.</p>
            </section>
          </div>

          <div class="ui-table-wrap app-after-fields" style="--table-max-h: none">
            <table class="ui-table">
              <thead>
                <tr>
                  <th>Line totals</th>
                  <th class="ui-cell-num">Hits</th>
                  <th class="ui-cell-num">Errors</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={team <- @teams}>
                  <td class="ui-row-name">{Team.full_name(team)}</td>
                  <td class="ui-cell-num ui-cell-mono">
                    <span id={"baseball-hits-#{team.position}"}>
                      {@state["hits"][to_string(team.position)]}
                    </span>
                  </td>
                  <td class="ui-cell-num ui-cell-mono">
                    <span id={"baseball-errors-#{team.position}"}>
                      {@state["errors"][to_string(team.position)]}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </details>

      <section id="baseball-quick-changes" aria-label="Personnel changes">
        <details
          phx-mounted={JS.ignore_attributes(["open"])}
          id="baseball-personnel-change"
          class="app-section"
        >
          <summary class="app-section-title">
            <span class="app-collapsible-name">Personnel changes</span>
            <span class="ui-panel-title-aside">Change a pitcher or replace a lineup player.</span>
          </summary>
          <div class="app-section-body app-columns">
            <div :for={team <- @teams}>
              <p class="ui-row-name app-team-name">{Team.full_name(team)}</p>
              <.quick_substitution_form
                team={team}
                form={@substitution_forms[team.position]}
                lineup={@state["lineups"][to_string(team.position)]}
                players={@state["rosters"][to_string(team.position)]}
                pitcher={@state["pitchers"][to_string(team.position)]}
              />
            </div>
          </div>
        </details>
      </section>

      <details phx-mounted={JS.ignore_attributes(["open"])} id="baseball-rosters" class="app-section">
        <summary class="app-section-title">
          <span class="app-collapsible-name">Teams and lineups</span>
          <span class="ui-panel-title-aside">
            Batting order, active hitter, pitcher and pitch count.
          </span>
        </summary>
        <div class="app-section-body">
          <div class="app-section-tools">
            <button
              id="baseball-open-game-rosters-modal"
              type="button"
              aria-label="Paste game rosters"
              class="ui-button ui-button--small"
              phx-click={
                JS.push_focus()
                |> show("#baseball-game-rosters-modal")
                |> JS.focus(to: "#baseball-game-rosters-data")
              }
            >
              Paste game rosters
            </button>
          </div>
          <div class="app-columns">
            <.roster_control
              :for={team <- @teams}
              team={team}
              lineup={@state["lineups"][to_string(team.position)]}
              active_index={@state["active_batters"][to_string(team.position)]}
              pitcher={@state["pitchers"][to_string(team.position)]}
              batting?={team.position == @batting_position}
            />
          </div>
        </div>
      </details>

      <div
        id="baseball-game-rosters-modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="baseball-game-rosters-modal-title"
        class="app-modal"
        style="display: none;"
        phx-window-keydown={hide("#baseball-game-rosters-modal") |> JS.pop_focus()}
        phx-key="escape"
      >
        <div
          class="ui-dialog app-modal-dialog"
          phx-click-away={hide("#baseball-game-rosters-modal") |> JS.pop_focus()}
        >
          <div class="ui-dialog-header">
            <h2 id="baseball-game-rosters-modal-title" class="ui-dialog-title">
              Paste game rosters
            </h2>
            <button
              id="baseball-close-game-rosters-modal"
              type="button"
              aria-label="Close"
              class="ui-button ui-button--ghost ui-button--small"
              phx-click={hide("#baseball-game-rosters-modal") |> JS.pop_focus()}
            >
              ✕
            </button>
          </div>

          <.form
            for={@game_rosters_form}
            id="baseball-game-rosters-form"
            phx-submit={
              JS.push("sport_action")
              |> hide("#baseball-game-rosters-modal")
              |> JS.pop_focus()
            }
            phx-value-action="save_game_rosters"
          >
            <div class="ui-dialog-body">
              <p class="ui-muted app-panel-note">
                Imports the away and home teams together from formatted game data.
              </p>
              <.input
                field={@game_rosters_form[:data]}
                id="baseball-game-rosters-data"
                type="textarea"
                rows="20"
                label="Away and home game data"
                placeholder={game_rosters_placeholder(@teams)}
                hint="Keep the Away/Home, Team, Lineup, Starting pitcher, Bullpen and Roster headings. Colors are hex values such as #123456. Lineup rows are BATTER | POSITION; bullpen rows may add | STATUS. Names are de-duplicated and the first 26 per club are kept."
              />
            </div>
            <div class="ui-dialog-footer">
              <button
                id="baseball-cancel-game-rosters"
                type="button"
                class="ui-button"
                phx-click={hide("#baseball-game-rosters-modal") |> JS.pop_focus()}
              >
                Cancel
              </button>
              <button
                id="baseball-save-game-rosters"
                type="submit"
                class="ui-button ui-button--primary"
              >
                Save both rosters
              </button>
            </div>
          </.form>
        </div>
      </div>

      <details
        phx-mounted={JS.ignore_attributes(["open"])}
        id="baseball-graphics-controls"
        class="app-section"
      >
        <summary class="app-section-title">
          <span class="app-collapsible-name">Broadcast graphics</span>
          <span class="ui-panel-title-aside">
            Defense, bullpens, spotlight and player comparison.
          </span>
        </summary>

        <div class="app-section-body">
          <div class="app-columns">
            <.team_graphics_control
              :for={team <- @teams}
              team={team}
              bullpen={@state["bullpens"][to_string(team.position)]}
            />
          </div>

          <.form
            for={@highlight_form}
            id="baseball-highlight-selection-form"
            class="app-after-fields"
            phx-submit="sport_action"
            phx-value-action="select_highlights"
          >
            <div class="app-fields">
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
              aria-label="Update highlight players"
              class="ui-button ui-button--primary ui-button--compact app-after-fields"
            >
              Update highlights
            </button>
          </.form>

          <dl class="ui-kv app-kv-prose app-after-fields">
            <dt>Spotlight</dt>
            <dd>
              <span class="ui-row-name">{display_name(@state["graphics"]["single"]["name"])}</span>
              <span class="ui-hint app-block-hint">
                Chosen from the game's plate appearances by hits, home runs, RBI and walks. Its H–AB, AVG, HR, RBI, BB and SO update after every plate appearance.
              </span>
            </dd>
            <dt>Comparison</dt>
            <dd>
              <span class="ui-row-name">
                {display_name(@state["graphics"]["comparison"]["left_name"])}
              </span>
              <span class="ui-muted">vs.</span>
              <span class="ui-row-name">
                {display_name(@state["graphics"]["comparison"]["right_name"])}
              </span>
              <span class="ui-hint app-block-hint">
                Each team's current leader, compared from the recorded plate appearances.
              </span>
            </dd>
          </dl>
        </div>
      </details>

      <div class="app-section-end">
        <button
          id="baseball-reset-game"
          type="button"
          aria-label="Reset game"
          class="ui-button ui-button--danger ui-button--small"
          phx-click="reset_sport"
          data-confirm="Reset the game stats and scores?"
          data-confirm-body="Runs, counts, bases and every recorded play are cleared. Saved lineups and pitcher names stay."
          data-confirm-action="Reset game"
        >
          Reset game
        </button>
      </div>
    </div>
    """
  end

  def panel(assigns), do: fallback_panel(assigns)

  attr :team, :any, required: true
  attr :form, :any, required: true
  attr :lineup, :list, required: true
  attr :players, :list, required: true
  attr :pitcher, :map, required: true

  defp quick_substitution_form(assigns) do
    pitcher_options =
      if assigns.pitcher["id"] do
        [{"#{assigns.pitcher["name"]} · Pitcher", assigns.pitcher["id"]}]
      else
        []
      end

    lineup_options =
      assigns.lineup
      |> Enum.filter(& &1["id"])
      |> Enum.map(&{"#{&1["name"]} · #{&1["field_position"]}", &1["id"]})

    outgoing_options = Enum.uniq_by(pitcher_options ++ lineup_options, &elem(&1, 1))

    active_ids =
      assigns.lineup
      |> Enum.map(& &1["id"])
      |> Kernel.++([assigns.pitcher["id"]])
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    bench_options =
      assigns.players
      |> Enum.reject(&MapSet.member?(active_ids, &1["id"]))
      |> Enum.map(&{&1["name"], &1["id"]})

    assigns =
      assigns
      |> assign(:outgoing_options, outgoing_options)
      |> assign(:bench_options, bench_options)

    ~H"""
    <.form
      for={@form}
      id={"baseball-substitution-form-#{@team.position}"}
      phx-submit="sport_action"
      phx-value-action="substitute_player"
      class="app-substitution"
    >
      <.input
        field={@form[:position]}
        id={"baseball-substitution-position-#{@team.position}"}
        type="hidden"
      />
      <.input
        field={@form[:outgoing_player_id]}
        id={"baseball-substitution-outgoing-#{@team.position}"}
        type="select"
        label="Active player"
        options={[{"Choose active player", ""} | @outgoing_options]}
      />
      <.input
        field={@form[:incoming_player_id]}
        id={"baseball-substitution-incoming-#{@team.position}"}
        type="select"
        label="Replacement"
        options={[{"Choose roster player", ""} | @bench_options]}
      />
      <.input
        field={@form[:field_position]}
        id={"baseball-substitution-field-position-#{@team.position}"}
        type="select"
        label="Defensive position"
        hint="Lineup changes only."
        options={[
          {"Keep replaced player's position", ""}
          | Enum.map(~w(P C 1B 2B 3B SS LF CF RF DH), &{&1, &1})
        ]}
      />
      <button
        id={"baseball-confirm-substitution-#{@team.position}"}
        type="submit"
        class="ui-button ui-button--primary app-full-width"
      >
        Confirm substitution
      </button>
    </.form>
    """
  end

  attr :team, :any, required: true
  attr :bullpen, :list, required: true

  defp team_graphics_control(assigns) do
    ~H"""
    <div>
      <p class="ui-row-name app-team-name">{Team.full_name(@team)} bullpen</p>
      <div id={"baseball-bullpen-#{@team.position}"}>
        <p :if={@bullpen == []} class="ui-empty">
          No bullpen yet. Paste the game rosters to add one.
        </p>
        <ul :if={@bullpen != []} class="app-rows">
          <li :for={pitcher <- @bullpen} class="app-row">
            <span class="ui-truncate">{pitcher["name"]}</span>
            <span class="ui-label">{pitcher["status"]}</span>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  defp fallback_panel(assigns) do
    assigns =
      assigns
      |> assign(:teams, sorted_teams(assigns.show))
      |> assign(:game_count, length(List.wrap(assigns.show.games)))

    ~H"""
    <div
      id="esports-controls"
      class="ui-toolbar ui-toolbar--sticky app-live-strip"
      role="group"
      aria-label="Live controls"
    >
      <.score_control :for={team <- @teams} team={team} />

      <span class="ui-stat-divider app-strip-divider" aria-hidden="true"></span>

      <button
        type="button"
        id="swap-sides"
        class="ui-button"
        phx-click="swap_sides"
        aria-pressed={to_string(@show.swap_sides)}
        title={
          if @show.swap_sides,
            do: "Team 2 is drawn on the left. Press to put team 1 back.",
            else: "Team 1 is drawn on the left"
        }
      >
        <span aria-hidden="true">⇄</span> Swap sides
      </button>

      <span class="ui-stat-divider app-strip-divider" aria-hidden="true"></span>

      <div class="ui-stepper" role="group" aria-label="Current game">
        <button
          type="button"
          id="previous-game"
          class="ui-button"
          phx-click="step_game"
          phx-value-delta="-1"
          disabled={@show.current_game <= 1}
          title={@show.current_game <= 1 && "Game 1 is the first game"}
        >
          ‹ Previous game
        </button>
        <span class="ui-stepper-value app-game-value" aria-live="polite">
          <span class="ui-label">Game</span>
          <span>{@show.current_game}<span class="ui-muted">/{max(@game_count, 1)}</span></span>
        </span>
        <button
          type="button"
          id="next-game"
          class="ui-button"
          phx-click="step_game"
          phx-value-delta="1"
          disabled={@show.current_game >= @game_count}
          title={next_game_reason(@show.current_game, @game_count)}
        >
          Next game ›
        </button>
      </div>

      <div class="ui-toolbar-end">
        <button
          type="button"
          id="reset-scores"
          class="ui-button ui-button--danger"
          phx-click="reset_scores"
          disabled={Enum.all?(@teams, &(&1.score == 0))}
          title={Enum.all?(@teams, &(&1.score == 0)) && "Both scores are already 0"}
          data-confirm="Reset both series scores?"
          data-confirm-body="The scorebug shows 0–0 at once."
          data-confirm-action="Reset scores"
        >
          Reset scores
        </button>
      </div>
    </div>
    """
  end

  defp next_game_reason(_current, 0), do: "No games in the series yet"

  defp next_game_reason(current, count) when current >= count,
    do: "Game #{count} is the last game"

  defp next_game_reason(_current, _count), do: nil

  attr :id, :string, required: true
  attr :action, :string, required: true
  attr :result, :string, required: true
  attr :label, :string, required: true
  attr :submit, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :reason, :string, default: nil, doc: "why the action does not apply, shown when disabled"

  defp game_action(assigns) do
    assigns = assign(assigns, :submit, assigns.submit || assigns.action == "record_play")

    ~H"""
    <button
      id={@id}
      type={if(@submit, do: "submit", else: "button")}
      name={if(@submit, do: "play[result]")}
      value={if(@submit, do: @result)}
      disabled={@disabled}
      title={@disabled && @reason}
      class="ui-button app-action"
      phx-click={if(!@submit, do: "sport_action")}
      phx-value-action={if(!@submit, do: @action)}
      phx-value-result={if(!@submit, do: @result)}
    >
      {@label}
    </button>
    """
  end

  attr :team, :any, required: true
  attr :lineup, :list, required: true
  attr :active_index, :integer, required: true
  attr :pitcher, :map, required: true
  attr :batting?, :boolean, required: true

  defp roster_control(assigns) do
    assigns = assign(assigns, :active_batter, Enum.at(assigns.lineup, assigns.active_index))

    ~H"""
    <div>
      <div class="app-subhead">
        <span class="ui-row-name ui-truncate">{Team.full_name(@team)}</span>
        <span class="ui-badge" data-status={if(@batting?, do: "progress", else: "neutral")}>
          {if(@batting?, do: "Batting", else: "Fielding")}
        </span>
      </div>

      <div id={"baseball-lineup-#{@team.position}"}>
        <p :if={@lineup == []} class="ui-empty">
          No lineup yet. Paste the game rosters to add one.
        </p>
        <ol :if={@lineup != []} class="app-rows" aria-label={"#{Team.full_name(@team)} batting order"}>
          <li :for={{player, index} <- Enum.with_index(@lineup)}>
            <button
              id={"baseball-batter-#{@team.position}-#{index}"}
              type="button"
              class="app-row app-lineup-row"
              aria-pressed={to_string(index == @active_index)}
              aria-label={"Make #{player["name"]} the active batter"}
              phx-click="sport_action"
              phx-value-action="set_batter"
              phx-value-position={@team.position}
              phx-value-index={index}
            >
              <span class="ui-mono ui-muted">{index + 1}</span>
              <span class="ui-truncate">{player["name"]}</span>
              <span class="ui-label">{player["field_position"]}</span>
              <span class="ui-mono" title="Hits-at bats">{player["hits"]}-{player["at_bats"]}</span>
            </button>
          </li>
        </ol>
      </div>

      <div :if={@active_batter} class="app-cell app-after-fields">
        <div class="app-subhead">
          <span class="ui-label">Selected batter</span>
          <button
            id={"baseball-next-batter-#{@team.position}"}
            type="button"
            class="ui-button ui-button--small"
            phx-click="sport_action"
            phx-value-action="next_batter"
            phx-value-position={@team.position}
          >
            Next batter ›
          </button>
        </div>
        <p class="ui-row-name ui-truncate">{@active_batter["name"]}</p>
        <dl class="ui-spec">
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
        </dl>
      </div>

      <div class="app-cell app-after-fields">
        <div class="app-subhead">
          <span class="ui-label">Starting or current pitcher</span>
        </div>
        <div class="app-pitcher">
          <span class="ui-row-name ui-truncate">{display_name(@pitcher["name"])}</span>
          <div class="ui-stepper" role="group" aria-label={"Pitch count, #{Team.full_name(@team)}"}>
            <button
              id={"baseball-pitches-down-#{@team.position}"}
              type="button"
              class="ui-button ui-button--small"
              phx-click="sport_action"
              phx-value-action="adjust_pitch_count"
              phx-value-position={@team.position}
              phx-value-delta="-1"
              aria-label="Lower pitch count"
            >
              −
            </button>
            <span
              id={"baseball-pitches-#{@team.position}"}
              class="ui-stepper-value"
              aria-live="polite"
            >
              {@pitcher["pitch_count"]}
            </span>
            <button
              id={"baseball-pitches-up-#{@team.position}"}
              type="button"
              class="ui-button ui-button--small"
              phx-click="sport_action"
              phx-value-action="adjust_pitch_count"
              phx-value-position={@team.position}
              phx-value-delta="1"
              aria-label="Raise pitch count"
            >
              +
            </button>
          </div>
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
    <section class="app-cell" aria-label={"#{@role} runs, #{Team.full_name(@team)}"}>
      <div class="app-subhead">
        <span class="ui-label">{@role}</span>
        <span :if={@batting?} class="ui-badge" data-status="progress">At bat</span>
      </div>
      <div class="app-score-row">
        <span class="ui-row-name ui-truncate app-score-name">{Team.full_name(@team)}</span>
        <div class="ui-stepper" role="group" aria-label={"Runs, #{Team.full_name(@team)}"}>
          <button
            id={"run-down-#{@team.position}"}
            type="button"
            class="ui-button"
            phx-click="score"
            phx-value-position={@team.position}
            phx-value-delta="-1"
            disabled={@team.score == 0}
            title={@team.score == 0 && "Runs are already 0"}
            aria-label={"Lower #{@role} runs"}
          >
            −
          </button>
          <span id={"baseball-runs-#{@team.position}"} class="ui-stepper-value" aria-live="polite">
            {@team.score}
          </span>
          <button
            id={"run-up-#{@team.position}"}
            type="button"
            class="ui-button"
            phx-click="score"
            phx-value-position={@team.position}
            phx-value-delta="1"
            aria-label={"Raise #{@role} runs"}
          >
            +
          </button>
        </div>
      </div>
    </section>
    """
  end

  attr :team, :any, required: true

  defp score_control(assigns) do
    ~H"""
    <div class="ui-stepper" role="group" aria-label={"Series score, #{Team.full_name(@team)}"}>
      <span class="ui-label app-stepper-label" title={Team.full_name(@team)}>
        {Team.display_name(@team)}
      </span>
      <button
        type="button"
        id={"score-down-#{@team.position}"}
        class="ui-button"
        phx-click="score"
        phx-value-position={@team.position}
        phx-value-delta="-1"
        disabled={@team.score == 0}
        title={@team.score == 0 && "The score is already 0"}
        aria-label={"Lower score, #{Team.full_name(@team)}"}
      >
        −
      </button>
      <span id={"score-value-#{@team.position}"} class="ui-stepper-value" aria-live="polite">
        {@team.score}
      </span>
      <button
        type="button"
        id={"score-up-#{@team.position}"}
        class="ui-button"
        phx-click="score"
        phx-value-position={@team.position}
        phx-value-delta="1"
        aria-label={"Raise score, #{Team.full_name(@team)}"}
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
    <div class="app-count" role="group" aria-label={@label}>
      <span class="ui-label">{@label}</span>
      <span id={"baseball-#{@kind}"} class="ui-stepper-value" aria-live="polite">{@value}</span>
      <div class="ui-stepper">
        <button
          id={"baseball-#{@kind}-down"}
          type="button"
          class="ui-button ui-button--small"
          phx-click="sport_action"
          phx-value-action="adjust_count"
          phx-value-kind={@kind}
          phx-value-delta="-1"
          disabled={@value == 0}
          title={@value == 0 && "Already 0"}
          aria-label={"Lower #{@label}"}
        >
          −
        </button>
        <button
          id={"baseball-#{@kind}-up"}
          type="button"
          class="ui-button ui-button--small"
          disabled={@value >= @maximum}
          title={@value >= @maximum && "The next one ends the count; record it as a pitch or play"}
          phx-click="sport_action"
          phx-value-action="adjust_count"
          phx-value-kind={@kind}
          phx-value-delta="1"
          aria-label={"Raise #{@label}"}
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

  # A base is a toggle: pressed (inverted) means a runner is on it. The square
  # is turned 45 degrees to read as a base; that is a static transform, not
  # motion.
  defp base_button(assigns) do
    ~H"""
    <button
      id={"baseball-base-#{@base}"}
      type="button"
      class={["ui-button app-base", @class]}
      phx-click="sport_action"
      phx-value-action="toggle_base"
      phx-value-base={@base}
      aria-label={"Runner on #{@base} base"}
      aria-pressed={to_string(@occupied)}
    >
    </button>
    """
  end

  attr :label, :string, required: true
  attr :stat, :string, required: true
  attr :position, :integer, required: true
  attr :value, :integer, required: true

  defp player_stat_control(assigns) do
    ~H"""
    <div>
      <dt>{@label}</dt>
      <dd id={"baseball-batter-#{@stat}-#{@position}"}>{@value}</dd>
    </div>
    """
  end

  defp play_form, do: to_form(%{"notation" => ""}, as: :play)

  defp substitution_forms(teams) do
    Map.new(teams, fn team ->
      form =
        to_form(
          %{
            "position" => to_string(team.position),
            "outgoing_player_id" => "",
            "incoming_player_id" => "",
            "field_position" => ""
          },
          as: :substitution
        )

      {team.position, form}
    end)
  end

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

  defp game_rosters_form(teams, state) do
    data = Enum.map_join(teams, "\n\n", &team_roster_text(&1, state))
    to_form(%{"data" => data}, as: :game_rosters)
  end

  defp team_roster_text(team, state) do
    position = to_string(team.position)
    lineup = state["lineups"][position]
    pitcher = state["pitchers"][position]
    bullpen = state["bullpens"][position]

    used_names =
      lineup
      |> Enum.map(& &1["name"])
      |> Kernel.++([pitcher["name"]])
      |> Kernel.++(Enum.map(bullpen, & &1["name"]))
      |> MapSet.new()

    lineup_text =
      lineup
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {player, order} ->
        ["#{order}. #{player["name"]}", player["field_position"]]
        |> Enum.reject(&(&1 in [nil, ""]))
        |> Enum.join(" | ")
      end)

    bullpen_text =
      Enum.map_join(bullpen, "\n", fn reliever ->
        [reliever["name"], reliever["status"]]
        |> Enum.reject(&(&1 in [nil, ""]))
        |> Enum.join(" | ")
      end)

    remaining_roster =
      state["rosters"][position]
      |> Enum.reject(&MapSet.member?(used_names, &1["name"]))
      |> Enum.map_join("\n", & &1["name"])

    [
      if(team.position == 1,
        do: "AWAY — #{Team.full_name(team)}",
        else: "HOME — #{Team.full_name(team)}"
      ),
      "TEAM",
      "Name: #{team.name}",
      "Short name: #{team.short_name}",
      "Code: #{team.code}",
      "Logo URL: #{team.logo_url}",
      "Primary color: #{team.primary_color}",
      "Secondary color: #{team.secondary_color}",
      "Record: #{team.record}",
      "Side label: #{team.side}",
      "LINEUP",
      lineup_text,
      "STARTING PITCHER",
      pitcher["name"],
      "BULLPEN",
      bullpen_text,
      "ROSTER",
      remaining_roster
    ]
    |> Enum.join("\n")
  end

  defp game_rosters_placeholder(teams) do
    [away, home] = teams

    """
    AWAY — #{Team.full_name(away)}
    TEAM
    Name: Harbour Kings
    Short name: Kings
    Code: HKG
    Logo URL: https://example.com/harbour-kings.svg
    Primary color: #0f766e
    Secondary color: #f8fafc
    Record: 18-8
    Side label: Away
    LINEUP
    1. Alex Cruz | SS
    2. Morgan Ellis | CF
    STARTING PITCHER
    Jordan Lee
    BULLPEN
    Taylor Reed | Warming
    Casey Park | Available
    ROSTER
    Remaining Player

    HOME — #{Team.full_name(home)}
    TEAM
    Name: Ridgeline Foxes
    Short name: Foxes
    Code: RFX
    Logo URL: https://example.com/ridgeline-foxes.svg
    Primary color: #c2410c
    Secondary color: #fff7ed
    Record: 16-10
    Side label: Home
    LINEUP
    1. Jamie Fox | 2B
    STARTING PITCHER
    Riley Stone
    BULLPEN
    Avery Cole | Ready
    ROSTER
    Remaining Player
    """
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
    away = player_options(state["lineups"]["1"], state["pitchers"]["1"])
    home = player_options(state["lineups"]["2"], state["pitchers"]["2"])
    %{away: away, home: home, all: away ++ home}
  end

  defp player_options(players, pitcher) do
    pitcher_options =
      if Map.get(pitcher, "id"), do: [{"#{pitcher["name"]} · P", pitcher["id"]}], else: []

    (pitcher_options ++
       (players
        |> Enum.filter(&Map.get(&1, "id"))
        |> Enum.map(&{&1["name"], &1["id"]})))
    |> Enum.uniq_by(&elem(&1, 1))
  end

  defp sorted_teams(show), do: show.teams |> List.wrap() |> Enum.sort_by(& &1.position)

  defp with_rosters(%{"rosters" => rosters} = state) when is_map(rosters), do: state

  defp with_rosters(state) do
    rosters =
      Map.new(~w(1 2), fn position ->
        players =
          (state["lineups"][position] ++ [state["pitchers"][position]])
          |> Enum.reject(&(&1["name"] in [nil, ""]))
          |> Enum.uniq_by(& &1["name"])
          |> Enum.map(&Map.take(&1, ~w(id name)))

        {position, players}
      end)

    Map.put(state, "rosters", rosters)
  end

  defp display_name(""), do: "Waiting for game events"
  defp display_name(name), do: name

  defp baseball_state(%{baseball_game: %Showish.Baseball.Game{}} = show), do: show.sport_state
  defp baseball_state(show), do: Baseball.normalize_state(show.sport_state)
end
