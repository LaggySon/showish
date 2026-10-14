defmodule ShowishWeb.ShowJSONControllerTest do
  use ShowishWeb.ConnCase, async: true

  import Showish.BroadcastsFixtures

  test "returns a snapshot of the show without a login", %{conn: conn} do
    show = show_fixture(%{title: "Autumn Cup", stage: "Grand Finals"})

    body =
      conn
      |> get(~p"/api/shows/#{show.slug}")
      |> json_response(200)

    assert body["data"]["title"] == "Autumn Cup"
    assert body["data"]["stage"] == "Grand Finals"
    assert body["data"]["sport"] == "esports"
    assert body["data"]["sport_state"] == %{}
    assert length(body["data"]["teams"]) == 2
  end

  test "404s for a slug that does not exist", %{conn: conn} do
    body =
      conn
      |> get(~p"/api/shows/nope")
      |> json_response(404)

    assert body["error"] =~ "nope"
  end
end
