defmodule ShowishWeb.HealthController do
  use ShowishWeb, :controller

  def show(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
