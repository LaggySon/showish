defmodule ShowishWeb.ObsSceneCollectionTest do
  use ExUnit.Case, async: true

  alias Showish.Broadcasts.Show
  alias ShowishWeb.ObsSceneCollection
  alias ShowishWeb.Scenes

  # Nothing here reaches the database: a collection is built out of a show's
  # slug and title and the scene catalogue, and that is all.
  defp show_fixture(attrs \\ %{}) do
    struct!(%Show{slug: "autumn-cup", title: "Autumn Cup"}, attrs)
  end

  defp sources_of_kind(collection, id) do
    Enum.filter(collection["sources"], &(&1["id"] == id))
  end

  describe "build/1" do
    test "gives every scene in the catalogue its own OBS scene, in order" do
      show = show_fixture()

      collection = ObsSceneCollection.build(show)

      assert Enum.map(collection["scene_order"], & &1["name"]) ==
               Enum.map(Scenes.all(), & &1.name)

      assert collection["current_scene"] == hd(Scenes.all()).name
      assert collection["current_program_scene"] == collection["current_scene"]
    end

    test "points one 1920 x 1080 browser source at each overlay URL" do
      show = show_fixture()

      settings =
        show
        |> ObsSceneCollection.build()
        |> sources_of_kind("browser_source")
        |> Enum.map(& &1["settings"])

      assert Enum.map(settings, & &1["url"]) ==
               Enum.map(Scenes.all(), &Scenes.url("autumn-cup", &1.key))

      assert Enum.all?(settings, &(&1["width"] == 1920 and &1["height"] == 1080))
    end

    test "each scene holds exactly its own browser source" do
      show = show_fixture()

      collection = ObsSceneCollection.build(show)
      browsers = sources_of_kind(collection, "browser_source")

      for {scene, browser} <- Enum.zip(sources_of_kind(collection, "scene"), browsers) do
        assert [item] = scene["settings"]["items"]
        assert item["name"] == browser["name"]
        assert item["source_uuid"] == browser["uuid"]
        assert item["visible"]
      end
    end

    test "names and identifiers are unique across the collection" do
      show = show_fixture()

      sources = ObsSceneCollection.build(show)["sources"]
      names = Enum.map(sources, & &1["name"])
      uuids = Enum.map(sources, & &1["uuid"])

      assert length(Enum.uniq(names)) == length(names)
      assert length(Enum.uniq(uuids)) == length(uuids)
    end

    test "survives a round trip through JSON" do
      show = show_fixture()

      collection = ObsSceneCollection.build(show)

      assert collection |> Jason.encode!() |> Jason.decode!() == collection
    end
  end

  describe "filename/1 and name/1" do
    test "are named after the show" do
      show = show_fixture()

      assert ObsSceneCollection.filename(show) == "showish-autumn-cup-obs.json"
      assert ObsSceneCollection.name(show) =~ "Autumn Cup"
    end
  end
end
