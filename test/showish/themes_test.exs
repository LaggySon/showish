defmodule Showish.ThemesTest do
  use Showish.DataCase, async: true

  import Showish.AccountsFixtures
  import Showish.BroadcastsFixtures
  import Showish.ThemesFixtures

  alias Showish.Broadcasts
  alias Showish.Themes
  alias Showish.Themes.CustomCSS
  alias Showish.Themes.Theme

  doctest Showish.Themes.Tokens
  doctest Showish.Themes.CustomCSS

  test "the theme guide documents every token" do
    guide = File.read!("docs/themes.md")

    for key <- Showish.Themes.Tokens.keys() do
      assert guide =~ "| `#{key}` |", "docs/themes.md has no row for #{key}"
    end
  end

  describe "tokens" do
    test "a theme keeps only tokens it knows, cleaned" do
      theme =
        theme_fixture(%{"tokens" => %{"radius" => "6", "panel_color" => "#ABC", "font" => ""}})

      assert theme.tokens == %{"radius" => 6, "panel_color" => "#aabbcc"}
    end

    test "a bad token is refused, naming the token" do
      scope = user_scope_fixture()

      assert {:error, changeset} =
               Themes.create_theme(scope, %{
                 "name" => "Bad",
                 "tokens" => %{"radius" => 99, "shadow" => "fuzzy", "colour" => "#fff"}
               })

      messages = errors_on(changeset).tokens
      assert "colour is not a theme token" in messages
      assert Enum.any?(messages, &(&1 =~ "radius must be a whole number from 0 to 32"))
      assert Enum.any?(messages, &(&1 =~ "shadow must be one of"))
    end

    test "only the base must be a built-in look" do
      assert {:error, changeset} =
               Themes.create_theme(user_scope_fixture(), %{"name" => "X", "base" => "nope"})

      assert "must be one of the built-in looks" in errors_on(changeset).base
    end
  end

  describe "custom CSS" do
    test "may not reach the network" do
      for css <- [
            ~s(@import "https://example.com/x.css";),
            "body { background: url(https://example.com/x.png); }",
            ~s|body { background: URL( "//example.com/x.png" ); }|,
            ~s|body { background: image-set("https://example.com/x.png" 1x); }|,
            ~s|body { background: -webkit-image-set("x.png" 1x); }|,
            ~s|body { background: src("https://example.com/x.png"); }|
          ] do
        assert {:error, _message} = CustomCSS.check(css), "accepted #{css}"
      end
    end

    test "may not escape a forbidden word or the page" do
      assert {:error, _} = CustomCSS.check("body { background: \\75 rl(https://x.y/z); }")
      assert {:error, _} = CustomCSS.check("</style><script>alert(1)</script>")
    end

    test "the template follows the rules, and only comments" do
      template = Themes.template()

      assert CustomCSS.check(template) == :ok
      assert template |> String.replace(~r{/\*.*?\*/}s, "") |> String.trim() == ""
    end

    test "may embed data URLs" do
      css =
        ~s|@font-face { font-family: X; src: url("data:font/woff2;base64,d09GMgAB") format("woff2"); }
               .overlay-panel { background-image: url(data:image/png;base64,iVBORw0KGgo=); }|

      assert CustomCSS.check(css) == :ok
    end

    test "is refused on the theme with its reason" do
      assert {:error, changeset} =
               Themes.create_theme(user_scope_fixture(), %{
                 "name" => "X",
                 "css" => "a { background: url(http://x.y/z) }"
               })

      assert "may only use url() with an embedded data: URL" in errors_on(changeset).css
    end
  end

  describe "fonts" do
    test "a font file travels inside the theme" do
      theme =
        theme_fixture(%{
          "fonts" => %{
            "text" => %{"name" => "Acme Sans", "format" => "woff2", "data" => woff2_data()}
          }
        })

      assert theme.fonts["text"]["name"] == "Acme Sans"
    end

    test "anything that is not a font is refused" do
      assert {:error, changeset} =
               Themes.create_theme(user_scope_fixture(), %{
                 "name" => "X",
                 "fonts" => %{
                   "text" => %{
                     "name" => "Evil",
                     "format" => "woff2",
                     "data" => Base.encode64("<svg onload=x>")
                   }
                 }
               })

      assert "the text font is not a font file" in errors_on(changeset).fonts
    end

    test "a font name cannot carry CSS" do
      assert {:error, changeset} =
               Themes.create_theme(user_scope_fixture(), %{
                 "name" => "X",
                 "fonts" => %{
                   "text" => %{
                     "name" => ~s(X"; } body { x),
                     "format" => "woff2",
                     "data" => woff2_data()
                   }
                 }
               })

      assert [message] = errors_on(changeset).fonts
      assert message =~ "font name may only use"
    end
  end

  describe "the stylesheet" do
    test "carries the fonts, the tokens and the theme's own CSS, scoped to its stage" do
      theme =
        theme_fixture(%{
          "tokens" => %{"radius" => 8, "font" => "custom", "grays" => "stone"},
          "fonts" => %{
            "text" => %{"name" => "Acme Sans", "format" => "woff2", "data" => woff2_data()}
          },
          "css" => ".overlay-panel { outline: 1px solid red; }"
        })

      css = Themes.stylesheet(theme)
      family = "theme-#{theme.id}-text"

      assert css =~ ~s(font-family: "#{family}";)
      assert css =~ "src: url(data:font/woff2;base64,#{woff2_data()})"
      assert css =~ ".overlay-stage.theme-#{theme.id} {"
      assert css =~ "--overlay-radius-card: 8px;"
      assert css =~ "--overlay-radius-hero: 12px;"
      assert css =~ ~s(font-family: "#{family}", ui-sans-serif, sans-serif;)
      assert css =~ "--color-slate-950: #0c0a09;"
      assert css =~ ".overlay-panel { outline: 1px solid red; }"
    end

    test "an empty theme is its base look" do
      css = Themes.stylesheet(theme_fixture())

      refute css =~ "{"
    end
  end

  describe "ownership" do
    test "a theme is invisible and unwritable to anybody else" do
      theme = theme_fixture()
      stranger = user_scope_fixture()

      assert Themes.list_themes(stranger) == []
      assert_raise Ecto.NoResultsError, fn -> Themes.get_theme!(stranger, theme.id) end
      assert Themes.get_own_theme(stranger, theme.id) == nil

      assert_raise Ecto.NoResultsError, fn ->
        Themes.update_theme(stranger, theme, %{"name" => "Mine"})
      end

      assert_raise Ecto.NoResultsError, fn -> Themes.delete_theme(stranger, theme) end
    end

    test "names are unique per account, not across accounts" do
      scope = user_scope_fixture()
      theme_fixture(scope, %{"name" => "Acme"})

      assert {:error, changeset} = Themes.create_theme(scope, %{"name" => "Acme"})
      assert "you already have a theme with this name" in errors_on(changeset).name
      assert %Theme{} = theme_fixture(user_scope_fixture(), %{"name" => "Acme"})
    end
  end

  describe "on a show" do
    test "a show takes its own theme, and its theme's base as its preset" do
      scope = user_scope_fixture()
      theme = theme_fixture(scope, %{"base" => "laggish"})
      show = show_fixture(scope)

      {:ok, show} = Broadcasts.update_show(scope, show, %{"look" => "theme-#{theme.id}"})

      assert show.theme_id == theme.id
      assert show.theme.id == theme.id
      assert show.preset == "laggish"
      assert Broadcasts.look(show) == "theme-#{theme.id}"

      {:ok, show} = Broadcasts.update_show(scope, show, %{"look" => "tranquility"})
      assert show.theme_id == nil
      assert show.preset == "tranquility"
    end

    test "a show cannot take somebody else's theme" do
      scope = user_scope_fixture()
      show = show_fixture(scope)
      theirs = theme_fixture()

      {:ok, show} = Broadcasts.update_show(scope, show, %{"look" => "theme-#{theirs.id}"})

      assert show.theme_id == nil
    end

    test "editing a theme redraws its shows, and deleting it leaves them on its base" do
      scope = user_scope_fixture()
      theme = theme_fixture(scope, %{"base" => "laggish"})
      show = show_fixture(scope)
      {:ok, show} = Broadcasts.update_show(scope, show, %{"look" => "theme-#{theme.id}"})
      Broadcasts.subscribe(show.slug)

      {:ok, theme} = Themes.update_theme(scope, theme, %{"tokens" => %{"radius" => 3}})
      assert_receive {:show_updated, %{theme: %Theme{tokens: %{"radius" => 3}}}}

      {:ok, _theme} = Themes.delete_theme(scope, theme)
      assert_receive {:show_updated, %{theme: nil, preset: "laggish"}}
    end
  end

  describe "files and sharing" do
    test "a theme survives a round trip through its file" do
      scope = user_scope_fixture()

      theme =
        theme_fixture(scope, %{
          "name" => "Acme",
          "base" => "tranquility",
          "tokens" => %{"radius" => 4, "shadow" => "hard"},
          "fonts" => %{
            "numbers" => %{"name" => "Acme Mono", "format" => "woff2", "data" => woff2_data()}
          },
          "css" => ".overlay-vs { color: red; }"
        })

      file = Themes.export(theme)
      assert Themes.export_filename(theme) == "acme.showish-theme.json"

      {:ok, copy} = Themes.import_file(scope, file)
      assert copy.name == "Acme (2)"

      assert {copy.base, copy.tokens, copy.fonts, copy.css} ==
               {theme.base, theme.tokens, theme.fonts, theme.css}

      {:ok, again} = Themes.import_file(scope, file)
      assert again.name == "Acme (3)"

      {:ok, elsewhere} = Themes.import_file(user_scope_fixture(), file)
      assert elsewhere.name == "Acme"
    end

    test "a file that is not a theme says why" do
      scope = user_scope_fixture()

      assert {:error, "This is not a theme file: it is not valid JSON."} =
               Themes.import_file(scope, "{")

      assert {:error, message} = Themes.import_file(scope, ~s({"name": "x"}))
      assert message =~ ~s("format": "showish-theme")

      assert {:error, "This theme file is version 9; this Showish reads version 1."} =
               Themes.import_file(scope, ~s({"format": "showish-theme", "version": 9}))

      bad =
        Jason.encode!(%{format: "showish-theme", version: 1, name: "X", tokens: %{radius: -1}})

      assert {:error, %Ecto.Changeset{}} = Themes.import_file(scope, bad)
    end

    test "a share link copies the theme into the reader's account, and only once reset stops working" do
      owner = user_scope_fixture()
      theme = theme_fixture(owner, %{"name" => "Acme", "tokens" => %{"radius" => 4}})
      reader = user_scope_fixture()

      {:ok, copy} = Themes.copy_shared(reader, theme.share_code)
      assert copy.user_id == reader.user.id
      assert copy.tokens == theme.tokens
      assert copy.share_code != theme.share_code

      {:ok, _theme} = Themes.update_theme(owner, theme, %{"tokens" => %{"radius" => 20}})
      assert Themes.get_theme!(reader, copy.id).tokens == %{"radius" => 4}

      {:ok, reset} = Themes.reset_share_code(owner, theme)
      assert {:error, :not_found} = Themes.copy_shared(reader, theme.share_code)
      assert {:ok, _copy} = Themes.copy_shared(reader, reset.share_code)
    end
  end
end
