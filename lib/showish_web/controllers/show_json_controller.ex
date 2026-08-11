defmodule ShowishWeb.ShowJSONController do
  @moduledoc """
  A read-only snapshot of a show.

  The LiveView overlays never need this — they are pushed to. It exists for
  everything else: a static overlay, a bot, a scoreboard built on another stack.

  The field lists below are the published contract. They are written out rather
  than derived from the schemas so that adding a column to a table does not
  quietly start publishing it, and so that removing one from here is a decision
  somebody made on purpose.
  """

  use ShowishWeb, :controller

  alias Showish.Broadcasts
  alias Showish.Broadcasts.Show

  @show_fields ~w(slug title subtitle stage starts_at ticker accent_color best_of
                  current_game show_sides swap_sides break_message updated_at)a

  @team_fields ~w(position name short_name code logo_url record score primary_color
                  secondary_color side)a

  @game_fields ~w(position name mode image_url score_a score_b winner completed info)a

  # Deliberately without `on_cam`: which of the crew is pointed at a camera is a
  # control-room detail, and no use to anything reading this.
  @talent_fields ~w(position role name pronouns social avatar_url)a

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
    show
    |> Map.take(@show_fields)
    |> Map.merge(%{
      # The three status slots are flattened in the schema — text beside a
      # visibility flag — and paired back up here, where a caller reading one
      # cannot miss the other.
      status: %{
        left: %{text: show.status_left, visible: show.show_status_left},
        center: %{text: show.status_center, visible: show.show_status_center},
        right: %{text: show.status_right, visible: show.show_status_right}
      },
      teams: Enum.map(Show.teams(show), &Map.take(&1, @team_fields)),
      games: Enum.map(Show.games(show), &Map.take(&1, @game_fields)),
      talents: Enum.map(Show.talents(show), &Map.take(&1, @talent_fields))
    })
  end
end
