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

  @impl Phoenix.LiveView
  def render(%{show: %{sport: "baseball"}} = assigns) do
    assigns =
      assigns
      |> assign(:away, Show.team(assigns.show, 1))
      |> assign(:home, Show.team(assigns.show, 2))
      |> assign(:state, Baseball.normalize_state(assigns.show.sport_state))

    baseball(assigns)
  end

  def render(assigns) do
    {left, right} = Show.sides(assigns.show)

    assigns =
      assigns
      |> assign(:left, left)
      |> assign(:right, right)
      |> assign(:center_line, Show.center_line(assigns.show))

    render_preset(assigns)
  end

  defp baseball(assigns) do
    ~H"""
    <.stage preset={@show.preset} accent={@show.accent_color}>
      <div
        id="baseball-scorebug"
        class="absolute left-12 top-10 overlay-in-left font-[Oswald] text-white"
      >
        <div class="flex h-[104px] w-[624px] overflow-hidden rounded-[3px] border border-white/15 bg-[#06182b] shadow-[0_8px_24px_rgba(0,0,0,0.42)]">
          <div class="min-w-0 flex-1">
            <div class="grid h-6 grid-cols-[minmax(0,1fr)_48px_42px_42px] items-center border-b border-white/12 bg-[#0b2947] px-3 text-[9px] font-bold uppercase tracking-[0.16em] text-blue-100/60">
              <span class="truncate">{stage_label(@show)}</span>
              <span class="text-center">R</span>
              <span class="text-center">H</span> <span class="text-center">E</span>
            </div>

            <.baseball_team_row
              team={@away}
              position={1}
              role="A"
              runs={score(@away)}
              hits={@state["hits"]["1"]}
              errors={@state["errors"]["1"]}
            />
            <.baseball_team_row
              team={@home}
              position={2}
              role="H"
              runs={score(@home)}
              hits={@state["hits"]["2"]}
              errors={@state["errors"]["2"]}
            />
          </div>

          <div class="grid w-[218px] grid-cols-[52px_82px_1fr] items-center border-l border-white/12 bg-[#04111f]">
            <div class="text-center">
              <div
                id="baseball-overlay-inning"
                class="text-[27px] font-bold leading-none tabular-nums"
              >
                <span class="mr-0.5 text-[13px] text-blue-100/70">
                  {if(@state["half"] == "top", do: "▲", else: "▼")}
                </span>
                <span>{@state["inning"]}</span>
              </div>
              <div class="mt-1 text-[8px] font-bold uppercase tracking-[0.14em] text-blue-100/45">
                Inning
              </div>
            </div>

            <.baseball_bases bases={@state["bases"]} />

            <div class="space-y-1.5 border-l border-white/10 pl-3">
              <.count_dots label="B" value={@state["balls"]} maximum={3} color="bg-[#43c98b]" />
              <.count_dots label="S" value={@state["strikes"]} maximum={2} color="bg-[#f3c85b]" />
              <.count_dots label="O" value={@state["outs"]} maximum={2} color="bg-[#f16f6f]" />
            </div>
          </div>
        </div>
      </div>
    </.stage>
    """
  end

  attr :team, :any, required: true
  attr :position, :integer, required: true
  attr :role, :string, required: true
  attr :runs, :integer, required: true
  attr :hits, :integer, required: true
  attr :errors, :integer, required: true

  defp baseball_team_row(assigns) do
    ~H"""
    <div class="relative grid h-10 grid-cols-[minmax(0,1fr)_48px_42px_42px] items-center border-b border-white/10 bg-[#071d33] px-3 last:border-0">
      <span class="absolute inset-y-0 left-0 w-[3px]" style={"background: #{@team.primary_color}"}>
      </span>
      <div class="flex min-w-0 items-center gap-2 pl-1">
        <span class="text-[8px] font-bold text-blue-100/40">{@role}</span>
        <span class="truncate text-[18px] font-bold uppercase leading-none tracking-[0.025em]">
          {short_name(@team)}
        </span>
      </div>
      <span
        id={"baseball-overlay-runs-#{@position}"}
        class="border-x border-white/10 text-center text-[23px] font-bold leading-10 tabular-nums"
      >
        {@runs}
      </span>
      <span
        id={"baseball-overlay-hits-#{@position}"}
        class="text-center text-[17px] font-medium text-blue-50/85 tabular-nums"
      >
        {@hits}
      </span>
      <span
        id={"baseball-overlay-errors-#{@position}"}
        class="text-center text-[17px] font-medium text-blue-50/85 tabular-nums"
      >
        {@errors}
      </span>
    </div>
    """
  end

  attr :bases, :map, required: true

  defp baseball_bases(assigns) do
    ~H"""
    <div
      id="baseball-overlay-bases"
      class="mx-auto grid size-[48px] shrink-0 grid-cols-3 grid-rows-2 gap-1"
    >
      <span class={base_classes(@bases["second"], "col-start-2")}></span>
      <span class={base_classes(@bases["third"], "col-start-1 row-start-2")}></span>
      <span class={base_classes(@bases["first"], "col-start-3 row-start-2")}></span>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :maximum, :integer, required: true
  attr :color, :string, required: true

  defp count_dots(assigns) do
    ~H"""
    <div class="flex items-center gap-1">
      <span class="w-2.5 text-[9px] font-bold text-blue-100/65">{@label}</span>
      <span
        :for={index <- 1..@maximum}
        class={[
          "size-[7px] rounded-full border border-white/20",
          index <= @value && @color,
          index > @value && "bg-white/10"
        ]}
      >
      </span>
    </div>
    """
  end

  defp base_classes(occupied?, position) do
    [
      "size-3.5 rotate-45 rounded-[1px] border",
      occupied? && "border-[#f7d168] bg-[#f7d168] shadow-[0_0_7px_rgba(247,209,104,0.55)]",
      !occupied? && "border-blue-100/30 bg-blue-100/8",
      position
    ]
  end

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
          /> <.score_box team={@left} delay={140} />
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
            :if={@team && @team.record not in [nil, ""]}
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

      <div :if={(@show_sides and @team) && @team.side not in [nil, ""]} class="tranq-side">
        {@team.side}
      </div>
    </div>
    """
  end

  # The status slots become the small caption above each team's plate, which is
  # where this look puts per-team copy.
  defp stat_line(show, :left) do
    if show.show_status_left, do: String.trim(show.status_left || ""), else: ""
  end

  defp stat_line(show, :right) do
    if show.show_status_right, do: String.trim(show.status_right || ""), else: ""
  end

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
      style={"background: linear-gradient(#{gradient_angle(@align)}, #{wash(@team, 0.9)} 0%, rgba(9, 12, 18, 0.92) 78%);"}
    >
      <div class={["flex min-w-0 flex-col gap-1", @align == "right" && "items-end"]}>
        <div class="truncate text-[34px] font-black uppercase leading-none tracking-tight">
          {short_name(@team)}
        </div>

        <div class={["flex items-center gap-2", @align == "left" && "flex-row-reverse"]}>
          <span
            :if={@team && @team.record not in [nil, ""]}
            class="text-[14px] font-semibold uppercase tracking-[0.16em] text-slate-300/80"
          >
            {@team.record}
          </span>
          <span
            :if={(@show_sides and @team) && @team.side not in [nil, ""]}
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
      style={"background: #{primary(@team)}; color: #{contrast(@team)}; --overlay-delay: #{@delay}ms;"}
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

  defp gradient_angle("right"), do: "270deg"
  defp gradient_angle(_align), do: "90deg"

  defp stage_label(show) do
    case String.trim(show.stage || "") do
      "" -> String.trim(show.subtitle || "")
      stage -> stage
    end
  end

  defp game_label(show) do
    total = length(List.wrap(show.games))

    cond do
      total > 0 -> "Game #{min(show.current_game, total)}"
      show.best_of > 1 -> "BO#{show.best_of}"
      true -> "Live"
    end
  end
end
