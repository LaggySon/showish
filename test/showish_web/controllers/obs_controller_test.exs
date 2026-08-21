defmodule ShowishWeb.ObsControllerTest do
  use ShowishWeb.ConnCase, async: true

  import Showish.AccountsFixtures
  import Showish.BroadcastsFixtures

  alias ShowishWeb.Scenes

  describe "when nobody is logged in" do
    test "the download sends you to the login page", %{conn: conn} do
      show = show_fixture()

      conn = get(conn, ~p"/shows/#{show.slug}/obs.json")

      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "download" do
    setup :register_and_log_in_user

    test "returns a scene collection named after the show", %{conn: conn, scope: scope} do
      show = show_fixture(scope, %{slug: "autumn-cup", title: "Autumn Cup"})

      conn = get(conn, ~p"/shows/#{show.slug}/obs.json")

      assert response_content_type(conn, :json) =~ "charset=utf-8"

      assert get_resp_header(conn, "content-disposition") == [
               ~s(attachment; filename="showish-autumn-cup-obs.json")
             ]

      collection = Jason.decode!(response(conn, 200))

      assert collection["name"] =~ "Autumn Cup"

      assert Enum.map(collection["scene_order"], & &1["name"]) ==
               Enum.map(Scenes.all(), & &1.name)
    end

    test "the browser sources point at this show's overlays", %{conn: conn, scope: scope} do
      show = show_fixture(scope, %{slug: "autumn-cup"})

      conn = get(conn, ~p"/shows/#{show.slug}/obs.json")

      urls =
        conn
        |> response(200)
        |> Jason.decode!()
        |> Map.fetch!("sources")
        |> Enum.filter(&(&1["id"] == "browser_source"))
        |> Enum.map(& &1["settings"]["url"])

      assert urls == Enum.map(Scenes.all(), &Scenes.url("autumn-cup", &1.key))
    end

    test "will not hand over someone else's show", %{conn: conn} do
      theirs = show_fixture(user_scope_fixture())

      assert_error_sent :not_found, fn ->
        get(conn, ~p"/shows/#{theirs.slug}/obs.json")
      end
    end
  end
end
