defmodule ShowishWeb.Overlays.Scorebug do
  @moduledoc """
  The in-game bar: both teams, the series score, and the line of copy that says
  what is currently being played.

  This is the scene that spends the whole match on screen, so it is anchored to
  the top of the canvas and everything below y=140 is left clear for gameplay.
  """

  use ShowishWeb.OverlayLive

  alias Showish.Broadcasts.Show
  alias Showish.Broadcasts.Sports.Baseball
  alias Showish.Text

  @impl Phoenix.LiveView
  def render(%{show: %{sport: "baseball"}} = assigns) do
    state = Baseball.normalize_state(assigns.show.sport_state)
    batting_position = if state["half"] == "top", do: "1", else: "2"
    fielding_position = if batting_position == "1", do: "2", else: "1"
    active_index = state["active_batters"][batting_position]

    assigns =
      assigns
      |> assign(:away, Show.team(assigns.show, 1))
      |> assign(:home, Show.team(assigns.show, 2))
      |> assign(:state, state)
      |> assign(:batting_position, batting_position)
      |> assign(:batter, Enum.at(state["lineups"][batting_position], active_index))
      |> assign(:batter_order, active_index + 1)
      |> assign(:pitcher, state["pitchers"][fielding_position])

    baseball(assigns)
  end

  def render(assigns) do
    assigns = assign(assigns, :center_line, Show.center_line(assigns.show))

    render_preset(assigns)
  end

  defp baseball(assigns) do
    ~H"""
    <.stage preset={@show.preset} accent={@show.accent_color}>
      <div
        id="baseball-scorebug"
        class="absolute left-12 top-10 overlay-in-left font-[Oswald] text-white"
      >
        <div class="w-[600px] overflow-hidden rounded-[3px] border-2 border-white/25 bg-[#06182b] shadow-[0_10px_28px_rgba(0,0,0,0.48)]">
          <div class="grid h-[148px] grid-cols-[430px_170px] border-b-2 border-white/20">
            <div class="grid grid-cols-[1fr_92px] grid-rows-2 bg-[#071d33]">
              <.baseball_team team={@away} position={1} runs={score(@away)} />
              <.baseball_team team={@home} position={2} runs={score(@home)} />
            </div>

            <div class="grid grid-cols-[76px_94px] border-l-2 border-white/20 bg-[#04111f]">
              <div class="grid grid-rows-2 items-center text-center">
                <div
                  id="baseball-overlay-outs"
                  class="flex h-full flex-col items-center justify-center border-b-2 border-white/20"
                >
                  <span class="text-[31px] font-bold leading-none tabular-nums">
                    {@state["outs"]}
                  </span>
                  <span class="mt-1 text-[15px] font-semibold uppercase leading-none tracking-[0.08em]">
                    {if(@state["outs"] == 1, do: "out", else: "outs")}
                  </span>
                </div>
                <div
                  id="baseball-overlay-count"
                  class="text-[30px] font-bold leading-none tracking-[0.08em] tabular-nums"
                >
                  {@state["balls"]}-{@state["strikes"]}
                </div>
              </div>

              <div class="flex flex-col items-center justify-center border-l-2 border-white/20">
                <.baseball_bases bases={@state["bases"]} />
                <div
                  id="baseball-overlay-inning"
                  class="mt-3 flex items-center gap-2 text-[31px] font-bold leading-none tabular-nums"
                >
                  <span class="text-[22px] text-blue-100/80">
                    {if(@state["half"] == "top", do: "▲", else: "▼")}
                  </span>
                  <span>{@state["inning"]}</span>
                </div>
              </div>
            </div>
          </div>

          <.baseball_player_line
            id="baseball-overlay-pitcher"
            name={player_name(@pitcher, "PITCHER")}
            stat={"P: #{@pitcher["pitch_count"]}"}
          />
          <.baseball_player_line
            id="baseball-overlay-batter"
            name={batter_name(@batter_order, @batter)}
            stat={batter_line(@batter)}
          />
        </div>
      </div>
    </.stage>
    """
  end

  attr :team, :any, required: true
  attr :position, :integer, required: true
  attr :runs, :integer, required: true

  defp baseball_team(assigns) do
    ~H"""
    <div
      class={[
        "col-span-2 grid grid-cols-[1fr_92px]",
        @position == 1 && "border-b-2 border-white/20"
      ]}
      style={baseball_team_style(@team)}
    >
      <div class="relative flex min-w-0 items-center px-6">
        <span class="truncate text-[34px] font-semibold uppercase leading-none tracking-[0.08em]">
          {team_code(@team)}
        </span>
      </div>
      <span
        id={"baseball-overlay-runs-#{@position}"}
        class="flex items-center justify-center text-[46px] font-bold leading-none tabular-nums"
      >
        {@runs}
      </span>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :stat, :string, required: true

  defp baseball_player_line(assigns) do
    ~H"""
    <div
      id={@id}
      class="grid h-[62px] grid-cols-[430px_170px] border-b-2 border-white/20 bg-[#071d33] last:border-b-0"
    >
      <span class="flex min-w-0 items-center truncate px-6 text-[27px] font-semibold uppercase leading-none tracking-[0.06em]">
        {@name}
      </span>
      <span class="flex items-center justify-center border-l-2 border-white/20 bg-[#04111f] text-[28px] font-bold uppercase leading-none tracking-[0.04em] tabular-nums">
        {@stat}
      </span>
    </div>
    """
  end

  attr :bases, :map, required: true

  defp baseball_bases(assigns) do
    ~H"""
    <div
      id="baseball-overlay-bases"
      class="grid h-[48px] w-[66px] shrink-0 grid-cols-3 grid-rows-2 gap-1.5"
    >
      <span class={base_classes(@bases["second"], "col-start-2")}></span>
      <span class={base_classes(@bases["third"], "col-start-1 row-start-2")}></span>
      <span class={base_classes(@bases["first"], "col-start-3 row-start-2")}></span>
    </div>
    """
  end

  defp base_classes(occupied?, position) do
    [
      "size-[19px] rotate-45 rounded-[2px] border-2",
      occupied? && "border-[#f7d168] bg-[#f7d168] shadow-[0_0_8px_rgba(247,209,104,0.5)]",
      !occupied? && "border-blue-100/30 bg-blue-100/8",
      position
    ]
  end

  defp team_code(nil), do: "TBD"

  defp team_code(team) do
    case String.trim(team.code || "") do
      "" -> short_name(team)
      code -> code
    end
  end

  defp player_name(%{"name" => name}, fallback) when is_binary(name) do
    case String.trim(name) do
      "" -> fallback
      name -> name
    end
  end

  defp player_name(_player, fallback), do: fallback

  defp batter_name(_order, nil), do: "BATTER"
  defp batter_name(order, batter), do: "#{order}. #{player_name(batter, "BATTER")}"

  defp batter_line(nil), do: "—"
  defp batter_line(batter), do: "#{batter["hits"]}-#{batter["at_bats"]}"

  # The scorebug is the one scene whose geometry actually changes between
  # presets, so it dispatches on the show's preset rather than leaning on
  # scoped CSS the way the other six do.
  defp render_preset(%{show: %{preset: "tranquility"}} = assigns), do: tranquility(assigns)
  defp render_preset(assigns), do: broadcast(assigns)

  defp broadcast(assigns) do
    ~H"""
    <.stage preset={@show.preset} accent={@show.accent_color}>
      <div class="absolute left-1/2 top-0 -translate-x-1/2">
        <div class="flex h-[92px] items-stretch">
          <.team_plate
            team={@left}
            align="right"
            show_sides={@show.show_sides}
            enter="overlay-in-left"
          />
          <.score_box team={@left} delay={140} />

          <div class="overlay-panel overlay-in-down flex w-[210px] flex-col items-center justify-center gap-1.5 border-x-0">
            <.eyebrow color={@show.accent_color}>{stage_label(@show)}</.eyebrow>

            <div class="text-[26px] font-black uppercase leading-none tracking-tight">
              {game_label(@show)}
            </div>
          </div>
          <.score_box team={@right} delay={140} />
          <.team_plate
            team={@right}
            align="left"
            show_sides={@show.show_sides}
            enter="overlay-in-right"
          />
        </div>

        <div :if={@center_line != ""} class="flex justify-center">
          <div
            class="overlay-panel overlay-shear overlay-in-down -mt-px flex h-[42px] min-w-[420px] max-w-[820px] items-center justify-center px-10"
            style="--overlay-delay: 220ms"
          >
            <span class="truncate text-[17px] font-medium uppercase tracking-[0.18em] text-slate-100/90">
              {@center_line}
            </span>
          </div>
        </div>
      </div>

      <div
        :if={@show.show_status_left and @show.status_left != ""}
        class="absolute left-16 top-8 overlay-in-left"
        style="--overlay-delay: 300ms"
      >
        <.status_pill accent={@show.accent_color}>{@show.status_left}</.status_pill>
      </div>

      <div
        :if={@show.show_status_right and @show.status_right != ""}
        class="absolute right-16 top-8 overlay-in-right"
        style="--overlay-delay: 300ms"
      >
        <.status_pill accent={@show.accent_color}>{@show.status_right}</.status_pill>
      </div>
    </.stage>
    """
  end

  # Each team gets a flat plate in its own top corner, mirrored, with the scores
  # facing the middle of the frame. The centred slugs replace the broadcast
  # preset's middle panel, which has nowhere to live once the teams move apart.
  defp tranquility(assigns) do
    ~H"""
    <.stage preset={@show.preset} accent={@show.accent_color}>
      <div class="tranq-teams">
        <.tranq_team
          team={@left}
          side="left"
          stats={stat_line(@show, :left)}
          show_sides={@show.show_sides}
          enter="overlay-in-left"
        />
        <.tranq_team
          team={@right}
          side="right"
          stats={stat_line(@show, :right)}
          show_sides={@show.show_sides}
          enter="overlay-in-right"
        />
      </div>

      <div
        :if={@center_line != ""}
        class="tranq-info overlay-in-down"
        style="--overlay-delay: 220ms"
      >
        {@center_line}
      </div>

      <div
        :if={stage_label(@show) != ""}
        class="tranq-tag overlay-in-up"
        style="--overlay-delay: 300ms"
      >
        {stage_label(@show)}
      </div>
    </.stage>
    """
  end

  attr :team, :any, required: true
  attr :side, :string, required: true
  attr :stats, :string, default: ""
  attr :show_sides, :boolean, default: false
  attr :enter, :string, default: nil

  defp tranq_team(assigns) do
    ~H"""
    <div class={["tranq-team", @side == "right" && "tranq-team-right", @enter]}>
      <div class="tranq-team-col">
        <div :if={@stats != ""} class="tranq-stats">{@stats}</div>

        <div class="tranq-bar" style={"background: #{primary(@team)};"}>
          <div
            :if={@team && Text.present?(@team.record)}
            class="tranq-record"
            style={"color: #{secondary(@team)};"}
          >
            {@team.record}
          </div>

          <div class="tranq-name" style={"color: #{secondary(@team)};"}>{short_name(@team)}</div>

          <div class="tranq-logo" style={"background-color: #{primary(@team)};"}>
            <img :if={logo?(@team)} src={@team.logo_url} alt={full_name(@team)} />
            <span :if={!logo?(@team)} class="text-[20px]" style={"color: #{secondary(@team)};"}>
              {initials(@team)}
            </span>
          </div>

          <div class="tranq-score tabular">{score(@team)}</div>
        </div>
      </div>

      <div :if={(@show_sides and @team) && Text.present?(@team.side)} class="tranq-side">
        {@team.side}
      </div>
    </div>
    """
  end

  # The status slots become the small caption above each team's plate, which is
  # where this look puts per-team copy.
  defp stat_line(%{show_status_left: true} = show, :left), do: Text.presence(show.status_left)
  defp stat_line(%{show_status_right: true} = show, :right), do: Text.presence(show.status_right)
  defp stat_line(_show, side) when side in [:left, :right], do: ""

  attr :team, :any, required: true
  attr :align, :string, required: true
  attr :show_sides, :boolean, default: false
  attr :enter, :string, default: nil

  @doc false
  def team_plate(assigns) do
    ~H"""
    <div
      class={[
        "overlay-panel flex w-[440px] items-center gap-5 px-8",
        @enter,
        @align == "right" && "justify-end ",
        @align == "left" && "flex-row-reverse justify-end "
      ]}
      style={team_plate_style(@team, @align)}
    >
      <div class={["flex min-w-0 flex-col gap-1", @align == "right" && "items-end"]}>
        <div class="truncate text-[34px] font-black uppercase leading-none tracking-tight">
          {short_name(@team)}
        </div>

        <div class={["flex items-center gap-2", @align == "left" && "flex-row-reverse"]}>
          <span
            :if={@team && Text.present?(@team.record)}
            class="text-[14px] font-semibold uppercase tracking-[0.16em] text-slate-300/80"
          >
            {@team.record}
          </span>
          <span
            :if={(@show_sides and @team) && Text.present?(@team.side)}
            class="overlay-round-pill px-2 py-0.5 text-[12px] font-bold uppercase tracking-[0.14em]"
            style={"background: #{primary(@team)}; color: #{contrast(@team)};"}
          >
            {@team.side}
          </span>
        </div>
      </div>
      <.team_logo team={@team} size={58} />
    </div>
    """
  end

  attr :team, :any, required: true
  attr :delay, :integer, default: 0

  @doc false
  def score_box(assigns) do
    ~H"""
    <div
      class="tabular overlay-in-pop flex w-[104px] items-center justify-center text-[54px] font-black leading-none"
      style={score_box_style(@team, @delay)}
    >
      {score(@team)}
    </div>
    """
  end

  attr :accent, :string, required: true
  slot :inner_block, required: true

  @doc false
  def status_pill(assigns) do
    ~H"""
    <div
      class="overlay-panel overlay-round-pill flex h-[46px] items-center px-6 text-[16px] font-semibold uppercase tracking-[0.18em]"
      style={"border-left: 4px solid #{@accent};"}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp baseball_team_style(team) do
    "#{team_vars(team)} background: var(--team-primary); color: #{contrast(team)}; box-shadow: inset 6px 0 0 var(--team-secondary);"
  end

  defp team_plate_style(team, _align) do
    "#{team_vars(team)} background: var(--team-primary); color: #{contrast(team)}; box-shadow: inset 0 -5px 0 var(--team-secondary);"
  end

  defp score_box_style(team, delay) do
    "#{team_vars(team)} background: var(--team-primary); color: #{contrast(team)}; box-shadow: inset 0 -5px 0 var(--team-secondary); --overlay-delay: #{delay}ms;"
  end

  # The round being played, or the week it is part of if the operator named only
  # that.
  defp stage_label(show), do: Text.first_present([show.stage, show.subtitle])

  defp game_label(show) do
    total = length(Show.games(show))

    cond do
      total > 0 -> "Game #{min(show.current_game, total)}"
      show.best_of > 1 -> "BO#{show.best_of}"
      true -> "Live"
    end
  end
end
