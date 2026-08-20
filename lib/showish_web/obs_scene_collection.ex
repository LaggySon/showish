defmodule ShowishWeb.ObsSceneCollection do
  @moduledoc """
  A show's overlays, as a scene collection OBS can import.

  OBS reads an entire scene collection out of one JSON file — *Scene Collection
  → Import* — so instead of adding eight browser sources by hand an operator
  downloads this once and lands with one OBS scene per Showish scene, each
  holding a single 1920 × 1080 browser source already pointed at the right
  overlay URL for this show.

  The shape below is OBS's own save format. Every field OBS leaves out of a
  source falls back to the default it would have used had the source been added
  by hand, so the only settings written are the ones that actually differ: the
  URL and the size.
  """

  alias Showish.Broadcasts.Show
  alias ShowishWeb.Scenes

  @width 1920
  @height 1080

  # OBS stamps every source with the version that wrote it and uses it to decide
  # which migrations to run on load. 30.0.0 is the oldest release this is
  # written for.
  @prev_ver 503_316_480

  # OBS_ALIGN_LEFT ||| OBS_ALIGN_TOP. The overlay sits in the top-left corner,
  # unscaled, filling a 1920 × 1080 canvas.
  @align_top_left 5

  @doc """
  The collection for `show`, as a map ready to be encoded as JSON.

  Source identifiers are minted fresh on every call, which is what OBS expects:
  importing twice gives two independent collections rather than two halves of
  the same one.
  """
  def build(%Show{} = show) do
    scenes = Enum.map(Scenes.all(), &prepare(show, &1))
    first = List.first(scenes)

    %{
      "name" => name(show),
      "current_scene" => (first && first.scene_name) || "",
      "current_program_scene" => (first && first.scene_name) || "",
      "current_transition" => "Fade",
      "transition_duration" => 300,
      "transitions" => [],
      "scene_order" => Enum.map(scenes, &%{"name" => &1.scene_name}),
      "sources" => Enum.flat_map(scenes, &[scene_source(&1), browser_source(&1)]),
      "groups" => [],
      "modules" => %{},
      "preview_locked" => false,
      "saved_projectors" => [],
      "scaling_enabled" => false,
      "scaling_level" => 0,
      "scaling_off_x" => 0.0,
      "scaling_off_y" => 0.0
    }
  end

  @doc "The name OBS files the imported collection under."
  def name(%Show{} = show), do: "Showish — #{show.title}"

  @doc "What the download should be called on the operator's disk."
  def filename(%Show{} = show), do: "showish-#{show.slug}-obs.json"

  # One OBS scene and one browser source per Showish scene. The scene keeps the
  # scene's own name so the OBS scene list reads like the scene reference; the
  # source is named after it so the two are never confused in the sources dock.
  defp prepare(show, scene) do
    %{
      scene_name: scene.name,
      scene_uuid: Ecto.UUID.generate(),
      source_name: "#{scene.name} overlay",
      source_uuid: Ecto.UUID.generate(),
      url: Scenes.url(show.slug, scene.key)
    }
  end

  defp scene_source(scene) do
    source(scene.scene_name, scene.scene_uuid, "scene", %{
      "custom_size" => false,
      "id_counter" => 1,
      "items" => [scene_item(scene)]
    })
  end

  defp browser_source(scene) do
    source(scene.source_name, scene.source_uuid, "browser_source", %{
      "url" => scene.url,
      "width" => @width,
      "height" => @height
    })
  end

  # Scene items are matched to their source by UUID in current OBS and by name
  # in older releases, so both are written.
  defp scene_item(scene) do
    %{
      "name" => scene.source_name,
      "source_uuid" => scene.source_uuid,
      "id" => 1,
      "visible" => true,
      "locked" => false,
      "rot" => 0.0,
      "pos" => %{"x" => 0.0, "y" => 0.0},
      "scale" => %{"x" => 1.0, "y" => 1.0},
      "align" => @align_top_left,
      "bounds_type" => 0,
      "bounds_align" => 0,
      "bounds" => %{"x" => 0.0, "y" => 0.0},
      "crop_left" => 0,
      "crop_top" => 0,
      "crop_right" => 0,
      "crop_bottom" => 0,
      "group_item_backup" => false,
      "scale_filter" => "disable",
      "blend_method" => "default",
      "blend_type" => "normal",
      "show_transition" => %{"duration" => 0},
      "hide_transition" => %{"duration" => 0},
      "private_settings" => %{}
    }
  end

  defp source(name, uuid, id, settings) do
    %{
      "prev_ver" => @prev_ver,
      "name" => name,
      "uuid" => uuid,
      "id" => id,
      "versioned_id" => id,
      "settings" => settings,
      "mixers" => 0,
      "sync" => 0,
      "flags" => 0,
      "volume" => 1.0,
      "balance" => 0.5,
      "enabled" => true,
      "muted" => false,
      "push-to-mute" => false,
      "push-to-mute-delay" => 0,
      "push-to-talk" => false,
      "push-to-talk-delay" => 0,
      "hotkeys" => %{},
      "deinterlace_mode" => 0,
      "deinterlace_field_order" => 0,
      "monitoring_type" => 0,
      "private_settings" => %{}
    }
  end
end
