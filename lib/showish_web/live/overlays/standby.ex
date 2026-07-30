defmodule ShowishWeb.Overlays.Standby do
  @moduledoc """
  The pre-show card: what is about to happen, who is playing, and how long the
  audience has to wait. Full frame, so it is safe to cut to before the feed is
  live.
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
      <div class="absolute inset-0 overlay-in-fade"></div>

      <div class="absolute inset-0 flex flex-col items-center justify-center gap-12">
        <div class="flex flex-col items-center gap-4 overlay-in-down" style="--overlay-delay: 120ms">
          <.eyebrow color={@show.accent_color}>Starting soon</.eyebrow>
          <h1 class="text-[72px] font-black uppercase leading-none tracking-tight">
            {display(@show.title, "Showish")}
          </h1>
          <p :if={subtitle(@show) != ""} class="text-[26px] font-medium text-slate-300">
            {subtitle(@show)}
          </p>
        </div>

        <div
          :if={@show.starts_at}
          class="tabular overlay-clock overlay-in-pop text-[120px] font-black leading-none"
          style="--overlay-delay: 240ms"
        >
          <.countdown target={@show.starts_at} now={@now} />
        </div>

        <div class="flex items-center gap-16">
          <.matchup_side team={@left} enter="overlay-in-left" delay={320} />
          <span
            class="overlay-vs text-[32px] font-black uppercase tracking-[0.3em] text-slate-500 overlay-in-fade"
            style="--overlay-delay: 440ms"
          >
            vs
          </span>
          <.matchup_side team={@right} enter="overlay-in-right" delay={320} />
        </div>
      </div>

      <div
        :if={@show.ticker not in [nil, ""]}
        class="absolute inset-x-0 bottom-0 overflow-hidden border-t border-white/10 bg-slate-950/90 py-5 overlay-in-up"
        style="--overlay-delay: 500ms"
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
  attr :enter, :string, default: nil
  attr :delay, :integer, default: 0

  @doc false
  def matchup_side(assigns) do
    ~H"""
    <div
      class={["flex w-[420px] flex-col items-center gap-5", @enter]}
      style={"--overlay-delay: #{@delay}ms; #{team_vars(@team)}"}
    >
      <.team_logo team={@team} size={140} radius="hero" />
      <div class="flex flex-col items-center gap-2">
        <div class="overlay-teamname text-center text-[38px] font-black uppercase leading-tight">
          {full_name(@team)}
        </div>
        <div
          :if={@team && @team.record not in [nil, ""]}
          class="text-[16px] font-semibold uppercase tracking-[0.2em] text-slate-400"
        >
          {@team.record}
        </div>
      </div>
    </div>
    """
  end

  defp subtitle(show) do
    [show.stage, show.subtitle]
    |> Enum.map(&String.trim(to_string(&1 || "")))
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" · ")
  end

  defp display(value, fallback) do
    case String.trim(to_string(value || "")) do
      "" -> fallback
      text -> text
    end
  end
end
