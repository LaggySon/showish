defmodule ShowishWeb.Overlays.Credits do
  @moduledoc """
  The end-of-broadcast roll: everyone who worked the show, grouped by role.
  """

  use ShowishWeb.OverlayLive

  @impl Phoenix.LiveView
  def render(assigns) do
    assigns = assign(assigns, :groups, group_by_role(assigns.show.talents))

    ~H"""
    <.stage>
      <div class="absolute inset-0 bg-slate-950/90"></div>

      <div class="absolute inset-0 overflow-hidden">
        <div class="overlay-credits flex flex-col items-center gap-16 py-24">
          <div class="flex flex-col items-center gap-4">
            <h1 class="text-[64px] font-black uppercase leading-none tracking-tight">
              {@show.title}
            </h1>
            <div class="h-1 w-40" style={"background: #{@show.accent_color}"}></div>
          </div>

          <div :for={{role, people} <- @groups} class="flex flex-col items-center gap-4">
            <.eyebrow color={@show.accent_color}>{role}</.eyebrow>
            <div :for={person <- people} class="flex items-baseline gap-3">
              <span class="text-[34px] font-bold uppercase leading-tight">{person.name}</span>
              <span :if={person.pronouns not in [nil, ""]} class="text-[18px] text-slate-400">
                {person.pronouns}
              </span>
              <span :if={person.social not in [nil, ""]} class="text-[18px] text-slate-500">
                {person.social}
              </span>
            </div>
          </div>

          <div class="text-[20px] uppercase tracking-[0.3em] text-slate-500">
            Thanks for watching
          </div>
        </div>
      </div>
    </.stage>
    """
  end

  # Keeps the order the operator arranged rows in, while collapsing consecutive
  # people who share a role under one heading.
  defp group_by_role(talents) do
    talents
    |> List.wrap()
    |> Enum.reject(&(String.trim(to_string(&1.name || "")) == ""))
    |> Enum.chunk_by(&role_of/1)
    |> Enum.map(fn [first | _rest] = people -> {role_of(first), people} end)
  end

  defp role_of(talent) do
    case String.trim(to_string(talent.role || "")) do
      "" -> "Crew"
      role -> role
    end
  end
end
