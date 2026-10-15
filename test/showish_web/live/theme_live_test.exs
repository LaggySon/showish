defmodule ShowishWeb.ThemeLiveTest do
  use ShowishWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Showish.AccountsFixtures
  import Showish.BroadcastsFixtures
  import Showish.ThemesFixtures

  alias Showish.Broadcasts
  alias Showish.Themes
  alias ShowishWeb.Scenes
  alias ShowishWeb.ThemePreview

  describe "signed in" do
    setup :register_and_log_in_user

    test "lists the account's themes and nobody else's", %{conn: conn, scope: scope} do
      mine = theme_fixture(scope, %{"name" => "Acme"})
      theirs = theme_fixture(%{"name" => "Rival"})

      {:ok, view, html} = live(conn, ~p"/themes")

      assert has_element?(view, ~s{a[href="/themes/#{mine.id}"]}, "Acme")
      refute html =~ theirs.name
    end

    test "says so when there are none", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/themes")
      assert has_element?(view, "#themes-empty")
    end

    test "creates a theme and opens it", %{conn: conn, scope: scope} do
      {:ok, view, _html} = live(conn, ~p"/themes/new")

      assert {:error, {:live_redirect, %{to: "/themes/" <> id}}} =
               view
               |> form("#new-theme-form", theme: %{name: "Acme", base: "laggish"})
               |> render_submit()

      assert %{name: "Acme", base: "laggish"} = Themes.get_theme!(scope, id)
    end

    test "imports a theme file", %{conn: conn, scope: scope} do
      file = theme_fixture(%{"name" => "Shared", "tokens" => %{"radius" => 5}}) |> Themes.export()
      {:ok, view, _html} = live(conn, ~p"/themes")

      upload =
        file_input(view, "#import-theme-form", :theme_file, [
          %{name: "shared.showish-theme.json", content: file, type: "application/json"}
        ])

      assert {:error, {:live_redirect, %{to: "/themes/" <> id}}} =
               render_upload(upload, "shared.showish-theme.json")

      assert %{name: "Shared", tokens: %{"radius" => 5}} = Themes.get_theme!(scope, id)
    end

    test "a file that is not a theme says why", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/themes")

      upload =
        file_input(view, "#import-theme-form", :theme_file, [
          %{name: "nope.json", content: ~s({"hello": 1}), type: "application/json"}
        ])

      render_upload(upload, "nope.json")
      assert has_element?(view, "#import-failed", "This is not a theme file")
    end

    test "the editor saves as you type", %{conn: conn, scope: scope} do
      theme = theme_fixture(scope)
      {:ok, view, _html} = live(conn, ~p"/themes/#{theme.id}")

      view
      |> form("#theme-form", theme: %{name: theme.name, tokens: %{radius: "12", shadow: "hard"}})
      |> render_change()

      assert Themes.get_theme!(scope, theme.id).tokens == %{"radius" => 12, "shadow" => "hard"}
    end

    test "CSS arrives as an uploaded file, and replaces the theme's", %{conn: conn, scope: scope} do
      theme = theme_fixture(scope, %{"css" => "a { color: red; }"})
      {:ok, view, _html} = live(conn, ~p"/themes/#{theme.id}")

      upload_css(view, "acme.css", ".overlay-panel { border-radius: 0; }")

      assert Themes.get_theme!(scope, theme.id).css == ".overlay-panel { border-radius: 0; }"
      assert has_element?(view, "#theme-css", "border-radius: 0")
      refute has_element?(view, "#css-error")
    end

    test "CSS that reaches the network is refused, and the theme keeps its own",
         %{conn: conn, scope: scope} do
      theme = theme_fixture(scope, %{"css" => "a { color: red; }"})
      {:ok, view, _html} = live(conn, ~p"/themes/#{theme.id}")

      upload_css(view, "evil.css", "a { background: url(https://example.com/x) }")

      assert has_element?(view, "#css-error", "may only use url()")
      assert Themes.get_theme!(scope, theme.id).css == "a { color: red; }"
    end

    test "a file that is not UTF-8 text is refused", %{conn: conn, scope: scope} do
      theme = theme_fixture(scope)
      {:ok, view, _html} = live(conn, ~p"/themes/#{theme.id}")

      upload_css(view, "binary.css", <<0xFF, 0xFE, 0, 1>>)

      assert has_element?(view, "#css-error", "save it as UTF-8")
    end

    test "CSS can be removed and downloaded", %{conn: conn, scope: scope} do
      theme = theme_fixture(scope, %{"name" => "Acme", "css" => "a { color: red; }"})

      download = get(conn, ~p"/themes/#{theme.id}/custom.css")
      assert response(download, 200) == "a { color: red; }"
      assert get_resp_header(download, "content-disposition") |> hd() =~ "acme.showish-theme.css"

      {:ok, view, _html} = live(conn, ~p"/themes/#{theme.id}")
      view |> element("#remove-css") |> render_click()

      assert Themes.get_theme!(scope, theme.id).css == ""
      refute has_element?(view, "#theme-css")
    end

    test "the template downloads, changes nothing as it is, and imports as a theme",
         %{conn: conn, scope: scope} do
      template = conn |> get(~p"/theme-template.css") |> response(200)
      assert template == Themes.template()

      {:ok, view, _html} = live(conn, ~p"/themes")
      assert has_element?(view, ~s{#download-template[href="/theme-template.css"]})

      upload =
        file_input(view, "#import-theme-form", :theme_file, [
          %{name: "acme_esports.css", content: template, type: "text/css"}
        ])

      assert {:error, {:live_redirect, %{to: "/themes/" <> id}}} =
               render_upload(upload, "acme_esports.css")

      assert %{name: "Acme Esports", base: "broadcast", css: css} = Themes.get_theme!(scope, id)
      assert css == String.trim(template)
    end

    test "a color is set and cleared with buttons", %{conn: conn, scope: scope} do
      theme = theme_fixture(scope)
      {:ok, view, _html} = live(conn, ~p"/themes/#{theme.id}")

      view |> element("#token-panel_color") |> render_click()
      assert %{"panel_color" => _} = Themes.get_theme!(scope, theme.id).tokens

      view
      |> element(~s{button[phx-click="clear_token"][phx-value-key="panel_color"]})
      |> render_click()

      assert Themes.get_theme!(scope, theme.id).tokens == %{}
    end

    test "uploads a font and picks it", %{conn: conn, scope: scope} do
      theme = theme_fixture(scope)
      {:ok, view, _html} = live(conn, ~p"/themes/#{theme.id}")

      upload =
        file_input(view, "#font-text-form", :text_font, [
          %{name: "Acme-Sans.woff2", content: Base.decode64!(woff2_data()), type: "font/woff2"}
        ])

      render_upload(upload, "Acme-Sans.woff2")

      theme = Themes.get_theme!(scope, theme.id)
      assert %{"name" => "Acme-Sans", "format" => "woff2"} = theme.fonts["text"]
      assert theme.tokens["font"] == "custom"
    end

    test "previews the theme on one of the account's own shows", %{conn: conn, scope: scope} do
      theme = theme_fixture(scope)
      show = show_fixture(scope)
      {:ok, view, _html} = live(conn, ~p"/themes/#{theme.id}")

      assert has_element?(view, ~s{iframe[src^="/overlay/#{show.slug}/scorebug?theme_preview="]})
    end

    test "somebody else's theme does not exist", %{conn: conn} do
      theme = theme_fixture()

      assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/themes/#{theme.id}") end
    end

    test "a share link adds a copy", %{conn: conn, scope: scope} do
      theirs = theme_fixture(%{"name" => "Acme", "tokens" => %{"radius" => 2}})
      {:ok, view, _html} = live(conn, ~p"/themes/shared/#{theirs.share_code}")

      assert {:error, {:live_redirect, %{to: "/themes/" <> id}}} =
               view |> element("#add-shared-theme") |> render_click()

      assert %{name: "Acme", tokens: %{"radius" => 2}} = Themes.get_theme!(scope, id)
    end

    test "a reset share link says it is gone", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/themes/shared/not-a-code")
      assert has_element?(view, "#shared-theme-missing")
    end

    test "downloads the theme file", %{conn: conn, scope: scope} do
      theme = theme_fixture(scope, %{"name" => "Acme Esports"})

      conn = get(conn, ~p"/themes/#{theme.id}/download")

      assert response_content_type(conn, :json)

      assert get_resp_header(conn, "content-disposition") |> hd() =~
               "acme-esports.showish-theme.json"

      assert %{"format" => "showish-theme", "name" => "Acme Esports"} = json_response(conn, 200)
    end

    test "the control room's Look menu offers the account's themes", %{conn: conn, scope: scope} do
      theme = theme_fixture(scope, %{"name" => "Acme", "base" => "laggish"})
      show = show_fixture(scope)
      {:ok, view, _html} = live(conn, ~p"/shows/#{show.slug}/control")

      assert has_element?(view, ~s{#show_look option[value="theme-#{theme.id}"]}, "Acme")

      view |> form("#control-form", show: %{look: "theme-#{theme.id}"}) |> render_change()

      assert %{theme_id: theme_id, preset: "laggish"} = Broadcasts.get_show!(scope, show.id)
      assert theme_id == theme.id
    end
  end

  defp upload_css(view, name, content) do
    view
    |> file_input("#css-upload-form", :css_file, [
      %{name: name, content: content, type: "text/css"}
    ])
    |> render_upload(name)
  end

  test "the theme pages need a sign-in", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/themes")
  end

  describe "on air" do
    test "a themed show loads its stylesheet and builds on its base", %{conn: conn} do
      scope = user_scope_fixture()
      theme = theme_fixture(scope, %{"base" => "laggish", "tokens" => %{"radius" => 3}})
      show = show_fixture(scope)
      {:ok, _show} = Broadcasts.update_show(scope, show, %{"look" => "theme-#{theme.id}"})

      {:ok, view, _html} = live(conn, Scenes.path(show.slug, "scorebug"))

      assert has_element?(view, "#overlay-stage.preset-laggish.theme-#{theme.id}")

      assert has_element?(
               view,
               ~s{link#overlay-theme[href="/overlay/themes/#{theme.id}/#{Themes.version(theme)}"]}
             )

      assert has_element?(view, ".lg-bug")

      css = conn |> get(~p"/overlay/themes/#{theme.id}/#{Themes.version(theme)}")
      assert response(css, 200) =~ "--overlay-radius-card: 3px;"
      assert response_content_type(css, :css)
      assert get_resp_header(css, "cache-control") == ["public, max-age=31536000, immutable"]
    end

    test "every scene of either sport is drawn in the theme", %{conn: conn} do
      scope = user_scope_fixture()
      theme = theme_fixture(scope, %{"base" => "laggish"})
      show = show_fixture(scope)
      {:ok, show} = Broadcasts.update_show(scope, show, %{"look" => "theme-#{theme.id}"})

      for sport <- ["esports", "baseball"] do
        {:ok, show} = Broadcasts.update_show(scope, show, %{"sport" => sport})

        for scene <- Scenes.for_sport(show.sport) do
          {:ok, view, _html} = live(conn, Scenes.path(show.slug, scene.key))
          assert has_element?(view, "#overlay-theme"), "#{scene.key} did not load the theme"
          assert has_element?(view, "#overlay-stage.preset-laggish.theme-#{theme.id}")
        end
      end
    end

    test "an edited theme reaches a connected overlay", %{conn: conn} do
      scope = user_scope_fixture()
      theme = theme_fixture(scope)
      show = show_fixture(scope)
      {:ok, _show} = Broadcasts.update_show(scope, show, %{"look" => "theme-#{theme.id}"})
      {:ok, view, _html} = live(conn, Scenes.path(show.slug, "scorebug"))

      {:ok, theme} = Themes.update_theme(scope, theme, %{"base" => "tranquility"})

      assert has_element?(view, "#overlay-stage.preset-tranquility")
      assert has_element?(view, ~s{link#overlay-theme[href$="/#{Themes.version(theme)}"]})
    end

    test "the editor's preview parameter dresses one page only, and only when signed", %{
      conn: conn
    } do
      theme = theme_fixture(%{"base" => "tranquility"})
      show = show_fixture()
      path = Scenes.path(show.slug, "scorebug")

      {:ok, view, _html} = live(conn, path <> "?theme_preview=#{ThemePreview.sign(theme)}")
      assert has_element?(view, "#overlay-stage.preset-tranquility.theme-#{theme.id}")

      {:ok, view, _html} = live(conn, path <> "?theme_preview=forged")
      refute has_element?(view, "#overlay-theme")

      {:ok, view, _html} = live(conn, path)
      refute has_element?(view, "#overlay-theme")
    end

    test "a missing theme's stylesheet is a 404", %{conn: conn} do
      assert conn |> get("/overlay/themes/999999/x") |> response(404)
    end
  end
end
