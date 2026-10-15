defmodule ShowishWeb.ThemeCSSController do
  @moduledoc """
  Serves a theme's stylesheet to the overlays drawn in it.

  Public, like the overlays themselves: a browser source cannot log in. The URL
  carries the theme's version, so a stylesheet is cached for good and an edit
  reaches every overlay as a new URL rather than a stale cache.
  """

  use ShowishWeb, :controller

  alias Showish.Themes
  alias Showish.Themes.Theme

  def show(conn, %{"id" => id, "version" => version}) do
    with {id, ""} <- Integer.parse(id),
         %Theme{} = theme <- Themes.get_theme(id) do
      # An old version's URL still answers, with the current theme, but is not
      # cached under that old URL.
      cache =
        if version == Themes.version(theme),
          do: "public, max-age=31536000, immutable",
          else: "no-cache"

      conn
      |> put_resp_content_type("text/css")
      |> put_resp_header("cache-control", cache)
      |> put_resp_header("x-content-type-options", "nosniff")
      |> send_resp(200, Themes.stylesheet(theme))
    else
      _ -> send_resp(conn, 404, "")
    end
  end
end
