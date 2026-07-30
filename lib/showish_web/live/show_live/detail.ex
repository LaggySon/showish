defmodule ShowishWeb.ShowLive.Detail do
  @moduledoc """
  Everything an operator needs to wire a show into their broadcast software:
  one browser-source URL per scene, at the resolution the scenes are drawn for.
  """

  use ShowishWeb, :live_view

  alias Showish.Broadcasts
  alias ShowishWeb.Scenes

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    if connected?(socket), do: Broadcasts.subscribe(slug)

    show = Broadcasts.get_show_by_slug!(slug)

    {:ok,
     socket
     |> assign(:show, show)
     |> assign(:page_title, show.title)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p class="text-sm text-base-content/60">/{@show.slug}</p>
          <h1 class="text-3xl font-black tracking-tight">{@show.title}</h1>
        </div>
        <.link navigate={~p"/shows/#{@show.slug}/control"} class="btn btn-primary">
          Open control room
        </.link>
      </div>

      <div class="rounded-box border border-base-300 bg-base-200 p-5">
        <h2 class="font-bold">Adding an overlay to your broadcast software</h2>
        <ol class="mt-2 list-decimal space-y-1 pl-5 text-sm text-base-content/70">
          <li>Add a <strong>Browser</strong> source to your scene.</li>
          <li>Paste one of the URLs below, and set the size to <strong>1920 × 1080</strong>.</li>
          <li>
            Leave the background transparent — the scenes draw nothing where nothing belongs.
          </li>
          <li>
            Everything you change in the control room appears on air immediately; there is
            nothing to refresh.
          </li>
        </ol>
      </div>

      <div class="grid gap-3">
        <div
          :for={scene <- Scenes.all()}
          class="rounded-box flex flex-wrap items-center gap-4 border border-base-300 bg-base-100 p-4"
        >
          <div class="min-w-[220px] flex-1">
            <div class="font-bold">{scene.name}</div>
            <div class="text-sm text-base-content/60">{scene.summary}</div>
          </div>

          <code class="rounded bg-base-200 px-3 py-2 text-xs break-all">
            {Scenes.url(@show.slug, scene.key)}
          </code>

          <div class="flex gap-2">
            <button
              type="button"
              id={"copy-#{scene.key}"}
              phx-hook="ClipboardCopy"
              data-clipboard-text={Scenes.url(@show.slug, scene.key)}
              class="btn btn-sm"
            >
              Copy
            </button>
            <a href={Scenes.path(@show.slug, scene.key)} target="_blank" class="btn btn-sm btn-ghost">
              Open
            </a>
          </div>
        </div>
      </div>

      <div class="rounded-box border border-base-300 bg-base-100 p-5">
        <h2 class="font-bold">Read the show as JSON</h2>
        <p class="mt-1 text-sm text-base-content/70">
          For anything that cannot hold a websocket open — a static overlay, a bot, a
          scoreboard on a different stack.
        </p>
        <code class="mt-3 block rounded bg-base-200 px-3 py-2 text-xs break-all">
          {url(~p"/api/shows/#{@show.slug}")}
        </code>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_info({:show_updated, show}, socket) do
    {:noreply, assign(socket, :show, show)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}
end
