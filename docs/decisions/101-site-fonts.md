---
date: 2026-11-12
issue: 101
status: accepted
---

# The site serves Latin-only WOFF2 cuts of Inter and Caveat, at the weights it uses

**Decision:** `site/assets/fonts/` holds two files made from `Shared/Fonts/` (`docs/decisions/84-bundled-fonts.md`),
with their OFL files beside them, loaded by `site/assets/paper-ink.css` with `font-display: swap`:

| File | Made from | Size | SHA-256 |
|---|---|---|---|
| `Inter.woff2` | `Inter.ttf`, `wght` 400 to 700, `opsz` fixed at 14 | 30 KB | `bb44f4354f9332ffedcb77eacd8f1492a36dd023491be788835533b9df99eedd` |
| `Caveat-Bold.woff2` | `Caveat.ttf`, static at `wght` 700 | 50 KB | `5211245f4781c1c21e0e530ab837b3d4ad24833c2cb577440bcd8dec361907bb` |

Made with fontTools 4.68.0 and brotli 1.2.1:

```sh
U="U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+2000-206F,U+20AC,U+2122,U+2190-2193,U+2212,U+2215,U+FEFF,U+FFFD"
fonttools varLib.instancer Shared/Fonts/Inter.ttf wght=400:700 opsz=14 -o Inter-400-700.ttf
fonttools varLib.instancer Shared/Fonts/Caveat.ttf wght=700 -o Caveat-700.ttf
pyftsubset Inter-400-700.ttf --unicodes="$U" --flavor=woff2 --output-file=site/assets/fonts/Inter.woff2
pyftsubset Caveat-700.ttf --unicodes="$U" --flavor=woff2 --output-file=site/assets/fonts/Caveat-Bold.woff2
```

**Why:**

- **Latin only:** `U` is Google Fonts' "latin" range, which covers every character the English pages use, including
  → and curly quotes. Other scripts fall back to the system font; a page in another language sets its own fallbacks
  (`site/CLAUDE.md`).
- **Only the weights the pages use:** subsetting alone left Inter at 100 KB and Caveat at 76 KB. The pages use Inter
  400 and 700 and Caveat 700 only, as the app does, so cutting the axes down brings both to 80 KB together.
  Inter's optical size is fixed at 14, its text setting: the site has no Inter large enough to need the display cut.
- **Served from the site,** not a font CDN, so the pages make no third-party requests.
- **OFL:** both fonts have no Reserved Font Name, so the modified files keep their names. Each ships with its license.

Rejected: subsetting the variable fonts unchanged, which the issue suggested, at more than twice the size.
