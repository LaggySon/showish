defmodule ShowishWeb.ThemeController do
  @moduledoc """
  Theme files to download: a whole theme (fonts included, ready to import into
  another account or another Showish), a theme's own CSS, and the commented
  template people start their CSS from.
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

  @doc "A theme's own CSS on its own, to edit and upload again."
  def custom_css(conn, %{"id" => id}) do
    theme = Themes.get_theme!(conn.assigns.current_scope, id)

    send_download(conn, {:binary, theme.css},
      filename: Themes.css_filename(theme),
      content_type: "text/css",
      charset: "utf-8"
    )
  end

  @doc "The commented starting point for a theme's CSS."
  def template(conn, _params) do
    send_download(conn, {:binary, Themes.template()},
      filename: "showish-theme-template.css",
      content_type: "text/css",
      charset: "utf-8"
    )
  end
end
