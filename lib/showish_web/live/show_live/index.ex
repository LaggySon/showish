defmodule ShowishWeb.ShowLive.Index do
  @moduledoc """
  The shelf of shows. Each one is an independent broadcast with its own set of
  overlay URLs.
  """

  use ShowishWeb, :live_view

  alias Showish.Broadcasts
  alias Showish.Broadcasts.Preset
  alias Showish.Broadcasts.Show
  alias Showish.Broadcasts.Sport
  alias Showish.Broadcasts.Team
  alias Showish.Text
  alias ShowishWeb.Scenes

  @impl true
  def mount(_params, _session, socket) do
    shows = Broadcasts.list_shows(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "Shows")
     |> assign(:form, new_form(socket))
     |> assign(:show_count, length(shows))
     |> stream(:shows, shows)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} section="shows">
      <.header>
        Shows
        <:aside>
          <span class="ui-mono">{count(@show_count, "show")}</span>
          <.button :if={@live_action != :new} id="new-show" patch={~p"/shows/new"} variant="primary">
            + New show
          </.button>
        </:aside>
      </.header>

      <.panel
        :if={@live_action == :new}
        id="new-show-panel"
        title="New show"
        class="app-block app-narrow"
      >
        <.form for={@form} id="new-show-form" phx-change="validate" phx-submit="create">
          <div class="app-fields">
            <.input
              field={@form[:title]}
              label="Title"
              placeholder="Summer Cup Grand Finals"
              required
              prose
              phx-mounted={JS.focus()}
            />
            <.input
              field={@form[:slug]}
              label="URL slug"
              placeholder="summer-cup-finals"
              hint="Left empty, it is made from the title."
            />
            <.input field={@form[:sport]} type="select" label="Sport" options={Sport.options()} />
          </div>
          <div class="ui-button-group app-form-actions">
            <.button variant="primary" phx-disable-with="Creating…">Create show</.button>
            <.button patch={~p"/"} variant="ghost">Cancel</.button>
          </div>
        </.form>
      </.panel>

      <div :if={@show_count == 0} id="shows-empty" class="ui-empty">
        No shows yet. Create a show to get its overlay URLs.
        <.button :if={@live_action != :new} patch={~p"/shows/new"} variant="primary">
          + New show
        </.button>
      </div>

      <.table :if={@show_count > 0} id="shows" rows={@streams.shows}>
        <:col :let={{_id, show}} label="Show">
          <.link
            navigate={~p"/shows/#{show.slug}/control"}
            class="ui-quiet-link ui-row-name ui-truncate"
            title={show.title}
          >
            {show.title}
          </.link>
        </:col>
        <:col :let={{_id, show}} label="Slug" class="ui-cell-mono app-wide-only">/{show.slug}</:col>
        <:col :let={{_id, show}} label="Teams" class="app-wide-only">
          <span class="ui-truncate" title={matchup(show)}>{matchup(show)}</span>
        </:col>
        <:col :let={{_id, show}} label="Sport" class="app-wide-only">
          {Sport.fetch(show.sport).name}
        </:col>
        <:col :let={{_id, show}} label="Look" class="app-wide-only">
          {Preset.fetch(show.preset).name}
        </:col>
        <:col :let={{_id, show}} label="Accent" class="app-wide-only">
          <span class="app-swatch-value">
            <span class="ui-color-swatch" style={"--swatch: #{show.accent_color}"}></span>
            <span class="ui-mono">{String.upcase(show.accent_color)}</span>
          </span>
        </:col>
        <:col :let={{_id, show}} label="Updated (UTC)" class="ui-cell-mono app-wide-only">
          {Calendar.strftime(show.updated_at, "%Y-%m-%d %H:%M")}
        </:col>
        <:action :let={{_id, show}}>
          <.button navigate={~p"/shows/#{show.slug}/control"} size="small">Control room</.button>
          <.button navigate={~p"/shows/#{show.slug}"} size="small" variant="quiet">
            Overlay URLs
          </.button>
        </:action>
        <:action :let={{_id, show}}>
          <.button
            type="button"
            size="small"
            variant="danger"
            phx-click="delete"
            phx-value-id={show.id}
            data-confirm={"Delete #{show.title}?"}
            data-confirm-body={"Its #{length(Scenes.for_sport(show.sport))} overlay URLs stop working at once. This cannot be undone."}
            data-confirm-action="Delete show"
          >
            Delete
          </.button>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"show" => params}, socket) do
    form =
      socket
      |> blank_show()
      |> Broadcasts.change_show(fill_slug(params))
      |> to_form(action: :validate)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("create", %{"show" => params}, socket) do
    case Broadcasts.create_show(socket.assigns.current_scope, fill_slug(params)) do
      {:ok, show} ->
        {:noreply,
         socket
         |> put_flash(:info, "Created #{show.title}. Its overlay URLs are live.")
         |> push_navigate(to: ~p"/shows/#{show.slug}/control")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    show = Broadcasts.get_show!(scope, id)
    {:ok, _show} = Broadcasts.delete_show(scope, show)

    {:noreply,
     socket
     |> put_flash(:info, "Deleted #{show.title}.")
     |> update(:show_count, &(&1 - 1))
     |> stream_delete(:shows, show)}
  end

  defp new_form(socket) do
    socket |> blank_show() |> Broadcasts.change_show() |> to_form()
  end

  # The show being built already knows whose it is, so the form and the insert
  # agree about the owner.
  defp blank_show(socket) do
    %Show{user_id: socket.assigns.current_scope.user.id}
  end

  # An operator should not have to think about slugs, but should be able to
  # override the one we derive from the title.
  defp fill_slug(params) do
    if Text.present?(params["slug"]) do
      params
    else
      Map.put(params, "slug", Show.slugify(params["title"] || ""))
    end
  end

  defp matchup(show) do
    case Show.teams(show) do
      [] -> "—"
      teams -> Enum.map_join(teams, " vs ", &Team.full_name/1)
    end
  end

  defp count(1, noun), do: "1 #{noun}"
  defp count(n, noun), do: "#{n} #{noun}s"
end
