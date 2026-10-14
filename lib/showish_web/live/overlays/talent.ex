defmodule ShowishWeb.Overlays.Talent do
  @moduledoc """
  Lower thirds for the people on air: casters, hosts, analysts, observers.

  Cards sit along the bottom of the canvas and size themselves to however many
  people are on the desk, from one host up to a full panel.
  """

  use ShowishWeb.OverlayLive

  alias Showish.Broadcasts.Show

  @impl Phoenix.LiveView
  def render(assigns) do
    assigns = assign(assigns, :talents, Show.talents(assigns.show))

    ~H"""
    <.stage preset={@show.preset} accent={@show.accent_color}>
      <div class="absolute inset-x-0 bottom-[96px] flex justify-center gap-6 px-24">
        <div
          :for={{talent, index} <- Enum.with_index(@talents)}
          class="overlay-panel overlay-round-card overlay-talent overlay-in-up flex min-w-[320px] max-w-[460px] flex-col gap-2 px-8 py-6"
          style={"--talent-accent: #{@show.accent_color}; --overlay-delay: #{index * 90}ms;"}
        >
          <.talent_details talent={talent} accent={@show.accent_color} />
        </div>
      </div>

      <div :if={@talents == []} class="absolute inset-x-0 bottom-[96px] flex justify-center">
        <.empty_notice class="overlay-in-up">No talent has been added to this show.</.empty_notice>
      </div>
    </.stage>
    """
  end
end
