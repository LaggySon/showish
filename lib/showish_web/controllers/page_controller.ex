defmodule ShowishWeb.PageController do
  use ShowishWeb, :controller

  @options [
    %{text: "data", link: "/"},
    %{text: "starting", link: "/"},
    %{text: "game", link: "/"},
    %{text: "casters", link: "/"}
  ]

  def home(conn, _params) do
    conn
    |> assign(:options, @options)
    |> render()
  end
end
