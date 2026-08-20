defmodule ShowishWeb.ShowJSONController do
  @moduledoc """
  A read-only snapshot of a show.

  The LiveView overlays never need this — they are pushed to. It exists for
  everything else: a static overlay, a bot, a scoreboard built on another stack.
  """

  use ShowishWeb, :controller

  alias Showish.Broadcasts

  def show(conn, %{"slug" => slug}) do
    case Broadcasts.get_public_show_by_slug(slug) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "no show with slug #{slug}"})

      show ->
        json(conn, %{data: payload(show)})
    end
  end

  defp payload(show) do
    %{
      slug: show.slug,
      title: show.title,
      subtitle: show.subtitle,
      stage: show.stage,
      starts_at: show.starts_at,
      ticker: show.ticker,
      accent_color: show.accent_color,
      sport: show.sport,
      sport_state: show.sport_state,
      best_of: show.best_of,
      current_game: show.current_game,
      show_sides: show.show_sides,
      swap_sides: show.swap_sides,
      break_message: show.break_message,
      status: %{
        left: %{text: show.status_left, visible: show.show_status_left},
        center: %{text: show.status_center, visible: show.show_status_center},
        right: %{text: show.status_right, visible: show.show_status_right}
      },
      teams: Enum.map(List.wrap(show.teams), &team_payload/1),
      games: Enum.map(List.wrap(show.games), &game_payload/1),
      talents: Enum.map(List.wrap(show.talents), &talent_payload/1),
      updated_at: show.updated_at
    }
  end

  defp team_payload(team) do
    %{
      position: team.position,
      name: team.name,
      short_name: team.short_name,
      code: team.code,
      logo_url: team.logo_url,
      record: team.record,
      score: team.score,
      primary_color: team.primary_color,
      secondary_color: team.secondary_color,
      side: team.side
    }
  end

  defp game_payload(game) do
    %{
      position: game.position,
      name: game.name,
      mode: game.mode,
      image_url: game.image_url,
      score_a: game.score_a,
      score_b: game.score_b,
      winner: game.winner,
      completed: game.completed,
      info: game.info
    }
  end

  defp talent_payload(talent) do
    %{
      position: talent.position,
      role: talent.role,
      name: talent.name,
      pronouns: talent.pronouns,
      social: talent.social,
      avatar_url: talent.avatar_url
    }
  end
end
