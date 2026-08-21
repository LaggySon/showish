defmodule ShowishWeb.Overlays.BaseballComparison do
  @moduledoc "Head-to-head baseball player statistics graphic."

  use ShowishWeb.OverlayLive

  alias Showish.Broadcasts.Sports.Baseball

  @impl Phoenix.LiveView
  def render(assigns) do
    graphic = Baseball.normalize_state(assigns.show.sport_state)["graphics"]["comparison"]
    assigns = assign(assigns, :graphic, graphic)

    ~H"""
    <.stage preset={@show.preset} accent={@show.accent_color}>
      <div id="baseball-comparison-scene" class="absolute inset-x-[220px] top-[120px]">
        <header class="overlay-in-down text-center">
          <.eyebrow color={@show.accent_color}>{@show.title}</.eyebrow>
          <h1 class="mt-3 text-[52px] font-black uppercase leading-none">{@graphic["title"]}</h1>
        </header>

        <section class="overlay-panel overlay-round-hero overlay-in-up mt-8 overflow-hidden">
          <div class="grid grid-cols-[1fr_240px_1fr] bg-slate-900">
            <.player_header name={@graphic["left_name"]} detail={@graphic["left_detail"]} side="left" />
            <div class="grid place-items-center border-x border-white/10 text-[22px] font-black uppercase tracking-[0.2em] text-slate-500">
              Stat
            </div>
            <.player_header
              name={@graphic["right_name"]}
              detail={@graphic["right_detail"]}
              side="right"
            />
          </div>

          <div class="bg-slate-950">
            <div
              :for={stat <- @graphic["stats"]}
              class="grid h-[92px] grid-cols-[1fr_240px_1fr] items-center border-t border-white/10"
            >
              <span class="px-12 text-right text-[36px] font-black tabular-nums">{stat["left"]}</span>
              <span class="text-center text-[15px] font-black uppercase tracking-[0.18em] text-slate-400">
                {stat["label"]}
              </span>
              <span class="px-12 text-[36px] font-black tabular-nums">{stat["right"]}</span>
            </div>
            <div
              :if={@graphic["stats"] == []}
              class="grid h-[410px] place-items-center border-t border-white/10 text-[23px] text-slate-500"
            >
              Add comparison statistics in the control room
            </div>
          </div>
        </section>
      </div>
    </.stage>
    """
  end

  attr :name, :string, required: true
  attr :detail, :string, required: true
  attr :side, :string, required: true

  defp player_header(assigns) do
    ~H"""
    <div class={["px-12 py-8", @side == "left" && "text-right"]}>
      <p class="text-[38px] font-black uppercase leading-none">{display(@name, "Player")}</p>
      <p class="mt-3 text-[15px] font-bold uppercase tracking-[0.18em] text-slate-400">
        {display(@detail, "—")}
      </p>
    </div>
    """
  end

  defp display("", fallback), do: fallback
  defp display(value, _fallback), do: value
end
