# Post-Scaffold Audit & Output Format (`scaffold-deck`)

## Validation & Source-Level Audit

Quarto is not installed locally (it runs in GitHub Actions CI, which renders and deploys PR previews to `preview.lopes.id`). After writing `decks/<slug>/index.qmd` to disk:

1. **Run repository validation**:
   Execute `make check` (`bash scripts/pre-commit.sh`) from the repo root to verify front matter, slug/title/description lengths, TLP classification, theme path, `_`-prefixed markdown files, and image sizes.
2. **Run source-level `.qmd` checks** (below) on `decks/<slug>/index.qmd`.

### Audit Checks (Run on Every Scaffold)

1. **Kicker-only slide missing `.center` — flag only, no auto-fix.**
   - Inspect each `##` slide in `index.qmd`. If a slide has *only* a heading + kicker (no bullets, no paragraphs, no image, no code, no SVG, no composition primitive) and lacks `{.center}` on the heading, flag it: recommend adding `{.center}`.
   - Do **not** flag slides that have a title + body (`## whoami`, `## Agenda`, `## Thank you`, or content slides).

2. **Suffocation risk — flag only, no auto-fix.**
   - Count bullets and estimate wrapped lines per bullet (> 60 chars ≈ 2 lines; > 120 ≈ 3 lines).
   - For `:::: columns` layouts: flag when any column has > 4 bullets or > ~10 wrapped lines.
   - For single-column slides: flag when total bullets > 6 or total wrapped lines > 12.

3. **Naked image — flag only, no auto-fix.**
   - For each `![](path)` reference, check whether the slide has a kicker, paragraph, or caption within the same `##` section. Flag if the image is the sole body content.

4. **Quarto callout in a deck — flag only, no auto-fix.**
   - Check for `::: {.callout-` in `index.qmd`. Flag any occurrence to be replaced with `.aside-box`, `.takeaways`, or `.big-idea`.

5. **Bullet-list-only content slide (design failure) — HARD FLAG, no auto-fix.**
   - For each content slide (excluding auto-generated title, `whoami`, `Agenda`, `Thank you`, `Q&A`), check if its body reduces to a plain bulleted/numbered list without any composition primitive, diagram, code fence, image, or `<!-- shape: bullets because ... -->` justification comment.
   - Report the ratio explicitly: `bullet-only content slides: <b>/<n> (<pct>%)`.

6. **Screenshot-only content slide (design failure) — HARD FLAG, no auto-fix.**
   - Check if any content slide reduces to just `## Title` + `[KICKER]{.kicker}` + `![](path)` without on-slide summary text or composition primitives.
   - Report the ratio explicitly: `screenshot-only content slides: <s>/<n> (<pct>%)`.

7. **Storyboard block present — flag only, no auto-fix.**
   - Verify `<!-- STORYBOARD ... -->` is placed **inside `## whoami`** (after `## whoami` and before the next `##`).
   - Cross-check beat lines (`- slide N: <shape> · <role>`) against the actual content slide count, and verify all images are accounted for in `screenshots_in_brief`.

8. **Text-carrying image inside a column (legibility risk) — auto-fix when safe.**
   - For any `![](path)` inside a `:::: columns` block whose filename matches `/screenshot|terminal|chat|log|error|code|snippet|shell/i` (or visually carries small text):
   - **Auto-fix (when safe)**: remove `:::: columns`, promote the image to full-slide, and move neighbor-column bullets into `::: notes`. If structure is too complex to rewrite safely, flag under `Needs attention ⚠`.

9. **`whoami` reveal & heading — auto-fix.**
   - Ensure the heading is lowercase `## whoami` and the 70%-column bullet list is wrapped in `::: {.nonincremental}` … `:::`. Auto-fix if missing.

10. **`whoami` budget — flag only, no auto-fix.**
    - Flag if > 3 bullets, if any bullet exceeds ~55 plain-text characters (including bold label), or if social handles (`github.com/`, `linkedin.com/`, `@`) appear on `whoami`.

11. **Fixed-frame sanity — flag only.**
    - Last heading must be `## Q&A {.center}`; penultimate heading must be `## Thank you` with non-empty references and `.contact-row`.

---

## Deck `.qmd` Template

Write the composed deck directly to `decks/<slug>/index.qmd` (do not print the deck contents in chat):

````markdown
---
title: "..."
description: "..."       # doubles as title-slide sub-line + OG card description
image: og-<slug>.webp
tlp: clear
duration: 30
event: "..."
date: 2026-05-01

resources:
  - assets/   # include when using background-iframe escape-hatch slides

format:
  revealjs:
    theme: [default, ../../static/styles/vigil-reveal-dark.scss]
    footer: "TLP:CLEAR"          # ★ mirror front-matter tlp:; visible on every slide
    incremental: true
    code-line-numbers: true
    slide-number: c/t
    toc: false
    controls: true
    progress: true
    history: true
    hash-type: number
---

## whoami

<!-- STORYBOARD
thesis: ...
arc:
  hook: ...
  setup: ...
  turn: ...
  evidence: ...
  land: ...
beats:
  - slide 1: ...
wow_moments:
  - ...
screenshots_in_brief:
  - ...
-->

[<ONE-LINE ROLE / DOMAIN>]{.kicker}

:::: columns
::: {.column width="30%"}
![](/static/images/photo-<name>.webp){.portrait}
:::
::: {.column width="70%"}
::: {.nonincremental}
- **<Thread 1>** — <≤ ~35-char tail>
- **<Thread 2>** — <≤ ~35-char tail>
- **<Thread 3>** — <≤ ~35-char tail>
:::
:::
::::

::: notes
Extra threads that didn't fit on the slide: <thread 4>, <thread 5>. Riff if Q&A drifts.
:::

## Agenda

[<KICKER>]{.kicker}

1. **<Section 1>** — <one-line hook>
2. **<Section 2>** — <one-line hook>
3. **<Section 3>** — <one-line hook>

::: notes
30-second walk-through of the arc so the audience knows what they're getting.
:::

## <First content slide title>

[<SECTION KICKER>]{.kicker}

<body using composition primitives>

## Thank you

[REFERENCES]{.kicker}

::: {.nonincremental}
- **<Reference 1 title>** — <one-line hook> · [link](<url>)
- **<Reference 2 title>** — <one-line hook> · [link](<url>)
:::

```{=html}
<div class="contact-row">
  <a href="https://lopes.id" class="contact-link">
    <svg class="contact-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="12" cy="12" r="10"/>
      <path d="M2 12h20"/><path d="M12 2a15 15 0 0 1 0 20"/><path d="M12 2a15 15 0 0 0 0 20"/>
    </svg>
    <span class="contact-label">lopes.id</span>
  </a>
  <a href="https://linkedin.com/in/jlopesjr" class="contact-link">
    <svg class="contact-icon" viewBox="0 0 24 24" fill="currentColor">
      <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0z"/>
    </svg>
    <span class="contact-label">jlopesjr</span>
  </a>
  <a href="https://github.com/lopes" class="contact-link">
    <svg class="contact-icon" viewBox="0 0 24 24" fill="currentColor">
      <path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12"/>
    </svg>
    <span class="contact-label">lopes</span>
  </a>
</div>
```

## Q&A {.center}

[QUESTIONS]{.kicker}
````

---

## Chat Output Format (Scaffolding Notes)

Emit a two-line confirmation followed by the four-tier Scaffolding Notes:

```text
Wrote decks/<slug>/index.qmd (<n> slides, <duration>min slot).
Budget: <slot>min − <buffer>min Q&A = <content>min · <n> slides (<w>).
```

**Scaffolding Notes**

**Ready ✓**
- Slug: `<slug>` (<n> chars, cap 50)
- Budget: `<slot>min − <buffer>min Q&A = <content>min → <n> slides` — <one-line rationale>
- Read from brief-referenced resources: `<list what you read + one-line summary>` (or omit if none referenced)
- Pre-commit validation (`make check`): `<PASS / details>`

**Needs attention ⚠**
- `[VERIFY]` `<label>` at slide N — `<what to sanity-check>`, `<source if known>`
- `INSERT_` `<label>` at slide N — `<what to swap in>`, `<expected source>`
- `<asset the user must supply>` — e.g., `og-<slug>.webp`, data file
- Convert `assets/<file>.<png|jpg|jpeg|gif>` → `assets/<file>.webp` and delete original (one line per file)
- `<unreadable resource, if any>` — flag the path and why

**Decisions ℹ**
- Content cut / not included: `<what and why>` (or "everything fit")
- Escape-hatch apps to write: `<list of assets/<name>.html shells, or "none">`
- `whoami` filtering: kept threads `<list>`, dropped `<list>` (moved to speaker notes)

**Post-scaffold audit**
- Auto-fixed: `<list of fixes applied, one per line>` (or "no auto-fixes needed")
- Kicker-only slides missing `.center`: `slide <N>: <first-few-words>` (or "none")
- Suffocation risk (breathing budget blown): `slide <N>: <column or "single"> — <b> bullets, ~<L> wrapped lines` (or "none")
- **Bullet-only content slides (design failure): `<b>/<n> (<pct>%)` — `slide <N>: "<title>"`** (list all, or "none")
- **Screenshot-only content slides (design failure): `<s>/<n> (<pct>%)` — `slide <N>: "<title>", <image path>`** (list all, or "none")
- Storyboard block: present + `<b>` beats matching `<n>` slides (or "MISSING — regenerate", or "mismatch: `<details>`")
- Naked images (no kicker or caption): `slide <N>: <image path>` (or "none")
- Quarto callouts in deck: `slide <N>` (or "none")
- Legibility risk (text-in-image in column): `slide <N>: <image path>` (or "none")
- `whoami` budget: `<b> bullets (cap 3), longest <L> chars (cap ~55), handles found: <yes/no>`
- Fixed-frame sanity: OK (or `<what's missing>`)
