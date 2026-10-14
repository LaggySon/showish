defmodule ShowishWeb.Overlays.Ticker do
  @moduledoc """
  A bottom bar: a compact score on the left and the operator's ticker copy
  scrolling beside it. Useful as a second browser source that stays up while the
  main scorebug is hidden.
  """

  use ShowishWeb.OverlayLive

  alias Showish.Colors
  alias Showish.Text

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.stage preset={@show.preset} accent={@show.accent_color}>
      <div class="overlay-ticker absolute inset-x-0 bottom-0 flex h-[84px] items-stretch overlay-in-up">
        <div
          class="overlay-in-left flex items-center gap-4 px-8"
          style={"background: #{@show.accent_color}; color: #{Colors.contrast_text(@show.accent_color)}; --overlay-delay: 260ms;"}
        >
          <span class="text-[20px] font-black uppercase tracking-[0.16em]">
            {headline(@show)}
          </span>
        </div>

        <div class="flex items-center gap-4 bg-slate-950/95 px-8">
          <.compact_team team={@left} />
          <span class="tabular text-[30px] font-black" style={"color: #{primary(@left)}"}>
            {score(@left)}
          </span>
          <span class="text-[18px] text-slate-600">–</span>
          <span class="tabular text-[30px] font-black" style={"color: #{primary(@right)}"}>
            {score(@right)}
          </span>
          <.compact_team team={@right} />
        </div>

        <div class="overlay-ticker-copy flex flex-1 items-center overflow-hidden bg-slate-950/90">
          <.marquee
            :if={Text.present?(@show.ticker)}
            text={@show.ticker}
            spacing="px-16"
            class="text-[24px] font-medium uppercase tracking-[0.18em] text-slate-200"
          />
        </div>
      </div>
    </.stage>
    """
  end

  attr :team, :any, required: true

  @doc false
  def compact_team(assigns) do
    ~H"""
    <div class="flex items-center gap-3" style={team_vars(@team)}>
      <.team_logo team={@team} size={40} />
      <span class="overlay-teamname text-[22px] font-black uppercase leading-none">
        {short_name(@team)}
      </span>
    </div>
    """
  end

  # The block on the left names the broadcast: the stage if there is one, the
  # show's title if not, and "Live" for a show that has neither.
  defp headline(show), do: Text.first_present([show.stage, show.title], "Live")
end
