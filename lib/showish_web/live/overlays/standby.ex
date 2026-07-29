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
    <.stage>
      <div class="absolute inset-0 bg-slate-950/85"></div>

      <div class="absolute inset-0 flex flex-col items-center justify-center gap-12 overlay-rise">
        <div class="flex flex-col items-center gap-4">
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
          class="tabular text-[120px] font-black leading-none"
          style={"color: #{@show.accent_color}"}
        >
          <.countdown target={@show.starts_at} now={@now} />
        </div>

        <div class="flex items-center gap-16">
          <.matchup_side team={@left} />
          <span class="text-[32px] font-black uppercase tracking-[0.3em] text-slate-500">vs</span>
          <.matchup_side team={@right} />
        </div>
      </div>

      <div
        :if={@show.ticker not in [nil, ""]}
        class="absolute inset-x-0 bottom-0 overflow-hidden border-t border-white/10 bg-slate-950/90 py-5"
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

  @doc false
  def matchup_side(assigns) do
    ~H"""
    <div class="flex w-[420px] flex-col items-center gap-5">
      <.team_logo team={@team} size={140} class="rounded-xl" />
      <div class="flex flex-col items-center gap-2">
        <div class="text-center text-[38px] font-black uppercase leading-tight">
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
