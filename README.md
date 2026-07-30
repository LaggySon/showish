# Showish

Web overlays for live broadcasts, built with Phoenix LiveView.

Showish is two things: a **control room** you keep open on a second monitor, and
a set of **overlay URLs** you point your broadcast software at. Everything you
change in the control room is on air a moment later — no polling, no refresh, no
spreadsheet in the middle.

- [Quick start](#quick-start)
- [Accounts](#accounts)
- [Your first show](#your-first-show)
- [Wiring overlays into OBS](#wiring-overlays-into-obs)
- [The control room](#the-control-room)
- [Running a match](#running-a-match)
- [Scene reference](#scene-reference)
- [Looks](#looks)
- [Things worth knowing](#things-worth-knowing)
- [Reading a show from somewhere else](#reading-a-show-from-somewhere-else)
- [For developers](#for-developers)

## Quick start

Requires Elixir, Erlang/OTP and PostgreSQL.

```bash
mix setup                     # deps, database, assets
mix run priv/repo/seeds.exs   # optional: a demo show to poke at
mix phx.server
```

Open [`localhost:4000`](http://localhost:4000) and create an account — shows
belong to whoever made them, so the first thing you see is a login page.

If you ran the seeds, they created an account for you (`operator@example.com`,
password `showish-demo-account`, both overridable with `SEED_EMAIL` and
`SEED_PASSWORD`) and a show called **Showish Invitational**, with two teams, a
five-game series and a crew already filled in — log in, open its control room and
drag the scorebug URL into OBS to see the whole loop working in about a minute.

The seeds also point at placeholder artwork in `priv/static/images` — two team
crests and five map cards, all SVG — so the scenes that draw logos and map images
show something real out of the box. Replace the URLs in the control room with
your own; nothing depends on these files existing.

## Accounts

Everything that can *change* a show is behind a login: the shelf of shows, the
control room, the overlay URL list. Sign up at `/users/register`, and from then
on you only see your own shows — someone else's control room answers exactly the
way a show that does not exist would.

Overlay URLs are deliberately **not** behind the login. A browser source in OBS
cannot fill in a login form, so anyone with the URL can watch a show; only its
owner can change it. Treat an overlay URL like an unlisted link — the slug is the
only thing guarding it. The same goes for the JSON snapshot at `/api/shows/:slug`.

Slugs are unique across the whole server, not per account, because an overlay URL
is just a URL: if someone else already has `grand-finals`, you need a different
one.

Manage your email and password at `/users/settings`. Changing your password logs
out every other browser you are signed in on.

### Shows created before accounts existed

If you are upgrading an installation that ran without accounts, its shows have no
owner and appear on nobody's shelf. Their overlay URLs keep working the whole
time. Register the account that should have them, then:

```bash
mix showish.claim_shows operator@example.com
```

or, in a release:

```bash
bin/showish eval 'Showish.Release.claim_shows("operator@example.com")'
```

## Your first show

1. **Create it.** From the home page, *New show* → give it a title (say
   `Summer Cup — Grand Finals`). The URL slug fills itself in from the title;
   you can override it. The slug is the part of every overlay URL that
   identifies this show, so keep it short.

2. **You land in the control room.** Two teams already exist — a show without
   competitors cannot go on air, so they are created for you as *Team One* and
   *Team Two*.

3. **Fill in the teams.** Real name, short name, code, and their two colors. The
   colors are not decoration: the scorebug's score boxes, the plate gradients
   behind each team and the winner strips on the series board are all drawn from
   the primary color, and text on top of it flips between black and white
   automatically based on contrast. Use the colors from the team's actual kit
   and everything downstream looks deliberate.

4. **Build the series.** *Add game* once per map/level/set. Name and mode are
   free text — `Old Harbour` / `Control`, `Nuke` / `Bomb`, `Set 3` / `Doubles`.

5. **Add the crew.** *Add person* for each caster, host, analyst or observer.

6. **Grab the URLs.** *Overlay URLs* in the top right lists all seven scenes
   with a copy button each.

Nothing needs saving. The form writes as you type.

## Wiring overlays into OBS

For each scene you want:

1. Add a **Browser** source to your scene.
2. Paste the overlay URL.
3. Set **Width 1920, Height 1080**.
4. Leave the rest at OBS's defaults — the page is already transparent and
   already refuses to scroll.

Scenes are drawn on a fixed 1920×1080 canvas. For a bigger canvas, create the
source at 1920×1080 and scale it in your OBS scene rather than resizing the
source, so text stays crisp and the layout stays put.

**Which scenes leave the frame clear:** `scorebug`, `series`, `talent` and
`ticker` draw only their own furniture and are meant to sit over gameplay.
`standby`, `break` and `credits` paint a near-opaque backdrop across the whole
frame — they are full-frame cards, so put them in their own OBS scene rather
than on top of a game feed.

The same URLs work anywhere with a browser source: Streamlabs, vMix, Wirecast,
XSplit, Ecamm. There is nothing OBS-specific about them.

## The control room

`/shows/:slug/control`. Four editing panels, one strip of on-air buttons, and a
live preview.

### On air

The row of buttons at the top. These are the ones you hit mid-match, when there
is no time to tab through a form:

| Control | What it does |
| --- | --- |
| **− / +** per team | Series score, clamped at zero |
| **Swap sides** | Flips which team is drawn on the left, everywhere at once |
| **Previous / Next game** | Moves the series pointer, stopping at either end |
| **Reset scores** | Both teams back to zero (asks first) |

Swapping sides is presentation only. Team 1 stays Team 1 — the *Winner* dropdown
on a game still means the team you filled in as Team 1, no matter which side of
the screen they are currently drawn on.

### Match

| Field | Where it shows up |
| --- | --- |
| **Title** | Standby headline, credits headline, ticker label (if no stage) |
| **URL slug** | Every overlay URL. Changing it moves them all |
| **Stage** | Scorebug centre eyebrow, series header, ticker label |
| **Subtitle** | Standby and series header; scorebug falls back to it if stage is blank |
| **Countdown target (UTC)** | The clock on both standby and break |
| **Best of** | Series header; scorebug centre if no games exist yet |
| **Accent color** | Eyebrows, status pills, current-game outline, ticker block |
| **Look** | Which visual preset every scene is drawn in — see [Looks](#looks) |
| **Break message** | The headline on the break card |
| **Ticker** | Scrolling copy on standby, break and ticker |
| **Status — left / centre / right** | Free-text slots, each with its own on-air toggle |
| **Show side labels** | Whether each team's side label appears on the scorebug |

The three status slots are the escape hatch for whatever your broadcast needs
that the schema does not have — `OVERTIME`, `TECHNICAL PAUSE`, `MAP 3 PENDING`.
Left and right render as pills in the top corners of the scorebug. The centre
one replaces the line under the scorebug; **with the centre toggle off, that
line describes the current game instead** (`Game 3 · Old Harbour · Control`),
which is what you want most of the time.

### Teams

| Field | Notes |
| --- | --- |
| **Name** | The full name. Used wherever there is room: series, standby, break |
| **Short name** | What the scorebug and ticker print |
| **Code** | Three-ish letters. Also the fallback plate when there is no logo |
| **Record** | Free text — `4-1`, `12-2 (+18)`, anything |
| **Side label** | `Attack`, `Serve`, `Home` — only drawn when *Show side labels* is on |
| **Series score** | The big number. Usually easier to drive with the ± buttons |
| **Primary / Secondary color** | Primary drives everything; secondary is reserved for future scenes |
| **Logo URL** | Any publicly reachable image URL |

If a team has no logo, Showish draws a plate in their primary color with their
code on it — so a show with nothing but names and colors still looks finished.

### Series

One row per game. Each row has a name, mode, per-game scores, an image URL (used
as the card background on the series board), a note, a *Winner* dropdown and a
*Completed* checkbox.

Per-row buttons: **Make current** points the series at that game, the arrows
reorder, **Remove** deletes it. The row currently on air is outlined.

Per-game scores are separate from the series scores at the top. Series score is
"maps won"; per-game score is what happened inside that map.

### Talent

Role, name, pronouns, social handle, and an **On camera** tick. The arrows
reorder.

*On camera* is what the caster cams scene reads. Roles are free text, so Showish
cannot guess that your producer and observer are on the crew but not on the desk
— tick the people who have a camera and only they get a window. It changes
nothing on the talent or credits scenes, which still list everyone.

Order matters on the credits scene: it groups **consecutive** people who share a
role under one heading, so keep all your casters together and you get one
*Caster* heading rather than three.

### Preview

The panel on the right is a real overlay, loaded from its real URL and scaled to
fit. What you see there is what OBS composites, pixel for pixel. Use the tabs to
flip between scenes, and the copy button underneath to grab the URL for whichever
one you are looking at.

## Running a match

A rough script for a normal broadcast:

**Before the show.** Fill in teams, series and crew. Set *Countdown target* to
your go-live time (in UTC). Cut to `standby` — it shows the matchup and counts
down.

**Going live.** Cut away from standby. Bring up `scorebug`, and `talent` for the
first thirty seconds while the casters introduce themselves.

**During a game.** Leave the scorebug up. If you are tracking rounds inside a
map, type them into that game's *Team 1 / Team 2 score* fields. Flip *Show side
labels* on and set each team's side label if sides matter in your game; hit
**Swap sides** when they switch.

**Between games.** Set the finished game's *Winner*, tick *Completed*, bump the
winning team's series score with **+**, then hit **Next game**. Cut to `series`
for the between-games board.

**At the break.** Set *Countdown target* to when you are coming back, write a
*Break message*, cut to `break`.

**At the end.** Cut to `credits` and let it roll.

Everything above is safe to do while live. Writes go out over the open
websocket, so overlays never flicker, reload or drop a frame when something
changes.

## Scene reference

| Scene | URL | Frame | What it draws |
| --- | --- | --- | --- |
| **Scorebug** | `/overlay/:slug/scorebug` | Clear | Top bar: both teams, series score, current game, status pills |
| **Series** | `/overlay/:slug/series` | Clear | Every game, its result and what is next |
| **Talent** | `/overlay/:slug/talent` | Clear | Lower thirds — role, name, pronouns, social |
| **Caster cams** | `/overlay/:slug/cams` | Clear | Frames and name plates for a desk of camera sources |
| **Standby** | `/overlay/:slug/standby` | Full | Pre-show card: title, countdown, matchup, ticker |
| **Break** | `/overlay/:slug/break` | Full | Intermission: message, clock back to air, score, ticker |
| **Credits** | `/overlay/:slug/credits` | Full | Scrolling roll of the crew, grouped by role |
| **Ticker** | `/overlay/:slug/ticker` | Clear | Bottom bar: compact score and scrolling copy |

The talent scene is built for a desk of up to about five people at once; for the
whole crew, use credits.

**Caster cams draws nothing inside its windows, on purpose.** It is the furniture
around your camera sources, not the sources themselves: put your cams in the OBS
scene *underneath* this browser source and they show through, framed, with each
person's plate on them.

It draws only the people ticked **On camera** in the Talent panel, so your
producer and observer stay off the desk while still appearing in credits. Up to
four sit in a row; past that it wraps to a second row rather than shaving every
window down to a letterbox. With nobody ticked it says so rather than drawing an
empty frame.

## Looks

*Look* in the Match panel picks the visual preset the whole package is drawn in.
It applies to every scene at once, so a broadcast never mixes two, and it
switches live like everything else — flip it mid-show and every browser source
redraws without a reload.

| Look | Character |
| --- | --- |
| **Broadcast** | The default. Sheared panels, soft shadows, rounded corners, wide-tracked labels. |
| **Tranquility** | Flat rectangles, hard edges, condensed uppercase type. |

**Tranquility** moves the scorebug as well as restyling it. Instead of one bar
across the middle, each team gets a flat plate pinned to its own top corner with
the scores facing the centre, the current game sits in a slug at the top of the
frame and the stage name in one at the bottom. The plate is filled with the
team's primary color and the name and record are drawn in their *secondary*
color rather than auto-contrasted — so on this look, pick a secondary that reads
against the primary or the name will disappear into the plate.

The per-team status slots move too: *Status — left* and *Status — right* become
the small caption above each team's plate rather than pills in the frame corners.

**Series is rebuilt too.** Under Tranquility it becomes a map board: each team
takes a fixed column at its edge of the frame — logo plate above a white code
block above a very large white score block — and the games stack between them,
one full-width row each. The row for the game on air grows to fill whatever
vertical room the other rows leave, so a best-of-three and a best-of-seven both
fill the frame with no per-show tuning, and it carries an **Up next** banner.
Finished rows desaturate their artwork, sit under a wash of the winning team's
color and take that color as a thick strip along the bottom. The right-hand
column shows the winner's code once a game is called, an ellipsis on the game
being played and a dash on anything still to come.

The remaining five scenes follow the same package rather than a new geometry:

| Scene | Under Tranquility |
| --- | --- |
| **Series** | Laid out as a map board — a team column pinned to each edge, the series stacked down the middle |
| **Talent** | Narrow centred plates modelled on the caster lower third — name large, a small condensed sub-line under it, pronouns bracketed |
| **Caster cams** | Same plates, and each window gets a thick near-black matte instead of a hairline border |
| **Standby** | Team names in their own color, the countdown and the *vs* in the accent |
| **Break** | Same treatment, with the score as white blocks |
| **Credits** | Crew names roll in the accent |
| **Ticker** | A near-black tray with a black copy strip rather than a translucent bar |

Two details worth knowing, because they are the look rather than an accident:
panels are opaque `#101010` with a hard offset shadow instead of a soft ambient
one, and anything the original picked out in its brand yellow uses your show's
**Accent color** instead — so the highlight is yours, not a borrowed one.

Both looks use the same URLs, the same fields and the same control room. Nothing
about your OBS setup changes when you switch.

Typography is self-hosted from `priv/static/fonts` rather than pulled from a CDN,
so overlays render correctly on a venue machine with no internet.

## Things worth knowing

**The control room needs a login; overlays do not.** Shows belong to the account
that created them, and only that account can see or change them. The `/overlay`
routes stay open on purpose — broadcast software cannot log in — so anyone with a
slug can watch a show go out. See [Accounts](#accounts).

**Times are UTC.** *Countdown target* is a UTC datetime and both countdowns read
from it. A target in the past reads `00:00` rather than counting up, which is
what you want on screen.

**One countdown, two scenes.** Standby and break share *Countdown target*. Reset
it when you go into a break.

**Renaming the slug moves everything.** Change it and every overlay URL for the
show changes with it. The control room follows you to the new address and says
so; your OBS browser sources will not, so update them.

**Two operators are fine.** Both control rooms see each other's button presses
immediately. The *form fields* deliberately do not refresh under you while you
type — so if you are both editing the same text field at the same time, last
write wins.

**Empty slots degrade politely.** A team with nothing filled in reads `TBD` with
a plain plate; a game with no name reads `TBD`; a scene with no talent says so
rather than rendering an empty box. Nothing crashes mid-broadcast because a
field was left blank.

**An unknown slug is a 404.** If an overlay is blank in OBS, the slug is almost
certainly wrong — open the URL in a normal browser and you will see the error.

## Reading a show from somewhere else

```
GET /api/shows/:slug
```

Returns a JSON snapshot of the whole show — teams, games, talent, status slots.
For anything that cannot hold a websocket open: a static overlay, a bot, a
scoreboard built on another stack.

## For developers

### How it fits together

```
control room ──▶ Showish.Broadcasts ──▶ Phoenix.PubSub "show:<slug>"
   (LiveView)         (context)                    │
                                                   ▼
                                       overlay LiveViews (one per scene)
```

Reads and writes that belong to an operator take a `Showish.Accounts.Scope`, so
"whose show is this?" is answered in one place; the overlay LiveViews use the one
call that deliberately skips that check, because they are loaded by software that
cannot log in.

Every write goes through `Showish.Broadcasts`, which reloads the show and pushes
it to the `show:<slug>` topic. Overlays subscribe once at mount and re-render on
`{:show_updated, show}`. A LiveView diff over an open websocket is the whole
update path, so a score bump lands on air in milliseconds.

### Layout

```
lib/showish/accounts.ex                registration, login, session tokens
lib/showish/accounts/scope.ex          who a request is being served for
lib/showish_web/user_auth.ex           the login plugs and LiveView hooks
lib/showish/broadcasts.ex              the context: every write and the fan-out
lib/showish/broadcasts/                show, team, game, talent schemas
lib/showish/broadcasts/preset.ex       the catalogue of visual presets
lib/showish/colors.ex                  contrast and rgba helpers for operator colors
lib/showish_web/live/overlay_live.ex   shared mount/subscribe/tick for scenes
lib/showish_web/live/overlays/         one LiveView per scene
lib/showish_web/live/show_live/        index, overlay URLs, control room
lib/showish_web/scenes.ex              the scene catalogue
```

### Adding a scene

Three steps:

1. A LiveView under `lib/showish_web/live/overlays/`. `use ShowishWeb.OverlayLive`
   gives you `@show` (subscribed and kept current) and `@now` (ticking once a
   second); you supply `render/1` and wrap it in `<.stage>`.
2. A route in the `/overlay` scope.
3. An entry in `ShowishWeb.Scenes` — the preview tabs, the URL list and the copy
   buttons all come from that catalogue.

Shared pieces live in `ShowishWeb.OverlayComponents`: `<.stage>` (the 1920×1080
canvas), `<.team_logo>`, `<.countdown>`, `<.eyebrow>`, and the color helpers
(`primary/1`, `contrast/1`, `wash/2`) that keep scenes looking like one package.

### Adding a preset

The show carries a preset; `<.stage>` puts it on the canvas as a `preset-<key>`
class, and everything is scoped to that class so two looks cannot leak into each
other. Three steps:

1. An entry in `Showish.Broadcasts.Preset`. The control room dropdown and the
   changeset's `validate_inclusion` both read from that list.
2. A `.preset-<key>` block in `assets/css/app.css`. Restyling the shared
   primitives — `.overlay-panel`, the shear clip-paths, radius, type — is enough
   for most scenes, because they are all built from the same pieces.
3. Only for a scene whose *geometry* differs: a `render/1` clause matching on the
   preset. `ShowishWeb.Overlays.Scorebug` is the one that needs this, because
   Tranquility moves the teams to opposite corners rather than restyling a bar
   that stays put. Everything else is CSS.

### Tests

```bash
mix test
```
