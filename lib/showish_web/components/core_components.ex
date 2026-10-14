defmodule ShowishWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  The control room follows the Laggish design guide (`DESIGN.md` in the
  project root): flat, dense, grayscale chrome with color only where something
  has a state. These components render the guide's `ui-*` classes from
  `assets/css/components.css`, so templates keep using `<.button>`, `<.input>`
  and friends and get the look for free.

  Tailwind is still available for layout (flex, grid, gaps). Colors, type,
  borders and shapes come from the `ui-*` classes and the tokens, never from
  utilities.

  The overlays are product output with their own design and do not use these
  components; see `ShowishWeb.OverlayComponents`.
  """
  use Phoenix.Component
  use Gettext, backend: ShowishWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders a flash message as a notice at the top of the page.

  Info messages are a progress notice, errors a failure notice. A notice stays
  until the user dismisses it or navigates away; there are no toasts.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} id="save-error">Save failed.</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      class="ui-notice"
      data-status={if @kind == :error, do: "failure", else: "progress"}
      role={if @kind == :error, do: "alert", else: "status"}
      {@rest}
    >
      <span>{msg}</span>
      <button
        type="button"
        class="ui-button ui-button--ghost ui-button--small ui-notice-end"
        aria-label={gettext("Dismiss")}
        phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      >
        ✕
      </button>
    </div>
    """
  end

  @doc """
  Renders a button, or a link that looks like one.

  Labels are a verb or a verb and a noun. An action that adds an item starts
  with "+ ". While the action runs, pass `phx-disable-with="Saving…"`.

  ## Examples

      <.button>Retry</.button>
      <.button variant="primary" phx-disable-with="Creating…">Create show</.button>
      <.button variant="danger" size="small" data-confirm="Delete 1 show?">Delete</.button>
      <.button navigate={~p"/"} variant="ghost">Cancel</.button>
  """
  attr :rest, :global,
    include: ~w(href navigate patch method download name value disabled type form target)

  attr :class, :any, default: nil, doc: "extra classes, for layout only"

  attr :variant, :string,
    default: nil,
    values: [nil | ~w(primary danger quiet ghost)],
    doc: "primary is the one commit action of a region, danger is destructive"

  attr :size, :string, default: nil, values: [nil | ~w(compact small)]
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    assigns =
      assign(assigns, :classes, [
        "ui-button",
        assigns.variant && "ui-button--#{assigns.variant}",
        assigns.size && "ui-button--#{assigns.size}",
        assigns.class
      ])

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@classes} {@rest}>{render_slot(@inner_block)}</.link>
      """
    else
      ~H"""
      <button class={@classes} {@rest}>{render_slot(@inner_block)}</button>
      """
    end
  end

  @doc """
  Renders an input with its label, hint and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  The label sits above the field and the hint under it. Values are set in the
  mono face; pass `prose` for a field that holds a sentence or a name.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values, with
      the label to the right of the box

    * `type="color"` renders the picker next to its value in mono, because a
      color chosen by a user is shown as a swatch and its hex code

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as radio, are best
  written directly in your templates.

  ## Examples

  ```heex
  <.input field={@form[:title]} label="Title" prose />
  <.input field={@form[:slug]} label="URL slug" hint="Part of every overlay URL." />
  ```

  ## Select type

  When using `type="select"`, you must pass the `options` and optionally
  a `value` to mark which option should be preselected.

  ```heex
  <.input field={@form[:user_type]} type="select" options={["Admin": "admin", "User": "user"]} />
  ```

  For more information on what kind of data can be passed to `options` see
  [`options_for_select`](https://hexdocs.pm/phoenix_html/Phoenix.HTML.Form.html#options_for_select/2).
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :hint, :string, default: nil, doc: "a short line under the field"
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :prose, :boolean, default: false, doc: "set the value in the sans face"

  attr :required, :boolean,
    default: false,
    doc: "mark the field as required; the server still validates it"

  attr :class, :any, default: nil, doc: "extra classes for the field wrapper, for layout only"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assigns
      |> assign_new(:checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)
      |> assign_described_by()

    ~H"""
    <div class={["ui-field", @class]}>
      <label class="app-check">
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          aria-invalid={@errors != [] && "true"}
          aria-required={@required && "true"}
          aria-describedby={@described_by}
          {@rest}
        />
        <span>{@label}</span>
      </label>
      <.hint :if={@hint} id={"#{@id}-hint"}>{@hint}</.hint>
      <.error :if={@errors != []} id={"#{@id}-error"} messages={@errors} />
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    assigns = assign_described_by(assigns)

    ~H"""
    <div class={["ui-field", @class]}>
      <label :if={@label} for={@id} class="ui-field-label">
        {@label}<span :if={@required} class="ui-required" aria-hidden="true">*</span>
      </label>
      <select
        id={@id}
        name={@name}
        class="ui-select"
        multiple={@multiple}
        aria-invalid={@errors != [] && "true"}
        aria-required={@required && "true"}
        aria-describedby={@described_by}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <.hint :if={@hint} id={"#{@id}-hint"}>{@hint}</.hint>
      <.error :if={@errors != []} id={"#{@id}-error"} messages={@errors} />
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    assigns = assign_described_by(assigns)

    ~H"""
    <div class={["ui-field", @class]}>
      <label :if={@label} for={@id} class="ui-field-label">
        {@label}<span :if={@required} class="ui-required" aria-hidden="true">*</span>
      </label>
      <textarea
        id={@id}
        name={@name}
        class={["ui-textarea", @prose && "app-prose"]}
        aria-invalid={@errors != [] && "true"}
        aria-required={@required && "true"}
        aria-describedby={@described_by}
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      <.hint :if={@hint} id={"#{@id}-hint"}>{@hint}</.hint>
      <.error :if={@errors != []} id={"#{@id}-error"} messages={@errors} />
    </div>
    """
  end

  def input(%{type: "color"} = assigns) do
    assigns = assign_described_by(assigns)

    ~H"""
    <div class={["ui-field", @class]}>
      <label :if={@label} for={@id} class="ui-field-label">
        {@label}<span :if={@required} class="ui-required" aria-hidden="true">*</span>
      </label>
      <div class="app-color">
        <input
          type="color"
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value("color", @value)}
          class="app-color-input"
          aria-invalid={@errors != [] && "true"}
          aria-required={@required && "true"}
          aria-describedby={@described_by}
          {@rest}
        />
        <span class="ui-mono">{format_color(@value)}</span>
      </div>
      <.hint :if={@hint} id={"#{@id}-hint"}>{@hint}</.hint>
      <.error :if={@errors != []} id={"#{@id}-error"} messages={@errors} />
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    assigns = assign_described_by(assigns)

    ~H"""
    <div class={["ui-field", @class]}>
      <label :if={@label} for={@id} class="ui-field-label">
        {@label}<span :if={@required} class="ui-required" aria-hidden="true">*</span>
      </label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={["ui-input", @prose && "app-prose"]}
        aria-invalid={@errors != [] && "true"}
        aria-required={@required && "true"}
        aria-describedby={@described_by}
        {@rest}
      />
      <.hint :if={@hint} id={"#{@id}-hint"}>{@hint}</.hint>
      <.error :if={@errors != []} id={"#{@id}-error"} messages={@errors} />
    </div>
    """
  end

  # Points the input at its hint and its error, so a screen reader reads both.
  defp assign_described_by(assigns) do
    ids =
      [assigns.hint && "#{assigns.id}-hint", assigns.errors != [] && "#{assigns.id}-error"]
      |> Enum.filter(& &1)

    assign(assigns, :described_by, if(ids != [], do: Enum.join(ids, " ")))
  end

  defp format_color("#" <> _ = hex), do: String.upcase(hex)
  defp format_color(_value), do: "—"

  attr :id, :string, required: true
  slot :inner_block, required: true

  defp hint(assigns) do
    ~H"""
    <span id={@id} class="ui-hint">{render_slot(@inner_block)}</span>
    """
  end

  # Helper used by inputs to generate form errors. Ecto's messages are
  # fragments ("can't be blank"); the hint writes them as sentences.
  attr :id, :string, required: true
  attr :messages, :list, required: true

  defp error(assigns) do
    ~H"""
    <span id={@id} class="ui-hint ui-hint--error">{Enum.map_join(@messages, " ", &sentence/1)}</span>
    """
  end

  defp sentence(message) do
    {first, rest} = String.split_at(message, 1)
    String.upcase(first) <> String.trim_trailing(rest, ".") <> "."
  end

  @doc """
  Renders the page header: the title on the left and a muted aside on the
  right (counts, state, actions), baseline-aligned.

  ## Examples

      <.header>
        Shows
        <:aside><span class="ui-mono">3 shows</span></:aside>
      </.header>
  """
  slot :inner_block, required: true
  slot :aside, doc: "counts, state and the page's actions, on the right"

  def header(assigns) do
    ~H"""
    <header class="ui-page-header">
      <h1 class="ui-title">{render_slot(@inner_block)}</h1>
      <div :if={@aside != []} class="ui-title-aside">{render_slot(@aside)}</div>
    </header>
    """
  end

  @doc """
  Renders a panel: a hairline box with a micro-label title.

  ## Examples

      <.panel id="match" title="Match">
        <:aside>saved 2s ago</:aside>
        ...
      </.panel>
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :class, :any, default: nil
  attr :rest, :global
  slot :aside, doc: "a short note or controls on the right of the title row"
  slot :inner_block, required: true

  def panel(assigns) do
    ~H"""
    <section id={@id} class={["ui-panel", @class]} aria-labelledby={"#{@id}-title"} {@rest}>
      <h2 class="ui-panel-title" id={"#{@id}-title"}>
        {@title}
        <span :if={@aside != []} class="ui-panel-title-aside">{render_slot(@aside)}</span>
      </h2>
      {render_slot(@inner_block)}
    </section>
    """
  end

  @doc """
  Renders a table.

  Cells do not wrap. Give a column `class="ui-cell-mono"` for IDs and values,
  `"ui-cell-num"` for numbers and `"ui-cell-wrap"` for prose.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="ID" class="ui-cell-mono">{user.id}</:col>
        <:col :let={user} label="Username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
    attr :class, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="ui-table-wrap">
      <table class="ui-table">
        <thead>
          <tr>
            <th :for={col <- @col} class={col[:class]}>{col[:label]}</th>
            <th :if={@action != []}>
              <span class="ui-sr-only">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
            <td :for={col <- @col} class={col[:class]}>
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []}>
              <div class="ui-button-group app-row-actions">
                <%= for action <- @action do %>
                  {render_slot(action, @row_item.(row))}
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a key-value list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <dl class="ui-kv">
      <%= for item <- @item do %>
        <dt>{item.title}</dt>
        <dd>{render_slot(item)}</dd>
      <% end %>
    </dl>
    """
  end

  @doc """
  Renders a glyph.

  The design guide uses Unicode glyphs instead of an icon library. The names
  are the Heroicon names this app used before, mapped to their glyph. A glyph
  next to a word is decoration; an icon-only button needs an `aria-label`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" />
  """
  attr :name, :string, required: true

  @glyphs %{
    "hero-x-mark" => "✕",
    "hero-arrow-up-mini" => "↑",
    "hero-arrow-down-mini" => "↓",
    "hero-arrows-right-left-mini" => "⇄",
    "hero-arrow-path" => "↻",
    "hero-pencil" => "✎",
    "hero-arrow-top-right-on-square" => "↗",
    "hero-check" => "✓"
  }

  def icon(%{name: name} = assigns) do
    assigns = assign(assigns, :glyph, Map.fetch!(@glyphs, name))

    ~H"""
    <span aria-hidden="true">{@glyph}</span>
    """
  end

  ## JS Commands

  # Nothing moves or fades in (DESIGN.md section 8), so these show and hide
  # without a transition.
  def show(js \\ %JS{}, selector) do
    JS.show(js, to: selector)
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js, to: selector)
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(ShowishWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(ShowishWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
