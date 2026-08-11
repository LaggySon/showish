defmodule ShowishWeb.Overlays.Standby do
  @moduledoc """
  The pre-show card: what is about to happen, who is playing, and how long the
  audience has to wait. Full frame, so it is safe to cut to before the feed is
  live.
  """

  use ShowishWeb.OverlayLive

  alias Showish.Text

  @impl Phoenix.LiveView
  def render(assigns) do
    assigns = assign(assigns, :subtitle, subtitle(assigns.show))

    ~H"""
    <.stage preset={@show.preset} accent={@show.accent_color}>
      <div class="absolute inset-0 overlay-in-fade"></div>

      <div class="absolute inset-0 flex flex-col items-center justify-center gap-12">
        <div class="flex flex-col items-center gap-4 overlay-in-down" style="--overlay-delay: 120ms">
          <.eyebrow color={@show.accent_color}>Starting soon</.eyebrow>
          <h1 class="text-[72px] font-black uppercase leading-none tracking-tight">
            {Text.presence(@show.title, "Showish")}
          </h1>
          <p :if={@subtitle != ""} class="text-[26px] font-medium text-slate-300">
            {@subtitle}
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

      <.ticker_bar text={@show.ticker} delay={500} />
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
          :if={@team && Text.present?(@team.record)}
          class="text-[16px] font-semibold uppercase tracking-[0.2em] text-slate-400"
        >
          {@team.record}
        </div>
      </div>
    </div>
    """
  end

  # The two lines of copy under the title, as one line: whichever of them the
  # operator filled in, and no stray separator for the one they did not.
  defp subtitle(show), do: Text.join_present([show.stage, show.subtitle])
end
