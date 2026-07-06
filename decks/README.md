# Decks

Reveal.js presentations authored the same way as the blog posts: Quarto `.qmd`, vigil theme, rendered by CI, published under `lopes.id/decks/<slug>/` — **silently**. No navbar entry, no talks index, no discovery on-site. A URL exists for anyone who has it; nothing on `lopes.id` links to it.

## Runbook — from idea to published deck

Zero to a live deck at `lopes.id/decks/<slug>/` in eight steps. Assumes the git hook is installed (`./scripts/setup.sh`, one-time) and branch protection is on `main`.

### 1. Branch

```bash
git checkout main && git pull
git checkout -b post/<slug>          # no deck/talk namespace yet; use post/
```

Slug is kebab-case, ≤ 50 characters. It's the deck's directory name AND its URL segment (`lopes.id/decks/<slug>/`).

### 2. Folder + brief

```bash
mkdir -p decks/<slug>/apps decks/<slug>/images
```

Drop a brief at `decks/<slug>/_brief.md`. Anything works — outline, voice-memo transcript, half-sentences, links, image refs, contradictions. **The underscore prefix keeps Quarto from rendering it** to the site.

If you already have a brief elsewhere (a separate talks repo, an Obsidian note, etc.):

```bash
cp ~/somewhere/existing-notes.md decks/<slug>/_brief.md
```

Otherwise start fresh:

```bash
$EDITOR decks/<slug>/_brief.md
```

For a working example, look at `decks/lantana-little-help-claude/_brief.md` — cleanest structural template for a new brief.

#### The brief, at a minimum

Include: **audience**, **duration in minutes**, **TLP** (`clear` / `white` / `green` only — everything else is rejected at commit), **event context**, **rough section structure**. The skill asks for anything missing.

### 3. Scaffold the deck

In a Claude Code session (this one or a fresh one), say:

> scaffold-deck from `decks/<slug>/_brief.md`

The `scaffold-deck` skill will:

- Ask for `duration` and `tlp` if they're not in the brief. Never guesses — a wrong TLP is a hard error.
- Compute a slide budget from `duration` (Q&A buffer = `max(5, round(0.15 × duration))`).
- Refuse to overfill — if the outline doesn't fit, it cuts and states what.
- Write `decks/<slug>/index.qmd` with front matter, mono kickers, TLP badge, columns, progressive code reveals, and inline SVG where a diagram would be structural.
- Leave `INSERT_` markers for anything it can't confidently infer (hero images, dates, external references).
- **Push back on `amber`/`red` requests** and redirect you to a private repo. Pre-commit will reject them anyway.

Hand-authoring is fine too — copy the [Front-matter reference](#front-matter-reference) below.

### 4. OG image

Drop `decks/<slug>/og-<slug>.webp` (≤ 300 KB, ≤ 70-char filename). Pre-commit rejects a deck without an `image:` field. For silent-publishing decks the OG image is rarely seen — a solid-color card or hand-composed screenshot is fine.

### 5. Preview live

```bash
quarto preview decks/<slug>/index.qmd
```

Browser opens at a local port. Speaker view: press **S**. Save the `.qmd` → browser re-renders. Iterate here until the deck feels right.

Keyboard cheatsheet:
- `→` / `↓` — next slide / next reveal step
- `←` / `↑` — back
- `S` — speaker notes view
- `F` — fullscreen
- `Esc` — slide overview grid
- `B` — blank the screen (for Q&A pauses)

### 6. Dry-run the pipeline

```bash
rm -rf _test-site
quarto render --output-dir _test-site
bash scripts/pre-commit.sh
```

Render should complete without errors; pre-commit should pass. If anything fails, fix before staging.

### 7. Commit

```bash
git add decks/<slug>/
git status                                    # sanity-check what's staged
git commit -m "decks: add <slug> talk on <topic>"
```

The pre-commit hook fires here and fails the commit if any rule is violated. Common failures:

- `tlp: amber` (or `red`) → not publishable in this repo; change to `green`/`white`/`clear` or move the material to a private repo
- Title > 60 or description > 160 → trim
- Missing `image:` field → add it
- Any brief / notes file inside the deck folder without an `_` prefix → rename to `_brief.md` (or another `_`-prefixed name)
- Non-`apps/` `.html` files in the deck → move under `apps/` or delete

Full list under [Common pitfalls](#common-pitfalls).

### 8. Push, PR, merge

```bash
git push -u origin post/<slug>
gh pr create --title "decks: add <slug>" --body "$(cat <<'EOF'
## Summary
- New deck: <one-line description>
- Event: <where you'll present>
- TLP: <clear|white|green>

## Test plan
- [ ] Local `quarto preview` renders cleanly
- [ ] Speaker view works
- [ ] Iframe apps (if any) load
EOF
)"
```

PR CI runs `scripts/pre-commit.sh` + a full `quarto render`. Merge to `main` → deploy workflow renders and ships. Live at `https://lopes.id/decks/<slug>/` within ~2 minutes. No navbar entry, no talks index — you share the URL yourself.

## Front-matter reference

Full annotated shape for `decks/<slug>/index.qmd`:

```yaml
---
title: "..."                 # ★ ≤ 60 chars
subtitle: "..."              # optional; one-line hook
description: "..."           # ★ ≤ 160 chars, no trailing period (OG card + future indexes)
image: og-<slug>.webp        # ★ .webp only, ≤ 300 KB
tlp: green                   # ★ clear | white | green — see TLP section below
duration: 15                 # minutes; drives the scaffold-deck skill's slide budget
event: "..."                 # optional; free-form event name
date: 2026-05-01             # optional; talk date

# Only needed if the deck uses `background-iframe` escape-hatch slides:
resources:
  - apps/

format:
  revealjs:
    # Theme is fully picked by the SCSS path. NEVER add a top-level `theme:` field
    # (Quarto merges it with reveal's `theme:` list and stacks a stray built-in theme).
    theme: [default, ../../static/styles/vigil-reveal-dark.scss]   # or -light
    incremental: true
    code-line-numbers: true
    slide-number: c/t
    toc: false
    controls: true
    progress: true
    history: true
    hash-type: number
---

## Deck title {.center}

[TLP:GREEN]{.tlp-badge}

[EVENT · YYYY-MM-DD]{.kicker}

One-line hook.

::: notes
Speaker cue for the opening.
:::

## First slide

[SECTION KICKER]{.kicker}

Body copy.
```

Fields marked ★ are enforced by pre-commit.

## TLP — publishable values only

**This repo is public.** Sensitive presentations don't live here — they belong in a separate private repo. The pre-commit hook enforces this: only publishable TLP values are accepted at commit time. There is no runtime filter; TLP is provenance metadata + a commit-time gate.

| `tlp:` value    | Accepted? | Meaning |
|-----------------|:---------:|---------|
| `clear`         | ✅ | TLP 2.0 unrestricted; freely shareable |
| `white`         | ✅ | TLP 1.0 legacy alias for `clear` |
| `green`         | ✅ | Community disclosure. `lopes.id` is treated as the author's community platform — this is a project-specific reading of GREEN, not standard TLP 2.0 semantics |
| `amber`         | ❌ | Rejected at commit — author in a private repo |
| `amber+strict`  | ❌ | Same |
| `red`           | ❌ | Same |
| *(missing)*     | ❌ | Rejected at commit — TLP is required |

Every published deck must declare `tlp:` explicitly. The badge on the title slide (`[TLP:CLEAR]{.tlp-badge}`) mirrors the front-matter value.

## Slide conventions

The vigil-reveal theme adds two hooks on top of standard Quarto revealjs:

- **`[TEXT]{.kicker}`** — mono ALL-CAPS section label. Use one per slide, above or below the title.
- **`[TLP:CLEAR]{.tlp-badge}`** — framed mono chip. Use once, on the title slide only.

Everything else is standard Quarto revealjs:

- **Progressive code reveal** — ` ```yaml{code-line-numbers="1|2-3|4"} `. Each `|`-separated segment is an arrow-key step.
- **Columns** — `:::: columns` / `::: {.column width="50%"}` blocks. Two columns is the sweet spot.
- **Fragments** — `::: {.fragment}` blocks reveal one at a time. `incremental: true` (default in the template) makes bulleted lists advance one bullet per step automatically.
- **Speaker notes** — `::: notes` blocks. Press `S` in the deck for speaker view.
- **Inline SVG** — draw diagrams directly in the `.qmd`. Use `stroke="currentColor"` so they work on both dark and light themes. One accent color per SVG (`#057dbc` on light, `#4db8e0` on dark). See [`references/reveal-conventions.md`](../../.config/claude/skills/scaffold-deck/references/reveal-conventions.md) for the full pattern.
- **Mermaid diagrams** — ` ```{mermaid} ` blocks render natively. The theme sets the mermaid font to JetBrains Mono.
- **Iframe escape-hatch** — `## Title {background-iframe="apps/poll.html"}`. Use for live polls, embedded tools, custom canvas animations, anything that genuinely needs to be an interactive HTML app. The referenced file must live at `decks/<slug>/apps/<name>.html`. Requires `resources: - apps/` in front matter (Quarto doesn't auto-detect iframe paths).

**What NOT to do:**

- No inline `<style>` or `<script>` tags. If you need code, that's what `apps/` is for.
- No top-level `theme:` field in front matter. Quarto merges it with reveal's own `theme:` list and stacks a stray built-in theme on top of vigil. The SCSS path in `format.revealjs.theme` is the single source of truth.
- No PDF export. Decks are HTML mini-sites.
- No `decks/index.qmd`, no navbar entry. Silent publishing.

## File layout

```
decks/
  README.md                  # this file — auto-excluded by Quarto
  _metadata.yml              # shared defaults for all decks (no freeze, no citation)
  <slug>/
    index.qmd                # the deck source (front matter + slides) — the ONLY thing Quarto renders here
    _brief.md                # the talk brief — input for scaffold-deck
    _NOTES.md                # any other Markdown must be _-prefixed (Quarto's "don't render" convention)
    og-<slug>.webp           # OG card, ≤ 300 KB
    apps/                    # only if the deck uses iframe slides
      poll.html
    images/                  # optional; slide-body images
      <name>.webp
    assets/                  # optional; other non-render artifacts (referenced from the deck)
```

The slug (directory name) is capped at **50 characters** — same rule as the `log/` filename cap. Everything the deck needs must sit inside `decks/<slug>/`. Cross-deck reuse doesn't exist yet — copy, don't symlink.

## Pipeline — what happens on commit and merge

**On commit** (pre-commit hook, `scripts/pre-commit.sh`):

- Slug length ≤ 50 chars.
- Title present, ≤ 60 chars.
- Description present, ≤ 160 chars.
- Image field present, ends `.webp`.
- `tlp:` field present and one of `clear`, `white`, `green` (see TLP section above).
- `format.revealjs.theme` references `vigil-reveal-light.scss` or `vigil-reveal-dark.scss`.
- Any `.html` under `decks/` must live at `decks/<slug>/apps/<name>.html` exactly (not deeper, not at deck root).
- Any `.md` inside a `decks/<slug>/` folder (other than the deck's own `index.qmd`) must be **`_`-prefixed** — otherwise Quarto renders it and it leaks to `lopes.id/decks/<slug>/<name>.html`.
- Any image (`.webp`/`.jpg`/`.png`/`.gif`/`.svg`/`.ico`) is ≤ 70 chars filename and ≤ 300 KB.

Install the hook once with `./scripts/setup.sh`. Standalone check: `bash scripts/pre-commit.sh`.

**On merge to `main`** (GitHub Actions, `.github/workflows/deploy.yml`):

1. `quarto render --output-dir _site` — renders every `.qmd` (posts + decks). Full site output in `_site/`.
2. `cloudflare pages deploy _site` — uploads the tree as-is.

Two steps. No runtime TLP filter — because pre-commit already blocks anything not publishable from entering the repo, everything under `decks/` is publishable by construction. This depends on branch protection preventing direct pushes to `main` without PR CI (which runs pre-commit).

## The `scaffold-deck` skill

Skill lives at `~/.config/claude/skills/scaffold-deck/`. Description:

> Scaffold a complete Quarto revealjs presentation for lopes.id from a rough outline, a talk brief, or an existing blog post.

Invoke by mentioning: `scaffold a deck`, `turn this post into a talk`, `slides for X`, etc. The skill will:

- Ask for `duration` and `tlp` if missing (never guesses those).
- Compute a slide budget from `duration` (Q&A buffer = `max(5, round(0.15 * duration))`; weighted min/slide by kind).
- Refuse to overfill — if the outline needs more slides than fit, it cuts and states what.
- Emit the deck at `decks/<slug>/index.qmd` with the front matter, kickers, TLP badge, columns, code reveals, escape-hatch iframe patterns, and inline SVG diagrams where structural.
- Leave `INSERT_` markers for anything it can't confidently infer (hero images, dates, external references).

Post-to-talk mode: point it at an existing `log/<slug>/index.qmd` and it will convert (cutting prose, extracting code blocks as walkthrough slides, mapping H2s to slide titles).

## Illustrations — what the skill can and can't draw

- ✅ **Data-driven charts / tables / metrics** — `{python}` code cells run at render time and produce matplotlib/plotly/polars output on the slide. See [Data-driven slides](#data-driven-slides-with-python-cells) below for the pattern.
- ✅ **Structural diagrams** (flowcharts, block sketches, before/after schematics, icons) — the skill emits inline SVG directly.
- ✅ **Flowcharts / sequence / state diagrams** — the skill prefers ` ```{mermaid} ` blocks (native to Quarto, theme-styled).
- ❌ **Photo-real hero imagery, custom illustrations** — the skill leaves an `INSERT_ hero image` marker. Supply the `.webp` yourself (or add an image-gen MCP later — not wired in today).
- ❌ **QR codes** — deliberately not built. Add when a real talk needs one.

## Data-driven slides with `{python}` cells

Quarto revealjs supports Jupyter code cells natively — same syntax as the blog posts. Use them when the slide is naturally data-shaped: charts, tables, computed metrics, distributions, rankings. Anything you'd otherwise type by hand into a static slide, but where the numbers or picture should come from real data.

**Pattern:**

````markdown
## Login attempts by hour

```{python}
#| echo: false
#| fig-align: center
import matplotlib.pyplot as plt
hours = list(range(24))
counts = [12, 8, 4, 3, 2, 3, 5, 9, 15, 28, 41, 55,
          62, 60, 51, 43, 38, 32, 25, 21, 18, 16, 14, 13]
plt.bar(hours, counts, color="#4db8e0")   # theme accent
plt.xlabel("hour (UTC)")
plt.ylabel("attempts")
plt.show()
```

::: notes
Peak between 09:00–14:00 UTC — Asia-Pacific business hours.
:::
````

- `#| echo: false` hides the code, shows only the output.
- `#| echo: true` shows both — useful when the code IS the point (walkthroughs).
- `#| fig-align: center` / `#| fig-cap: "..."` are the usual Quarto figure knobs.

**Dependencies.** Whatever you `import` must be in `requirements.txt` so CI can install it. Baseline is just `jupyter`; add `matplotlib`, `pandas`, `polars`, `pyarrow`, etc. when a deck actually needs them. CI is the source of truth — if it renders in CI, it renders on Cloudflare.

**Freeze.** `decks/_metadata.yml` sets `freeze: auto`: cells re-execute only when the source of the cell changes. Cached output lands under `_freeze/decks/<slug>/`. Commit the cache directory so CI doesn't have to re-execute (and doesn't need every dep at deploy time). Two caveats worth internalizing:

- If a *data file* next to the deck changes but the `.qmd` doesn't, the cache won't invalidate. Force a re-render with `quarto render --cache-refresh decks/<slug>/index.qmd`.
- To always re-execute (for demos that need fresh randomness or live data), set `freeze: false` in that specific deck's front matter.

**Where data lives.** Deck-local — `decks/<slug>/data/*.parquet` (or `.csv`, `.json`) — is the simplest convention. Keep sample files small (the 300 KB image cap doesn't apply to data, but bloat still bloats the repo). For larger data, prefer a URL read at cell time and rely on `freeze` to cache the result.

## Common pitfalls

- **YAML front-matter with inline `# comments`.** The pre-commit's parser handles inline comments on unquoted values (`image: og.webp  # foo` → `og.webp`), but if the value is quoted and contains `#`, keep the `#` inside the quotes.
- **Forgetting `resources: - apps/`.** The deck renders fine but the iframe 404s at runtime because Quarto's resource-scanner doesn't recognize `background-iframe` paths. Symptom: blank slide in the browser.
- **Adding a top-level `theme:` field.** Quarto merges it into `format.revealjs.theme` and stacks a stray built-in theme (e.g. `dracula`, `dark`) on top of vigil. Symptom: unexpected colors, mismatched fonts. Fix: remove the top-level field; the SCSS path is the only source of truth.
- **Slides too wordy.** The scaffold-deck skill refuses to overfill — trust its cuts and use speaker notes for the prose you were going to put on the slide.
- **Committing rendered `index.html`.** Only source files belong in `decks/`. The pre-commit rejects arbitrary HTML at the deck root (only `apps/<name>.html` is allowed).
- **Dropping notes / provenance `.md` next to `index.qmd`.** Quarto renders any `.md` it finds and ships it to `lopes.id/decks/<slug>/<name>.html`. Prefix with `_` (`_brief.md`, `_NOTES.md`) so Quarto skips it. The pre-commit hook enforces this rule.

## What this system doesn't do (and won't, without explicit scope)

- No image generation (raster or vector, beyond hand-authored SVG / Mermaid).
- No QR codes.
- No PDF export path — decks are HTML mini-sites, not print artifacts.
- No talks index or listing page on `lopes.id` — decks are silent by design.
- No runtime light/dark toggle — theme is baked in at render time via the deck's `format.revealjs.theme` path.
- No cross-deck asset sharing — each deck is self-contained; copy assets rather than symlink.

Additions gated on real need: if a talk actually requires QR codes, wire up the shortcode then. If a hero image matters, add an image-gen MCP integration then. Iterate from real talks, not from feature lists.
