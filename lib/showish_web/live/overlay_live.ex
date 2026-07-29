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
  """

  defmacro __using__(_opts) do
    quote do
      use ShowishWeb, :live_view

      import ShowishWeb.OverlayComponents

      alias Showish.Broadcasts

      @impl Phoenix.LiveView
      def mount(%{"slug" => slug}, _session, socket) do
        if connected?(socket) do
          Broadcasts.subscribe(slug)
          :timer.send_interval(1000, self(), :tick)
        end

        show = Broadcasts.get_show_by_slug!(slug)

        {:ok,
         socket
         |> assign(:show, show)
         |> assign(:now, DateTime.utc_now())
         |> assign(:page_title, show.title)}
      end

      @impl Phoenix.LiveView
      def handle_info({:show_updated, show}, socket) do
        {:noreply, assign(socket, :show, show)}
      end

      def handle_info(:tick, socket) do
        {:noreply, assign(socket, :now, DateTime.utc_now())}
      end

      def handle_info(_message, socket), do: {:noreply, socket}
    end
  end
end
