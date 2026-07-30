defmodule Showish.Broadcasts.Preset do
  @moduledoc """
  The catalogue of visual presets a show can be drawn in.

  A preset is a whole look for the overlay package: panel treatment, corner
  radius, typography and, where a scene needs it, a different layout entirely.
  The show carries one preset and every scene honours it, so a broadcast never
  mixes two looks across its browser sources.

  Adding a preset means an entry here, a `preset-<key>` block in
  `assets/css/app.css`, and — only for scenes whose geometry actually differs —
  a `render/1` clause that matches on it.
  """

  @presets [
    %{
      key: "broadcast",
      name: "Broadcast",
      summary: "Sheared panels, soft shadows and rounded corners."
    },
    %{
      key: "tranquility",
      name: "Tranquility",
      summary: "Flat rectangles, hard edges and condensed uppercase type."
    }
  ]

  @doc "Every preset, in the order they are offered to an operator."
  def all, do: @presets

  @doc "The keys a show may be set to."
  def keys, do: Enum.map(@presets, & &1.key)

  @doc """
  The key new shows start on, and the fallback for anything unrecognised.

      iex> Showish.Broadcasts.Preset.default()
      "broadcast"
  """
  def default, do: hd(@presets).key

  @doc """
  Looks a preset up by key, falling back to the default for anything unknown.

      iex> Showish.Broadcasts.Preset.fetch("tranquility").name
      "Tranquility"

      iex> Showish.Broadcasts.Preset.fetch("nonsense").key
      "broadcast"
  """
  def fetch(key), do: Enum.find(@presets, hd(@presets), &(&1.key == key))

  @doc "Name/key pairs for a `<select>` in the control room."
  def options, do: Enum.map(@presets, &{&1.name, &1.key})
end
