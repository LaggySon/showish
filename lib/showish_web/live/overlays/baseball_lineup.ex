defmodule ShowishWeb.Overlays.BaseballLineup do
  @moduledoc "Full-screen batting orders for a baseball broadcast."

  use ShowishWeb.OverlayLive

  alias Showish.Broadcasts.Show
  alias Showish.Broadcasts.Sports.Baseball

  @impl Phoenix.LiveView
  def render(assigns) do
    state = Baseball.normalize_state(assigns.show.sport_state)

    assigns =
      assigns
      |> assign(:state, state)
      |> assign(:teams, Enum.map([1, 2], &Show.team(assigns.show, &1)))

    ~H"""
    <.stage preset={@show.preset} accent={@show.accent_color}>
      <div id="baseball-lineup-scene" class="absolute inset-x-[120px] top-[84px] bottom-[84px]">
        <header class="overlay-in-down flex items-end justify-between border-b border-white/20 pb-5">
          <div>
            <.eyebrow color={@show.accent_color}>Starting nine</.eyebrow>
            <h1 class="mt-2 text-[54px] font-black uppercase leading-none tracking-[-0.04em]">
              Batting lineups
            </h1>
          </div>
          <div class="text-right text-[18px] font-bold uppercase tracking-[0.15em] text-slate-400">
            {@show.stage}<br />{@show.title}
          </div>
        </header>

        <div class="mt-7 grid grid-cols-2 gap-7">
          <.lineup_card
            :for={team <- @teams}
            team={team}
            lineup={@state["lineups"][to_string(team.position)]}
            active={@state["active_batters"][to_string(team.position)]}
          />
        </div>
      </div>
    </.stage>
    """
  end

  attr :team, :any, required: true
  attr :lineup, :list, required: true
  attr :active, :integer, required: true

  defp lineup_card(assigns) do
    ~H"""
    <section
      class="overlay-panel overlay-round-card overlay-in-up overflow-hidden"
      style={team_vars(@team)}
    >
      <div class="flex h-[108px] items-center gap-5 px-7" style={"background: #{wash(@team, 0.9)}"}>
        <.team_logo team={@team} size={72} />
        <div class="min-w-0 flex-1">
          <p class="text-[13px] font-bold uppercase tracking-[0.2em] text-white/65">
            {if(@team.position == 1, do: "Away", else: "Home")}
          </p>
          <h2 class="truncate text-[34px] font-black uppercase leading-none">{full_name(@team)}</h2>
        </div>
        <span class="text-[18px] font-black uppercase tracking-[0.14em] text-white/65">H-AB</span>
      </div>

      <div class="min-h-[594px] bg-slate-950/90 p-3">
        <div
          :for={{player, index} <- Enum.with_index(@lineup)}
          id={"lineup-player-#{@team.position}-#{index}"}
          class={[
            "grid h-[61px] grid-cols-[52px_minmax(0,1fr)_92px] items-center border-b border-white/10 px-4",
            index == @active && "bg-white/10 shadow-[inset_5px_0_0_var(--team-primary)]"
          ]}
        >
          <span class="text-[22px] font-black text-slate-500 tabular-nums">{index + 1}</span>
          <span class="truncate text-[25px] font-black uppercase">{player["name"]}</span>
          <span class="text-right text-[23px] font-black tabular-nums">
            {player["hits"]}-{player["at_bats"]}
          </span>
        </div>

        <div :if={@lineup == []} class="grid h-[594px] place-items-center text-[22px] text-slate-500">
          Lineup not entered
        </div>
      </div>
    </section>
    """
  end
end
