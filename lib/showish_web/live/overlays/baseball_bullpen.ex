defmodule ShowishWeb.Overlays.BaseballBullpen do
  @moduledoc "Two-team bullpen availability board."

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
      <div id="baseball-bullpen-scene" class="absolute inset-x-[150px] top-[100px]">
        <header class="overlay-in-down text-center">
          <.eyebrow color={@show.accent_color}>{@show.stage}</.eyebrow>
          <h1 class="mt-3 text-[58px] font-black uppercase leading-none tracking-[-0.04em]">
            Bullpen report
          </h1>
        </header>

        <div class="mt-10 grid grid-cols-2 gap-8">
          <.bullpen_card
            :for={team <- @teams}
            team={team}
            entries={@state["bullpens"][to_string(team.position)]}
            current={@state["pitchers"][to_string(team.position)]}
          />
        </div>
      </div>
    </.stage>
    """
  end

  attr :team, :any, required: true
  attr :entries, :list, required: true
  attr :current, :map, required: true

  defp bullpen_card(assigns) do
    ~H"""
    <section
      class="overlay-panel overlay-round-card overlay-in-up overflow-hidden"
      style={team_vars(@team)}
    >
      <div class="flex items-center gap-5 px-7 py-6" style={"background: #{wash(@team, 0.9)}"}>
        <.team_logo team={@team} size={74} />
        <h2 class="min-w-0 truncate text-[36px] font-black uppercase">{full_name(@team)}</h2>
      </div>
      <div class="min-h-[575px] bg-slate-950/92 p-5">
        <div
          :if={@current["name"] != ""}
          class="mb-4 rounded-xl border border-white/15 bg-white/8 px-5 py-4"
        >
          <p class="text-[12px] font-bold uppercase tracking-[0.18em] text-slate-400">
            In game · {@current["pitch_count"]} pitches
          </p>
          <p class="mt-1 text-[27px] font-black uppercase">{@current["name"]}</p>
        </div>
        <div
          :for={{pitcher, index} <- Enum.with_index(@entries)}
          id={"bullpen-pitcher-#{@team.position}-#{index}"}
          class="flex h-[66px] items-center justify-between border-b border-white/10 px-4"
        >
          <span class="text-[24px] font-black uppercase">{pitcher["name"]}</span>
          <span class="rounded-full bg-white/10 px-4 py-1.5 text-[13px] font-black uppercase tracking-[0.12em] text-amber-300">
            {if(pitcher["status"] == "", do: "Available", else: pitcher["status"])}
          </span>
        </div>
        <div :if={@entries == []} class="grid h-[360px] place-items-center text-[21px] text-slate-500">
          Bullpen not entered
        </div>
      </div>
    </section>
    """
  end
end
