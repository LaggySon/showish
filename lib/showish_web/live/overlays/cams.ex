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

  alias Showish.Broadcasts.Show

  # Past this many windows the desk goes to two rows rather than shaving every
  # window down to a letterbox.
  @windows_per_row 4

  @impl Phoenix.LiveView
  def render(assigns) do
    talents = Enum.filter(Show.talents(assigns.show), & &1.on_cam)

    assigns =
      assigns
      |> assign(:talents, talents)
      |> assign(:second_row?, length(talents) > @windows_per_row)

    ~H"""
    <.stage preset={@show.preset} accent={@show.accent_color}>
      <div class={["overlay-cams", @second_row? && "overlay-cams-wrap"]}>
        <div
          :for={{talent, index} <- Enum.with_index(@talents)}
          class="overlay-cam overlay-in-up"
          style={"--talent-accent: #{@show.accent_color}; --overlay-delay: #{index * 90}ms;"}
        >
          <div class="overlay-cam-window"></div>

          <div class="overlay-panel overlay-round-card overlay-talent overlay-cam-plate flex flex-col">
            <.talent_details talent={talent} accent={@show.accent_color} size={:compact} />
          </div>
        </div>
      </div>

      <div :if={@talents == []} class="absolute inset-0 flex items-center justify-center">
        <.empty_notice class="overlay-in-up">
          Nobody on the crew is marked as on camera.
        </.empty_notice>
      </div>
    </.stage>
    """
  end
end
