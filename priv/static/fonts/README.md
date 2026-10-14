# Fonts

These are vendored rather than pulled from a CDN. An overlay is loaded as a
browser source on a machine that may have no internet at showtime, and a scene
that silently falls back to a different face mid-broadcast is worse than a
slightly larger repo. The control room is often run from that same machine, so
its fonts are vendored too.

All families are licensed under the SIL Open Font License 1.1, which permits
redistribution alongside this project.

| File | Family | Used by | Source |
| --- | --- | --- | --- |
| `Heebo-latin.woff2` | Heebo (variable, latin subset) | Tranquility overlays | <https://fonts.google.com/specimen/Heebo> |
| `Oswald-Medium.woff` | Oswald 500 | Tranquility overlays | <https://fonts.google.com/specimen/Oswald> |
| `Oswald-SemiBold.woff` | Oswald 600 | Tranquility overlays | <https://fonts.google.com/specimen/Oswald> |
| `Oswald-Bold.woff` | Oswald 700 | Tranquility overlays | <https://fonts.google.com/specimen/Oswald> |
| `Geist-Variable.woff2` | Geist (variable) | Control room | <https://github.com/vercel/geist-font> (npm `geist` 1.7.2) |
| `GeistMono-Variable.woff2` | Geist Mono (variable) | Control room | <https://github.com/vercel/geist-font> (npm `geist` 1.7.2) |

Full licence text: <https://openfontlicense.org/>

The overlay `@font-face` declarations live in `assets/css/overlays/base.css`,
the control room ones in `assets/css/ui-local.css`. The default Broadcast
overlay preset draws on the system stack and loads none of these.
