# Themes

A theme is a look you make yourself, without changing Showish's code. It starts
from one of the built-in looks (Broadcast, Tranquility or Laggish), keeps that
look's layout, and changes how it is drawn: colors, corners, borders, shadows,
fonts, entrances, and if you need it, your own CSS.

Themes are saved to your account. Pick one for a show from the control room's
**Look** menu, where your themes are listed under the built-in ones. Overlays
redraw the moment you save a change; you never reload a browser source.

## Making one

**Themes → + New theme**, give it a name and the look to build on, and the
editor opens. It is laid out like the control room: the fields save as you type,
and the preview on the right draws a real scene of one of your shows in the
theme. The preview does not touch that show, so you can build a theme while the
show is on air in another look.

- **Design** holds the tokens below. A blank field keeps the base look's own
  value, so a new theme is exactly its base look until you change something.
- **Fonts** takes a font file for words and one for numbers. The file is stored
  inside the theme, so overlays never fetch a font from anywhere else, and a
  venue machine with no internet still draws it. Uploading a font picks it.
- **Custom CSS** is for anything the tokens do not cover. It is a `.css` file
  you upload, starting from the template. See [Custom CSS](#custom-css).

## Sharing

There are two ways, and both give the other person their own copy. A copy does
not follow your later edits, so nothing you change can alter a broadcast
somebody else has on air.

- **Share link.** The editor's Share panel has a link. Anyone signed in who opens
  it can add a copy to their account. *Reset link* stops the old link working.
- **Theme file.** *Download file* saves the theme as JSON, fonts included.
  **Themes → Import file…** reads one into your account. A name you already use
  gets a number added ("Acme (2)") rather than replacing anything.

## The file

A theme file is JSON. Everything except `format`, `version` and `name` is
optional.

```json
{
  "format": "showish-theme",
  "version": 1,
  "name": "Acme Esports",
  "base": "broadcast",
  "tokens": {
    "panel_color": "#101a3a",
    "panel_opacity": 0.96,
    "border_color": "#ffd400",
    "border_width": 2,
    "shadow": "hard",
    "radius": 0,
    "text_color": "#ffffff",
    "grays": "zinc",
    "font": "custom",
    "numbers_font": "geist-mono",
    "entrance": "fade",
    "entrance_ms": 300
  },
  "fonts": {
    "text": { "name": "Acme Sans", "format": "woff2", "data": "d09GMgABAAAA…" }
  },
  "css": ".overlay-talent { border-bottom-color: #ffd400; }"
}
```

`base` is `broadcast`, `tranquility` or `laggish`. An unknown token, a value out
of range or a misspelt key is refused with a message naming it, so a hand-edited
file says what is wrong instead of silently doing nothing.

### Tokens

| Token | Value | What it changes |
| --- | --- | --- |
| `panel_color` | hex color | The fill behind every card, plate and bar |
| `panel_opacity` | 0 to 1 | How see-through that fill is |
| `border_color` | hex color | The line around panels |
| `border_width` | 0 to 8 (px) | Its width; 0 for none |
| `shadow` | `none`, `soft`, `hard` | A blurred glow or a sharp offset under panels |
| `blur` | 0 to 24 (px) | Frosts whatever shows through a see-through panel |
| `radius` | 0 to 32 (px) | Card corners. Pills take half, logos three quarters, full-frame cards one and a half |
| `text_color` | hex color | The main ink. Team colors and the show's accent are unaffected |
| `grays` | `slate`, `gray`, `zinc`, `neutral`, `stone` | The tint of secondary text and dividers |
| `font` | `system`, `geist`, `heebo`, `oswald`, `geist-mono`, `custom` | The face for words. `custom` is the theme's `text` font file |
| `numbers_font` | `same`, `system`, `geist`, `heebo`, `oswald`, `geist-mono`, `custom` | Scores, clocks and records. `custom` is the `numbers` font file, or the `text` one |
| `entrance` | `slide`, `fade`, `none` | How pieces arrive when a scene is cut to. `slide` is the base look's own |
| `entrance_ms` | 0 to 1500 | How long each piece takes |

The show's **Accent color** stays a per-show setting, so one theme serves every
event a company runs.

### Fonts

`fonts` has up to two entries, `text` and `numbers`. Each is a `name` (letters,
numbers, spaces, dots and dashes), a `format` (`woff2`, `woff`, `ttf` or `otf`)
and the file itself as base64 in `data`, up to 600 KB before encoding. Subset a
large font to the scripts you need before uploading it. Only use a font your
license lets you embed and redistribute.

## Custom CSS

A theme's CSS is a file, not something typed into the app:

1. **Download template** (on the Themes page, or in the editor's Custom CSS
   panel) gives you `showish-theme-template.css`. It lists every variable and
   class a theme can reach, each with an example, all commented out, so as
   downloaded it changes nothing. The same file is
   [`priv/themes/template.css`](../priv/themes/template.css) in this repository.
2. Uncomment the parts you want and change the values, in any editor.
3. Upload it: **Upload CSS file…** in a theme's Custom CSS panel replaces that
   theme's CSS, or **Themes → Import file…** makes a new theme from it, named
   after the file and built on Broadcast.

*Download CSS* gives the current file back to edit again. The panel shows the
CSS it holds, read-only.

The theme's CSS loads after everything else, on that theme's overlays only, and
outside the cascade layers the built-in looks use, so a plain selector wins over
them. Scope rules to your theme with `.overlay-stage` if you like; it is not
required. The classes worth targeting are listed in
[the overlay guide](overlays.md#2c-reaching-what-tokens-cannot).

A theme can be shared, so its CSS may be written by somebody else, and CSS can
make a browser fetch things. A fetch that depends on a selector is enough to
leak what is on the page or tell the author who is watching. So theme CSS may
not reach the network at all:

- no `@import`;
- no `url()` except an embedded `data:` URL (images and fonts travel inside the
  theme);
- no `image-set()` or `src()`;
- no `<` and no `\` (a backslash escape could spell a forbidden word), comments
  included.

A file that breaks a rule is refused whole, with the reason, and the theme and
its overlays keep the CSS they had. The file must be UTF-8 text, up to 200 KB.

A setting under **Design** wins over the same variable in the file; leave it
blank there to control it from the CSS.

Inline colors set from the control room (a team's colors, the show's accent) are
written on the element, so a rule changing them needs `!important`.

## For developers

- `Showish.Themes` is the context: scoped reads and writes, files, sharing and
  the stylesheet.
- `Showish.Themes.Tokens` lists the tokens. Adding one is an entry in its list
  and a clause in `declarations/2`; the editor and the file format follow. Add
  it to the table above too (a test checks).
- `Showish.Themes.CustomCSS` holds the rules above.
- Overlays load the stylesheet from `/overlay/themes/:id/:version`, which is
  public like the overlays and cached forever, because the version changes with
  every edit. `ShowishWeb.OverlayLive` puts the theme on the stage and sets the
  show's preset to the theme's base, so every scene rebuilds itself for that
  base exactly as it would for the built-in look.
- The editor's preview adds a signed `theme_preview` parameter to the overlay
  URL (`ShowishWeb.ThemePreview`). It only dresses that page, never the show.
