defmodule ShowishWeb.Overlays.Talent do
  @moduledoc """
  Lower thirds for the people on air: casters, hosts, analysts, observers.

  Cards sit along the bottom of the canvas and size themselves to however many
  people are on the desk, from one host up to a full panel.
  """

  use ShowishWeb.OverlayLive

  @impl Phoenix.LiveView
  def render(assigns) do
    assigns = assign(assigns, :talents, List.wrap(assigns.show.talents))

    ~H"""
    <.stage preset={@show.preset} accent={@show.accent_color}>
      <div class="absolute inset-x-0 bottom-[96px] flex justify-center gap-6 px-24">
        <div
          :for={{talent, index} <- Enum.with_index(@talents)}
          class="overlay-panel overlay-round-card overlay-talent overlay-in-up flex min-w-[320px] max-w-[460px] flex-col gap-2 px-8 py-6"
          style={"--talent-accent: #{@show.accent_color}; --overlay-delay: #{index * 90}ms;"}
        >
          <.eyebrow color={@show.accent_color}>{display(talent.role, "Talent")}</.eyebrow>

          <div class="overlay-talent-name truncate text-[38px] font-black uppercase leading-none">
            {display(talent.name, "TBD")}
          </div>

          <div
            :if={talent.pronouns not in [nil, ""] or talent.social not in [nil, ""]}
            class="overlay-talent-sub flex items-baseline gap-3"
          >
            <span
              :if={talent.pronouns not in [nil, ""]}
              class="overlay-pronouns text-[16px] font-medium lowercase text-slate-400"
            >
              {talent.pronouns}
            </span>
            <span
              :if={talent.social not in [nil, ""]}
              class="text-[18px] font-semibold tracking-wide text-slate-300/90"
            >
              {talent.social}
            </span>
          </div>
        </div>
      </div>

      <div
        :if={@talents == []}
        class="absolute inset-x-0 bottom-[96px] flex justify-center text-[22px] text-slate-300 overlay-in-up"
      >
        <div class="overlay-panel overlay-round-card px-12 py-8">
          No talent has been added to this show.
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
