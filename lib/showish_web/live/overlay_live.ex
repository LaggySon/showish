defmodule ShowishWeb.OverlayLive do
  @moduledoc """
  Shared plumbing for overlay scenes.

  Every scene mounts the same way: look the show up by slug, subscribe to it,
  and tick once a second so clocks stay honest. Scenes then only have to supply
  a `render/1`.

      defmodule ShowishWeb.Overlays.Scorebug do
        use ShowishWeb.OverlayLive

        def render(assigns) do
          ~H"<.stage>...</.stage>"
        end
      end

  ## What a scene is handed

    * `@show` — the show, fully preloaded, replaced whenever the control room
      changes it;
    * `@left` and `@right` — the two teams in the order they are drawn, which
      is `@show.swap_sides` already applied. Either may be `nil`, for a show
      whose second team has not been filled in yet;
    * `@now` — the current time, one second fresh, for the countdowns;
    * `@theme` — the account theme the show is drawn in, or `nil`. When there is
      one, `@show.preset` is already the theme's base look. The theme editor's
      preview swaps a theme in with a signed `theme_preview` parameter.

  The sides are assigned here rather than worked out in each `render/1` because
  every scene that draws two teams needs the same answer, and a scene that
  disagreed with the others about which team is on the left would be a bug
  nobody would notice until it was on air.
  """

  import Phoenix.Component, only: [assign: 2, assign: 3]

  alias Showish.Broadcasts.Show
  alias Showish.Themes
  alias Showish.Themes.Theme
  alias ShowishWeb.ThemePreview

  @doc """
  Puts a show, and the sides derived from it, on the socket.

  Public so the `mount/3` and `handle_info/2` generated below can share it.
  """
  def assign_show(socket, %Show{} = show) do
    theme = socket.assigns[:preview_theme] || own_theme(show)

    # A theme decides which base look its scenes are built from, whatever the
    # show's own preset says.
    show = if theme, do: %{show | preset: theme.base}, else: show
    {left, right} = Show.sides(show)

    assign(socket, show: show, theme: theme, left: left, right: right)
  end

  defp own_theme(%Show{theme: %Theme{} = theme}), do: theme
  defp own_theme(%Show{}), do: nil

  @doc """
  Reads the theme editor's `theme_preview` parameter, if the page has one, and
  subscribes to that theme so the preview follows every edit.
  """
  def assign_preview_theme(socket, params) do
    with id when is_integer(id) <- ThemePreview.verify(params["theme_preview"]),
         %Theme{} = theme <- Themes.get_theme(id) do
      if Phoenix.LiveView.connected?(socket), do: Themes.subscribe(theme)
      assign(socket, :preview_theme, theme)
    else
      _ -> assign(socket, :preview_theme, nil)
    end
  end

  defmacro __using__(_opts) do
    quote do
      use ShowishWeb, :live_view

      import ShowishWeb.OverlayComponents

      alias Showish.Broadcasts
      alias ShowishWeb.OverlayLive

      @impl Phoenix.LiveView
      def mount(%{"slug" => slug} = params, _session, socket) do
        if connected?(socket) do
          Broadcasts.subscribe(slug)
          :timer.send_interval(1000, self(), :tick)
        end

        show = Broadcasts.get_public_show_by_slug!(slug)

        {:ok,
         socket
         |> OverlayLive.assign_preview_theme(params)
         |> OverlayLive.assign_show(show)
         |> assign(:now, DateTime.utc_now())
         |> assign(:page_title, show.title)}
      end

      @impl Phoenix.LiveView
      def handle_info({:show_updated, show}, socket) do
        {:noreply, OverlayLive.assign_show(socket, show)}
      end

      def handle_info({:theme_updated, theme}, socket) do
        {:noreply,
         socket
         |> assign(:preview_theme, theme)
         |> OverlayLive.assign_show(socket.assigns.show)}
      end

      def handle_info(:tick, socket) do
        {:noreply, assign(socket, :now, DateTime.utc_now())}
      end

      def handle_info(_message, socket), do: {:noreply, socket}
    end
  end
end
