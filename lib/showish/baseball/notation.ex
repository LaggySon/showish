defmodule Showish.Baseball.Notation do
  @moduledoc """
  Interprets common paper-scorebook and Retrosheet-style plate-appearance notation.

  A non-empty notation is authoritative over a selected quick-action result. This
  prevents an operator from entering `E1` and accidentally recording a routine out.
  """

  @results ~w(single double triple home_run walk hit_by_pitch reached_on_error
              fielders_choice sacrifice sacrifice_fly sacrifice_bunt double_play
              triple_play interference out strikeout strikeout_reached)

  @runner_events ~r/^(?:WP|PB|BK|DI|OA|SB[123H]?|CS[123H]?|PO[123H]?)(?:\b|[-+])/u

  @doc "Interprets notation, falling back to the selected result only when notation is blank."
  def interpret(notation, selected_result \\ nil) do
    notation = normalize(notation)

    cond do
      notation == "" ->
        fallback(selected_result)

      String.length(notation) > 40 ->
        {:error, :scorebook_notation_too_long}

      Regex.match?(@runner_events, notation) ->
        {:error, :runner_event_does_not_end_at_bat}

      location_only?(notation) and (selected_result in @results or selected_result == "reached") ->
        result = if selected_result == "reached", do: "single", else: selected_result
        ok(result, notation)

      true ->
        parse(notation)
    end
  end

  defp location_only?(notation), do: Regex.match?(~r/^[1-9]$/u, notation)

  defp fallback("reached"), do: ok("single", "")
  defp fallback(result) when result in @results, do: ok(result, "")
  defp fallback(_result), do: {:error, :scorebook_notation_required}

  defp parse(notation) do
    core = event_core(notation)
    compact = String.replace(core, ~r/[\s-]/u, "")

    cond do
      strikeout_reached?(compact) -> ok("strikeout_reached", canonical(notation))
      triple_play?(core, compact) -> ok("triple_play", play_notation(core, "TP"))
      double_play?(core, compact) -> ok("double_play", play_notation(core, "DP"))
      sacrifice_fly?(compact) -> ok("sacrifice_fly", canonical(notation))
      sacrifice_bunt?(compact) -> ok("sacrifice_bunt", canonical(notation))
      interference?(compact) -> ok("interference", canonical(notation))
      reached_on_error?(compact) -> ok("reached_on_error", canonical(notation))
      fielders_choice?(compact) -> ok("fielders_choice", canonical(notation))
      hit_by_pitch?(compact) -> ok("hit_by_pitch", canonical(notation))
      walk?(compact) -> ok("walk", canonical(notation))
      home_run?(compact) -> ok("home_run", canonical(notation))
      triple?(compact) -> ok("triple", canonical(notation))
      double?(compact) -> ok("double", canonical(notation))
      single?(compact) -> ok("single", canonical(notation))
      strikeout?(compact) -> ok("strikeout", canonical(notation))
      ordinary_out?(core, compact) -> ok("out", canonical_fielders(core))
      true -> {:error, :unrecognized_scorebook_notation}
    end
  end

  # Retrosheet places batted-ball modifiers after `/` and runner advances after `.`.
  # C/E2 is kept intact because it is the conventional catcher-interference code.
  defp event_core("C/E2" <> _suffix), do: "C/E2"

  defp event_core(notation) do
    notation
    |> String.split(".", parts: 2)
    |> hd()
    |> String.split("/", parts: 2)
    |> hd()
    |> String.trim()
  end

  defp strikeout_reached?(compact),
    do: Regex.match?(~r/^(?:K|KS|KC|KL|ꓘ)(?:\+|E[1-9]|WP|PB)/u, compact)

  defp triple_play?(core, compact),
    do:
      Regex.match?(~r/(?:^|[^A-Z])TP(?:$|[^A-Z])/u, core) or String.starts_with?(compact, "TP") or
        String.ends_with?(compact, "TP")

  defp double_play?(core, compact) do
    explicit? =
      Regex.match?(~r/(?:^|[^A-Z])(?:DP|GDP|LDP|FDP)(?:$|[^A-Z])/u, core) or
        Regex.match?(~r/^(?:DP|GDP|LDP|FDP)|(?:DP|GDP|LDP|FDP)$/u, compact)

    # Compact/hyphenated three-fielder notation is the operator-friendly convention
    # used by this control panel (for example 463 or 4-6-3).
    explicit? or Regex.match?(~r/^[1-9](?:-?[1-9]){2}$/u, core)
  end

  defp sacrifice_fly?(compact),
    do:
      Regex.match?(~r/^(?:SF|SACFLY|SACRIFICEFLY)[1-9]?$/u, compact) or
        Regex.match?(~r/^[FLP][1-9]SF$/u, compact)

  defp sacrifice_bunt?(compact),
    do: Regex.match?(~r/^(?:SH|SAC|SACBUNT|SACRIFICEBUNT|BUNT)[1-9-]*$/u, compact)

  defp interference?(compact),
    do: compact in ~w(CI C/E2 INT INTERFERENCE OBSTRUCTION)

  defp reached_on_error?(compact) do
    compact == "ROE" or
      Regex.match?(~r/^E[1-9](?:TH|F|T)?$/u, compact) or
      Regex.match?(~r/^[1-9]+E[1-9]$/u, compact)
  end

  defp fielders_choice?(compact),
    do: Regex.match?(~r/^(?:FC|FO)[1-9-]*$/u, compact)

  defp hit_by_pitch?(compact), do: compact in ~w(HBP HP HITBYPITCH)
  defp walk?(compact), do: compact in ~w(BB W WALK IBB IW INTENTIONALWALK)
  defp home_run?(compact), do: compact in ["HR", "HOMER", "HOMERUN", "="]
  defp triple?(compact), do: Regex.match?(~r/^(?:3B|T|TRIPLE)[1-9]?$/u, compact)
  defp double?(compact), do: Regex.match?(~r/^(?:2B|D|DOUBLE)[1-9]?$/u, compact)
  defp single?(compact), do: Regex.match?(~r/^(?:1B|S|SINGLE)[1-9]?$/u, compact)

  defp strikeout?(compact),
    do: compact in ~w(K ꓘ KS KC KL SO SOꓘ STRIKEOUT) or Regex.match?(~r/^K2?-?3$/u, compact)

  defp ordinary_out?(core, compact) do
    compact in ~w(OUT GO AO BOO) or
      Regex.match?(~r/^[1-9](?:-?[1-9])?$/u, core) or
      Regex.match?(~r/^(?:F|L|P|G|U)[1-9](?:-?[1-9])?$/u, compact)
  end

  defp canonical_fielders(notation, suffix \\ nil) do
    digits = Regex.scan(~r/[1-9]/u, notation) |> List.flatten()

    value =
      if digits == [] do
        canonical(notation)
      else
        prefix =
          notation
          |> String.replace(~r/[1-9\s-]/u, "")
          |> String.replace(~r/(?:GDP|LDP|FDP|DP|TP)$/u, "")

        prefix <> Enum.join(digits, "-")
      end

    if suffix && not String.ends_with?(value, suffix), do: "#{value} #{suffix}", else: value
  end

  defp play_notation(notation, suffix) do
    suffix = if String.contains?(notation, suffix), do: suffix, else: nil
    canonical_fielders(notation, suffix)
  end

  defp canonical(notation), do: String.replace(notation, ~r/\s+/u, " ")

  defp ok(result, notation),
    do: {:ok, %{result: result, notation: notation, advances: runner_advances(notation)}}

  defp runner_advances(notation) do
    case String.split(notation, ".", parts: 2) do
      [_event, advances] ->
        advances
        |> String.split(";")
        |> Enum.flat_map(fn advance ->
          case Regex.run(~r/^\s*([B123])-([123H])(?:\([^)]*\))?\s*$/u, advance,
                 capture: :all_but_first
               ) do
            [from, to] -> [%{"from" => from, "to" => to}]
            _ -> []
          end
        end)

      _ ->
        []
    end
  end

  defp normalize(nil), do: ""

  defp normalize(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.upcase()
    |> String.replace(~r/[–—−]/u, "-")
    |> String.replace("BACKWARDS K", "ꓘ")
    |> String.replace("BACKWARD K", "ꓘ")
  end
end
