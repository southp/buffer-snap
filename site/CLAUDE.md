# site/

Public pages on GitHub Pages (`https://southp.github.io/buffer-snap/`), published from this folder by
`.github/workflows/pages.yml`. How it deploys: `.github/CLAUDE.md`, "Site".

- **`oauth/` is off-limits.** It's Buffer's registered redirect URI, and the app's sign-in depends on it
  (`docs/decisions/43-oauth-redirect-page.md`). `oauth-scope-check/` is a developer tool with its own style and
  script. The rules below are for the pages users read, `support/` and `privacy/` and their translations, and don't
  apply to either.
- **One stylesheet:** every page links `assets/paper-ink.css`, Paper & Ink as in the app
  (`docs/decisions/84-paper-and-ink.md`). No inline `<style>` and no per-page stylesheet: add a class there instead.
  Its colors mirror `Shared/Theme.xcassets`, light and dark; change them in both.
- **Every language shares it.** The stylesheet holds no text. A page in another language sets `lang` on `<html>`,
  links the same file (`../../assets/paper-ink.css` from a folder one level deeper), and if it needs other fallback
  fonts, sets `--font-text` and `--font-hand` under its `:lang()` there. The bundled fonts are Latin only
  (`docs/decisions/101-site-fonts.md`).
- **A page's markup:** `header.site-header` (the Doodle Bulb, "BufSnap" and the App Store chip), then `main` with the
  `h1`, a `div.intro` for the paragraphs under it, and one `section.card` per `h2`.
- **No JavaScript and no third-party requests:** no CDN, font service, analytics or embeds. Everything a page loads
  comes from this folder. Links out are fine.
- **Check a change** with a local server (`python3 -m http.server -d site`), in light and dark, at 390 px and desktop
  width, and in the Network tab that every request is to the server itself. Text colors must meet WCAG AA (4.5:1) on
  both paper and a card.
- What the pages say is set elsewhere: `site/privacy/` follows what the app does, and `site/support/` follows its
  steps (root `CLAUDE.md`, "Docs that describe behavior").
