# Overlays: adding scenes and presets

This guide covers the two visual extension axes. For game rules, live operator
controls, and sport-specific scene availability, see [Adding sports](sports.md).

An overlay is a browser source composited over live video by the broadcast
software. Two things vary independently:

- a **scene** — *what* is on screen (scorebug, talent lower-third, series board,
  caster cams, credits, …), and
- a **preset** — *how the whole package looks* (panel treatment, corner radius,
  typography, accent colour).

A show carries one preset; every scene honours it, so a broadcast never mixes two
looks across its browser sources.

The system is built so the two axes stay cheap and independent:

- **Adding a scene** touches only that scene's own files. It reads shared tokens,
  so it inherits every existing preset for free — you do **not** edit any preset.
- **Adding a reskin preset** (colour / radius / shadow / type only) is **one token
  file**. Every existing scene restyles automatically — you do **not** edit any
  scene.

The one thing this cannot do for free is a preset that changes a scene's
**layout/geometry** (a different element tree, not just different paint). CSS
cannot restructure the DOM, so that case needs a small per-scene markup fork.
See [Structural presets](#2b-a-structural-preset).

---

## How it fits together

```
lib/showish/broadcasts/preset.ex        The catalogue: one entry per preset.
lib/showish_web/live/overlay_live.ex     Shared mount/subscribe/tick for every scene.
lib/showish_web/live/overlays/*.ex       One LiveView per scene.
lib/showish_web/components/overlay_components.ex
                                         <.stage>, <.team_logo>, <.talent_details>,
                                         <.marquee>, <.empty_notice>, style helpers.
lib/showish_web/router.ex                One `live` route per scene under /overlay.

assets/css/
  app.css                               Tailwind/daisyUI setup, the @layer
                                        declaration, and the layered @imports.
  overlays/base.css                     The TOKEN CONTRACT (defaults on
                                        .overlay-stage), preset-agnostic
                                        foundation, .overlay-panel, and the
                                        .overlay-round-* utilities. Imported
                                        into @layer overlays.
  presets/<key>/
    _index.css                          Imports this preset's files.
    tokens.css                          The preset: a block of --overlay-* overrides.
                                        Imported into @layer presets. Reskin
                                        presets need nothing else.
    <scene>.css                         Only for scenes this preset restructures.
```

### The two ideas that make it work

**1. A token contract.** Every value a preset might want to change is exposed as
a CSS custom property with a default, declared once in `base.css` on the stage
root so it inherits into every scene. **These defaults *are* the broadcast
look** — the package's baseline skin — so the broadcast preset adds no token
overrides of its own:

```css
.overlay-stage {
  --overlay-panel-bg: linear-gradient(180deg, rgba(9,12,18,.94), rgba(9,12,18,.86));
  --overlay-panel-border: 1px solid rgba(248,250,252,.12);
  --overlay-panel-shadow: none;
  --overlay-panel-blur: blur(6px);
  --overlay-radius-pill: 0.25rem;  /* side / status indicators */
  --overlay-radius-logo: 0.375rem; /* team logo plates */
  --overlay-radius-card: 0.5rem;   /* content panels */
  --overlay-radius-hero: 0.75rem;  /* full-frame cards */
  /* …one line per themeable knob… */
}
```

Scenes read tokens, never literals. `.overlay-panel` is the shared card recipe,
and radius is chosen by *role* through the `.overlay-round-*` utilities rather
than by a Tailwind `rounded-*` size — so a preset controls every corner from the
four tokens above:

```css
.overlay-panel {
  background: var(--overlay-panel-bg);
  border: var(--overlay-panel-border);
  border-radius: var(--overlay-radius-card);
  box-shadow: var(--overlay-panel-shadow);
  backdrop-filter: var(--overlay-panel-blur);
}
.overlay-round-hero { border-radius: var(--overlay-radius-hero); }
```

In markup, a scene picks the role — `<div class="overlay-panel overlay-round-hero">`
or `<.team_logo radius="hero">` — never a pixel size. A component that reads
`var(--token)` is **preset-agnostic**: it does not know or care which preset is
on. That is what lets a new scene inherit every preset, and a new preset restyle
every scene, without either editing the other.

**2. Cascade layers instead of scope selectors.** `app.css` declares, *after*
Tailwind's own `@layer theme, base, components, utilities`:

```css
@layer overlays, presets;   /* both sort after utilities; presets wins over overlays */
```

Layer order is fixed by first declaration, so appending `overlays` and `presets`
here places them **above every Tailwind utility**. `base.css` and broadcast
import into `overlays`; each preset's `tokens.css` imports into `presets`. Two
consequences:

- A rule in `overlays` beats a Tailwind utility (`rounded-lg`, `tracking-*`) with
  a plain selector — no `!important`. This is why `.overlay-round-*` can override
  a `rounded-*` class, and why it is safe to drop `rounded-*` from scene markup.
- A rule in `presets` beats one in `overlays` regardless of specificity, so a
  preset overrides a token (or, rarely, a whole rule) with a plain, **unprefixed**
  selector. That is why preset files are short.

> **Do not reuse Tailwind's layer names.** A layer literally named `base` is
> *Tailwind's* base layer, which sorts *below* `utilities` — rules put there
> would lose to `rounded-*`. Always use the fresh `overlays` / `presets` names.

`<.stage>` still stamps a `preset-<key>` class on the stage root, so a preset's
token block is written `.preset-<key> { … }` and only applies when that preset is
active. That selector is doing **scoping** (apply only under this preset), which
is a different job from **winning the cascade** (handled by the layer) — which is
why a reskin preset never needs `.preset-<key> .overlay-thing` descendant rules.

---

## 1. Add a scene

Worked example: a "standings" table. Four edits, all in the scene's own turf.
No preset file is touched.

### Step 1 — the LiveView

`lib/showish_web/live/overlays/standings.ex`:

```elixir
defmodule ShowishWeb.Overlays.Standings do
  use ShowishWeb.OverlayLive   # mount, subscribe, and per-second tick for free

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.stage preset={@show.preset} accent={@show.accent_color}>
      <div class="overlay-standings overlay-panel overlay-in-up">
        <%!-- rows reading @show data --%>
      </div>
    </.stage>
    """
  end
end
```

- `use ShowishWeb.OverlayLive` supplies the shared `mount/3` (look the show up by
  slug, subscribe, tick every second). You only write `render/1`.
- It also hands you the assigns every scene turned out to need: `@show`, `@left`
  and `@right` (the two teams with `swap_sides` already applied — either may be
  `nil`), and `@now`.
- Wrap the scene in `<.stage>` and pass `@show.preset`. The stage stamps the
  `preset-<key>` class, so the preset system applies automatically.
- Reuse the shared primitives — the components in `overlay_components.ex`
  (`<.team_logo>`, `<.talent_details>`, `<.marquee>`, `<.empty_notice>`), the
  `overlay-panel` recipe, the `overlay-in-*` entrances — wherever they fit, and
  `Showish.Text` for deciding what an empty field should say.

### Step 2 — the route

`lib/showish_web/router.ex`, one line inside the existing `/overlay` scope:

```elixir
live "/:slug/standings", Standings
```

The browser source is then `…/overlay/<slug>/standings`.

### Step 3 — the catalogue entry

Add the scene to `ShowishWeb.Scenes`. This one entry drives the control-room
preview tabs and the browser-source URL list:

```elixir
%{
  key: "standings",
  name: "Standings",
  summary: "League table with records and rank changes."
}
```

Scenes are shared by every sport unless they include a `:sports` restriction:

```elixir
%{
  key: "diamond-defense",
  name: "Diamond defense",
  summary: "Current fielders and defensive alignment.",
  sports: ["baseball"]
}
```

Use `sports: ["sport-a", "sport-b"]` when several registered sports share a
scene. See [Decide which scenes apply](sports.md#step-5--decide-which-scenes-apply)
for the complete behavior.

### Step 4 — the scene's structural CSS

In `assets/css/overlays/base.css`. That file is imported into `@layer overlays`,
so write plain rules — do **not** wrap them in an `@layer` block yourself; the
`@import … layer(overlays)` in `app.css` already places them. Read tokens for
anything a preset should be able to change:

```css
.overlay-standings {
  display: grid;
  gap: 0.25rem;
  background: var(--overlay-panel-bg);   /* preset decides the fill */
}

/* Pick a radius role rather than a size, so a preset controls the corner. */
.overlay-standings-card {
  border-radius: var(--overlay-radius-card);
}
```

In markup, reach for the shared `.overlay-round-*` utilities (or `.overlay-panel`)
rather than a Tailwind `rounded-*` class, so the corner stays reachable by a
preset.

**Done.** You did not open any `presets/` folder — every existing preset skins the
new scene through the tokens it already sets.

> **If the scene needs a brand-new knob** no token covers (say a zebra-stripe
> colour), add it to the contract on `.overlay-stage` in `base.css` with a
> sensible default: `--overlay-stripe: rgba(255,255,255,.04);`. Existing presets
> inherit the default silently; only a preset that wants a *different* stripe adds
> one line. Still not "edit every preset."

---

## 2. Add a preset

First decide which kind it is:

- **Reskin** — it only changes colour, radius, shadow, spacing, or type. → §2a,
  one file.
- **Structural** — it rearranges a scene's layout / element tree (as Tranquility
  re-pins the scorebug to opposite corners). → §2a **plus** §2b for each scene
  that differs.

### 2a. A reskin preset

Worked example: "Midnight". Three edits, no per-scene work.

**Step 1 — the catalogue entry.** `lib/showish/broadcasts/preset.ex`, one map in
`@presets`:

```elixir
%{key: "midnight", name: "Midnight", summary: "High-contrast, neon accents."}
```

This alone makes the preset selectable in the control room and pass validation —
`options/0`, `keys/0`, and `stage_class/1` all derive from this list.

**Step 2 — the token file.** `assets/css/presets/midnight/tokens.css` — pure
variable overrides, scoped to the preset's stage class. Write plain rules; the
layer is applied by the `@import … layer(presets)` in Step 3, so do **not** wrap
this in an `@layer` block:

```css
.preset-midnight {
  --overlay-panel-bg: #0a0a14;
  --overlay-panel-border: 0;
  --overlay-radius-card: 0.5rem;
  --overlay-radius-hero: 0.75rem;
  /* …only the tokens that differ from the default… */
}
```

Give it an `_index.css` that imports its files (mirroring the existing presets),
so a structural preset (§2b) can add scene files without touching `app.css`
again.

**Step 3 — the import.** In `assets/css/app.css`, alongside the other presets,
into the `presets` layer:

```css
@import "./presets/midnight/_index.css" layer(presets);
```

**Done.** No `.preset-midnight .overlay-panel { … }` rules, no per-scene files.
Every scene — including any added later — restyles because they all read
`var(--overlay-*)`, and the `presets` layer lets these plain, unprefixed
selectors win.

### 2b. A structural preset

Tokens cannot change layout — CSS cannot add, remove, or reparent DOM nodes. When
a preset must restructure a scene, do everything in §2a, then, **for each scene
whose geometry actually differs**:

**Step 4 — fork that scene's markup** with a `render_preset/1` clause matching on
the preset:

```elixir
@impl Phoenix.LiveView
def render(assigns), do: render_preset(assigns)

defp render_preset(%{show: %{preset: "midnight"}} = assigns), do: midnight(assigns)
defp render_preset(assigns), do: default(assigns)

defp midnight(assigns) do
  ~H"""
  <.stage preset={@show.preset} accent={@show.accent_color}>
    <%!-- the restructured element tree for this look --%>
  </.stage>
  """
end
```

**Step 5 — that look's structural CSS** for the scene, in
`assets/css/presets/midnight/<scene>.css`, and add it to the preset's
`_index.css` (which already imports into `@layer presets` — no `app.css` change).
Use classes only this look emits so they cannot leak into other presets.

Scenes that keep their default geometry (typically talent, ticker, cams) need
**nothing** beyond the token file from §2a.

---

## Cost at a glance

| Task | Files touched |
|------|---------------|
| Add a scene | 1 LiveView + 1 route line + 1 catalogue entry + 1 rule in `base.css`. **Zero preset files.** |
| Add a reskin preset | 1 catalogue entry + 1 token file + 1 layered `@import`. **Zero scene files.** |
| Add a structural preset | the reskin steps **+** a `render_preset/1` fork and a CSS file for **only the scenes that differ**. |

---

## Removing a preset

Reverse §2a: delete its `presets/<key>/` folder, remove its `@import` from
`app.css`, and delete its `@presets` entry. Nothing else references it — shows
set to a removed key fall back to the default via `Preset.fetch/1`.

## Conventions to keep

- **Scenes read tokens, never literals.** A hard-coded colour or radius in a scene
  is a value a preset can no longer reach — it is a bug waiting to be filed. For
  corners that means the `.overlay-round-*` utilities (or `<.team_logo radius=…>`),
  never a Tailwind `rounded-*` class.
- **Preset token files carry no layout.** If you are writing `display`,
  `position`, or `flex` in a `tokens.css`, it belongs in a scene file (§2b) or the
  value should have been a token.
- **Do not scope with `.preset-<key> .thing` to win specificity.** That is what the
  `presets` cascade layer is for. Reach for a descendant selector only when you
  genuinely mean "this element, only under this preset" (as with the shear-removal
  and scoreplate-invert rules Tranquility keeps).
- **Never wrap a CSS file in `@layer`.** The layer is applied at import time by
  `app.css` (`@import … layer(overlays|presets)`). Write plain rules; wrapping them
  again nests a layer inside a layer and changes where they land.
- **New themeable value → new token.** Add it to the contract on `.overlay-stage`
  in `base.css` with a default so every existing preset keeps working untouched.
