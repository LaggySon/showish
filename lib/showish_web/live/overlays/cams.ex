defmodule ShowishWeb.Overlays.Cams do
  @moduledoc """
  The caster desk: a window per person with their name plate on it.

  The windows are deliberately empty. Broadcast software composites the actual
  camera sources behind this scene, so all this draws is the furniture around
  them — the frame and the plate — and leaves the middle of each window clear.

  Only people marked *On camera* in the control room appear here. Roles are free
  text, so there is no way to infer that a producer or an observer is not on the
  desk — the operator says who is.

  Sizes itself to however many people are on the desk, wrapping to a second row
  past four so a full panel still fits the frame.
  """

  use ShowishWeb.OverlayLive

  @impl Phoenix.LiveView
  def render(assigns) do
    talents = assigns.show.talents |> List.wrap() |> Enum.filter(& &1.on_cam)

    assigns = assign(assigns, :talents, talents)

    ~H"""
    <.stage preset={@show.preset} accent={@show.accent_color}>
      <div class={["overlay-cams", length(@talents) > 4 && "overlay-cams-wrap"]}>
        <div
          :for={{talent, index} <- Enum.with_index(@talents)}
          class="overlay-cam overlay-in-up"
          style={"--talent-accent: #{@show.accent_color}; --overlay-delay: #{index * 90}ms;"}
        >
          <div class="overlay-cam-window"></div>

          <div class="overlay-panel overlay-talent overlay-cam-plate flex flex-col rounded-lg">
            <.eyebrow color={@show.accent_color}>{display(talent.role, "Talent")}</.eyebrow>

            <div class="overlay-talent-name truncate text-[32px] font-black uppercase leading-none">
              {display(talent.name, "TBD")}
            </div>

            <div
              :if={talent.pronouns not in [nil, ""] or talent.social not in [nil, ""]}
              class="overlay-talent-sub flex items-baseline justify-center gap-3"
            >
              <span
                :if={talent.pronouns not in [nil, ""]}
                class="overlay-pronouns text-[15px] font-medium lowercase text-slate-400"
              >
                {talent.pronouns}
              </span>
              <span
                :if={talent.social not in [nil, ""]}
                class="text-[16px] font-semibold tracking-wide text-slate-300/90"
              >
                {talent.social}
              </span>
            </div>
          </div>
        </div>
      </div>

      <div
        :if={@talents == []}
        class="overlay-in-up absolute inset-0 flex items-center justify-center text-[22px] text-slate-300"
      >
        <div class="overlay-panel rounded-lg px-12 py-8">
          Nobody on the crew is marked as on camera.
        </div>
      </div>
    </.stage>
    """
  end

  defp display(value, fallback) do
    case String.trim(to_string(value || "")) do
      "" -> fallback
      text -> text
    end
  end
end
