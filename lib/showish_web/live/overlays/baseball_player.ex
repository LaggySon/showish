defmodule ShowishWeb.Overlays.BaseballPlayer do
  @moduledoc "Single-player baseball statistics feature card."

  use ShowishWeb.OverlayLive

  alias Showish.Broadcasts.Sports.Baseball

  @impl Phoenix.LiveView
  def render(assigns) do
    graphic = Baseball.normalize_state(assigns.show.sport_state)["graphics"]["single"]
    assigns = assign(assigns, :graphic, graphic)

    ~H"""
    <.stage preset={@show.preset} accent={@show.accent_color}>
      <div id="baseball-player-scene" class="absolute inset-x-[250px] top-[185px] flex justify-center">
        <section class="overlay-panel overlay-round-hero overlay-in-up w-[1280px] overflow-hidden">
          <div class="h-3" style={"background: #{@show.accent_color}"}></div>
          <div class="grid min-h-[650px] grid-cols-[0.8fr_1.2fr]">
            <div class="relative flex flex-col justify-end overflow-hidden bg-slate-900 p-12">
              <div class="absolute -right-28 -top-24 size-[480px] rounded-full border-[90px] border-white/5">
              </div>
              <p
                class="relative text-[15px] font-black uppercase tracking-[0.24em]"
                style={"color: #{@show.accent_color}"}
              >
                {@graphic["kicker"]}
              </p>
              <h1 class="relative mt-4 text-[62px] font-black uppercase leading-[0.94] tracking-[-0.05em]">
                {display(@graphic["name"], "Player name")}
              </h1>
              <p class="relative mt-5 text-[22px] font-bold uppercase tracking-[0.16em] text-slate-400">
                {display(@graphic["detail"], @show.title)}
              </p>
            </div>
            <div class="grid content-center grid-cols-2 gap-px bg-white/10 p-px">
              <div
                :for={stat <- @graphic["stats"]}
                class="flex min-h-[180px] flex-col items-center justify-center bg-slate-950 px-6 text-center"
              >
                <span class="text-[16px] font-black uppercase tracking-[0.2em] text-slate-400">
                  {stat["label"]}
                </span>
                <span class="mt-3 text-[54px] font-black leading-none tabular-nums">
                  {stat["value"]}
                </span>
              </div>
              <div
                :if={@graphic["stats"] == []}
                class="col-span-2 grid h-[500px] place-items-center bg-slate-950 text-[23px] text-slate-500"
              >
                Add player statistics in the control room
              </div>
            </div>
          </div>
        </section>
      </div>
    </.stage>
    """
  end

  defp display("", fallback), do: fallback
  defp display(value, _fallback), do: value
end
