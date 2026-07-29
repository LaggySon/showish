defmodule ShowishWeb.Overlays.Scorebug do
  @moduledoc """
  The in-game bar: both teams, the series score, and the line of copy that says
  what is currently being played.

  This is the scene that spends the whole match on screen, so it is anchored to
  the top of the canvas and everything below y=140 is left clear for gameplay.
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
      |> assign(:center_line, Show.center_line(assigns.show))

    ~H"""
    <.stage>
      <div class="absolute left-1/2 top-0 -translate-x-1/2 overlay-rise">
        <div class="flex h-[92px] items-stretch">
          <.team_plate team={@left} align="right" show_sides={@show.show_sides} />
          <.score_box team={@left} />

          <div class="overlay-panel flex w-[210px] flex-col items-center justify-center gap-1.5 border-x-0">
            <.eyebrow color={@show.accent_color}>
              {stage_label(@show)}
            </.eyebrow>
            <div class="text-[26px] font-black uppercase leading-none tracking-tight">
              {game_label(@show)}
            </div>
          </div>

          <.score_box team={@right} />
          <.team_plate team={@right} align="left" show_sides={@show.show_sides} />
        </div>

        <div :if={@center_line != ""} class="flex justify-center">
          <div class="overlay-panel overlay-shear -mt-px flex h-[42px] min-w-[420px] max-w-[820px] items-center justify-center px-10">
            <span class="truncate text-[17px] font-medium uppercase tracking-[0.18em] text-slate-100/90">
              {@center_line}
            </span>
          </div>
        </div>
      </div>

      <div :if={@show.show_status_left and @show.status_left != ""} class="absolute left-16 top-8">
        <.status_pill accent={@show.accent_color}>{@show.status_left}</.status_pill>
      </div>

      <div :if={@show.show_status_right and @show.status_right != ""} class="absolute right-16 top-8">
        <.status_pill accent={@show.accent_color}>{@show.status_right}</.status_pill>
      </div>
    </.stage>
    """
  end

  attr :team, :any, required: true
  attr :align, :string, required: true
  attr :show_sides, :boolean, default: false

  @doc false
  def team_plate(assigns) do
    ~H"""
    <div
      class={[
        "overlay-panel flex w-[440px] items-center gap-5 px-8",
        @align == "right" && "justify-end overlay-shear-left",
        @align == "left" && "flex-row-reverse justify-end overlay-shear-right"
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
            :if={@show_sides and @team && @team.side not in [nil, ""]}
            class="rounded-sm px-2 py-0.5 text-[12px] font-bold uppercase tracking-[0.14em]"
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

  @doc false
  def score_box(assigns) do
    ~H"""
    <div
      class="tabular flex w-[104px] items-center justify-center text-[54px] font-black leading-none"
      style={"background: #{primary(@team)}; color: #{contrast(@team)};"}
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
      class="overlay-panel flex h-[46px] items-center rounded-sm px-6 text-[16px] font-semibold uppercase tracking-[0.18em]"
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
