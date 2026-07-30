defmodule ShowishWeb.Overlays.Break do
  @moduledoc """
  The interval card: a message, a clock back to air, and the series score so
  viewers who join during the break know where things stand.
  """

  use ShowishWeb.OverlayLive

  alias Showish.Broadcasts.Show

  @impl Phoenix.LiveView
  def render(assigns) do
    {left, right} = Show.sides(assigns.show)

    assigns =
      assigns
      |> assign(:left, left)
      |> assign(:right, right)

    ~H"""
    <.stage preset={@show.preset} accent={@show.accent_color}>
      <div class="absolute inset-0 bg-slate-950/88 overlay-in-fade"></div>

      <div class="absolute inset-0 flex flex-col items-center justify-center gap-14">
        <div class="flex flex-col items-center gap-5 overlay-in-down" style="--overlay-delay: 120ms">
          <.eyebrow color={@show.accent_color}>Intermission</.eyebrow>
          <h1 class="max-w-[1400px] text-center text-[64px] font-black uppercase leading-[1.05]">
            {display(@show.break_message, "We'll be right back")}
          </h1>
        </div>

        <div
          :if={@show.starts_at}
          class="flex flex-col items-center gap-2 overlay-in-pop"
          style="--overlay-delay: 240ms"
        >
          <span class="text-[16px] font-semibold uppercase tracking-[0.28em] text-slate-400">
            Back in
          </span>
          <div class="tabular overlay-clock text-[104px] font-black leading-none">
            <.countdown target={@show.starts_at} now={@now} />
          </div>
        </div>

        <div
          class="overlay-panel overlay-round-hero overlay-in-up flex items-center gap-12 px-16 py-8"
          style="--overlay-delay: 360ms"
        >
          <.break_side team={@left} align="right" />
          <div class="tabular flex items-center gap-6 text-[64px] font-black leading-none">
            <span class="overlay-scoreplate" style={"--score-color: #{primary(@left)}"}>{score(@left)}</span>
            <span class="overlay-vs text-[32px] text-slate-500">–</span>
            <span class="overlay-scoreplate" style={"--score-color: #{primary(@right)}"}>{score(@right)}</span>
          </div>
          <.break_side team={@right} align="left" />
        </div>
      </div>

      <div
        :if={@show.ticker not in [nil, ""]}
        class="absolute inset-x-0 bottom-0 overflow-hidden border-t border-white/10 bg-slate-950/90 py-5 overlay-in-up"
        style="--overlay-delay: 480ms"
      >
        <div class="overlay-marquee text-[22px] font-medium uppercase tracking-[0.2em] text-slate-300">
          <span class="px-12">{@show.ticker}</span>
          <span class="px-12">{@show.ticker}</span>
        </div>
      </div>
    </.stage>
    """
  end

  attr :team, :any, required: true
  attr :align, :string, required: true

  @doc false
  def break_side(assigns) do
    ~H"""
    <div
      class={["flex w-[300px] items-center gap-5", @align == "right" && "flex-row-reverse"]}
      style={team_vars(@team)}
    >
      <.team_logo team={@team} size={80} />
      <div class="overlay-teamname truncate text-[30px] font-black uppercase leading-none">
        {full_name(@team)}
      </div>
    </div>
    """
  end

  defp display(value, fallback) do
    case String.trim(to_string(value || "")) do
      "" -> fallback
      text -> text
    end
  end
end
