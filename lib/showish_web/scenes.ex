defmodule ShowishWeb.Scenes do
  @moduledoc """
  The catalogue of overlay scenes.

  One list drives the control room preview, the browser-source URLs an operator
  copies into their broadcast software, and the JSON payload, so a new scene is
  added in exactly one place (plus its LiveView and a route).
  """

  @scenes [
    %{
      key: "scorebug",
      name: "Scorebug",
      summary: "In-game bar with both teams, the series score and the current game."
    },
    %{
      key: "baseball-lineup",
      name: "Batting lineups",
      summary: "Full-screen batting orders with the active hitters and game totals.",
      sports: ["baseball"]
    },
    %{
      key: "baseball-defense",
      name: "Defensive alignment",
      summary: "On-field defensive positioning for the team currently in the field.",
      sports: ["baseball"]
    },
    %{
      key: "baseball-bullpen",
      name: "Bullpens",
      summary: "Both clubs' available, ready, and warming relief pitchers.",
      sports: ["baseball"]
    },
    %{
      key: "baseball-player",
      name: "Player spotlight",
      summary: "One-player feature card with operator-defined statistics.",
      sports: ["baseball"]
    },
    %{
      key: "baseball-comparison",
      name: "Player comparison",
      summary: "Head-to-head player graphic with matched statistical rows.",
      sports: ["baseball"]
    },
    %{
      key: "series",
      name: "Series",
      summary: "Between-games board showing every game, its result and what is next.",
      sports: ["esports"]
    },
    %{
      key: "talent",
      name: "Talent",
      summary: "Lower thirds for the casters, hosts and analysts on air."
    },
    %{
      key: "cams",
      name: "Caster cams",
      summary: "Frames and name plates for a desk of camera sources composited behind."
    },
    %{
      key: "standby",
      name: "Standby",
      summary: "Full-frame pre-show card with the countdown and the matchup."
    },
    %{
      key: "break",
      name: "Break",
      summary: "Intermission card with a message, a clock back to air and the score."
    },
    %{
      key: "credits",
      name: "Credits",
      summary: "End-of-broadcast roll of everyone who worked the show."
    },
    %{
      key: "ticker",
      name: "Ticker",
      summary: "Bottom bar with a compact score and scrolling copy."
    }
  ]

  @doc "Every scene, in the order they are offered to an operator."
  def all, do: @scenes

  @doc "Scenes applicable to a sport; scenes without a restriction are shared."
  def for_sport(sport) do
    Enum.filter(@scenes, fn scene -> Map.get(scene, :sports, [sport]) |> Enum.member?(sport) end)
  end

  @doc "Looks a scene up by key, returning the first scene for anything unknown."
  def fetch(key) do
    Enum.find(@scenes, hd(@scenes), &(&1.key == key))
  end

  @doc """
  The path a browser source should point at.

  Built by hand rather than with `~p` because the scene is only known at
  runtime, and a verified route cannot check a dynamic final segment.
  """
  def path(slug, key), do: "/overlay/#{slug}/#{key}"

  @doc "The absolute URL an operator pastes into their broadcast software."
  def url(slug, key), do: ShowishWeb.Endpoint.url() <> path(slug, key)
end
