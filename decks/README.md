# Decks

Reveal.js presentations authored like blog posts: Quarto `.qmd`, vigil theme, rendered by CI, published silently at `lopes.id/decks/<slug>/`. No navbar entry, no talks index, no on-site discovery. A URL exists for anyone who has it.

## Runbook

Assumes `./scripts/setup.sh` was run once (installs the pre-commit hook) and branch protection is on `main`.

### 1. Branch

```bash
git checkout main && git pull
git checkout -b post/<slug>          # no deck/talk namespace yet; use post/
```

Slug is kebab-case, ≤ 50 characters. It's both the directory name and the URL segment.

### 2. Folder + brief

```bash
mkdir -p decks/<slug>/assets
$EDITOR decks/<slug>/_brief.md
```

The `_` prefix keeps Quarto from rendering the brief. A minimal brief:

```markdown
# Deck title

audience: internal security team
duration: 15
tlp: clear
event: internal AI share-out

---

Frame: one-sentence thesis of the talk.

Structure:
- Section 1 — motivation
- Section 2 — the change
- Section 3 — takeaways

Context: link to any post, notes folder, or asset the skill should read
(https://lopes.id/log/foo, @~/Documents/obsidian/notes, ./assets/chart.webp).
```

Fuller example: `decks/lantana-little-help-claude/_brief.md`.

### 3. Scaffold

In a Claude Code session:

> scaffold-deck from `decks/<slug>/_brief.md`

The skill asks for `duration`/`tlp` if missing, computes a slide budget, refuses to overfill, and writes `decks/<slug>/index.qmd`. It pushes back on `amber`/`red` (would fail commit anyway). Hand-authoring is fine — copy the [front-matter reference](#front-matter-reference).

### 4. OG image

Drop `decks/<slug>/og-<slug>.webp` (≤ 300 KB, ≤ 70-char filename). Pre-commit requires the `image:` field. A solid card is fine for silent publishing.

### 5. Preview

```bash
quarto preview decks/<slug>/index.qmd
```

Browser opens locally, live-reloads on save. Keys: `→`/`↓` next · `←`/`↑` back · `S` speaker view · `F` fullscreen · `Esc` overview · `B` blank screen.

### 6. Commit, push, merge

```bash
git add decks/<slug>/
git commit -m "decks: add <slug> talk on <topic>"
git push -u origin post/<slug>
gh pr create --title "decks: add <slug>"
```

Pre-commit fires locally; PR CI reruns pre-commit and a full `quarto render`. Merge to `main` → deploy workflow renders and ships. Live at `https://lopes.id/decks/<slug>/` in ~2 minutes.

## Front-matter reference

```yaml
---
title: "..."                 # ★ ≤ 60 chars
subtitle: "..."              # optional one-line hook
description: "..."           # ★ ≤ 160 chars, no trailing period
image: og-<slug>.webp        # ★ .webp only, ≤ 300 KB
tlp: green                   # ★ clear | white | green
duration: 15                 # minutes; drives the scaffold-deck budget
event: "..."                 # optional
date: 2026-05-01             # optional

# Only if the deck uses `background-iframe` escape-hatch slides:
resources:
  - assets/

format:
  revealjs:
    # Theme is picked by the SCSS path. NEVER add a top-level `theme:` —
    # Quarto merges it with reveal's `theme:` list and stacks a stray theme.
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

This repo is public. Sensitive presentations live in a separate private repo.

| `tlp:` value                     | Accepted? | Meaning |
|----------------------------------|:---------:|---------|
| `clear`                          | ✅ | TLP 2.0 unrestricted; freely shareable |
| `white`                          | ✅ | TLP 1.0 legacy alias for `clear` |
| `green`                          | ✅ | Community disclosure. `lopes.id` is treated as the author's community platform — project-specific reading, not standard TLP 2.0 |
| `amber` / `amber+strict` / `red` | ❌ | Rejected at commit |
| *(missing)*                      | ❌ | Rejected at commit |

The title-slide badge (`[TLP:CLEAR]{.tlp-badge}`) mirrors the front-matter value.

## Slide conventions

The vigil-reveal theme adds two hooks:

- **`[TEXT]{.kicker}`** — mono ALL-CAPS section label. One per slide.
- **`[TLP:CLEAR]{.tlp-badge}`** — framed mono chip. Once, on the title slide.

Standard Quarto revealjs worth remembering:

- **Progressive code reveal** — ` ```yaml{code-line-numbers="1|2-3|4"} `. Each `|` segment is an arrow step.
- **Columns** — `:::: columns` / `::: {.column width="50%"}`.
- **Fragments** — `::: {.fragment}`. `incremental: true` (in the template) advances bulleted lists one at a time.
- **Speaker notes** — `::: notes` blocks. Press `S`.
- **Inline SVG** — `stroke="currentColor"` so it works on both themes. One accent: `#057dbc` light, `#4db8e0` dark.
- **Mermaid** — ` ```{mermaid} ` blocks render natively; theme sets JetBrains Mono.
- **Iframe escape-hatch** — `## Title {background-iframe="assets/poll.html"}`. File must live at `decks/<slug>/assets/<name>.html`. Requires `resources: - assets/`.

**Don't:**

- No inline `<style>` or `<script>` — use `assets/*.html`.
- No top-level `theme:` field.
- No PDF export path.
- No `decks/index.qmd`, no navbar entry.

## File layout

```
decks/
  README.md                  # this file — auto-excluded by Quarto
  _metadata.yml              # shared defaults (freeze: auto, no citation)
  <slug>/
    index.qmd                # deck source — the ONLY thing Quarto renders here
    _brief.md                # talk brief — input for scaffold-deck
    og-<slug>.webp           # OG card (stays at deck root — metadata, not slide content)
    assets/                  # everything else: slide images, iframe HTML, data files
      hero.webp
      poll.html              # iframe escape-hatch (if used)
      metrics.parquet        # {python} cell data (if used)
```

Rules the layout enforces:

- Any `.md` other than `index.qmd` inside a deck folder must be `_`-prefixed — otherwise Quarto renders it to `lopes.id/decks/<slug>/<name>.html`.
- Any image must be `.webp`. Pre-commit accepts webp/jpg/png/gif/svg/ico as a safety net, but the authoring convention is webp only — convert on ingest (`cwebp <src> -o <name>.webp`, same filename base, delete original).
- Each deck is self-contained — copy assets, don't symlink.

## Pipeline

**On commit** (`scripts/pre-commit.sh`):

- Slug ≤ 50 chars. Title ≤ 60. Description ≤ 160.
- `image:` present, ends `.webp`. Image files ≤ 300 KB, filename ≤ 70 chars.
- `tlp:` present and one of `clear`/`white`/`green`.
- `format.revealjs.theme` references `vigil-reveal-{light,dark}.scss`.
- Any `.html` under `decks/` must live at `decks/<slug>/assets/<name>.html`.
- Non-`index.qmd` `.md` inside a deck folder must be `_`-prefixed.

Standalone check: `bash scripts/pre-commit.sh`.

**On merge to `main`** (`.github/workflows/deploy.yml`):

1. `quarto render --output-dir _site` — renders posts and decks.
2. `cloudflare pages deploy _site` — uploads the tree.

No runtime TLP filter — pre-commit is the gate. Depends on branch protection blocking direct pushes to `main`.

## Data-driven slides — `{python}` cells

Quarto executes Jupyter cells at render time. Use when the slide is naturally data-shaped (charts, tables, computed metrics).

````markdown
## Login attempts by hour

```{python}
#| echo: false
#| fig-align: center
import matplotlib.pyplot as plt
hours = list(range(24))
counts = [12, 8, 4, 3, 2, 3, 5, 9, 15, 28, 41, 55,
          62, 60, 51, 43, 38, 32, 25, 21, 18, 16, 14, 13]
plt.bar(hours, counts, color="#4db8e0")   # dark theme accent
plt.xlabel("hour (UTC)"); plt.ylabel("attempts")
plt.show()
```
````

- `#| echo: false` hides the code; `#| echo: true` shows it (when the code IS the point).
- Whatever you `import` must be in `requirements.txt`. Baseline is `jupyter`; add `matplotlib`, `polars`, `pyarrow`, etc. per deck.
- `freeze: auto` (in `_metadata.yml`) caches cell output under `_freeze/`; re-executes only when the `.qmd` changes. Commit the cache so CI doesn't need every dep at deploy time. For live-data demos, set `freeze: false` in that deck's front matter.
- Deck-local data: `decks/<slug>/assets/*.parquet` (or `.csv`, `.json`). Reference with a relative path from the cell.

## Common pitfalls

- **Forgetting `resources: - assets/`.** Deck renders fine, iframe 404s at runtime — Quarto doesn't scan `background-iframe` paths.
- **Adding a top-level `theme:` field.** Stacks a stray built-in theme on top of vigil. The SCSS path in `format.revealjs.theme` is the only source of truth.
- **Notes / provenance `.md` next to `index.qmd` without `_` prefix.** Quarto renders it and it leaks to the public site.
