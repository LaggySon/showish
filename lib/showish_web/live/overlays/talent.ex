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
    <.stage>
      <div class="absolute inset-x-0 bottom-[96px] flex justify-center gap-6 px-24 overlay-rise">
        <div
          :for={talent <- @talents}
          class="overlay-panel flex min-w-[320px] max-w-[460px] flex-col gap-2 rounded-lg px-8 py-6"
          style={"border-bottom: 4px solid #{@show.accent_color};"}
        >
          <.eyebrow color={@show.accent_color}>{display(talent.role, "Talent")}</.eyebrow>

          <div class="flex items-baseline gap-3">
            <span class="truncate text-[38px] font-black uppercase leading-none">
              {display(talent.name, "TBD")}
            </span>
            <span
              :if={talent.pronouns not in [nil, ""]}
              class="text-[16px] font-medium lowercase text-slate-400"
            >
              {talent.pronouns}
            </span>
          </div>

          <div
            :if={talent.social not in [nil, ""]}
            class="text-[18px] font-semibold tracking-wide text-slate-300/90"
          >
            {talent.social}
          </div>
        </div>
      </div>

      <div
        :if={@talents == []}
        class="absolute inset-x-0 bottom-[96px] flex justify-center text-[22px] text-slate-300"
      >
        <div class="overlay-panel rounded-lg px-12 py-8">No talent has been added to this show.</div>
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
