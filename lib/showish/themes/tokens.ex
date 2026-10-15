defmodule Showish.Themes.Tokens do
  @moduledoc """
  The design tokens a theme may set, and the CSS they become.

  Every token is optional. One a theme leaves out keeps whatever the theme's
  base look draws, so an empty theme is exactly its base look, and a theme that
  only sets `"radius"` is its base look with different corners.

  This list is the single source for three things: what an uploaded theme file
  may contain, the fields of the theme editor, and the stylesheet an overlay
  loads. Adding a token is one entry here plus one clause in `declarations/2`.
  """

  alias Showish.Colors

  @fonts %{
    "system" => ~s(ui-sans-serif, system-ui, "Segoe UI", Roboto, sans-serif),
    "geist" => ~s("Laggish Sans", ui-sans-serif, system-ui, sans-serif),
    "heebo" => ~s("Heebo", "Segoe UI", Roboto, sans-serif),
    "oswald" => ~s("Oswald", "Arial Narrow", sans-serif),
    "geist-mono" => ~s("Laggish Mono", ui-monospace, monospace)
  }

  # Tailwind's gray families, 50 through 950. Scenes write `text-slate-400` and
  # the like, and Tailwind reads those through `--color-slate-*`, so remapping
  # those eleven variables re-tints every gray in every scene.
  @grays %{
    "slate" =>
      ~w(#f8fafc #f1f5f9 #e2e8f0 #cbd5e1 #94a3b8 #64748b #475569 #334155 #1e293b #0f172a #020617),
    "gray" =>
      ~w(#f9fafb #f3f4f6 #e5e7eb #d1d5db #9ca3af #6b7280 #4b5563 #374151 #1f2937 #111827 #030712),
    "zinc" =>
      ~w(#fafafa #f4f4f5 #e4e4e7 #d4d4d8 #a1a1aa #71717a #52525b #3f3f46 #27272a #18181b #09090b),
    "neutral" =>
      ~w(#fafafa #f5f5f5 #e5e5e5 #d4d4d4 #a3a3a3 #737373 #525252 #404040 #262626 #171717 #0a0a0a),
    "stone" =>
      ~w(#fafaf9 #f5f5f4 #e7e5e4 #d6d3d1 #a8a29e #78716c #57534e #44403c #292524 #1c1917 #0c0a09)
  }

  @steps ~w(50 100 200 300 400 500 600 700 800 900 950)

  @tokens [
    %{
      key: "panel_color",
      type: :color,
      label: "Panel color",
      hint: "The fill behind every card, plate and bar."
    },
    %{
      key: "panel_opacity",
      type: {:number, 0, 1},
      label: "Panel opacity",
      hint: "0 is see-through, 1 is solid."
    },
    %{
      key: "border_color",
      type: :color,
      label: "Border color",
      hint: "The line around panels."
    },
    %{
      key: "border_width",
      type: {:integer, 0, 8},
      label: "Border width (px)",
      hint: "0 for no border."
    },
    %{
      key: "shadow",
      type: {:enum, ~w(none soft hard)},
      label: "Shadow",
      hint: "Soft is a blurred glow; hard is a sharp offset."
    },
    %{
      key: "blur",
      type: {:integer, 0, 24},
      label: "Background blur (px)",
      hint: "Frosts whatever shows through a see-through panel."
    },
    %{
      key: "radius",
      type: {:integer, 0, 32},
      label: "Corner radius (px)",
      hint: "Cards use this; pills, logos and full-frame cards scale from it."
    },
    %{
      key: "text_color",
      type: :color,
      label: "Text color",
      hint: "The main ink. Team colors and the accent are unaffected."
    },
    %{
      key: "grays",
      type: {:enum, Map.keys(@grays) |> Enum.sort()},
      label: "Grays",
      hint: "The tint of secondary text and dividers."
    },
    %{
      key: "font",
      type: {:enum, ~w(system geist heebo oswald geist-mono custom)},
      label: "Font",
      hint: "Custom uses the font file uploaded with the theme."
    },
    %{
      key: "numbers_font",
      type: {:enum, ~w(same system geist heebo oswald geist-mono custom)},
      label: "Numbers font",
      hint: "Scores, clocks and records. Same follows the font above."
    },
    %{
      key: "entrance",
      type: {:enum, ~w(slide fade none)},
      label: "Entrances",
      hint: "How pieces arrive when a scene is cut to."
    },
    %{
      key: "entrance_ms",
      type: {:integer, 0, 1500},
      label: "Entrance length (ms)",
      hint: "How long each piece takes to arrive."
    }
  ]

  @keys Enum.map(@tokens, & &1.key)

  @doc "Every token, in the order the editor shows them."
  def all, do: @tokens

  @doc "The keys a theme may set."
  def keys, do: @keys

  @doc "The built-in fonts a theme can pick by name."
  def font_names, do: @fonts |> Map.keys() |> Enum.sort()

  @doc """
  Checks a map of tokens, returning the clean map or the problems with it.

  Values are coerced where the intent is plain (`"0.9"` for a number, `"#ABC"`
  for a color) and empty values are dropped, which is how an editor field is
  cleared. Unknown keys are reported rather than ignored, so a typo in a hand
  edited theme file says so instead of silently doing nothing.

      iex> Showish.Themes.Tokens.cast(%{"radius" => "4", "shadow" => ""})
      {:ok, %{"radius" => 4}}

      iex> Showish.Themes.Tokens.cast(%{"raduis" => 4})
      {:error, ["raduis is not a theme token"]}
  """
  def cast(tokens) when is_map(tokens) do
    {clean, errors} =
      Enum.reduce(tokens, {%{}, []}, fn {key, value}, {clean, errors} ->
        key = to_string(key)

        case Enum.find(@tokens, &(&1.key == key)) do
          nil ->
            {clean, ["#{key} is not a theme token" | errors]}

          token ->
            case cast_value(token.type, value) do
              :blank -> {clean, errors}
              {:ok, value} -> {Map.put(clean, key, value), errors}
              {:error, message} -> {clean, ["#{key} #{message}" | errors]}
            end
        end
      end)

    case errors do
      [] -> {:ok, clean}
      errors -> {:error, Enum.sort(errors)}
    end
  end

  def cast(_tokens), do: {:error, ["tokens must be an object"]}

  defp cast_value(_type, value) when value in [nil, ""], do: :blank

  defp cast_value(:color, value) when is_binary(value) do
    case Colors.normalize(String.trim(value), nil) do
      nil -> {:error, "must be a hex color like #1f2937"}
      hex -> {:ok, hex}
    end
  end

  defp cast_value({:enum, options}, value) when is_binary(value) do
    if value in options,
      do: {:ok, value},
      else: {:error, "must be one of: #{Enum.join(options, ", ")}"}
  end

  defp cast_value({kind, min, max}, value) when is_binary(value) do
    parsed = if kind == :integer, do: Integer.parse(value), else: Float.parse(value)

    case parsed do
      {number, ""} -> cast_value({kind, min, max}, number)
      _ -> {:error, "must be a number from #{min} to #{max}"}
    end
  end

  defp cast_value({:integer, min, max}, value) when is_number(value) do
    if value >= min and value <= max and round(value) == value,
      do: {:ok, round(value)},
      else: {:error, "must be a whole number from #{min} to #{max}"}
  end

  defp cast_value({:number, min, max}, value) when is_number(value) do
    if value >= min and value <= max,
      do: {:ok, value},
      else: {:error, "must be a number from #{min} to #{max}"}
  end

  defp cast_value(:color, _value), do: {:error, "must be a hex color like #1f2937"}

  defp cast_value({:enum, options}, _value),
    do: {:error, "must be one of: #{Enum.join(options, ", ")}"}

  defp cast_value({_kind, min, max}, _value),
    do: {:error, "must be a number from #{min} to #{max}"}

  @doc """
  The CSS for a theme's tokens, scoped to `selector` (the themed stage).

  `fonts` names the families the theme's own font files were declared under, so
  a `"custom"` font resolves to them.
  """
  def to_css(tokens, selector, fonts \\ %{}) do
    stage = declarations(tokens, fonts)

    [
      block(selector, stage),
      numbers_rule(tokens, selector, fonts),
      entrance_rule(tokens, selector)
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp block(_selector, []), do: ""

  defp block(selector, declarations) do
    body =
      Enum.map_join(declarations, "", fn {property, value} -> "  #{property}: #{value};\n" end)

    "#{selector} {\n#{body}}\n"
  end

  # Each base look keeps its own copy of the values these tokens stand for
  # (`--lg-panel`, `--tranq-card`), because its rebuilt scenes read those rather
  # than the shared contract. A token sets every copy, so it reaches the same
  # pieces whichever look the theme is built on.
  defp declarations(tokens, fonts) do
    List.flatten([
      panel(tokens),
      border(tokens),
      shadow(tokens),
      blur(tokens),
      radius(tokens),
      text(tokens),
      grays(tokens),
      font(tokens, fonts),
      duration(tokens)
    ])
  end

  defp panel(tokens) do
    if Map.has_key?(tokens, "panel_color") or Map.has_key?(tokens, "panel_opacity") do
      color = Map.get(tokens, "panel_color", "#090c12")
      fill = Colors.rgba(color, Map.get(tokens, "panel_opacity", 0.92))

      [
        {"--overlay-panel-bg", fill},
        {"--lg-panel", fill},
        {"--tranq-card", fill},
        {"--tranq-panel", fill}
      ]
    else
      []
    end
  end

  defp border(tokens) do
    if Map.has_key?(tokens, "border_color") or Map.has_key?(tokens, "border_width") do
      color = Map.get(tokens, "border_color", "#f8fafc")
      width = Map.get(tokens, "border_width", 1)
      line = Colors.rgba(color, if(Map.has_key?(tokens, "border_color"), do: 1, else: 0.12))

      value = if width == 0, do: "0", else: "#{width}px solid #{line}"
      [{"--overlay-panel-border", value}, {"--lg-line", line}]
    else
      []
    end
  end

  defp shadow(%{"shadow" => shadow}) do
    value =
      case shadow do
        "none" -> "none"
        "soft" -> "0 18px 48px rgba(0, 0, 0, 0.45)"
        "hard" -> "6px 6px 0 rgba(0, 0, 0, 0.85)"
      end

    [{"--overlay-panel-shadow", value}, {"--tranq-shadow", value}]
  end

  defp shadow(_tokens), do: []

  defp blur(%{"blur" => 0}), do: [{"--overlay-panel-blur", "none"}]
  defp blur(%{"blur" => blur}), do: [{"--overlay-panel-blur", "blur(#{blur}px)"}]
  defp blur(_tokens), do: []

  defp radius(%{"radius" => radius}) do
    px = fn factor -> "#{trim(radius * factor)}px" end

    [
      {"--overlay-radius-pill", px.(0.5)},
      {"--overlay-radius-logo", px.(0.75)},
      {"--overlay-radius-card", px.(1)},
      {"--overlay-radius-hero", px.(1.5)},
      {"--lg-radius", px.(1)},
      {"--tranq-radius", px.(1)}
    ]
  end

  defp radius(_tokens), do: []

  defp text(%{"text_color" => color}), do: [{"color", color}, {"--lg-ink", color}]
  defp text(_tokens), do: []

  defp grays(%{"grays" => family}) do
    @steps
    |> Enum.zip(Map.fetch!(@grays, family))
    |> Enum.map(fn {step, hex} -> {"--color-slate-#{step}", hex} end)
  end

  defp grays(_tokens), do: []

  defp font(%{"font" => font}, fonts) do
    case family(font, fonts) do
      nil -> []
      family -> [{"font-family", family}, {"--lg-sans", family}]
    end
  end

  defp font(_tokens, _fonts), do: []

  defp duration(%{"entrance_ms" => ms}), do: [{"--overlay-duration", "#{ms}ms"}]
  defp duration(_tokens), do: []

  defp numbers_rule(%{"numbers_font" => "same"} = tokens, selector, fonts) do
    case tokens |> Map.get("font") |> family(fonts) do
      nil -> ""
      family -> numbers_block(selector, family)
    end
  end

  defp numbers_rule(%{"numbers_font" => font}, selector, fonts) do
    case family(font, fonts, "numbers") do
      nil -> ""
      family -> numbers_block(selector, family)
    end
  end

  defp numbers_rule(_tokens, _selector, _fonts), do: ""

  defp numbers_block(selector, family) do
    "#{selector} :is(.tabular, .tabular-nums, .overlay-clock) {\n  font-family: #{family};\n}\n"
  end

  @entrances ".overlay-in-up, .overlay-in-down, .overlay-in-left, .overlay-in-right, .overlay-in-pop"

  defp entrance_rule(%{"entrance" => "fade"}, selector) do
    "#{selector} :is(#{@entrances}) {\n  animation-name: overlay-in-fade;\n}\n"
  end

  defp entrance_rule(%{"entrance" => "none"}, selector) do
    "#{selector} :is(#{@entrances}, .overlay-in-fade) {\n  animation: none;\n}\n"
  end

  defp entrance_rule(_tokens, _selector), do: ""

  # A "custom" font is the theme's own file for that role (numbers fall back to
  # the text file); with no file uploaded it falls back to the base look's own.
  defp family(font, fonts, role \\ "text")

  defp family("custom", fonts, role) do
    case Map.get(fonts, role) || Map.get(fonts, "text") do
      nil -> nil
      name -> ~s("#{name}", ui-sans-serif, sans-serif)
    end
  end

  defp family(font, _fonts, _role), do: Map.get(@fonts, font)

  defp trim(number) when is_float(number) do
    if number == Float.round(number), do: trunc(number), else: Float.round(number, 2)
  end

  defp trim(number), do: number
end
