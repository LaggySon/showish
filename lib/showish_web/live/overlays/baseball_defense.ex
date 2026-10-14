defmodule ShowishWeb.Overlays.BaseballDefense do
  @moduledoc "Baseball defensive alignment drawn over a field diagram."

  use ShowishWeb.OverlayLive

  alias Showish.Broadcasts.Show
  alias Showish.Broadcasts.Sports.Baseball

  @positions [
    {"LF", 14, 18},
    {"CF", 50, 9},
    {"RF", 86, 18},
    {"SS", 34, 43},
    {"2B", 66, 43},
    {"3B", 18, 62},
    {"1B", 82, 62},
    {"P", 50, 62},
    {"C", 50, 88}
  ]

  @impl Phoenix.LiveView
  def render(assigns) do
    state = Baseball.normalize_state(assigns.show.sport_state)
    fielding_position = if state["half"] == "top", do: 2, else: 1
    team = Show.team(assigns.show, fielding_position)

    assigns =
      assigns
      |> assign(:state, state)
      |> assign(:team, team)
      |> assign(:players, state["defense"][to_string(fielding_position)])
      |> assign(:positions, @positions)

    ~H"""
    <.stage preset={@show.preset} accent={@show.accent_color}>
      <div id="baseball-defense-scene" class="absolute inset-x-[170px] top-[72px] bottom-[60px]">
        <header class="overlay-in-down flex items-center justify-between">
          <div class="flex items-center gap-5">
            <.team_logo team={@team} size={82} />
            <div>
              <.eyebrow color={@show.accent_color}>On the field</.eyebrow>
              <h1 class="mt-2 text-[48px] font-black uppercase leading-none">{full_name(@team)}</h1>
            </div>
          </div>
          <p class="text-right text-[20px] font-bold uppercase tracking-[0.18em] text-slate-400">
            Defensive alignment<br />{if(@state["half"] == "top", do: "Top", else: "Bottom")} {@state[
              "inning"
            ]}
          </p>
        </header>

        <div class="overlay-panel overlay-round-hero overlay-in-up relative mx-auto mt-6 h-[790px] w-[1280px] overflow-hidden bg-emerald-950">
          <div class="absolute inset-0 bg-[radial-gradient(circle_at_50%_100%,rgba(34,197,94,0.5),rgba(6,78,59,0.85)_58%,rgba(2,44,34,0.98))]">
          </div>
          <div class="absolute left-1/2 top-[60%] size-[520px] -translate-x-1/2 -translate-y-1/2 rotate-45 border-[7px] border-white/30 bg-amber-700/35">
          </div>
          <div class="absolute bottom-[-170px] left-1/2 size-[470px] -translate-x-1/2 rounded-full border-[7px] border-white/30 bg-emerald-800">
          </div>

          <div
            :for={{position, x, y} <- @positions}
            id={"defense-position-#{position}"}
            class="absolute z-10 w-[220px] -translate-x-1/2 -translate-y-1/2 text-center"
            style={"left: #{x}%; top: #{y}%;"}
          >
            <div class="mx-auto inline-flex min-w-[170px] items-center justify-center gap-3 rounded-full border border-white/20 bg-slate-950/90 px-5 py-3 shadow-2xl backdrop-blur">
              <span class="text-[16px] font-black text-emerald-300">{position}</span>
              <span class="max-w-[130px] truncate text-[20px] font-black uppercase">
                {display(@players[position])}
              </span>
            </div>
          </div>
        </div>
      </div>
    </.stage>
    """
  end

  defp display(""), do: "—"
  defp display(value), do: value
end
