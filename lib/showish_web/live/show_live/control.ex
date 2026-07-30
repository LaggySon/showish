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
  alias Showish.Broadcasts.Show
  alias ShowishWeb.Scenes

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    if connected?(socket), do: Broadcasts.subscribe(slug)

    show = Broadcasts.get_show_by_slug!(socket.assigns.current_scope, slug)

    {:ok,
     socket
     |> assign(:page_title, "Control · #{show.title}")
     |> assign(:preview_scene, "scorebug")
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
          <.link navigate={~p"/shows/#{@show.slug}"} class="btn btn-sm">Overlay URLs</.link>
        </div>
      </div>

      <div class="grid gap-6 xl:grid-cols-[minmax(0,1fr)_560px]">
        <div class="space-y-6">
          <.panel title="On air" subtitle="The controls you reach for during a match.">
            <div class="grid gap-4 sm:grid-cols-2">
              <.score_control :for={team <- sorted_teams(@show)} team={team} />
            </div>

            <div class="mt-4 flex flex-wrap gap-2">
              <button id="swap-sides" type="button" class="btn btn-sm" phx-click="swap_sides">
                <.icon name="hero-arrows-right-left-mini" class="size-4" />
                {if @show.swap_sides, do: "Sides swapped", else: "Swap sides"}
              </button>
              <button
                id="previous-game"
                type="button"
                class="btn btn-sm"
                phx-click="step_game"
                phx-value-delta="-1"
              >
                Previous game
              </button>
              <span class="btn btn-sm btn-ghost pointer-events-none">
                Game {@show.current_game} of {max(length(@show.games), 1)}
              </span>
              <button
                id="next-game"
                type="button"
                class="btn btn-sm"
                phx-click="step_game"
                phx-value-delta="1"
              >
                Next game
              </button>
              <button
                id="reset-scores"
                type="button"
                class="btn btn-sm btn-ghost text-error"
                phx-click="reset_scores"
                data-confirm="Set both series scores back to zero?"
              >
                Reset scores
              </button>
            </div>
          </.panel>

          <.form for={@form} id="control-form" phx-change="save" phx-submit="save" class="space-y-6">
            <.panel title="Match" subtitle="Copy that frames the broadcast.">
              <div class="grid gap-4 sm:grid-cols-2">
                <.input field={@form[:title]} label="Title" phx-debounce="500" />
                <div>
                  <.input field={@form[:slug]} label="URL slug" phx-debounce="blur" />
                  <p class="text-xs text-base-content/60">
                    Part of every overlay URL for this show — changing it moves them all.
                  </p>
                </div>
                <.input field={@form[:stage]} label="Stage" placeholder="Grand Finals" phx-debounce="500" />
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
                <.input field={@form[:best_of]} type="number" min="1" label="Best of" />
                <.input field={@form[:accent_color]} type="color" label="Accent color" />
                <.input
                  field={@form[:preset]}
                  type="select"
                  label="Look"
                  options={Showish.Broadcasts.Preset.options()}
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
                <div>
                  <.input field={@form[:status_left]} label="Status — left" phx-debounce="500" />
                  <.input field={@form[:show_status_left]} type="checkbox" label="Show on air" />
                </div>
                <div>
                  <.input field={@form[:status_center]} label="Status — centre" phx-debounce="500" />
                  <.input field={@form[:show_status_center]} type="checkbox" label="Show on air" />
                </div>
                <div>
                  <.input field={@form[:status_right]} label="Status — right" phx-debounce="500" />
                  <.input field={@form[:show_status_right]} type="checkbox" label="Show on air" />
                </div>
              </div>

              <p class="mt-1 text-xs text-base-content/60">
                With the centre status off, the scorebug describes the current game instead.
              </p>

              <div class="mt-2">
                <.input field={@form[:show_sides]} type="checkbox" label="Show side labels on the scorebug" />
              </div>
            </.panel>

            <.panel title="Teams" subtitle="Colors drive every scene, so pick the ones from their kit.">
              <.inputs_for :let={tf} field={@form[:teams]}>
                <div class="rounded-box border border-base-300 p-4">
                  <h3 class="mb-3 font-bold">Team {tf.index + 1}</h3>
                  <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                    <.input field={tf[:name]} label="Name" phx-debounce="500" />
                    <.input field={tf[:short_name]} label="Short name" phx-debounce="500" />
                    <.input field={tf[:code]} label="Code" placeholder="ABC" phx-debounce="500" />
                    <.input field={tf[:record]} label="Record" placeholder="4-1" phx-debounce="500" />
                    <.input
                      field={tf[:side]}
                      label="Side label"
                      placeholder="Attack"
                      phx-debounce="500"
                    />
                    <.input field={tf[:score]} type="number" min="0" label="Series score" />
                    <.input field={tf[:primary_color]} type="color" label="Primary color" />
                    <.input field={tf[:secondary_color]} type="color" label="Secondary color" />
                    <.input field={tf[:logo_url]} label="Logo URL" phx-debounce="blur" />
                  </div>
                </div>
              </.inputs_for>
            </.panel>

            <.panel title="Series" subtitle="One row per game. The highlighted row is what is on air.">
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
                      class="btn btn-xs"
                      phx-click="set_game"
                      phx-value-number={gf.index + 1}
                    >
                      Make current
                    </button>
                    <div class="ml-auto flex gap-1">
                      <button
                        type="button"
                        class="btn btn-xs btn-ghost"
                        phx-click="move_game"
                        phx-value-id={game_id(gf)}
                        phx-value-delta="-1"
                      >
                        <.icon name="hero-arrow-up-mini" class="size-3" />
                      </button>
                      <button
                        type="button"
                        class="btn btn-xs btn-ghost"
                        phx-click="move_game"
                        phx-value-id={game_id(gf)}
                        phx-value-delta="1"
                      >
                        <.icon name="hero-arrow-down-mini" class="size-3" />
                      </button>
                      <button
                        type="button"
                        class="btn btn-xs btn-ghost text-error"
                        phx-click="delete_game"
                        phx-value-id={game_id(gf)}
                      >
                        Remove
                      </button>
                    </div>
                  </div>

                  <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                    <.input field={gf[:name]} label="Name" placeholder="Map or level" phx-debounce="500" />
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
                    />
                    <.input field={gf[:completed]} type="checkbox" label="Completed" />
                  </div>
                </div>
              </.inputs_for>

              <button id="add-game" type="button" class="btn btn-sm" phx-click="add_game">
                <.icon name="hero-plus-mini" class="size-4" /> Add game
              </button>
            </.panel>

            <.panel title="Talent" subtitle="Drives the lower thirds and the credit roll.">
              <.inputs_for :let={pf} field={@form[:talents]}>
                <div class="rounded-box mb-3 border border-base-300 p-4">
                  <div class="mb-3 flex items-center gap-2">
                    <span class="font-bold">#{pf.index + 1}</span>
                    <div class="ml-auto flex gap-1">
                      <button
                        type="button"
                        class="btn btn-xs btn-ghost"
                        phx-click="move_talent"
                        phx-value-id={talent_id(pf)}
                        phx-value-delta="-1"
                      >
                        <.icon name="hero-arrow-up-mini" class="size-3" />
                      </button>
                      <button
                        type="button"
                        class="btn btn-xs btn-ghost"
                        phx-click="move_talent"
                        phx-value-id={talent_id(pf)}
                        phx-value-delta="1"
                      >
                        <.icon name="hero-arrow-down-mini" class="size-3" />
                      </button>
                      <button
                        type="button"
                        class="btn btn-xs btn-ghost text-error"
                        phx-click="delete_talent"
                        phx-value-id={talent_id(pf)}
                      >
                        Remove
                      </button>
                    </div>
                  </div>

                  <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                    <.input field={pf[:role]} label="Role" placeholder="Caster" phx-debounce="500" />
                    <.input field={pf[:name]} label="Name" phx-debounce="500" />
                    <.input field={pf[:pronouns]} label="Pronouns" phx-debounce="500" />
                    <.input field={pf[:social]} label="Social" placeholder="@handle" phx-debounce="500" />
                    <.input field={pf[:on_cam]} type="checkbox" label="On camera" />
                  </div>
                </div>
              </.inputs_for>

              <button id="add-talent" type="button" class="btn btn-sm" phx-click="add_talent">
                <.icon name="hero-plus-mini" class="size-4" /> Add person
              </button>
            </.panel>
          </.form>
        </div>

        <div class="xl:sticky xl:top-6 xl:self-start">
          <.panel title="Preview" subtitle="Exactly what a browser source renders, scaled to fit.">
            <div class="mb-3 flex flex-wrap gap-1">
              <button
                :for={scene <- Scenes.all()}
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
                class="btn btn-sm"
              >
                Copy
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
  slot :inner_block, required: true

  @doc false
  def panel(assigns) do
    ~H"""
    <section class="rounded-box border border-base-300 bg-base-100 p-5">
      <header class="mb-4">
        <h2 class="text-lg font-bold">{@title}</h2>
        <p :if={@subtitle} class="text-sm text-base-content/60">{@subtitle}</p>
      </header>
      {render_slot(@inner_block)}
    </section>
    """
  end

  attr :team, :any, required: true

  @doc false
  def score_control(assigns) do
    ~H"""
    <div class="rounded-box flex items-center gap-3 border border-base-300 p-3">
      <span class="size-8 shrink-0 rounded" style={"background: #{@team.primary_color}"}></span>
      <div class="min-w-0 flex-1">
        <div class="truncate font-bold">{Showish.Broadcasts.Team.full_name(@team)}</div>
        <div class="text-xs text-base-content/60">Team {@team.position}</div>
      </div>
      <button
        type="button"
        id={"score-down-#{@team.position}"}
        class="btn btn-sm btn-circle"
        phx-click="score"
        phx-value-position={@team.position}
        phx-value-delta="-1"
        aria-label={"Decrease score for team #{@team.position}"}
      >
        −
      </button>
      <span class="w-10 text-center text-2xl font-black tabular-nums">{@team.score}</span>
      <button
        type="button"
        id={"score-up-#{@team.position}"}
        class="btn btn-sm btn-circle btn-primary"
        phx-click="score"
        phx-value-position={@team.position}
        phx-value-delta="1"
        aria-label={"Increase score for team #{@team.position}"}
      >
        +
      </button>
    </div>
    """
  end

  ## Helpers

  defp assign_show(socket, %Show{} = show) do
    socket
    |> assign(:show, show)
    |> assign(:form, to_form(Broadcasts.change_show(show)))
  end

  defp apply_result({:ok, %Show{} = show}, socket), do: {:noreply, assign_show(socket, show)}

  defp apply_result({:error, %Ecto.Changeset{} = changeset}, socket),
    do: {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}

  defp apply_result({:error, reason}, socket),
    do: {:noreply, put_flash(socket, :error, "Could not apply that change (#{inspect(reason)}).")}

  defp sorted_teams(show), do: show.teams |> List.wrap() |> Enum.sort_by(& &1.position)

  defp game_id(form), do: form.data.id
  defp talent_id(form), do: form.data.id
end
