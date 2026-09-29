# Design Vocabulary & Presentation Principles (`scaffold-deck`)

## First Principles — The Three Axes of Slide Design

Every slide is a composition on three axes. Reach for them in this order:

1. **Typography is paramount.** Type isn't chrome around the content — it *is* the content. A single Playfair Display sentence, a big Playfair number, a mono kicker, an italic Source Sans pull-quote — each carries meaning and rhythm the audience reads before they read the words. Reach for a `.big-idea`, `.big-number`, `.pull-quote`, or `.chat-snippet` before you reach for a bullet list. A well-typeset one-liner is louder than any five-bullet slide.
2. **Elements — boxes, images, text, transitions.** The theme ships a vocabulary of composition primitives (`.big-idea`, `.big-number`, `.metric-delta`, `.stat-grid`, `.pull-quote`, `.chat-snippet`, `.aside-box`, `.takeaways`, `.timeline`, `.section-divider`, `.hero-overlay`) plus layout primitives (columns, asymmetric split, centered element) plus reveal fragments and transitions. A slide is *composed* from these — the shape is a design decision, not a template pull.
3. **Blank space is content.** Whitespace around the load-bearing element tells the audience *this is what to look at*. Concrete target: vertical body content between ~40% and ~80% of usable slide height.

**Transitions are the fourth axis, but subordinate.** Set the deck-wide default in front matter and override per-slide only when the shift matters (section marker → `slide`; continuous argument → `fade`; tight code beats → `none`). Don't mix more than two transition types across the deck.

## Rule: Plain Bullet Lists Are Banned on Content Slides

Three exceptions only:
1. **Agenda** — numbered list *is* the point (N things, in this order).
2. **Thank you** — a short references list where the flat parallel structure is the content.
3. **Genuine flat parallel lists** on the rare content slide where you can *name in one sentence* why every other shape would misrepresent the content. Write the sentence in a `<!-- shape: bullets because ... -->` comment on the slide.

Anywhere else, if you are writing `## Title` + `[KICKER]{.kicker}` + `- bullet` + `- bullet`, stop and pick a shape from the vocabulary below.

## Atomic Elements

### Typography & Composition Primitives (Theme-Provided)

Defined in `static/styles/vigil-reveal-{dark,light}.scss` — never inline styles:

- `<div class="big-idea">One sentence.</div>` — huge Playfair Display, one sentence per slide. Use for the pivot line of the talk.
- `<div class="stat">70s<span class="stat-caption">saved per bail</span></div>` — giant number + small caption for corner/compound metrics.
- `<blockquote class="pullquote">…</blockquote>` — unattributed italic Lora blockquote with hairline accent border.
- `<div class="big-number"><span class="big-number-value">9×</span>…</div>` — dominant metric filling the slide.
- `<div class="metric-delta">…</div>` — before → after with a themed arrow.
- `<div class="stat-grid">…</div>` — 2–4 categorical mini-metrics side-by-side.
- `<div class="pull-quote">…<span class="pull-quote-attribution">…</span></div>` — attributed verbatim excerpt (mandatory attribution).
- `<div class="chat-snippet"><div class="chat-turn">…</div></div>` — styled monospace exchange (1–2 turns) replacing chat screenshots.
- `<div class="aside-box"><span class="aside-label">CAVEAT</span>…</div>` — on-brand replacement for Quarto callouts (which are banned in decks).
- `<div class="takeaways"><div class="takeaway">…</div></div>` — auto-fit grid of 2–4 bordered takeaway cards, each with `.takeaway-label`.
- `<div class="timeline">…</div>` — horizontal event strip with dots and dates (3–5 events).
- `<div class="contact-row">…</div>` — icon+label chips on the **Thank you** slide only, wrapped in a ```` ```{=html} ```` fence.

### Layout Primitives

- **Full-bleed image** with text overlay: `## Title {background-image="assets/foo.webp" background-size="cover"}` + `<div class="hero-overlay">`.
- **50/50 columns** — `:::: columns` / `::: {.column width="50%"}` for genuine contrast (each side visually distinct, not two matching bullet lists).
- **Asymmetric split (30/70 or 40/60)** — when one side is dominant (portrait + bio, diagram + labels).
- **Centered single element** — `## Title {.center}` on a slide whose body is one big element or kicker-only.
- **Grid of takeaway cards** — `::: {.takeaways}`. Do not hand-roll inline CSS grids.

## Shape Selection — Content-Shape Decision Table

| The content is … | Reach for | NOT |
|---|---|---|
| One number the whole slide is about | `.big-number` | `.stat`; bulleted list of number + context |
| Before/after change on one axis | `.metric-delta` | Two-column table; two `.stat`s side by side |
| 2–4 categorical metrics that land together | `.stat-grid` | Table; bullet list of "X: Y" pairs |
| A verbatim line — from a person, a tool, a chat log | `.pull-quote` (attributed) | Screenshot of the source; bulleted paraphrase |
| A chat/prompt exchange — one or two turns | `.chat-snippet` | Screenshot of the chat window |
| A single claim you want to land — the section's memory anchor | `.big-idea` | Slide title + supporting bullets |
| A sequence of dated events (3–5) | `.timeline` | Bulleted list with dates; table with a Date column |
| A caveat, warning, or side-note | `.aside-box` | `::: {.callout-note}` (banned); free-floating italic paragraph |
| 2–4 parallel takeaways / rules / caveats / steps | `.takeaways` (with `.takeaway` cards) | Inline `<div style="grid…">`; bullet list |
| A load-bearing screenshot whose text is illegible | Extract → `.pull-quote` / `.chat-snippet` | Full-slide screenshot with a kicker only |
| A load-bearing screenshot whose text is legible AND slide has summary text | Full-slide screenshot + one-line caption | Screenshot in a column beside bullets |
| Comparison of two things, each with distinct visual weight | 50/50 columns with different primitives per side | Two matching bullet lists |
| Structural / conceptual diagram | Inline SVG (theme-compliant) or Mermaid | Screenshot of a diagram from a doc |
| Data-shaped (counts, distributions, trends) | `{python}` cell | Hand-drawn SVG of a fake bar chart |
| An arc break in a long deck (`duration >= 30`) | `.section-divider` | A blank slide; a bulleted "next up" list |
| Genuinely N flat parallel items | Numbered list with `<!-- shape: bullets because … -->` justification | Bullets by default |

## Presentation Best Practices

- **First 5 seconds are the credibility budget.** `## whoami` shows all threads at once (`::: {.nonincremental}`), ≤ 3 bullets, each ≤ ~55 characters total including the bold label. No handles on `whoami` (they live on `## Thank you`).
- **`## Thank you` is the memory anchor.** Sits penultimate (before `## Q&A {.center}`) with `[REFERENCES]{.kicker}`, a `::: {.nonincremental}` reference list, and the `.contact-row` block.
- **`.center` centres the whole section, title and all.** Use `.center` only on kicker-only slides (`## Q&A {.center}`, `.section-divider`, or single-callout slides). Keep `.center` off `## whoami`, `## Agenda`, `## Thank you`, and standard content slides.
- **One reveal cadence per slide.** Either all at once (`::: {.nonincremental}`) or deliberate rhetorical beats (`::: {.fragment}`).
- **Breathing room & bullet limits.** Max ~4 bullets per column, each ≤ 2 wrapped lines (~60 chars/line). Single-column max 6 bullets / ~12 wrapped lines.
- **No naked images.** Every image needs a kicker, caption, or accompanying prose sentence.
- **No Quarto callout boxes (`::: {.callout-*}`).** Use `.aside-box`, `.takeaways`, or `.big-idea`.

## Data-Driven Cells (`{python}`)

When content is data-shaped ("count of", "top N", "distribution", "trend over time", "before/after numbers"), emit a `{python}` cell:
- `#| echo: false` for chart slides; `#| echo: true` for code walkthroughs.
- Match theme accent: `#4db8e0` on `vigil-reveal-dark.scss`, `#057dbc` on `vigil-reveal-light.scss`.
- Any imported library must be listed in `requirements.txt` (flag new dependencies in Scaffolding Notes).
- Data files live in `decks/<slug>/assets/`. `decks/_metadata.yml` sets `freeze: auto`.

## Illustrations — Inline SVG & Mermaid

- Prefer ```` ```{mermaid} ```` for standard flowcharts, sequence diagrams, and state diagrams.
- Use inline `<svg>` for custom structural or conceptual sketches:
  - Default strokes and text to `currentColor` so the SVG adapts to both light and dark themes.
  - Use at most one accent color (`#057dbc` light / `#4db8e0` dark).
  - Use only theme fonts (`Source Sans 3`, `JetBrains Mono`, `Playfair Display`), square corners, no gradients or shadows, and keep inline SVG under ~80 lines (`viewBox` + `style="width: 80%; height: auto; color: inherit;"`).

## Escape-Hatch Iframes

When a slide requires interactive HTML/JS (live poll, embedded tool, custom canvas):
- Never inline `<script>` or `<style>` into `index.qmd`.
- Place self-contained HTML at `decks/<slug>/assets/<name>.html`, reference via `## Title {background-iframe="assets/<name>.html"}`, and add `resources: [assets/]` to YAML front matter.
