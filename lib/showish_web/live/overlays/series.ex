defmodule ShowishWeb.Overlays.Series do
  @moduledoc """
  The between-games board: the whole series laid out, with completed games
  called and the current game highlighted.
  """

  use ShowishWeb.OverlayLive

  alias Showish.Broadcasts.Game
  alias Showish.Broadcasts.Show
  alias Showish.Text
  alias ShowishWeb.Status

  @impl Phoenix.LiveView
  def render(assigns) do
    assigns = assign(assigns, :games, Show.games(assigns.show))

    render_preset(assigns)
  end

  # Like the scorebug, this scene is laid out differently rather than merely
  # restyled under Tranquility and Laggish, so it dispatches on the preset.
  defp render_preset(%{show: %{preset: "tranquility"}} = assigns), do: tranquility(assigns)
  defp render_preset(%{show: %{preset: "laggish"}} = assigns), do: laggish(assigns)
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
              style={Text.present?(game.image_url) && "background-image: url('#{game.image_url}');"}
            >
              <div class="absolute inset-0 bg-gradient-to-t from-slate-950 via-slate-950/40 to-transparent">
              </div>
              <div class="absolute bottom-3 left-4 right-4">
                <div class="text-[13px] font-semibold uppercase tracking-[0.2em] text-slate-300/80">
                  {Game.label(game)}
                </div>
                <div class="truncate text-[24px] font-black uppercase leading-tight">
                  {Text.presence(game.name, "TBD")}
                </div>
              </div>
            </div>

            <div class="flex items-center justify-between px-4 py-3">
              <span class="text-[13px] font-semibold uppercase tracking-[0.16em] text-slate-400">
                {Text.presence(game.mode, "—")}
              </span>
              <span class="tabular text-[22px] font-black">
                <span class={game.winner == "a" && "text-emerald-400"}>{game.score_a}</span>
                <span class="px-1 text-slate-500">-</span>
                <span class={game.winner == "b" && "text-emerald-400"}>{game.score_b}</span>
              </span>
            </div>

            <div class="h-[6px] w-full" style={"background: #{winner_color(game, @show)};"}></div>
          </div>
        </div>

        <.empty_notice :if={@games == []} class="overlay-in-up" style="--overlay-delay: 160ms">
          No games have been added to this series yet.
        </.empty_notice>
      </div>
    </.stage>
    """
  end

  # The scorebug's bar, grown to full names, over a row of game cards. Each card
  # says where it stands in words (on air, played, upcoming) and in one rail:
  # the accent across the top of the game on air, the winner's colour along the
  # bottom of a game that has been played.
  defp laggish(assigns) do
    ~H"""
    <.stage preset={@show.preset} accent={@show.accent_color}>
      <div class="lg-series">
        <div class="lg-series-head">
          <.eyebrow color={@show.accent_color} class="overlay-in-fade">
            {header_label(@show)}
          </.eyebrow>

          <div class="lg-series-bar">
            <.lg_series_team team={@left} side="left" enter="overlay-in-right" />
            <div class="lg-series-score tabular overlay-in-pop" style={lg_score_style(@left)}>
              {score(@left)}
            </div>
            <div class="lg-series-score tabular overlay-in-pop" style={lg_score_style(@right)}>
              {score(@right)}
            </div>
            <.lg_series_team team={@right} side="right" enter="overlay-in-left" />
          </div>
        </div>

        <div class="lg-maps">
          <div
            :for={{game, index} <- Enum.with_index(@games)}
            class={[
              "lg-map overlay-in-up",
              index + 1 == @show.current_game && "lg-map-current",
              game.completed && "lg-map-done"
            ]}
            style={"--overlay-delay: #{160 + index * 70}ms; --winner: #{lg_winner_color(game, @show)};"}
          >
            <div class="lg-map-head">
              <span>{Game.label(game)}</span>
              <.lg_map_state show={@show} number={index + 1} game={game} />
            </div>

            <div
              class="lg-map-media"
              style={Text.present?(game.image_url) && "background-image: url('#{game.image_url}');"}
            >
            </div>

            <div class="lg-map-body">
              <div class="lg-map-name">{Text.presence(game.name, "TBD")}</div>
              <div class="lg-map-foot">
                <span class="lg-map-mode">{Text.presence(game.mode, "—")}</span>
                <span class="lg-map-score tabular">
                  <span class={game.winner == "a" && "lg-map-won"}>{game.score_a}</span>
                  <span class="lg-map-dash">–</span>
                  <span class={game.winner == "b" && "lg-map-won"}>{game.score_b}</span>
                </span>
              </div>
            </div>
          </div>
        </div>

        <.empty_notice :if={@games == []} class="overlay-in-up" style="--overlay-delay: 160ms">
          No games have been added to this series yet.
        </.empty_notice>
      </div>
    </.stage>
    """
  end

  attr :team, :any, required: true
  attr :side, :string, required: true
  attr :enter, :string, default: nil

  defp lg_series_team(assigns) do
    ~H"""
    <div
      class={["lg-series-team", @side == "right" && "lg-series-team-right", @enter]}
      style={"#{team_vars(@team)} --overlay-delay: 120ms;"}
    >
      <div class="lg-series-team-text">
        <div class="overlay-teamname lg-series-team-name">{full_name(@team)}</div>
        <div :if={@team && Text.present?(@team.record)} class="lg-series-team-record tabular">
          {@team.record}
        </div>
      </div>
      <.team_logo team={@team} size={72} />
    </div>
    """
  end

  # The control room's status words for a game, in the guide's state colours;
  # the accent stands in for "in progress" so the game on air matches its rail.
  attr :show, :any, required: true
  attr :number, :integer, required: true
  attr :game, :any, required: true

  defp lg_map_state(assigns) do
    {label, tone} = Status.game(assigns.show, assigns.number, assigns.game)
    assigns = assign(assigns, label: label, tone: tone)

    ~H"""
    <span class={["lg-map-state", "lg-map-state-#{@tone}"]}>{@label}</span>
    """
  end

  defp lg_score_style(team), do: "#{team_vars(team)} color: #{contrast(team)};"

  # A drawn game has no winner to colour, and an unplayed one has nothing at all.
  defp lg_winner_color(%{winner: winner} = game, show) when winner in ["a", "b"],
    do: winner_color(game, show)

  defp lg_winner_color(%{winner: "draw"}, _show), do: "var(--lg-muted)"
  defp lg_winner_color(_game, _show), do: "transparent"

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
              Text.blank?(game.image_url) && "tranq-map-bare",
              game.completed && "tranq-map-done"
            ]}
            style={"--overlay-delay: #{120 + index * 70}ms; --winner: #{winner_color(game, @show)};"}
          >
            <div class="tranq-map-media">
              <div class="tranq-map-mask">
                <div
                  :if={Text.present?(game.image_url)}
                  class="tranq-map-img"
                  style={"background-image: url('#{game.image_url}');"}
                >
                </div>
              </div>
              <div :if={game.completed} class="tranq-map-wash"></div>
            </div>

            <div :if={index + 1 == @show.current_game} class="tranq-map-banner">Up next</div>

            <div class="tranq-map-mode">{Text.presence(game.mode)}</div>
            <span class="tranq-map-name">{Text.presence(game.name, "TBD")}</span>
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
          :if={@team && Text.present?(@team.record)}
          class="text-[15px] font-semibold uppercase tracking-[0.18em] text-slate-400"
        >
          {@team.record}
        </div>
      </div>
    </div>
    """
  end

  # Everything the board is: the round, the week, and how long it runs for.
  defp header_label(show) do
    Text.join_present([show.stage, show.subtitle, "Best of #{show.best_of}"])
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
