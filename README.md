# Showish

Web overlays for live broadcasts, built with Phoenix LiveView.

Showish is a control room and a set of browser-source overlays. You point your
broadcast software (OBS, Streamlabs, vMix, anything with a browser source) at a
URL per scene, and everything you change in the control room is on air a moment
later — no polling, no refresh, no spreadsheet in the middle.

## What is in the box

A **show** is one broadcast. It holds two teams, a series of games, the crew on
air, and the copy that frames the whole thing (stage name, ticker, status lines,
countdown target).

Seven scenes read from it, each on its own URL:

| Scene | URL | What it is |
| --- | --- | --- |
| Scorebug | `/overlay/:slug/scorebug` | The in-game bar: both teams, the series score, the current game |
| Series | `/overlay/:slug/series` | Between-games board with every game and its result |
| Talent | `/overlay/:slug/talent` | Lower thirds for casters, hosts and analysts |
| Standby | `/overlay/:slug/standby` | Pre-show card with the countdown and the matchup |
| Break | `/overlay/:slug/break` | Intermission card with a message and a clock back to air |
| Credits | `/overlay/:slug/credits` | End-of-broadcast roll |
| Ticker | `/overlay/:slug/ticker` | Bottom bar with a compact score and scrolling copy |

Every scene is drawn on a fixed **1920 × 1080** canvas with a transparent
background, and scales itself down to fit anything smaller — so the same URL is
both the browser source and the preview in the control room.

## Running it

```bash
mix setup                     # deps, database, assets
mix run priv/repo/seeds.exs   # optional: a demo show to look at
mix phx.server
```

Then open [`localhost:4000`](http://localhost:4000), create a show, and open its
control room. The show page lists every overlay URL with a copy button.

### Adding an overlay to your broadcast software

1. Add a **Browser** source.
2. Paste the URL and set the size to **1920 × 1080**.
3. Leave the background transparent.

Scenes are drawn for 1080p. For a larger canvas, create the source at 1920 × 1080
and scale it in your scene.

## How it works

```
control room ──▶ Showish.Broadcasts ──▶ Phoenix.PubSub "show:<slug>"
   (LiveView)         (context)                    │
                                                   ▼
                                       overlay LiveViews (one per scene)
```

Every write goes through `Showish.Broadcasts`, which reloads the show and pushes
it to the `show:<slug>` topic. Overlays subscribe once at mount and re-render on
`{:show_updated, show}`. A LiveView diff over an open websocket is the whole
update path, so a score bump lands on air in milliseconds.

The control room writes as you type (debounced), so there is no save button to
forget mid-match. The buttons at the top — score ±, swap sides, step through the
series, reset — exist because during a match there is no time to tab through a
form.

### Reading a show from somewhere else

```
GET /api/shows/:slug
```

Returns a JSON snapshot of the whole show, for anything that cannot hold a
websocket open.

## Layout

```
lib/showish/broadcasts.ex              the context: every write and the fan-out
lib/showish/broadcasts/                show, team, game, talent schemas
lib/showish/colors.ex                  contrast and rgba helpers for operator colors
lib/showish_web/live/overlay_live.ex   shared mount/subscribe/tick for scenes
lib/showish_web/live/overlays/         one LiveView per scene
lib/showish_web/live/show_live/        index, overlay URLs, control room
lib/showish_web/scenes.ex              the scene catalogue
```

Adding a scene is three steps: a LiveView under `live/overlays/`, a route, and an
entry in `ShowishWeb.Scenes` — the preview, the URL list and the copy buttons all
follow from the catalogue.

## Tests

```bash
mix test
```
