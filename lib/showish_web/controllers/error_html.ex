defmodule ShowishWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs.

  A page of the app shows a full-page state inside the page shell (DESIGN.md
  section 7.25), so the operator can go elsewhere. An overlay URL keeps the
  plain status text: an error page drawn inside broadcast software would put
  an opaque page on air.
  """
  use ShowishWeb, :html

  def render(template, %{conn: %Plug.Conn{request_path: "/overlay/" <> _}}) do
    Phoenix.Controller.status_message_from_template(template)
  end

  def render("404.html", assigns) do
    page_state(
      Map.merge(assigns, %{
        title: "Page not found",
        message:
          "The show may have been deleted, or its URL slug changed. Every show is on the Shows page."
      })
    )
  end

  def render("500.html", assigns) do
    page_state(
      Map.merge(assigns, %{
        title: "Server error",
        message: "This page failed to load. Reload it, or go back to all shows."
      })
    )
  end

  # The default is to render a plain text page based on
  # the template name. For example, "404.html" becomes
  # "Not Found".
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end

  # The page shell without the LiveView parts: an error page has no socket.
  defp page_state(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="theme-color" content="#ffffff" media="(prefers-color-scheme: light)" />
        <meta name="theme-color" content="#0a0a0a" media="(prefers-color-scheme: dark)" />
        <title>{@title} · Showish</title>
        <link rel="stylesheet" href={~p"/assets/css/app.css"} />
        <script>
          (() => {
            const theme = localStorage.getItem("phx:theme");
            if (theme) document.documentElement.setAttribute("data-theme", theme);
          })();
        </script>
      </head>
      <body>
        <a class="ui-skip-link" href="#main">Skip to content</a>
        <div class="ui-shell">
          <header class="ui-topbar">
            <a href={~p"/"} class="ui-brand">
              <span class="ui-brand-mark" aria-hidden="true"></span>Showish
            </a>
            <nav class="ui-sitenav" aria-label="Site">
              <a href={~p"/"}>Shows</a>
            </nav>
          </header>
          <main class="ui-main" id="main">
            <div class="ui-page-state" data-status="failure" role="alert">
              <h1 class="ui-page-state-title">{@title}</h1>
              <p>{@message}</p>
              <a class="ui-button" href={~p"/"}>All shows</a>
            </div>
          </main>
        </div>
      </body>
    </html>
    """
  end
end
