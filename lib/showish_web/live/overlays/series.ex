defmodule ShowishWeb.Overlays.Series do
  @moduledoc """
  The between-games board: the whole series laid out, with completed games
  called and the current game highlighted.
  """

  use ShowishWeb.OverlayLive

  alias Showish.Broadcasts.Game
  alias Showish.Broadcasts.Show

  @impl Phoenix.LiveView
  def render(assigns) do
    {left, right} = Show.sides(assigns.show)

    assigns =
      assigns
      |> assign(:left, left)
      |> assign(:right, right)
      |> assign(:games, List.wrap(assigns.show.games))

    render_preset(assigns)
  end

  # Like the scorebug, this scene is laid out differently rather than merely
  # restyled under Tranquility, so it dispatches on the preset.
  defp render_preset(%{show: %{preset: "tranquility"}} = assigns), do: tranquility(assigns)
  defp render_preset(assigns), do: broadcast(assigns)

  defp broadcast(assigns) do
    ~H"""
    <.stage preset={@show.preset} accent={@show.accent_color}>
      <div class="absolute inset-x-0 top-[120px] flex flex-col items-center gap-10">
        <div class="flex flex-col items-center gap-3 overlay-in-down">
          <.eyebrow color={@show.accent_color}>
            {header_label(@show)}
          </.eyebrow>
          <div class="flex items-center gap-10">
            <.team_column team={@left} align="right" enter="overlay-in-left" />
            <div class="tabular overlay-in-pop flex items-center gap-6 text-[76px] font-black leading-none">
              <span class="overlay-scoreplate" style={"--score-color: #{primary(@left)}"}>
                {score(@left)}
              </span>
              <span class="overlay-vs text-[40px] text-slate-500">–</span>
              <span class="overlay-scoreplate" style={"--score-color: #{primary(@right)}"}>
                {score(@right)}
              </span>
            </div>
            <.team_column team={@right} align="left" enter="overlay-in-right" />
          </div>
        </div>

        <div class="flex flex-wrap items-stretch justify-center gap-6 px-24">
          <div
            :for={{game, index} <- Enum.with_index(@games)}
            class="overlay-panel overlay-round-card overlay-in-up flex w-[288px] flex-col overflow-hidden"
            style={"--overlay-delay: #{160 + index * 70}ms; #{current_outline(index, @show)}"}
          >
            <div
              class="relative h-[132px] bg-slate-800 bg-cover bg-center"
              style={game.image_url not in [nil, ""] && "background-image: url('#{game.image_url}');"}
            >
              <div class="absolute inset-0 bg-gradient-to-t from-slate-950 via-slate-950/40 to-transparent">
              </div>
              <div class="absolute bottom-3 left-4 right-4">
                <div class="text-[13px] font-semibold uppercase tracking-[0.2em] text-slate-300/80">
                  {Game.label(game)}
                </div>
                <div class="truncate text-[24px] font-black uppercase leading-tight">
                  {display(game.name, "TBD")}
                </div>
              </div>
            </div>

            <div class="flex items-center justify-between px-4 py-3">
              <span class="text-[13px] font-semibold uppercase tracking-[0.16em] text-slate-400">
                {display(game.mode, "—")}
              </span>
              <span class="tabular text-[22px] font-black">
                <span class={game.winner == "a" && "text-emerald-400"}>{game.score_a}</span>
                <span class="px-1 text-slate-500">-</span>
                <span class={game.winner == "b" && "text-emerald-400"}>{game.score_b}</span>
              </span>
            </div>

            <div
              class="h-[6px] w-full"
              style={"background: #{winner_color(game, @show)};"}
            >
            </div>
          </div>
        </div>

        <div
          :if={@games == []}
          class="overlay-panel overlay-round-card overlay-in-up px-12 py-8 text-[22px] text-slate-300"
          style="--overlay-delay: 160ms"
        >
          No games have been added to this series yet.
        </div>
      </div>
    </.stage>
    """
  end

  # The map board: a team column pinned to each edge and the series stacked down
  # the middle, with the game on air grown to fill whatever room the others leave
  # and the finished ones desaturated behind their winner's colour.
  defp tranquility(assigns) do
    ~H"""
    <.stage preset={@show.preset} accent={@show.accent_color}>
      <div class="tranq-mapinfo">
        <.tranq_map_team team={@left} enter="overlay-in-left" />

        <div class="tranq-mapbox">
          <div
            :for={{game, index} <- Enum.with_index(@games)}
            class={[
              "tranq-map overlay-in-up",
              index + 1 == @show.current_game && "tranq-map-active",
              game.image_url in [nil, ""] && "tranq-map-bare",
              game.completed && "tranq-map-done"
            ]}
            style={"--overlay-delay: #{120 + index * 70}ms; --winner: #{winner_color(game, @show)};"}
          >
            <div class="tranq-map-media">
              <div class="tranq-map-mask">
                <div
                  :if={game.image_url not in [nil, ""]}
                  class="tranq-map-img"
                  style={"background-image: url('#{game.image_url}');"}
                >
                </div>
              </div>
              <div :if={game.completed} class="tranq-map-wash"></div>
            </div>

            <div :if={index + 1 == @show.current_game} class="tranq-map-banner">Up next</div>

            <div class="tranq-map-mode">{display(game.mode, "")}</div>
            <span class="tranq-map-name">{display(game.name, "TBD")}</span>
            <div class="tranq-map-winner">{winner_mark(game, @show, index)}</div>
          </div>

          <div :if={@games == []} class="tranq-map-empty overlay-in-up">
            No games have been added to this series yet.
          </div>
        </div>

        <.tranq_map_team team={@right} enter="overlay-in-right" />
      </div>
    </.stage>
    """
  end

  attr :team, :any, required: true
  attr :enter, :string, default: nil

  defp tranq_map_team(assigns) do
    ~H"""
    <div class={["tranq-mapteam", @enter]} style={team_vars(@team)}>
      <div class="tranq-maplogo">
        <img :if={logo?(@team)} src={@team.logo_url} alt={full_name(@team)} />
        <span :if={!logo?(@team)} class="tranq-maplogo-code">{initials(@team)}</span>
      </div>
      <div class="tranq-mapcode">{initials(@team)}</div>
      <div class="tranq-mapscore tabular">{score(@team)}</div>
    </div>
    """
  end

  # The winner column reads as the winning team's mark once a game is called, an
  # ellipsis on the game being played, and a dash on anything still to come.
  defp winner_mark(%{winner: "a"}, show, _index), do: show |> Show.team(1) |> initials()
  defp winner_mark(%{winner: "b"}, show, _index), do: show |> Show.team(2) |> initials()
  defp winner_mark(%{winner: "draw"}, _show, _index), do: "–"

  defp winner_mark(_game, show, index) do
    if index + 1 == show.current_game, do: "…", else: "–"
  end

  attr :team, :any, required: true
  attr :align, :string, required: true
  attr :enter, :string, default: nil

  @doc false
  def team_column(assigns) do
    ~H"""
    <div
      class={["flex w-[380px] items-center gap-5", @enter, @align == "right" && "flex-row-reverse"]}
      style={team_vars(@team)}
    >
      <.team_logo team={@team} size={96} />
      <div class={["flex min-w-0 flex-col gap-1", @align == "right" && "items-end"]}>
        <div class="overlay-teamname truncate text-[36px] font-black uppercase leading-none">
          {full_name(@team)}
        </div>
        <div
          :if={@team && @team.record not in [nil, ""]}
          class="text-[15px] font-semibold uppercase tracking-[0.18em] text-slate-400"
        >
          {@team.record}
        </div>
      </div>
    </div>
    """
  end

  defp header_label(show) do
    [show.stage, show.subtitle, "Best of #{show.best_of}"]
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

  # The game currently on air keeps its accent ring alongside its entrance delay.
  defp current_outline(index, show) do
    if index + 1 == show.current_game do
      "box-shadow: 0 0 0 3px #{show.accent_color}, 0 24px 60px rgba(0, 0, 0, 0.55);"
    else
      ""
    end
  end

  defp winner_color(%{winner: "a"}, show), do: team_color(show, 1)
  defp winner_color(%{winner: "b"}, show), do: team_color(show, 2)
  defp winner_color(%{winner: "draw"}, _show), do: "#64748b"
  defp winner_color(_game, _show), do: "rgba(148, 163, 184, 0.18)"

  defp team_color(show, position), do: show |> Show.team(position) |> primary()
end
