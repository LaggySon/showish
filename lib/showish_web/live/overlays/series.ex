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

    ~H"""
    <.stage>
      <div class="absolute inset-x-0 top-[120px] flex flex-col items-center gap-10 overlay-rise">
        <div class="flex flex-col items-center gap-3">
          <.eyebrow color={@show.accent_color}>
            {header_label(@show)}
          </.eyebrow>
          <div class="flex items-center gap-10">
            <.team_column team={@left} align="right" />
            <div class="tabular flex items-center gap-6 text-[76px] font-black leading-none">
              <span style={"color: #{primary(@left)}"}>{score(@left)}</span>
              <span class="text-[40px] text-slate-500">–</span>
              <span style={"color: #{primary(@right)}"}>{score(@right)}</span>
            </div>
            <.team_column team={@right} align="left" />
          </div>
        </div>

        <div class="flex flex-wrap items-stretch justify-center gap-6 px-24">
          <div
            :for={{game, index} <- Enum.with_index(@games)}
            class="overlay-panel flex w-[288px] flex-col overflow-hidden rounded-lg"
            style={
              index + 1 == @show.current_game &&
                "box-shadow: 0 0 0 3px #{@show.accent_color}, 0 24px 60px rgba(0, 0, 0, 0.55);"
            }
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

        <div :if={@games == []} class="overlay-panel rounded-lg px-12 py-8 text-[22px] text-slate-300">
          No games have been added to this series yet.
        </div>
      </div>
    </.stage>
    """
  end

  attr :team, :any, required: true
  attr :align, :string, required: true

  @doc false
  def team_column(assigns) do
    ~H"""
    <div class={["flex w-[380px] items-center gap-5", @align == "right" && "flex-row-reverse"]}>
      <.team_logo team={@team} size={96} />
      <div class={["flex min-w-0 flex-col gap-1", @align == "right" && "items-end"]}>
        <div class="truncate text-[36px] font-black uppercase leading-none">
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

  defp winner_color(%{winner: "a"}, show), do: team_color(show, 1)
  defp winner_color(%{winner: "b"}, show), do: team_color(show, 2)
  defp winner_color(%{winner: "draw"}, _show), do: "#64748b"
  defp winner_color(_game, _show), do: "rgba(148, 163, 184, 0.18)"

  defp team_color(show, position), do: show |> Show.team(position) |> primary()
end
