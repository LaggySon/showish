defmodule ShowishWeb.ErrorHTMLTest do
  use ShowishWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  test "renders 404.html as a full-page state with a way out" do
    html = render_to_string(ShowishWeb.ErrorHTML, "404", "html", [])

    assert html =~ "Page not found"
    assert html =~ ~s{class="ui-page-state"}
    assert html =~ "All shows"
  end

  test "renders 500.html as a full-page state with a way out" do
    html = render_to_string(ShowishWeb.ErrorHTML, "500", "html", [])

    assert html =~ "Server error"
    assert html =~ "All shows"
  end

  test "keeps overlay errors to plain text, so nothing opaque reaches air" do
    conn = Phoenix.ConnTest.build_conn(:get, "/overlay/missing/scorebug")

    assert render_to_string(ShowishWeb.ErrorHTML, "404", "html", conn: conn) == "Not Found"
  end
end
