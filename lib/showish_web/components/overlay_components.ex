defmodule ShowishWeb.OverlayComponents do
  @moduledoc """
  Building blocks shared by every overlay scene.

  Overlays are drawn on a fixed 1920x1080 canvas and composited over live video,
  so components here lean on inline styles for anything driven by operator input
  (team colors) and on Tailwind for everything structural.
  """

  use Phoenix.Component

  alias Showish.Broadcasts.Preset
  alias Showish.Broadcasts.Team
  alias Showish.Colors
  alias Showish.Text

  @doc """
  The 1920x1080 canvas every scene is drawn on.

  The `OverlayScale` hook shrinks it to fit smaller viewports so the same URL
  works as a browser source and as a preview, without changing any layout math.
  """
  attr :class, :any, default: nil
  attr :id, :string, default: "overlay-stage"
  attr :preset, :string, default: nil
  attr :accent, :string, default: nil
  slot :inner_block, required: true

  def stage(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="OverlayScale"
      class={["overlay-stage", stage_class(@preset), @class]}
      style={@accent && "--overlay-accent: #{@accent};"}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The class that scopes a preset's styles to this stage.

      iex> ShowishWeb.OverlayComponents.stage_class("tranquility")
      "preset-tranquility"

      iex> ShowishWeb.OverlayComponents.stage_class(nil)
      "preset-broadcast"
  """
  def stage_class(key), do: "preset-" <> Preset.fetch(key).key

  @doc """
  A team's logo, or a colored plate with its code when no logo is configured.

  `radius` names a corner-radius token rather than a pixel size, so a preset
  controls it: `"logo"` (default) or `"hero"` for the larger standby plate.
  """
  attr :team, :any, required: true
  attr :size, :integer, default: 64
  attr :radius, :string, default: "logo", values: ~w(pill logo card hero)
  attr :class, :any, default: nil

  def team_logo(assigns) do
    ~H"""
    <div
      class={[
        "overlay-logo flex shrink-0 items-center justify-center overflow-hidden",
        "overlay-round-#{@radius}",
        logo?(@team) && "overlay-logo-image",
        !logo?(@team) && "overlay-logo-plate",
        @class
      ]}
      style={"width: #{@size}px; height: #{@size}px; #{team_vars(@team)}"}
    >
      <img
        :if={logo?(@team)}
        src={@team.logo_url}
        alt={Team.full_name(@team)}
        class="h-full w-full object-contain"
      />
      <span
        :if={!logo?(@team)}
        class="font-black leading-none"
        style={"font-size: #{round(@size * 0.34)}px; color: #{contrast(@team)}"}
      >
        {initials(@team)}
      </span>
    </div>
    """
  end

  @doc """
  A countdown to `target`, recomputed from the `now` assign the overlay ticks.
  """
  attr :target, :any, default: nil
  attr :now, :any, required: true
  attr :class, :any, default: nil

  def countdown(assigns) do
    ~H"""
    <span class={["tabular", @class]}>{format_countdown(@target, @now)}</span>
    """
  end

  @doc """
  Formats the time remaining until `target` as `MM:SS`, or `H:MM:SS` past an
  hour. Returns `00:00` once the target has passed, which is what a director
  wants on screen rather than a negative number.

      iex> ShowishWeb.OverlayComponents.format_countdown(nil, DateTime.utc_now())
      "00:00"
  """
  def format_countdown(nil, _now), do: "00:00"

  def format_countdown(%DateTime{} = target, %DateTime{} = now) do
    target
    |> DateTime.diff(now, :second)
    |> max(0)
    |> format_seconds()
  end

  defp format_seconds(seconds) do
    hours = div(seconds, 3600)
    minutes = seconds |> rem(3600) |> div(60)
    secs = rem(seconds, 60)

    if hours > 0 do
      "#{hours}:#{pad(minutes)}:#{pad(secs)}"
    else
      "#{pad(minutes)}:#{pad(secs)}"
    end
  end

  defp pad(number), do: number |> Integer.to_string() |> String.pad_leading(2, "0")

  @doc """
  A small uppercase label, used for stage names, roles and side indicators.
  """
  attr :class, :any, default: nil
  attr :color, :string, default: nil
  slot :inner_block, required: true

  def eyebrow(assigns) do
    ~H"""
    <span
      class={[
        "overlay-eyebrow text-[13px] font-semibold uppercase leading-none tracking-[0.22em] opacity-90",
        @class
      ]}
      style={@color && "color: #{@color}"}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc """
  A person's name plate: their role, their name, and the pronouns and handle
  they gave, if they gave any.

  Shared by the lower thirds and the caster-cam plates, which differ only in how
  much room they have to say it in — a lower third has the width of the frame, a
  cam plate the width of one camera window. Everything else about putting a name
  on air is decided here, once.
  """
  attr :talent, :any, required: true
  attr :accent, :string, required: true
  attr :size, :atom, default: :large, values: [:large, :compact]

  def talent_details(assigns) do
    assigns = assign(assigns, :type, talent_type_scale(assigns.size))

    ~H"""
    <.eyebrow color={@accent}>{Text.presence(@talent.role, "Talent")}</.eyebrow>

    <div class={["overlay-talent-name truncate font-black uppercase leading-none", @type.name]}>
      {Text.presence(@talent.name, "TBD")}
    </div>

    <div
      :if={Text.present?(@talent.pronouns) or Text.present?(@talent.social)}
      class={["overlay-talent-sub flex items-baseline gap-3", @type.meta]}
    >
      <span
        :if={Text.present?(@talent.pronouns)}
        class={["overlay-pronouns font-medium lowercase text-slate-400", @type.pronouns]}
      >
        {@talent.pronouns}
      </span>
      <span
        :if={Text.present?(@talent.social)}
        class={["font-semibold tracking-wide text-slate-300/90", @type.social]}
      >
        {@talent.social}
      </span>
    </div>
    """
  end

  defp talent_type_scale(:large) do
    %{name: "text-[38px]", pronouns: "text-[16px]", social: "text-[18px]", meta: nil}
  end

  defp talent_type_scale(:compact) do
    %{
      name: "text-[32px]",
      pronouns: "text-[15px]",
      social: "text-[16px]",
      meta: "justify-center"
    }
  end

  @doc """
  A line of copy scrolling forever along its container.

  The text is deliberately drawn twice: the animation slides the pair left by
  exactly half its width, so the second copy arrives as the first leaves and the
  loop has no gap in it. Both copies are the same string for that reason — do
  not be tempted to make the second one different.
  """
  attr :text, :string, required: true
  attr :class, :any, default: nil
  attr :spacing, :string, default: "px-12"

  def marquee(assigns) do
    ~H"""
    <div class={["overlay-marquee", @class]}>
      <span class={@spacing}>{@text}</span>
      <span class={@spacing}>{@text}</span>
    </div>
    """
  end

  @doc """
  The band across the bottom of a full-frame card that the ticker runs in.

  Draws nothing at all when the operator has left the ticker empty, rather than
  leaving an empty stripe across the bottom of the frame.
  """
  attr :text, :string, default: nil
  attr :delay, :integer, default: 0

  def ticker_bar(assigns) do
    ~H"""
    <div
      :if={Text.present?(@text)}
      class="overlay-in-up absolute inset-x-0 bottom-0 overflow-hidden border-t border-white/10 bg-slate-950/90 py-5"
      style={"--overlay-delay: #{@delay}ms"}
    >
      <.marquee
        text={@text}
        class="text-[22px] font-medium uppercase tracking-[0.2em] text-slate-300"
      />
    </div>
    """
  end

  @doc """
  The card a scene draws when it has nothing to draw.

  An overlay with a hole in it looks like a broken overlay, so a scene with no
  games or nobody on the desk says so in the operator's own preview instead of
  going quietly blank.
  """
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def empty_notice(assigns) do
    ~H"""
    <div
      class={["overlay-panel overlay-round-card px-12 py-8 text-[22px] text-slate-300", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  ## Style helpers
  #
  # Kept as plain functions so scenes can compose them into inline styles and so
  # they can be unit tested without rendering.

  @doc "The team's primary color, falling back to a neutral slate."
  def primary(team), do: color(team, :primary_color, "#1f2937")

  @doc "The team's secondary color, falling back to near-white."
  def secondary(team), do: color(team, :secondary_color, "#f8fafc")

  @doc "Black or white, whichever is readable on the team's primary color."
  def contrast(team), do: Colors.contrast_text(primary(team))

  @doc "A translucent wash of the team's primary color, for plate backgrounds."
  def wash(team, opacity \\ 0.85),
    do: Colors.rgba(primary(team), opacity, "rgba(15, 23, 42, 0.85)")

  defp color(nil, _field, fallback), do: fallback

  defp color(team, field, fallback) do
    team |> Map.get(field) |> Colors.normalize(fallback)
  end

  @doc """
  Whether a team has a logo configured, so a scene can decide between drawing it
  and falling back to the team's initials.

      iex> ShowishWeb.OverlayComponents.logo?(%{logo_url: "  "})
      false
  """
  def logo?(nil), do: false
  def logo?(team), do: Text.present?(team.logo_url)

  @doc """
  A team's colors as CSS custom properties.

  The plate background itself lives in `app.css` rather than inline, so a preset
  can restyle it — Tranquility draws a primary-to-secondary gradient where the
  default package uses a flat fill — without having to out-specify an inline
  style.
  """
  def team_vars(team) do
    "--team-primary: #{primary(team)}; --team-secondary: #{secondary(team)};"
  end

  @doc """
  Up to three letters standing in for a team without a logo.

      iex> ShowishWeb.OverlayComponents.initials(%{code: "", short_name: "", name: "Night Owls"})
      "NO"
  """
  def initials(nil), do: "?"

  def initials(team) do
    case Text.first_present([team.code, team.short_name]) do
      "" -> name_initials(team.name)
      label -> label |> String.slice(0, 3) |> String.upcase()
    end
  end

  # Nothing short to go on, so build something from the full name: the first
  # letter of each word, up to three, and a question mark if even that is empty.
  defp name_initials(name) do
    name
    |> to_string()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(&String.first/1)
    |> Enum.take(3)
    |> Enum.join()
    |> String.upcase()
    |> Text.presence("?")
  end

  @doc "The name to print on a scorebug, or a placeholder for an empty slot."
  def short_name(nil), do: "TBD"
  def short_name(team), do: Team.display_name(team)

  @doc "The full name, or a placeholder for an empty slot."
  def full_name(nil), do: "TBD"
  def full_name(team), do: Team.full_name(team)

  @doc "A team's score, tolerating an unfilled slot."
  def score(nil), do: 0
  def score(team), do: team.score || 0
end
