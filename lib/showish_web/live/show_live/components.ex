defmodule ShowishWeb.ShowLive.Components do
  @moduledoc """
  Pieces shared by the pages of one show: the sub-nav between them and the
  readout that tells an operator whether their typing has reached the show.
  """

  use ShowishWeb, :html

  @doc """
  The chips that switch between the pages of one show. The current one is
  inverted.
  """
  attr :show, :any, required: true
  attr :current, :atom, required: true, values: [:control, :overlays]

  def show_nav(assigns) do
    ~H"""
    <nav class="ui-subnav" aria-label="Show">
      <.link
        navigate={~p"/shows/#{@show.slug}/control"}
        class="ui-chip"
        aria-current={@current == :control && "page"}
      >
        Control room
      </.link>
      <.link
        navigate={~p"/shows/#{@show.slug}"}
        class="ui-chip"
        aria-current={@current == :overlays && "page"}
      >
        Overlay URLs
      </.link>
    </nav>
    """
  end

  @doc """
  A panel that folds away: the same hairline box and micro-label title as
  `<.panel>`, on a `<details>` element, with ▸ / ▾ in front of the title
  (DESIGN.md sections 7.6 and 7.15). The control room keeps the panels an
  operator rarely needs during a match closed.

  Every `<details>` in a LiveView needs `JS.ignore_attributes(["open"])`:
  otherwise the next patch (another operator's score change) strips the
  `open` the browser set, and the section folds away mid-edit.
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :open, :boolean, default: false
  attr :class, :any, default: nil
  slot :aside, doc: "a short note on the right of the title row"
  slot :inner_block, required: true

  def collapsible_panel(assigns) do
    ~H"""
    <details
      phx-mounted={JS.ignore_attributes(["open"])}
      id={@id}
      open={@open}
      class={["ui-panel app-collapsible", @class]}
    >
      <summary class="ui-panel-title app-collapsible-title">
        <span class="app-collapsible-name">{@title}</span>
        <span :if={@aside != []} class="ui-panel-title-aside">{render_slot(@aside)}</span>
      </summary>
      <div class="app-collapsible-body">
        {render_slot(@inner_block)}
      </div>
    </details>
    """
  end

  @doc """
  The autosave readout for a panel title (DESIGN.md section 7.7): "Saving…"
  while a write is in flight, "saved 4s ago" after it, "Not saved" when the
  last write was refused.

  "Saving…" is shown by CSS while the form carries LiveView's
  `phx-change-loading` class, so it needs no round trip of its own.
  """
  attr :id, :string, required: true
  attr :saved_at, :any, required: true, doc: "the DateTime of the last save, or nil"
  attr :failed, :boolean, required: true

  def save_state(assigns) do
    ~H"""
    <span class="app-save-state">
      <span class="app-saving">Saving…</span>
      <span :if={@failed} class="app-save-done app-save-failed">Not saved</span>
      <span
        :if={!@failed && @saved_at}
        id={@id}
        class="app-save-done ui-age"
        aria-live="off"
        phx-hook="SavedAge"
        data-saved-at={DateTime.to_unix(@saved_at, :millisecond)}
      >
        saved 0s ago
      </span>
      <span :if={!@failed && !@saved_at} class="app-save-done">Saves as you type</span>
    </span>
    """
  end
end
