defmodule ShowishWeb.Overlays.Ticker do
  @moduledoc """
  A bottom bar: a compact score on the left and the operator's ticker copy
  scrolling beside it. Useful as a second browser source that stays up while the
  main scorebug is hidden.
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
      <div class="overlay-ticker absolute inset-x-0 bottom-0 flex h-[84px] items-stretch overlay-in-up">
        <div
          class="overlay-in-left flex items-center gap-4 px-8"
          style={"background: #{@show.accent_color}; color: #{Showish.Colors.contrast_text(@show.accent_color)}; --overlay-delay: 260ms;"}
        >
          <span class="text-[20px] font-black uppercase tracking-[0.16em]">
            {ticker_label(@show)}
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
          <div
            :if={@show.ticker not in [nil, ""]}
            class="overlay-marquee text-[24px] font-medium uppercase tracking-[0.18em] text-slate-200"
          >
            <span class="px-16">{@show.ticker}</span>
            <span class="px-16">{@show.ticker}</span>
          </div>
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

  defp ticker_label(show) do
    [show.stage, show.title]
    |> Enum.map(&String.trim(to_string(&1 || "")))
    |> Enum.find("Live", &(&1 != ""))
  end
end
