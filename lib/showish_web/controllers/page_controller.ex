defmodule ShowishWeb.PageController do
  use ShowishWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
