defmodule ShowishWeb.ThemeController do
  @moduledoc """
  Hands a theme back as a file: everything in it, fonts included, ready to be
  imported into another account or another Showish.
  """

  use ShowishWeb, :controller

  alias Showish.Themes

  def download(conn, %{"id" => id}) do
    theme = Themes.get_theme!(conn.assigns.current_scope, id)

    send_download(conn, {:binary, Themes.export(theme)},
      filename: Themes.export_filename(theme),
      content_type: "application/json",
      charset: "utf-8"
    )
  end
end
