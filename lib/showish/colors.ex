defmodule Showish.Colors do
  @moduledoc """
  Small helpers for working with the hex colors operators type into the control
  panel. Overlays are drawn on top of live video, so contrast has to be derived
  rather than assumed.
  """

  import Ecto.Changeset, only: [validate_change: 3]

  @hex_regex ~r/^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/

  @doc """
  Validates that a changeset field looks like `#rgb` or `#rrggbb`.

  Blank values are allowed; overlays fall back to their own defaults.
  """
  def validate_hex(changeset, field) do
    validate_change(changeset, field, fn ^field, value ->
      cond do
        value in [nil, ""] -> []
        String.match?(value, @hex_regex) -> []
        true -> [{field, "must be a hex color like #1f2937"}]
      end
    end)
  end

  @doc """
  Expands `#abc` to `#aabbcc` and returns `fallback` for anything unusable.

      iex> Showish.Colors.normalize("#abc")
      "#aabbcc"

      iex> Showish.Colors.normalize("nope", "#000000")
      "#000000"
  """
  def normalize(hex, fallback \\ "#000000")

  def normalize("#" <> <<r::binary-1, g::binary-1, b::binary-1>> = value, fallback) do
    if String.match?(value, @hex_regex),
      do: String.downcase("##{r}#{r}#{g}#{g}#{b}#{b}"),
      else: fallback
  end

  def normalize("#" <> <<_::binary-6>> = value, fallback) do
    if String.match?(value, @hex_regex), do: String.downcase(value), else: fallback
  end

  def normalize(_hex, fallback), do: fallback

  @doc """
  Returns black or white, whichever stays readable on top of `hex`.

  Uses the YIQ luminosity formula, the same approach the original tool used.
  """
  def contrast_text(hex, fallback \\ "#ffffff") do
    case rgb(hex) do
      {r, g, b} ->
        luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
        if luminance > 0.7, do: "#0b0f14", else: "#ffffff"

      :error ->
        fallback
    end
  end

  @doc """
  Builds an `rgba(...)` string from a hex color and an opacity between 0 and 1.
  """
  def rgba(hex, opacity, fallback \\ "rgba(0, 0, 0, 0)") do
    case rgb(hex) do
      {r, g, b} -> "rgba(#{r}, #{g}, #{b}, #{opacity})"
      :error -> fallback
    end
  end

  @doc """
  Parses a hex color into an `{r, g, b}` tuple, or `:error`.
  """
  def rgb(hex) when is_binary(hex) do
    with "#" <> digits <- normalize(hex, :invalid),
         {r, ""} <- Integer.parse(String.slice(digits, 0, 2), 16),
         {g, ""} <- Integer.parse(String.slice(digits, 2, 2), 16),
         {b, ""} <- Integer.parse(String.slice(digits, 4, 2), 16) do
      {r, g, b}
    else
      _ -> :error
    end
  end

  def rgb(_hex), do: :error
end
