# Fonts

These are vendored rather than pulled from a CDN. An overlay is loaded as a
browser source on a machine that may have no internet at showtime, and a scene
that silently falls back to a different face mid-broadcast is worse than a
slightly larger repo. `@font-face` declarations live in `assets/css/app.css`.

Both families are licensed under the SIL Open Font License 1.1, which permits
redistribution alongside this project.

| File | Family | Source |
| --- | --- | --- |
| `Heebo-latin.woff2` | Heebo (variable, latin subset) | <https://fonts.google.com/specimen/Heebo> |
| `Oswald-Medium.woff` | Oswald 500 | <https://fonts.google.com/specimen/Oswald> |
| `Oswald-SemiBold.woff` | Oswald 600 | <https://fonts.google.com/specimen/Oswald> |
| `Oswald-Bold.woff` | Oswald 700 | <https://fonts.google.com/specimen/Oswald> |

Full licence text: <https://openfontlicense.org/>

Only the Tranquility preset uses them; the default Broadcast preset draws on the
system stack and loads none of these.
