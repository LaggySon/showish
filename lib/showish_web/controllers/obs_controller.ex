defmodule ShowishWeb.ObsController do
  @moduledoc """
  Hands a show's overlays back as a file OBS can import.

  A download rather than a page, but it belongs to the same owner-only half of
  the app as the control room: the collection is built from a show only its
  owner can read.
  """

  use ShowishWeb, :controller

  alias Showish.Broadcasts
  alias ShowishWeb.ObsSceneCollection

  def download(conn, %{"slug" => slug}) do
    show = Broadcasts.get_show_by_slug!(conn.assigns.current_scope, slug)

    collection = show |> ObsSceneCollection.build() |> Jason.encode!(pretty: true)

    send_download(conn, {:binary, collection},
      filename: ObsSceneCollection.filename(show),
      content_type: "application/json",
      charset: "utf-8"
    )
  end
end
