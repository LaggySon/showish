defmodule Showish.Text do
  @moduledoc """
  The handful of string questions the rest of the app asks over and over.

  Nearly every field an operator can type into is optional and defaults to `""`
  rather than `nil`, so "is there anything in this one?" — and "what goes on
  screen when there isn't?" — come up everywhere: schemas picking a display
  name, overlays filling a placeholder, scenes stringing two labels together.
  Those three questions are answered here and nowhere else.

  Blank means `nil`, `""`, or nothing but whitespace, because an operator who
  typed a space into a field meant to leave it empty.
  """

  @doc """
  Whether `value` has anything in it once trimmed.

      iex> Showish.Text.present?("  Kings ")
      true

      iex> Showish.Text.present?("   ")
      false

      iex> Showish.Text.present?(nil)
      false
  """
  def present?(value), do: trim(value) != ""

  @doc "The opposite of `present?/1`."
  def blank?(value), do: not present?(value)

  @doc """
  `value` trimmed, or `fallback` when there is nothing to show.

      iex> Showish.Text.presence("  Grand Finals ", "Live")
      "Grand Finals"

      iex> Showish.Text.presence("   ", "Live")
      "Live"
  """
  def presence(value, fallback \\ "") do
    case trim(value) do
      "" -> fallback
      text -> text
    end
  end

  @doc """
  The first of `values` with anything in it, or `fallback`.

  For the fields an operator fills in *instead of* one another — a team's short
  name or, failing that, its code, or failing that its full name.

      iex> Showish.Text.first_present(["", "  ", "Kings"], "TBD")
      "Kings"

      iex> Showish.Text.first_present([nil, ""], "TBD")
      "TBD"
  """
  def first_present(values, fallback \\ "") do
    values
    |> Enum.map(&trim/1)
    |> Enum.find(fallback, &(&1 != ""))
  end

  @doc """
  Every one of `values` that has something in it, joined.

  For the labels an operator fills in *alongside* one another, where the ones
  left empty should not leave a stray separator behind.

      iex> Showish.Text.join_present(["Game 1", nil, "Control"])
      "Game 1 · Control"

      iex> Showish.Text.join_present(["4", "1"], "-")
      "4-1"
  """
  def join_present(values, separator \\ " · ") do
    values
    |> Enum.map(&trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(separator)
  end

  defp trim(value) when is_binary(value), do: String.trim(value)
  defp trim(value), do: value |> to_string() |> String.trim()
end
