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
  def logo?(team), do: String.trim(team.logo_url || "") != ""

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
    code = String.trim(team.code || "")
    short = String.trim(team.short_name || "")

    cond do
      code != "" ->
        code |> String.slice(0, 3) |> String.upcase()

      short != "" ->
        short |> String.slice(0, 3) |> String.upcase()

      true ->
        (team.name || "")
        |> String.split(~r/\s+/, trim: true)
        |> Enum.map(&String.first/1)
        |> Enum.take(3)
        |> Enum.join()
        |> String.upcase()
        |> case do
          "" -> "?"
          letters -> letters
        end
    end
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
