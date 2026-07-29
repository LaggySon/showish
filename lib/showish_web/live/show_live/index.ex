defmodule ShowishWeb.ShowLive.Index do
  @moduledoc """
  The shelf of shows. Each one is an independent broadcast with its own set of
  overlay URLs.
  """

  use ShowishWeb, :live_view

  alias Showish.Broadcasts
  alias Showish.Broadcasts.Show

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Shows")
     |> assign(:form, new_form())
     |> stream(:shows, Broadcasts.list_shows())}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 class="text-3xl font-black tracking-tight">Shows</h1>
          <p class="mt-1 text-base-content/70">
            A show holds the teams, the series and the crew. Point your broadcast
            software at its overlay URLs and everything updates live.
          </p>
        </div>
        <.link :if={@live_action != :new} patch={~p"/shows/new"} class="btn btn-primary">
          <.icon name="hero-plus-mini" class="size-4" /> New show
        </.link>
      </div>

      <div :if={@live_action == :new} class="rounded-box border border-base-300 bg-base-200 p-6">
        <h2 class="text-lg font-bold">New show</h2>
        <.form for={@form} id="new-show-form" phx-change="validate" phx-submit="create" class="mt-4">
          <div class="grid gap-4 sm:grid-cols-2">
            <.input field={@form[:title]} label="Title" placeholder="Summer Cup — Grand Finals" />
            <.input
              field={@form[:slug]}
              label="URL slug"
              placeholder="summer-cup-finals"
            />
          </div>
          <div class="mt-4 flex gap-2">
            <.button variant="primary" phx-disable-with="Creating…">Create show</.button>
            <.link patch={~p"/"} class="btn btn-ghost">Cancel</.link>
          </div>
        </.form>
      </div>

      <div id="shows" phx-update="stream" class="grid gap-4 sm:grid-cols-2">
        <div class="hidden text-base-content/60 only:block">
          No shows yet. Create one to get your first overlay URL.
        </div>

        <div
          :for={{dom_id, show} <- @streams.shows}
          id={dom_id}
          class="rounded-box border border-base-300 bg-base-100 p-5"
        >
          <div class="flex items-start justify-between gap-3">
            <div class="min-w-0">
              <.link navigate={~p"/shows/#{show.slug}"} class="text-lg font-bold hover:underline">
                {show.title}
              </.link>
              <p class="truncate text-sm text-base-content/60">/{show.slug}</p>
            </div>
            <span
              class="mt-1 size-3 shrink-0 rounded-full"
              style={"background: #{show.accent_color}"}
              aria-hidden="true"
            >
            </span>
          </div>

          <p class="mt-3 text-sm text-base-content/70">
            {matchup(show)}
          </p>

          <div class="mt-4 flex flex-wrap gap-2">
            <.link navigate={~p"/shows/#{show.slug}/control"} class="btn btn-sm btn-primary">
              Control room
            </.link>
            <.link navigate={~p"/shows/#{show.slug}"} class="btn btn-sm">Overlay URLs</.link>
            <button
              type="button"
              class="btn btn-sm btn-ghost text-error"
              phx-click="delete"
              phx-value-id={show.id}
              data-confirm={"Delete #{show.title}? Its overlay URLs will stop working."}
            >
              Delete
            </button>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"show" => params}, socket) do
    form =
      %Show{}
      |> Broadcasts.change_show(fill_slug(params))
      |> to_form(action: :validate)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("create", %{"show" => params}, socket) do
    case Broadcasts.create_show(fill_slug(params)) do
      {:ok, show} ->
        {:noreply,
         socket
         |> put_flash(:info, "Show created.")
         |> push_navigate(to: ~p"/shows/#{show.slug}/control")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    show = Broadcasts.get_show!(id)
    {:ok, _show} = Broadcasts.delete_show(show)

    {:noreply,
     socket
     |> put_flash(:info, "Show deleted.")
     |> stream_delete(:shows, show)}
  end

  defp new_form do
    %Show{} |> Broadcasts.change_show() |> to_form()
  end

  # An operator should not have to think about slugs, but should be able to
  # override the one we derive from the title.
  defp fill_slug(%{"slug" => slug} = params) when is_binary(slug) do
    if String.trim(slug) == "" do
      Map.put(params, "slug", Show.slugify(params["title"] || ""))
    else
      params
    end
  end

  defp fill_slug(params), do: Map.put(params, "slug", Show.slugify(params["title"] || ""))

  defp matchup(show) do
    case List.wrap(show.teams) do
      [] ->
        "No teams yet"

      teams ->
        teams
        |> Enum.sort_by(& &1.position)
        |> Enum.map_join(" vs ", &Showish.Broadcasts.Team.full_name/1)
    end
  end
end
