defmodule ShowishWeb.ShowLive.Detail do
  @moduledoc """
  Everything an operator needs to wire a show into their broadcast software:
  one browser-source URL per scene, at the resolution the scenes are drawn for.
  """

  use ShowishWeb, :live_view

  import ShowishWeb.ShowLive.Components

  alias Showish.Broadcasts
  alias ShowishWeb.Scenes

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    if connected?(socket), do: Broadcasts.subscribe(slug)

    show = Broadcasts.get_show_by_slug!(socket.assigns.current_scope, slug)

    {:ok,
     socket
     |> assign(:show, show)
     |> assign(:page_title, "#{show.title} · Overlay URLs")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@show.title}
        <:aside>
          <span class="ui-mono">{length(Scenes.for_sport(@show.sport))} scenes</span>
          <span class="ui-sep" aria-hidden="true">·</span>
          <span class="ui-mono">1920×1080</span>
        </:aside>
      </.header>

      <.show_nav show={@show} current={:overlays} />

      <.panel id="obs" title="All of it at once, for OBS" class="app-block">
        <div class="app-obs">
          <p class="app-prose-block">
            A scene collection with one OBS scene per scene below, each holding its browser source
            already sized and pointed at this show. In OBS, choose <strong>Scene Collection</strong>
            › <strong>Import</strong>, pick the file, then <strong>Import</strong>.
          </p>
          <.button
            href={~p"/shows/#{@show.slug}/obs.json"}
            download
            id="download-obs-scene-collection"
            variant="primary"
          >
            Download for OBS
          </.button>
        </div>
      </.panel>

      <.panel id="setup" title="Or add a scene by hand" class="app-block">
        <ol class="app-steps">
          <li>Add a <strong>Browser</strong> source to your scene.</li>
          <li>Paste one of the URLs below, and set the size to <strong>1920×1080</strong>.</li>
          <li>Leave the background transparent. A scene draws nothing outside its own graphics.</li>
          <li>
            Changes made in the control room are on air at once. The browser source never needs a refresh.
          </li>
        </ol>
      </.panel>

      <div class="app-block">
        <.table id="scenes" rows={Scenes.for_sport(@show.sport)} row_id={&"scene-#{&1.key}"}>
          <:col :let={scene} label="Scene"><span class="ui-row-name">{scene.name}</span></:col>
          <:col :let={scene} label="What it shows" class="ui-cell-wrap app-muted-cell app-wide-only">
            {scene.summary}
          </:col>
          <:col :let={scene} label="Browser source URL" class="ui-cell-mono">
            <span class="ui-truncate" title={Scenes.url(@show.slug, scene.key)}>
              {Scenes.url(@show.slug, scene.key)}
            </span>
          </:col>
          <:action :let={scene}>
            <.button
              type="button"
              id={"copy-#{scene.key}"}
              phx-hook="ClipboardCopy"
              data-clipboard-text={Scenes.url(@show.slug, scene.key)}
              size="small"
              variant="ghost"
              aria-label={"Copy the #{scene.name} URL"}
            >
              Copy
            </.button>
            <.button
              href={Scenes.path(@show.slug, scene.key)}
              target="_blank"
              size="small"
              variant="ghost"
              aria-label={"Open #{scene.name} in a new tab"}
            >
              Open <span aria-hidden="true">↗</span>
            </.button>
          </:action>
        </.table>
      </div>

      <.panel id="json" title="Read the show as JSON" class="app-block">
        <p class="ui-muted app-prose-block">
          For anything that cannot hold a websocket open: a static overlay, a bot, a scoreboard on another stack.
          It returns the show as it is now; ask again for an update.
        </p>
        <div class="app-url-row">
          <code class="ui-pre ui-truncate" title={url(~p"/api/shows/#{@show.slug}")}>
            {url(~p"/api/shows/#{@show.slug}")}
          </code>
          <.button
            type="button"
            id="copy-json"
            phx-hook="ClipboardCopy"
            data-clipboard-text={url(~p"/api/shows/#{@show.slug}")}
            size="small"
            variant="ghost"
            aria-label="Copy the JSON URL"
          >
            Copy
          </.button>
        </div>
      </.panel>
    </Layouts.app>
    """
  end

  @impl true
  def handle_info({:show_updated, show}, socket) do
    {:noreply, assign(socket, :show, show)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}
end
