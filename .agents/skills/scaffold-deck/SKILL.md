---
name: scaffold-deck
description: >-
  Scaffold a complete Quarto revealjs presentation for lopes.id from a rough
  outline, a talk brief, or an existing blog post. Use this skill whenever the
  user mentions a talk, deck, slides, presentation, keynote, conference, or
  says "turn this post into a talk," "scaffold a deck," "make slides for X,"
  "reveal.js deck," "presentation from this post," or shares an outline and
  asks for a deck. Produces `decks/<slug>/index.qmd` with duration-aware slide
  budgeting, front matter (tlp/duration/theme), vigil-reveal theme, storyboard,
  and slide composition primitives.
---

# Deck Scaffolder

You are a technical-talk producer for `lopes.id`. Turn a rough outline, talk brief, or existing blog post into a valid, on-brand Quarto `revealjs` deck (`decks/<slug>/index.qmd`) that renders inside the site's CI pipeline, respects the speaker's time slot, applies the WIRED/vigil editorial conventions, and stays silent-publishable (no navbar entry, no talks index, no leaks past the TLP gate).

## Reference Manuals (Progressive Disclosure)

Read these reference files before composing slides:
- [design-vocabulary.md](file:///usr/local/google/home/joelopes/Projects/lopes.id/.agents/skills/scaffold-deck/references/design-vocabulary.md) — Three axes of slide design, banned bullet-list rule, atomic composition primitives, content-shape decision table, presentation best practices, `{python}` cells, inline SVG rules, and iframe escape hatches.
- [reveal-conventions.md](file:///usr/local/google/home/joelopes/Projects/lopes.id/.agents/skills/scaffold-deck/references/reveal-conventions.md) — Copy-paste Quarto/Reveal.js syntax for every primitive (`.big-idea`, `.big-number`, `.metric-delta`, `.stat-grid`, `.pull-quote`, `.chat-snippet`, `.aside-box`, `.takeaways`, `.timeline`, `.contact-row`, `.section-divider`), code line highlights, columns, fragments, and pacing table.
- [audit-and-output.md](file:///usr/local/google/home/joelopes/Projects/lopes.id/.agents/skills/scaffold-deck/references/audit-and-output.md) — Source-level post-scaffold audit checks, auto-fix rules, `.qmd` skeleton, and the 4-tier Scaffolding Notes report format.

## Inputs

The user provides at minimum one of:
- **An outline** — bullets or messy notes for a talk.
- **A brief** — audience, duration, event, one-sentence thesis (e.g., `decks/<slug>/_brief.md`).
- **A blog post** — a `.qmd` under `log/<slug>/` to convert into a talk (post→talk mode).

Required parameters (ask if missing; never guess `duration` or `tlp`):
- **`duration`** — talk length in minutes.
- **`tlp`** — TLP classification (`clear`, `white`, or `green`). Pre-commit rejects `amber`, `amber+strict`, and `red` because this repo is public. If the user proposes `amber`/`red`, stop and redirect to a private repo.
- **`theme`** — `dark` or `light` (default: `dark`). Selects `vigil-reveal-{dark,light}.scss` in `format.revealjs.theme`. **Never emit a top-level `theme:` field** in YAML.
- **`event`** and **`date`** — optional metadata.

## Workflow Sequence

1. **Confirm required inputs** (`duration`, `tlp`). Ask if missing.
2. **Inventory & read referenced resources** up front (local files, images, `log/<slug>/index.qmd`, external URLs). See "Inventory & Screenshot Policy" below.
3. **Compute the slide budget** from `duration`:
   - **Q&A buffer**: `max(5, round(0.15 * duration))` minutes.
   - **Content time**: `duration - buffer`.
   - **Weights**: Statement/section/title/closing = ~1 min; Prose/diagram = ~1.5 min; Code walkthrough = ~2.5–3 min.
   - **5 reserved slides** (always scaffolded, never cut): Title (auto-generated from front matter), `## whoami`, `## Agenda`, `## Thank you`, `## Q&A {.center}`.
   - **Refuse to overfill.** Cut and document what was cut in Scaffolding Notes.
4. **Storyboard pass.** Compose the `<!-- STORYBOARD ... -->` HTML comment block (thesis, arc, one beat line per content slide, wow-moment budget capped at `ceil(duration / 10)`, and `screenshots_in_brief` extract/embed ledger). Place it **inside `## whoami`**, right after the heading and before the kicker (placing it before `## whoami` causes Quarto to emit a phantom blank slide).
5. **Shape pass.** Using [design-vocabulary.md](file:///usr/local/google/home/joelopes/Projects/lopes.id/.agents/skills/scaffold-deck/references/design-vocabulary.md), assign a visual shape to every content slide (`big-idea`, `big-number`, `metric-delta`, `stat-grid`, `pull-quote`, `chat-snippet`, `timeline`, `aside-box`, `takeaways`, `diagram`, `contrast columns`, `story build`, `section-divider`, `screenshot-embed`). Plain bullet lists are banned on content slides unless justified with `<!-- shape: bullets because ... -->`.
6. **Compose & write `decks/<slug>/index.qmd`** directly to disk (never print the full deck in chat). Draft plausible content for missing details and mark `[VERIFY]` inline; bare `INSERT_` is a last resort.
7. **Validate & audit.** Quarto is not installed locally (it runs in GitHub Actions CI). Run `make check` (`bash scripts/pre-commit.sh`) from the repo root, then run every source-level check and allowed auto-fix in [audit-and-output.md](file:///usr/local/google/home/joelopes/Projects/lopes.id/.agents/skills/scaffold-deck/references/audit-and-output.md).
8. **Report.** Print the two-line confirmation and the four-tier **Scaffolding Notes** (`Ready ✓`, `Needs attention ⚠`, `Decisions ℹ`, `Post-scaffold audit`) defined in [audit-and-output.md](file:///usr/local/google/home/joelopes/Projects/lopes.id/.agents/skills/scaffold-deck/references/audit-and-output.md).

## Core Inference Rules

### Slug & Front Matter
- **Slug**: kebab-case, ≤ 50 chars (`MAX_DECK_SLUG_LEN` in `scripts/pre-commit.sh`).
- **Front matter**:
  ```yaml
  ---
  title: "..."              # ★ ≤ 60 chars
  description: "..."        # ★ ≤ 160 chars, no trailing period; doubles as title-slide sub-line + OG description
  image: og-<slug>.webp     # ★ .webp only, ≤ 300 KB
  tlp: clear                # ★ clear | white | green
  duration: 15              # minutes
  event: "..."              # optional
  date: YYYY-MM-DD          # optional
  resources:
    - assets/               # required if using background-iframe slides
  format:
    revealjs:
      theme: [default, ../../static/styles/vigil-reveal-dark.scss]
      footer: "TLP:CLEAR"   # ★ mirror front-matter tlp: in uppercase
      incremental: true
      code-line-numbers: true
      slide-number: c/t
      toc: false
      controls: true
      progress: true
      history: true
      hash-type: number
  ---
  ```
- **Title slide is auto-generated** by Quarto from `title:`, `description:`, and `date:` via `decks/_partials/title-slide.html`. Do **not** emit a `## <Title> {.center}` slide in the body or a `subtitle:` field.

### Storyboard Schema (inside `## whoami`)
```markdown
## whoami

<!-- STORYBOARD
thesis: <one sentence — the single claim the audience should leave with>

arc:
  hook:     <slide N — the promise; why care in 30s>
  setup:    <slide N — status-quo / problem shape>
  turn:     <slide N — the pivot>
  evidence: <slide N-M — concrete proof>
  land:     <slide N — the memory anchor>

beats:
  - slide N: <shape> · <one-line role in arc>

wow_moments:
  - <cap: ceil(duration / 10)>

screenshots_in_brief:
  - <path>: extract → <target primitive>  OR  embed → <legibility + support justification>
-->
```

### The Five Fixed Frames
1. **Title** — auto-generated from YAML front matter.
2. **`## whoami`** (lowercase, no `.center`) — 30/70 columns (`![](/static/images/photo-*.webp){.portrait}` on left; role kicker + `::: {.nonincremental}` list of **≤ 3 bullets, each ≤ 55 chars** filtered from `about.qmd` on right). No social handles here (those belong on `## Thank you`).
3. **`## Agenda`** (no `.center`) — numbered list (3–5 items) derived from the content arc.
4. **`## Thank you`** (penultimate slide, no `.center`) — `[REFERENCES]{.kicker}` + `::: {.nonincremental}` bulleted references (2–3 items) + `{=html}` `.contact-row` block at the bottom.
5. **`## Q&A {.center}`** (final slide) — `[QUESTIONS]{.kicker}` only.

### Post → Talk Mode
When converting `log/<slug>/index.qmd`:
1. Skim the thesis; drop blog prose scaffolding and hedges.
2. Turn structural H2s into slides with mono kickers (merge/drop to fit the slide budget; never shrink font).
3. Extract code blocks into progressive-reveal walkthrough slides (`code-line-numbers`).
4. Reuse the post's OG image or flag `og-<slug>.webp` in `Needs attention ⚠`.

### Inventory & Screenshot Policy
- **Read everything the brief points at** before composing (`log/<slug>/index.qmd`, local notes, images, external URLs).
- **Extract by default for text-carrying screenshots** (chat logs, terminals, code, error dialogs): convert into `.chat-snippet`, `.pull-quote`, `.big-number`, or `.metric-delta`, and move the raw image to `::: notes`.
- **Embed full-slide only for shape-carrying images** (diagrams, sketches, charts, photos) OR when text is legible at 50% zoom AND accompanied by on-slide summary text (never ship `kicker + screenshot + nothing else`).
- **WebP everywhere**: all persisted deck images must be `.webp` (≤ 300 KB, filename ≤ 70 chars). Propose `cwebp` conversion commands for any `.png`/`.jpg`/`.gif` assets and flag them in `Needs attention ⚠`.

## Related Repo Rules
- Branch namespace: use `deck/<slug>` or `post/<slug>` per `AGENTS.md`.
- Non-`index.qmd` Markdown inside `decks/<slug>/` must be `_`-prefixed (e.g., `_brief.md`).
- Escape-hatch HTML must live at `decks/<slug>/assets/<name>.html`.
