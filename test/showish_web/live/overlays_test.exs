defmodule ShowishWeb.OverlaysTest do
  use ShowishWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Showish.AccountsFixtures
  import Showish.BroadcastsFixtures

  alias Showish.Broadcasts
  alias ShowishWeb.Scenes

  doctest ShowishWeb.OverlayComponents

  @moduletag :overlays

  setup do
    # Overlays are watched by broadcast software that never logs in, so these
    # all run on a conn with nobody signed in.
    scope = user_scope_fixture()

    show =
      show_fixture(scope, %{
        title: "Autumn Cup",
        stage: "Grand Finals",
        ticker: "Welcome to the Autumn Cup",
        teams: [
          %{"position" => 1, "name" => "Harbour Kings", "short_name" => "Kings", "code" => "HRB"},
          %{
            "position" => 2,
            "name" => "Ridgeline Foxes",
            "short_name" => "Foxes",
            "code" => "RDG"
          }
        ]
      })

    %{scope: scope, show: show}
  end

  test "every scene renders on a transparent 1920x1080 stage", %{conn: conn, show: show} do
    for scene <- Scenes.all() do
      {:ok, view, html} = live(conn, Scenes.path(show.slug, scene.key))

      assert html =~ "overlay-stage"
      assert has_element?(view, "#overlay-stage")
    end
  end

  test "the scorebug names both teams and the stage", %{conn: conn, show: show} do
    {:ok, _view, html} = live(conn, Scenes.path(show.slug, "scorebug"))

    assert html =~ "Kings"
    assert html =~ "Foxes"
    assert html =~ "Grand Finals"
  end

  test "a score change reaches a connected overlay without a refresh", %{conn: conn, show: show} do
    {:ok, view, _html} = live(conn, Scenes.path(show.slug, "scorebug"))

    {:ok, _show} = Broadcasts.adjust_score(show, 1, 3)

    assert render(view) =~ ~r{>\s*3\s*</div>}
  end

  test "the scorebug follows the current game", %{conn: conn, show: show} do
    {:ok, view, _html} = live(conn, Scenes.path(show.slug, "scorebug"))

    {:ok, show} = Broadcasts.add_game(show)
    {:ok, show} = Broadcasts.add_game(show)
    {:ok, _show} = Broadcasts.set_current_game(show, 2)

    assert render(view) =~ "Game 2"
  end

  test "baseball gets its own scorebug and receives live state", %{
    conn: conn,
    scope: scope,
    show: show
  } do
    {:ok, show} = Broadcasts.update_show(scope, show, %{"sport" => "baseball"})
    {:ok, view, _html} = live(conn, Scenes.path(show.slug, "scorebug"))

    assert has_element?(view, "#baseball-scorebug")
    assert has_element?(view, "#baseball-overlay-inning")
    assert has_element?(view, "#baseball-overlay-bases")
    assert has_element?(view, "#baseball-overlay-errors-2", "0")

    {:ok, show} = Broadcasts.adjust_score(show, 1, 2)

    {:ok, _show} =
      Broadcasts.apply_sport_action(show, "adjust_stat", %{
        "stat" => "hits",
        "position" => "1",
        "delta" => "1"
      })

    assert has_element?(view, "#baseball-overlay-runs-1", "2")
    assert has_element?(view, "#baseball-overlay-hits-1", "1")
  end

  test "sport-aware scene lists hide the esports series board" do
    assert Enum.any?(Scenes.for_sport("esports"), &(&1.key == "series"))
    refute Enum.any?(Scenes.for_sport("baseball"), &(&1.key == "series"))
  end

  test "swapping sides reorders the scorebug", %{conn: conn, show: show} do
    {:ok, view, _html} = live(conn, Scenes.path(show.slug, "scorebug"))

    before = render(view)
    assert index_of(before, "Kings") < index_of(before, "Foxes")

    {:ok, _show} = Broadcasts.swap_sides(show)

    swapped = render(view)
    assert index_of(swapped, "Foxes") < index_of(swapped, "Kings")
  end

  test "the series board lists every game", %{conn: conn, scope: scope, show: show} do
    {:ok, show} = Broadcasts.add_game(show)

    {:ok, show} =
      Broadcasts.update_show(scope, show, %{
        "games" => [%{"id" => hd(show.games).id, "name" => "Old Harbour"}]
      })

    {:ok, _view, html} = live(conn, Scenes.path(show.slug, "series"))

    assert html =~ "Old Harbour"
    assert html =~ "Game 1"
  end

  test "talent and credits render the crew", %{conn: conn, scope: scope, show: show} do
    {:ok, show} = Broadcasts.add_talent(show)

    {:ok, show} =
      Broadcasts.update_show(scope, show, %{
        "talents" => [%{"id" => hd(show.talents).id, "role" => "Caster", "name" => "Bo Ferreira"}]
      })

    {:ok, _view, talent_html} = live(conn, Scenes.path(show.slug, "talent"))
    assert talent_html =~ "Bo Ferreira"

    {:ok, _view, credits_html} = live(conn, Scenes.path(show.slug, "credits"))
    assert credits_html =~ "Bo Ferreira"
    assert credits_html =~ "Caster"
  end

  test "standby counts down to the configured start time", %{
    conn: conn,
    scope: scope,
    show: show
  } do
    starts_at = DateTime.utc_now() |> DateTime.add(90, :second) |> DateTime.truncate(:second)
    {:ok, show} = Broadcasts.update_show(scope, show, %{"starts_at" => starts_at})

    {:ok, _view, html} = live(conn, Scenes.path(show.slug, "standby"))

    assert html =~ "Starting soon"
    assert html =~ ~r/0[01]:\d\d/
  end

  test "unknown shows 404 rather than rendering an empty overlay", %{conn: conn} do
    assert_raise Ecto.NoResultsError, fn ->
      live(conn, Scenes.path("no-such-show", "scorebug"))
    end
  end

  test "an overlay renders for someone who is not logged in", %{conn: conn, show: show} do
    {:ok, _view, html} = live(conn, Scenes.path(show.slug, "scorebug"))

    assert html =~ "Kings"
  end

  defp index_of(html, needle) do
    case :binary.match(html, needle) do
      {index, _length} -> index
      :nomatch -> flunk("expected to find #{needle} in the rendered overlay")
    end
  end
end
