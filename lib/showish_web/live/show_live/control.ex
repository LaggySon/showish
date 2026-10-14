defmodule ShowishWeb.ShowLive.Control do
  @moduledoc """
  The control room.

  Everything on this page writes straight through to the show and out to every
  connected overlay, so what an operator types is on air a moment later. The
  live controls exist because mid-match there is no time to tab through a form:
  for a series they are a strip that sticks to the top of the window and never
  moves; a sport with more to drive (baseball) gets its own console instead.
  """

  use ShowishWeb, :live_view

  import ShowishWeb.ShowLive.Components

  alias Showish.Broadcasts
  alias Showish.Broadcasts.Preset
  alias Showish.Broadcasts.Show
  alias Showish.Broadcasts.Sport
  alias Showish.Broadcasts.Team
  alias ShowishWeb.Scenes
  alias ShowishWeb.SportControls
  alias ShowishWeb.Status

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    if connected?(socket), do: Broadcasts.subscribe(slug)

    show = Broadcasts.get_show_by_slug!(socket.assigns.current_scope, slug)

    {:ok,
     socket
     |> assign(:page_title, "#{show.title} · Control room")
     |> assign(:saved_at, nil)
     |> assign(:save_failed, false)
     |> assign(:team_profiles, Broadcasts.list_team_profiles(socket.assigns.current_scope))
     |> assign_show(show)}
  end

  # The previewed scene lives in the URL, so a refresh keeps it (DESIGN.md
  # section 12.2).
  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, assign_preview(socket, params["scene"])}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :sport, Sport.fetch(assigns.show.sport))

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@show.title}
        <:aside>
          <span class="ui-mono">/{@show.slug}</span>
        </:aside>
      </.header>

      <.show_nav show={@show} current={:control} />

      <div id="control-room">
        <SportControls.panel :if={@show.sport != "baseball"} show={@show} />

        <div class="app-control-room">
          <div class="app-control-preview">
            <.preview show={@show} scene={Scenes.fetch(@preview_scene)} />
          </div>

          <div class="app-control-edit">
            <.collapsible_panel
              :if={@show.sport == "baseball"}
              id="live-controls-panel"
              title={@sport.control_title}
              open
            >
              <:aside>{@sport.control_summary}</:aside>
              <SportControls.panel show={@show} />
            </.collapsible_panel>

            <.form
              for={@form}
              id="control-form"
              class="app-control-form"
              phx-change="save"
              phx-submit="save"
            >
              <div
                :if={@save_failed}
                id="save-failed"
                class="ui-notice"
                data-status="failure"
                role="alert"
              >
                Not saved. Fix the fields with an error below; the overlays keep the last saved version.
              </div>

              <.collapsible_panel id="match-config-panel" title="Match">
                <:aside>
                  <.save_state id="saved-match" saved_at={@saved_at} failed={@save_failed} />
                </:aside>
                <div class="app-fields">
                  <.input field={@form[:title]} label="Title" required prose phx-debounce="500" />
                  <.input
                    field={@form[:slug]}
                    label="URL slug"
                    required
                    phx-debounce="blur"
                    hint="Part of every overlay URL. Changing it moves them all."
                  />
                  <.input
                    field={@form[:stage]}
                    label="Stage"
                    placeholder="Grand Finals"
                    prose
                    phx-debounce="500"
                  />
                  <.input
                    field={@form[:subtitle]}
                    label="Subtitle"
                    placeholder="Week 5"
                    prose
                    phx-debounce="500"
                  />
                  <.input
                    field={@form[:sport]}
                    type="select"
                    label="Sport"
                    options={Sport.options()}
                    hint="Switching changes the live controls and the scenes on offer."
                  />
                  <.input
                    field={@form[:preset]}
                    type="select"
                    label="Look"
                    options={Preset.options()}
                    hint={Preset.fetch(@show.preset).summary}
                  />
                  <.input
                    :if={@show.sport == "esports"}
                    field={@form[:best_of]}
                    type="number"
                    min="1"
                    label="Best of"
                  />
                  <.input
                    field={@form[:starts_at]}
                    type="datetime-local"
                    label="Countdown target (UTC)"
                    hint="The standby scene counts down to it."
                  />
                  <.input field={@form[:accent_color]} type="color" label="Accent color" />
                  <.input
                    field={@form[:break_message]}
                    label="Break message"
                    prose
                    phx-debounce="500"
                    class="app-field-wide"
                  />
                </div>
              </.collapsible_panel>

              <.collapsible_panel id="copy-config-panel" title="Scorebug and ticker">
                <:aside>
                  <.save_state id="saved-copy" saved_at={@saved_at} failed={@save_failed} />
                </:aside>
                <div class="app-fields">
                  <div
                    :for={{side, label} <- [left: "left", center: "centre", right: "right"]}
                    class="app-status-field"
                  >
                    <.input
                      field={@form[:"status_#{side}"]}
                      label={"Status, #{label}"}
                      prose
                      phx-debounce="500"
                    />
                    <.input field={@form[:"show_status_#{side}"]} type="checkbox" label="Show on air" />
                  </div>
                </div>
                <p class="ui-hint app-after-fields">
                  With the centre status off, the scorebug describes the current game instead.
                </p>
                <div class="app-fields app-after-fields">
                  <.input
                    :if={@show.sport == "esports"}
                    field={@form[:show_sides]}
                    type="checkbox"
                    label="Show side labels on the scorebug"
                    class="app-field-wide"
                  />
                  <.input
                    field={@form[:ticker]}
                    type="textarea"
                    rows="2"
                    label="Ticker"
                    prose
                    phx-debounce="500"
                    class="app-field-full"
                  />
                </div>
              </.collapsible_panel>

              <.collapsible_panel id="teams-config-panel" title="Teams">
                <:aside>
                  <.save_state id="saved-teams" saved_at={@saved_at} failed={@save_failed} />
                </:aside>
                <p class="ui-hint app-panel-note">
                  Team colors drive every scene. Take them from the team's kit.
                </p>
                <div class="app-items">
                  <.inputs_for :let={tf} field={@form[:teams]}>
                    <.team_item form={tf} show={@show} team_profiles={@team_profiles} />
                  </.inputs_for>
                </div>
              </.collapsible_panel>

              <.collapsible_panel
                :if={@show.sport == "esports"}
                id="series-config-panel"
                title="Series"
              >
                <:aside>
                  <span class="ui-mono">{count(length(@show.games), "game")}</span>
                  <span class="ui-sep" aria-hidden="true">·</span>
                  <.save_state id="saved-series" saved_at={@saved_at} failed={@save_failed} />
                </:aside>
                <div :if={@show.games == []} class="ui-empty">
                  No games yet. Add the first game to build the series.
                  <.add_button id="add-game" event="add_game">+ Add game</.add_button>
                </div>
                <ol :if={@show.games != []} class="app-items" aria-label="Games">
                  <.inputs_for :let={gf} field={@form[:games]} skip_hidden>
                    <.game_item
                      form={gf}
                      show={@show}
                      number={gf.index + 1}
                      count={length(@show.games)}
                    />
                  </.inputs_for>
                </ol>
                <div :if={@show.games != []} class="app-after-fields">
                  <.add_button id="add-game" event="add_game">+ Add game</.add_button>
                </div>
              </.collapsible_panel>

              <.collapsible_panel id="talent-config-panel" title="Talent">
                <:aside>
                  <span class="ui-mono">{count(length(@show.talents), "person", "people")}</span>
                  <span class="ui-sep" aria-hidden="true">·</span>
                  <.save_state id="saved-talent" saved_at={@saved_at} failed={@save_failed} />
                </:aside>
                <p class="ui-hint app-panel-note">
                  Drives the lower thirds, the caster cams and the credit roll.
                </p>
                <div :if={@show.talents == []} class="ui-empty">
                  No talent yet. Add a person to fill the lower thirds and the credits.
                  <.add_button id="add-talent" event="add_talent">+ Add person</.add_button>
                </div>
                <ol :if={@show.talents != []} class="app-items" aria-label="Talent">
                  <.inputs_for :let={pf} field={@form[:talents]} skip_hidden>
                    <.talent_item form={pf} number={pf.index + 1} count={length(@show.talents)} />
                  </.inputs_for>
                </ol>
                <div :if={@show.talents != []} class="app-after-fields">
                  <.add_button id="add-talent" event="add_talent">+ Add person</.add_button>
                </div>
              </.collapsible_panel>
            </.form>
          </div>
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
         |> put_flash(
           :info,
           "URL slug changed to #{slug}. Every overlay URL for this show has moved; update your browser sources."
         )
         |> push_navigate(to: ~p"/shows/#{slug}/control?#{[scene: socket.assigns.preview_scene]}")}

      {:ok, show} ->
        {:noreply,
         socket
         |> assign(saved_at: DateTime.utc_now(), save_failed: false)
         |> assign_show(show)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:save_failed, true)
         |> assign(:form, to_form(changeset, action: :validate))}
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
         |> put_flash(:info, "Saved #{Team.full_name(team)} to the team library.")}

      {:error, changeset} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Saving #{Team.full_name(team)} to the team library failed (#{inspect(changeset.errors)})."
         )}
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
    scene = assign_preview(socket, scene).assigns.preview_scene

    {:noreply,
     push_patch(socket, to: ~p"/shows/#{socket.assigns.show.slug}/control?#{[scene: scene]}")}
  end

  # Another operator changed something. Refresh the state the buttons read from,
  # but leave the form alone so we never yank a field out from under someone
  # who is mid-sentence.
  @impl true
  def handle_info({:show_updated, show}, socket) do
    {:noreply, socket |> assign(:show, show) |> assign_preview(socket.assigns[:preview_scene])}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  ## Components

  attr :show, :any, required: true
  attr :scene, :map, required: true

  defp preview(assigns) do
    assigns = assign(assigns, :url, Scenes.url(assigns.show.slug, assigns.scene.key))

    ~H"""
    <.collapsible_panel id="preview-panel" title="Preview" open>
      <:aside>{@scene.name} · 1920×1080</:aside>
      <form id="preview-form" phx-change="preview" class="app-preview-picker">
        <label class="ui-field ui-field--inline">
          <span class="ui-field-label">Scene</span>
          <select name="scene" class="ui-select ui-input--compact" aria-describedby="preview-summary">
            {Phoenix.HTML.Form.options_for_select(
              Enum.map(Scenes.for_sport(@show.sport), &{&1.name, &1.key}),
              @scene.key
            )}
          </select>
        </label>
        <span id="preview-summary" class="ui-hint">{@scene.summary}</span>
      </form>
      <div class="ui-preview ui-checker" style="--preview-ratio: 16 / 9">
        <iframe
          id={"preview-#{@scene.key}"}
          src={Scenes.path(@show.slug, @scene.key)}
          title={"#{@scene.name} preview"}
        >
        </iframe>
      </div>
      <div class="app-url-row app-after-fields">
        <code class="ui-pre ui-truncate" title={@url}>{@url}</code>
        <button
          type="button"
          id={"copy-preview-#{@scene.key}"}
          phx-hook="ClipboardCopy"
          data-clipboard-text={@url}
          class="ui-button ui-button--ghost ui-button--small"
          aria-label={"Copy the #{@scene.name} URL"}
        >
          Copy
        </button>
        <a
          href={Scenes.path(@show.slug, @scene.key)}
          target="_blank"
          class="ui-button ui-button--ghost ui-button--small"
          aria-label={"Open #{@scene.name} in a new tab"}
        >
          Open <span aria-hidden="true">↗</span>
        </a>
      </div>
    </.collapsible_panel>
    """
  end

  attr :form, :any, required: true
  attr :show, :any, required: true
  attr :team_profiles, :list, required: true

  defp team_item(assigns) do
    assigns = assign(assigns, :position, assigns.form.data.position)

    ~H"""
    <details
      phx-mounted={JS.ignore_attributes(["open"])}
      id={"team-config-#{@position}"}
      class="app-item app-team"
    >
      <summary class="app-item-header app-team-summary">
        <span class="app-item-title">
          <span class="app-collapsible-name">Team {@form.index + 1}</span>
          <span :if={@form.data.name not in [nil, ""]} class="ui-muted app-item-name">
            {@form.data.name}
          </span>
        </span>
        <span :if={@form.data.code not in [nil, ""]} class="ui-badge ui-badge--data">
          {@form.data.code}
        </span>
      </summary>
      <div class="app-fields">
        <.input field={@form[:name]} label="Name" prose phx-debounce="500" />
        <.input field={@form[:short_name]} label="Short name" prose phx-debounce="500" />
        <.input field={@form[:code]} label="Code" placeholder="ABC" phx-debounce="500" />
        <.input field={@form[:record]} label="Record" placeholder="4-1" phx-debounce="500" />
        <.input
          field={@form[:side]}
          label="Side label"
          placeholder="Attack"
          prose
          phx-debounce="500"
        />
        <.input
          field={@form[:score]}
          type="number"
          min="0"
          label={if(@show.sport == "baseball", do: "Runs", else: "Series score")}
        />
        <.input field={@form[:primary_color]} type="color" label="Primary color" />
        <.input field={@form[:secondary_color]} type="color" label="Secondary color" />
        <.input
          field={@form[:logo_url]}
          label="Logo URL"
          placeholder="https://example.com/logo.svg"
          phx-debounce="blur"
          class="app-field-full"
        />
      </div>
      <div class="ui-button-group app-after-fields">
        <button
          id={"save-team-profile-#{@position}"}
          type="button"
          class="ui-button ui-button--small"
          phx-click="save_team_profile"
          phx-value-position={@position}
        >
          Save to team library
        </button>
        <details
          :if={@team_profiles != []}
          phx-mounted={JS.ignore_attributes(["open"])}
          id={"team-library-menu-#{@position}"}
          class="ui-menu"
        >
          <summary class="ui-button ui-button--small">Use saved team ▾</summary>
          <div class="ui-menu-panel app-menu-left">
            <button
              :for={profile <- @team_profiles}
              id={"apply-team-profile-#{@position}-#{profile.id}"}
              type="button"
              class="ui-button ui-button--ghost ui-button--small app-menu-item"
              phx-click="apply_team_profile"
              phx-value-position={@position}
              phx-value-profile-id={profile.id}
            >
              {profile.name}
            </button>
          </div>
        </details>
        <span class="ui-hint">The library is shared by every show on this account.</span>
      </div>
    </details>
    """
  end

  attr :form, :any, required: true
  attr :show, :any, required: true
  attr :number, :integer, required: true
  attr :count, :integer, required: true

  defp game_item(assigns) do
    {word, role} = Status.game(assigns.show, assigns.number, assigns.form.data)
    {team_a, team_b} = {Show.team(assigns.show, 1), Show.team(assigns.show, 2)}

    assigns =
      assign(assigns,
        word: word,
        role: role,
        current?: assigns.number == assigns.show.current_game,
        name_a: team_a && Team.display_name(team_a),
        name_b: team_b && Team.display_name(team_b)
      )

    ~H"""
    <li
      id={"game-#{@form.data.id}"}
      class={["app-item", @current? && "ui-rail"]}
      data-status={@current? && "progress"}
      aria-current={@current? && "true"}
    >
      <.hidden_inputs form={@form} />
      <div class="app-item-header">
        <h3 class="app-item-title">Game {@number}</h3>
        <span class="ui-badge" data-status={@role}>{@word}</span>
        <div class="ui-button-group app-item-actions">
          <button
            type="button"
            class="ui-button ui-button--small"
            phx-click="set_game"
            phx-value-number={@number}
            disabled={@current?}
            title={@current? && "Game #{@number} is on air"}
          >
            Put on air
          </button>
          <.reorder_buttons
            event="move_game"
            id={@form.data.id}
            noun={"game #{@number}"}
            first?={@number == 1}
            last?={@number == @count}
          />
          <button
            type="button"
            class="ui-button ui-button--small ui-button--danger"
            phx-click="delete_game"
            phx-value-id={@form.data.id}
            data-confirm={"Remove game #{@number}?"}
            data-confirm-body="Its name, scores and result are deleted. This cannot be undone."
            data-confirm-action="Remove game"
          >
            Remove
          </button>
        </div>
      </div>
      <div class="app-fields">
        <.input
          field={@form[:name]}
          label="Name"
          placeholder="Map or level"
          prose
          phx-debounce="500"
        />
        <.input field={@form[:mode]} label="Mode" placeholder="Control" prose phx-debounce="500" />
        <.input field={@form[:score_a]} type="number" min="0" label={"#{@name_a || "Team 1"} score"} />
        <.input field={@form[:score_b]} type="number" min="0" label={"#{@name_b || "Team 2"} score"} />
        <.input
          field={@form[:winner]}
          type="select"
          label="Winner"
          options={[
            {"Undecided", ""},
            {@name_a || "Team 1", "a"},
            {@name_b || "Team 2", "b"},
            {"Draw", "draw"}
          ]}
        />
        <.input field={@form[:completed]} type="checkbox" label="Played" class="app-check-field" />
        <.input
          field={@form[:image_url]}
          label="Image URL"
          placeholder="https://example.com/map.jpg"
          phx-debounce="blur"
          class="app-field-wide"
        />
        <.input field={@form[:info]} label="Note" prose phx-debounce="500" class="app-field-wide" />
      </div>
    </li>
    """
  end

  attr :form, :any, required: true
  attr :number, :integer, required: true
  attr :count, :integer, required: true

  defp talent_item(assigns) do
    assigns = assign(assigns, :name, talent_name(assigns.form.data, assigns.number))

    ~H"""
    <li id={"talent-#{@form.data.id}"} class="app-item">
      <.hidden_inputs form={@form} />
      <div class="app-item-header">
        <h3 class="app-item-title">
          <span class="ui-mono">#{@number}</span>
          <span :if={@form.data.name not in [nil, ""]} class="app-item-name">{@form.data.name}</span>
        </h3>
        <div class="ui-button-group app-item-actions">
          <.reorder_buttons
            event="move_talent"
            id={@form.data.id}
            noun={@name}
            first?={@number == 1}
            last?={@number == @count}
          />
          <button
            type="button"
            class="ui-button ui-button--small ui-button--danger"
            phx-click="delete_talent"
            phx-value-id={@form.data.id}
            data-confirm={"Remove #{@name}?"}
            data-confirm-body="They leave the lower thirds, the caster cams and the credits at once."
            data-confirm-action="Remove person"
          >
            Remove
          </button>
        </div>
      </div>
      <div class="app-fields">
        <.input field={@form[:role]} label="Role" placeholder="Caster" prose phx-debounce="500" />
        <.input field={@form[:name]} label="Name" prose phx-debounce="500" />
        <.input
          field={@form[:pronouns]}
          label="Pronouns"
          placeholder="they/them"
          prose
          phx-debounce="500"
        />
        <.input field={@form[:social]} label="Social" placeholder="@handle" phx-debounce="500" />
        <.input field={@form[:on_cam]} type="checkbox" label="On camera" class="app-check-field" />
      </div>
    </li>
    """
  end

  # The id fields inputs_for would otherwise put straight into the <ol>.
  attr :form, :any, required: true

  defp hidden_inputs(assigns) do
    ~H"""
    <input
      :for={{key, value} <- @form.hidden}
      type="hidden"
      name={Phoenix.HTML.Form.input_name(@form, key)}
      value={value}
    />
    """
  end

  # Up and down buttons for a list item (DESIGN.md section 7.28). The first
  # item cannot go up and the last cannot go down.
  attr :event, :string, required: true
  attr :id, :any, required: true
  attr :noun, :string, required: true
  attr :first?, :boolean, required: true
  attr :last?, :boolean, required: true

  defp reorder_buttons(assigns) do
    ~H"""
    <button
      type="button"
      class="ui-button ui-button--ghost ui-button--small"
      phx-click={@event}
      phx-value-id={@id}
      phx-value-delta="-1"
      disabled={@first?}
      title={@first? && "Already first"}
      aria-label={"Move #{@noun} up"}
    >
      ↑
    </button>
    <button
      type="button"
      class="ui-button ui-button--ghost ui-button--small"
      phx-click={@event}
      phx-value-id={@id}
      phx-value-delta="1"
      disabled={@last?}
      title={@last? && "Already last"}
      aria-label={"Move #{@noun} down"}
    >
      ↓
    </button>
    """
  end

  attr :id, :string, required: true
  attr :event, :string, required: true
  slot :inner_block, required: true

  defp add_button(assigns) do
    ~H"""
    <button type="button" id={@id} class="ui-button ui-button--compact" phx-click={@event}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  ## Helpers

  defp assign_show(socket, %Show{} = show) do
    socket
    |> assign(:show, show)
    |> assign(:form, to_form(Broadcasts.change_show(show)))
    |> assign_preview(socket.assigns[:preview_scene])
  end

  # Only the scenes the show's sport offers can be previewed; anything else
  # (an old URL, a sport switch) falls back to the first of them.
  defp assign_preview(socket, scene) do
    available = Enum.map(Scenes.for_sport(socket.assigns.show.sport), & &1.key)
    assign(socket, :preview_scene, if(scene in available, do: scene, else: hd(available)))
  end

  defp apply_result({:ok, %Show{} = show}, socket),
    do: {:noreply, socket |> assign(:save_failed, false) |> assign_show(show)}

  defp apply_result({:error, %Ecto.Changeset{} = changeset}, socket),
    do: {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}

  defp apply_result({:error, reason}, socket),
    do:
      {:noreply,
       put_flash(
         socket,
         :error,
         "Change failed: #{describe(reason)}. Reload the page to see the show as it is now."
       )}

  defp describe(:no_such_team), do: "that team no longer exists"
  defp describe(:no_such_game), do: "that game no longer exists"
  defp describe(:no_such_talent), do: "that person is no longer on the show"
  defp describe(:not_found), do: "that item no longer exists"
  defp describe(reason), do: inspect(reason)

  defp talent_name(%{name: name}, _number) when is_binary(name) and name != "", do: name
  defp talent_name(_talent, number), do: "person #{number}"

  defp count(n, singular, plural \\ nil)
  defp count(1, singular, _plural), do: "1 #{singular}"
  defp count(n, singular, plural), do: "#{n} #{plural || singular <> "s"}"
end
