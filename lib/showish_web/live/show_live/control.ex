defmodule ShowishWeb.ShowLive.Control do
  @moduledoc """
  The control room.

  Everything on this page writes straight through to the show and out to every
  connected overlay, so what an operator types is on air a moment later. The
  buttons at the top exist because mid-match there is no time to tab through a
  form.
  """

  use ShowishWeb, :live_view

  alias Showish.Broadcasts
  alias Showish.Broadcasts.Preset
  alias Showish.Broadcasts.Show
  alias Showish.Broadcasts.Sport
  alias ShowishWeb.SportControls
  alias ShowishWeb.Scenes

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    if connected?(socket), do: Broadcasts.subscribe(slug)

    show = Broadcasts.get_show_by_slug!(socket.assigns.current_scope, slug)

    {:ok,
     socket
     |> assign(:page_title, "Control · #{show.title}")
     |> assign(:preview_scene, "scorebug")
     |> assign(:team_profiles, Broadcasts.list_team_profiles(socket.assigns.current_scope))
     |> assign_show(show)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} max_width="max-w-[1600px]">
      <div class="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p class="text-sm text-base-content/60">Control room · /{@show.slug}</p>

          <h1 class="text-3xl font-black tracking-tight">{@show.title}</h1>
        </div>

        <div class="flex items-center gap-2">
          <span class="flex items-center gap-2 text-sm text-base-content/60">
            <span class="size-2 animate-pulse rounded-full bg-success"></span> Live — changes go
            straight to air
          </span>
          <.link
            navigate={~p"/shows/#{@show.slug}"}
            aria-label="Open overlay URLs"
            title="Overlay URLs"
            class="grid size-7 place-items-center rounded text-base-content/45 transition hover:bg-base-200 hover:text-primary active:scale-90"
          >
            <.icon name="hero-link-mini" class="size-3.5" />
          </.link>
        </div>
      </div>

      <div id="control-room" class="grid gap-6 xl:grid-cols-[minmax(0,1fr)_560px]">
        <div class="space-y-6">
          <% sport = Sport.fetch(@show.sport) %>
          <.panel
            id="live-controls-panel"
            title={sport.control_title}
            subtitle={sport.control_summary}
            open
          >
            <SportControls.panel show={@show} />
          </.panel>

          <.form for={@form} id="control-form" phx-change="save" phx-submit="save" class="space-y-6">
            <.panel
              id="match-config-panel"
              title="Match"
              subtitle="Copy that frames the broadcast."
            >
              <div class="grid gap-4 sm:grid-cols-2">
                <.input field={@form[:title]} label="Title" phx-debounce="500" />
                <div>
                  <.input field={@form[:slug]} label="URL slug" phx-debounce="blur" />
                  <p class="text-xs text-base-content/60">
                    Part of every overlay URL for this show — changing it moves them all.
                  </p>
                </div>

                <.input
                  field={@form[:stage]}
                  label="Stage"
                  placeholder="Grand Finals"
                  phx-debounce="500"
                />
                <.input
                  field={@form[:subtitle]}
                  label="Subtitle"
                  placeholder="Week 5"
                  phx-debounce="500"
                />
                <.input
                  field={@form[:starts_at]}
                  type="datetime-local"
                  label="Countdown target (UTC)"
                />
                <.input
                  field={@form[:sport]}
                  type="select"
                  label="Sport"
                  options={Sport.options()}
                />
                <.input
                  :if={@show.sport == "esports"}
                  field={@form[:best_of]}
                  type="number"
                  min="1"
                  label="Best of"
                /> <.input field={@form[:accent_color]} type="color" label="Accent color" />
                <.input
                  field={@form[:preset]}
                  type="select"
                  label="Look"
                  options={Preset.options()}
                />
                <.input
                  field={@form[:break_message]}
                  label="Break message"
                  phx-debounce="500"
                />
              </div>

              <.input
                field={@form[:ticker]}
                type="textarea"
                rows="2"
                label="Ticker"
                phx-debounce="500"
              />
              <div class="mt-2 grid gap-4 sm:grid-cols-3">
                <.status_field
                  label="Status — left"
                  field={@form[:status_left]}
                  toggle={@form[:show_status_left]}
                />
                <.status_field
                  label="Status — centre"
                  field={@form[:status_center]}
                  toggle={@form[:show_status_center]}
                />
                <.status_field
                  label="Status — right"
                  field={@form[:status_right]}
                  toggle={@form[:show_status_right]}
                />
              </div>

              <p class="mt-1 text-xs text-base-content/60">
                With the centre status off, the scorebug describes the current game instead.
              </p>

              <div :if={@show.sport == "esports"} class="mt-2">
                <.input
                  field={@form[:show_sides]}
                  type="checkbox"
                  label="Show side labels on the scorebug"
                />
              </div>
            </.panel>

            <.panel
              id="teams-config-panel"
              title="Teams"
              subtitle="Colors drive every scene, so pick the ones from their kit."
            >
              <div class="space-y-2">
                <.inputs_for :let={tf} field={@form[:teams]}>
                  <details
                    id={"team-config-#{tf.data.position}"}
                    class="group/team overflow-hidden rounded-lg border border-base-300"
                  >
                    <summary class="flex cursor-pointer list-none items-center gap-3 px-3 py-2.5 transition hover:bg-base-200/60 [&::-webkit-details-marker]:hidden">
                      <span
                        class="size-2.5 shrink-0 rounded-full"
                        style={"background: #{tf.data.primary_color}"}
                      >
                      </span>
                      <span class="flex-1 truncate text-sm font-bold">
                        {tf.data.name || "Team #{tf.index + 1}"}
                      </span>
                      <span class="text-[10px] font-black uppercase tracking-wider text-base-content/40">
                        {tf.data.code}
                      </span>
                      <.icon
                        name="hero-chevron-down-mini"
                        class="size-3.5 text-base-content/35 transition group-open/team:rotate-180"
                      />
                    </summary>

                    <div class="border-t border-base-300 p-3">
                      <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                        <.input field={tf[:name]} label="Name" phx-debounce="500" />
                        <.input field={tf[:short_name]} label="Short name" phx-debounce="500" />
                        <.input field={tf[:code]} label="Code" placeholder="ABC" phx-debounce="500" />
                        <.input
                          field={tf[:record]}
                          label="Record"
                          placeholder="4-1"
                          phx-debounce="500"
                        />
                        <.input
                          field={tf[:side]}
                          label="Side label"
                          placeholder="Attack"
                          phx-debounce="500"
                        />
                        <.input
                          field={tf[:score]}
                          type="number"
                          min="0"
                          label={if(@show.sport == "baseball", do: "Runs", else: "Series score")}
                        /> <.input field={tf[:primary_color]} type="color" label="Primary color" />
                        <.input field={tf[:secondary_color]} type="color" label="Secondary color" />
                        <.input field={tf[:logo_url]} label="Logo URL" phx-debounce="blur" />
                      </div>

                      <div class="mt-3 flex flex-wrap items-center gap-2 border-t border-base-300 pt-2">
                        <button
                          id={"save-team-profile-#{tf.data.position}"}
                          type="button"
                          aria-label="Save to team library"
                          title="Save to team library"
                          class="grid size-7 place-items-center rounded text-base-content/45 transition hover:bg-primary/10 hover:text-primary active:scale-90"
                          phx-click="save_team_profile"
                          phx-value-position={tf.data.position}
                        >
                          <.icon name="hero-bookmark-mini" class="size-3.5" />
                        </button>
                        <details :if={@team_profiles != []} class="dropdown">
                          <summary
                            aria-label="Use saved team"
                            title="Use saved team"
                            class="grid size-7 cursor-pointer list-none place-items-center rounded text-base-content/45 transition hover:bg-primary/10 hover:text-primary active:scale-90 [&::-webkit-details-marker]:hidden"
                          >
                            <.icon name="hero-book-open-mini" class="size-3.5" />
                          </summary>
                          <div class="dropdown-content z-20 mt-2 w-64 rounded-box border border-base-300 bg-base-100 p-2 shadow-xl">
                            <button
                              :for={profile <- @team_profiles}
                              id={"apply-team-profile-#{tf.data.position}-#{profile.id}"}
                              type="button"
                              class="flex w-full items-center gap-2 rounded-md px-3 py-2 text-left text-sm font-bold transition hover:bg-base-200"
                              phx-click="apply_team_profile"
                              phx-value-position={tf.data.position}
                              phx-value-profile-id={profile.id}
                            >
                              <span
                                class="size-2.5 rounded-full"
                                style={"background: #{profile.primary_color}"}
                              >
                              </span>
                              {profile.name}
                            </button>
                          </div>
                        </details>
                        <span class="text-xs text-base-content/50">
                          Saved branding and rosters are reusable in every show on this account.
                        </span>
                      </div>
                    </div>
                  </details>
                </.inputs_for>
              </div>
            </.panel>

            <.panel
              :if={@show.sport == "esports"}
              id="series-config-panel"
              title="Series"
              subtitle="One row per game. The highlighted row is what is on air."
            >
              <.inputs_for :let={gf} field={@form[:games]}>
                <div class={[
                  "rounded-box mb-3 border p-4",
                  gf.index + 1 == @show.current_game && "border-primary",
                  gf.index + 1 != @show.current_game && "border-base-300"
                ]}>
                  <div class="mb-3 flex flex-wrap items-center gap-2">
                    <span class="font-bold">Game {gf.index + 1}</span>
                    <button
                      type="button"
                      aria-label={"Make game #{gf.index + 1} current"}
                      title="Make current"
                      class="grid size-7 place-items-center rounded text-base-content/45 transition hover:bg-primary/10 hover:text-primary active:scale-90"
                      phx-click="set_game"
                      phx-value-number={gf.index + 1}
                    >
                      <.icon name="hero-bolt-mini" class="size-3.5" />
                    </button>
                    <.row_actions kind="game" id={row_id(gf)} />
                  </div>

                  <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                    <.input
                      field={gf[:name]}
                      label="Name"
                      placeholder="Map or level"
                      phx-debounce="500"
                    />
                    <.input field={gf[:mode]} label="Mode" placeholder="Control" phx-debounce="500" />
                    <.input field={gf[:score_a]} type="number" label="Team 1 score" />
                    <.input field={gf[:score_b]} type="number" label="Team 2 score" />
                    <.input field={gf[:image_url]} label="Image URL" phx-debounce="blur" />
                    <.input field={gf[:info]} label="Note" phx-debounce="500" />
                    <.input
                      field={gf[:winner]}
                      type="select"
                      label="Winner"
                      options={[{"Undecided", ""}, {"Team 1", "a"}, {"Team 2", "b"}, {"Draw", "draw"}]}
                    /> <.input field={gf[:completed]} type="checkbox" label="Completed" />
                  </div>
                </div>
              </.inputs_for>

              <button
                id="add-game"
                type="button"
                aria-label="Add game"
                title="Add game"
                class="grid size-7 place-items-center rounded text-base-content/45 transition hover:bg-primary/10 hover:text-primary active:scale-90"
                phx-click="add_game"
              >
                <.icon name="hero-plus-mini" class="size-3.5" />
              </button>
            </.panel>

            <.panel
              id="talent-config-panel"
              title="Talent"
              subtitle="Drives the lower thirds and the credit roll."
            >
              <.inputs_for :let={pf} field={@form[:talents]}>
                <div class="rounded-box mb-3 border border-base-300 p-4">
                  <div class="mb-3 flex items-center gap-2">
                    <span class="font-bold">#{pf.index + 1}</span>
                    <.row_actions kind="talent" id={row_id(pf)} />
                  </div>

                  <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                    <.input field={pf[:role]} label="Role" placeholder="Caster" phx-debounce="500" />
                    <.input field={pf[:name]} label="Name" phx-debounce="500" />
                    <.input field={pf[:pronouns]} label="Pronouns" phx-debounce="500" />
                    <.input
                      field={pf[:social]}
                      label="Social"
                      placeholder="@handle"
                      phx-debounce="500"
                    /> <.input field={pf[:on_cam]} type="checkbox" label="On camera" />
                  </div>
                </div>
              </.inputs_for>

              <button
                id="add-talent"
                type="button"
                aria-label="Add person"
                title="Add person"
                class="grid size-7 place-items-center rounded text-base-content/45 transition hover:bg-primary/10 hover:text-primary active:scale-90"
                phx-click="add_talent"
              >
                <.icon name="hero-plus-mini" class="size-3.5" />
              </button>
            </.panel>
          </.form>
        </div>

        <div class="xl:sticky xl:top-6 xl:self-start">
          <.panel
            id="preview-panel"
            title="Preview"
            subtitle="Exactly what a browser source renders, scaled to fit."
            open
          >
            <div class="mb-3 flex flex-wrap gap-1">
              <button
                :for={scene <- Scenes.for_sport(@show.sport)}
                type="button"
                class={["btn btn-xs", @preview_scene == scene.key && "btn-primary"]}
                phx-click="preview"
                phx-value-scene={scene.key}
              >
                {scene.name}
              </button>
            </div>

            <div class="checkerboard aspect-video w-full overflow-hidden rounded-box border border-base-300">
              <iframe
                id={"preview-#{@preview_scene}"}
                src={Scenes.path(@show.slug, @preview_scene)}
                title={"#{@preview_scene} preview"}
                class="h-full w-full border-0"
              >
              </iframe>
            </div>

            <div class="mt-3 flex items-center gap-2">
              <code class="flex-1 truncate rounded bg-base-200 px-3 py-2 text-xs">
                {Scenes.url(@show.slug, @preview_scene)}
              </code>
              <button
                type="button"
                id={"copy-preview-#{@preview_scene}"}
                phx-hook="ClipboardCopy"
                data-clipboard-text={Scenes.url(@show.slug, @preview_scene)}
                aria-label="Copy preview URL"
                title="Copy preview URL"
                class="grid size-7 shrink-0 place-items-center rounded text-base-content/45 transition hover:bg-primary/10 hover:text-primary active:scale-90"
              >
                <.icon name="hero-clipboard-mini" class="size-3.5" />
              </button>
            </div>
          </.panel>
        </div>
      </div>
    </Layouts.app>
    """
  end

  ## Events

  @impl true
  def handle_event("save", %{"show" => params}, socket) do
    previous_slug = socket.assigns.show.slug

    case Broadcasts.update_show(socket.assigns.current_scope, socket.assigns.show, params) do
      # The slug is in every overlay URL, so a rename moves this page too rather
      # than leaving the operator on a stale address.
      {:ok, %Show{slug: slug} = show} when slug != previous_slug ->
        {:noreply,
         socket
         |> assign_show(show)
         |> put_flash(:info, "Slug changed — every overlay URL for this show has moved.")
         |> push_navigate(to: ~p"/shows/#{slug}/control")}

      {:ok, show} ->
        {:noreply, assign_show(socket, show)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
    end
  end

  def handle_event("score", %{"position" => position, "delta" => delta}, socket) do
    socket.assigns.show
    |> Broadcasts.adjust_score(String.to_integer(position), String.to_integer(delta))
    |> apply_result(socket)
  end

  def handle_event("reset_scores", _params, socket) do
    socket.assigns.show |> Broadcasts.reset_scores() |> apply_result(socket)
  end

  def handle_event("sport_action", %{"action" => action} = params, socket) do
    socket.assigns.show
    |> Broadcasts.apply_sport_action(action, Map.delete(params, "action"))
    |> apply_result(socket)
  end

  def handle_event("save_team_profile", %{"position" => position}, socket) do
    team = Show.team(socket.assigns.show, String.to_integer(position))

    case Broadcasts.save_team_profile(socket.assigns.current_scope, team) do
      {:ok, _profile} ->
        {:noreply,
         socket
         |> assign(:team_profiles, Broadcasts.list_team_profiles(socket.assigns.current_scope))
         |> put_flash(:info, "#{team.name} saved to the team library.")}

      {:error, changeset} ->
        {:noreply,
         put_flash(socket, :error, "Could not save that team (#{inspect(changeset.errors)}).")}
    end
  end

  def handle_event(
        "apply_team_profile",
        %{"position" => position, "profile-id" => profile_id},
        socket
      ) do
    Broadcasts.apply_team_profile(
      socket.assigns.current_scope,
      socket.assigns.show,
      String.to_integer(position),
      profile_id
    )
    |> apply_result(socket)
  end

  def handle_event("reset_sport", _params, socket) do
    socket.assigns.show |> Broadcasts.reset_sport() |> apply_result(socket)
  end

  def handle_event("swap_sides", _params, socket) do
    socket.assigns.show |> Broadcasts.swap_sides() |> apply_result(socket)
  end

  def handle_event("step_game", %{"delta" => delta}, socket) do
    socket.assigns.show
    |> Broadcasts.move_current_game(String.to_integer(delta))
    |> apply_result(socket)
  end

  def handle_event("set_game", %{"number" => number}, socket) do
    socket.assigns.show
    |> Broadcasts.set_current_game(String.to_integer(number))
    |> apply_result(socket)
  end

  def handle_event("add_game", _params, socket) do
    socket.assigns.show |> Broadcasts.add_game() |> apply_result(socket)
  end

  def handle_event("delete_game", %{"id" => id}, socket) do
    socket.assigns.show |> Broadcasts.delete_game(id) |> apply_result(socket)
  end

  def handle_event("move_game", %{"id" => id, "delta" => delta}, socket) do
    socket.assigns.show
    |> Broadcasts.move_game(id, String.to_integer(delta))
    |> apply_result(socket)
  end

  def handle_event("add_talent", _params, socket) do
    socket.assigns.show |> Broadcasts.add_talent() |> apply_result(socket)
  end

  def handle_event("delete_talent", %{"id" => id}, socket) do
    socket.assigns.show |> Broadcasts.delete_talent(id) |> apply_result(socket)
  end

  def handle_event("move_talent", %{"id" => id, "delta" => delta}, socket) do
    socket.assigns.show
    |> Broadcasts.move_talent(id, String.to_integer(delta))
    |> apply_result(socket)
  end

  def handle_event("preview", %{"scene" => scene}, socket) do
    {:noreply, assign(socket, :preview_scene, Scenes.fetch(scene).key)}
  end

  # Another operator changed something. Refresh the state the buttons read from,
  # but leave the form alone so we never yank a field out from under someone
  # who is mid-sentence.
  @impl true
  def handle_info({:show_updated, show}, socket) do
    {:noreply, assign(socket, :show, show)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  ## Components

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :id, :string, default: nil
  attr :open, :boolean, default: false
  slot :inner_block, required: true

  @doc false
  def panel(assigns) do
    ~H"""
    <details id={@id} open={@open} class="group rounded-box border border-base-300 bg-base-100">
      <summary class="flex cursor-pointer list-none items-center justify-between gap-4 px-5 py-4 transition hover:bg-base-200/55 [&::-webkit-details-marker]:hidden">
        <span>
          <span class="block text-lg font-bold">{@title}</span>
          <span :if={@subtitle} class="block text-sm text-base-content/60">{@subtitle}</span>
        </span>
        <.icon
          name="hero-chevron-down-mini"
          class="size-4 shrink-0 text-base-content/40 transition group-open:rotate-180"
        />
      </summary>
      <div class="border-t border-base-300 px-5 py-4">
        {render_slot(@inner_block)}
      </div>
    </details>
    """
  end

  attr :label, :string, required: true
  attr :field, Phoenix.HTML.FormField, required: true
  attr :toggle, Phoenix.HTML.FormField, required: true

  @doc false
  def status_field(assigns) do
    ~H"""
    <div>
      <.input field={@field} label={@label} phx-debounce="500" />
      <.input field={@toggle} type="checkbox" label="Show on air" />
    </div>
    """
  end

  attr :kind, :string, required: true, values: ~w(game talent)
  attr :id, :any, required: true

  @doc false
  def row_actions(assigns) do
    ~H"""
    <div class="ml-auto flex gap-1">
      <button
        type="button"
        title={"Move #{@kind} earlier"}
        class="grid size-6 place-items-center rounded text-base-content/35 transition hover:bg-base-200 hover:text-base-content active:scale-90"
        phx-click={"move_#{@kind}"}
        phx-value-id={@id}
        phx-value-delta="-1"
        aria-label={"Move this #{@kind} earlier"}
      >
        <.icon name="hero-arrow-up-mini" class="size-3" />
      </button>
      <button
        type="button"
        title={"Move #{@kind} later"}
        class="grid size-6 place-items-center rounded text-base-content/35 transition hover:bg-base-200 hover:text-base-content active:scale-90"
        phx-click={"move_#{@kind}"}
        phx-value-id={@id}
        phx-value-delta="1"
        aria-label={"Move this #{@kind} later"}
      >
        <.icon name="hero-arrow-down-mini" class="size-3" />
      </button>
      <button
        type="button"
        aria-label={"Remove this #{@kind}"}
        title={"Remove #{@kind}"}
        class="grid size-6 place-items-center rounded text-base-content/35 transition hover:bg-error/10 hover:text-error active:scale-90"
        phx-click={"delete_#{@kind}"}
        phx-value-id={@id}
      >
        <.icon name="hero-trash-mini" class="size-3" />
      </button>
    </div>
    """
  end

  ## Helpers

  defp assign_show(socket, %Show{} = show) do
    available_scenes = Enum.map(Scenes.for_sport(show.sport), & &1.key)
    preview_scene = socket.assigns[:preview_scene]

    preview_scene =
      if preview_scene in available_scenes, do: preview_scene, else: hd(available_scenes)

    socket
    |> assign(:show, show)
    |> assign(:preview_scene, preview_scene)
    |> assign(:form, to_form(Broadcasts.change_show(show)))
  end

  defp apply_result({:ok, %Show{} = show}, socket), do: {:noreply, assign_show(socket, show)}

  defp apply_result({:error, %Ecto.Changeset{} = changeset}, socket),
    do: {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}

  defp apply_result({:error, reason}, socket),
    do: {:noreply, put_flash(socket, :error, "Could not apply that change (#{inspect(reason)}).")}

  # The database id of the row behind a nested form, which is what the row
  # buttons send back — the form's index would move under them the moment a row
  # above it was removed.
  defp row_id(form), do: form.data.id
end
