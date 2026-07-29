defmodule ShowishWeb.Router do
  use ShowishWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ShowishWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # Overlays are loaded as browser sources inside broadcast software. They get a
  # bare, transparent document with no chrome, no theme switcher and no flashes.
  pipeline :overlay do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ShowishWeb.Layouts, :overlay_root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ShowishWeb do
    pipe_through :browser

    live "/", ShowLive.Index, :index
    live "/shows/new", ShowLive.Index, :new
    live "/shows/:slug", ShowLive.Detail, :show
    live "/shows/:slug/control", ShowLive.Control, :control
  end

  scope "/overlay", ShowishWeb.Overlays do
    pipe_through :overlay

    live "/:slug/scorebug", Scorebug
    live "/:slug/series", Series
    live "/:slug/talent", Talent
    live "/:slug/standby", Standby
    live "/:slug/break", Break
    live "/:slug/credits", Credits
    live "/:slug/ticker", Ticker
  end

  # A read-only snapshot of a show, for anything that cannot speak websockets.
  scope "/api", ShowishWeb do
    pipe_through :api

    get "/shows/:slug", ShowJSONController, :show
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:showish, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ShowishWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
