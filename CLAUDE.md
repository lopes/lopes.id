# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Quarto-based static site for a professional knowledge base published at [lopes.id](https://lopes.id). Content covers information security, detection engineering, and automation.

## Build Commands

| Command | Purpose |
| ------- | ------- |
| `quarto render --output-dir _site` | Build the full static site |
| `quarto preview` | Local dev server with live reload |
| `./scripts/setup.sh` | Install git pre-commit hooks |

There are no tests or linters beyond the pre-commit hook validation.

## Architecture

- **Static site generator**: Quarto with Python 3.14 (Jupyter kernel)
- **Content**: Quarto Markdown (`.qmd`) files in `log/<post-slug>/index.qmd`
- **Styling**: Custom "Vigil" theme in `static/styles/` (SCSS), dual dark/light mode
- **CI/CD**: GitHub Actions (`deploy.yml` for Cloudflare Pages, `integration.yml` for PR validation)
- **Validation**: `scripts/pre-commit.sh` enforces content rules at commit time

## Content Structure

Each post lives in its own directory under `log/`:

```text
log/post-slug/
  index.qmd      # Post content with YAML frontmatter
  og-*.webp      # Open Graph image
```

Required frontmatter fields: `title`, `description`, `image`. Image must be `.webp`.

## Validation Rules (pre-commit hook)

- Post filename: max 50 chars
- Deck slug (directory name under `decks/`): max 50 chars
- Title: max 60 chars (posts and decks)
- Description: max 160 chars (posts and decks)
- Deck `tlp:` field required; only `clear`, `white`, `green` accepted (see Deck Publication Policy)
- Deck `format.revealjs.theme` must reference `vigil-reveal-{light,dark}.scss`
- Escape-hatch HTML for decks lives at `decks/<slug>/assets/<name>.html` (nowhere else under `decks/`)
- Non-`index.qmd` Markdown inside `decks/<slug>/` must be `_`-prefixed (Quarto's "don't render" convention) — otherwise it leaks to the site
- Images: pre-commit accepts webp/jpg/png/gif/svg/ico (≤ 300 KB, filename ≤ 70 chars); authoring convention is `.webp` — convert non-webp raster on ingest

## Deck Publication Policy

This repo is public. **Sensitive presentations do NOT live here** — they belong in a separate private repo. The pre-commit hook accepts only publishable TLP values in decks:

- Allowed: `tlp: clear` | `white` | `green`
- Rejected at commit time: `tlp: amber` | `amber+strict` | `red`

TLP is provenance metadata + a commit-time assertion. There is no runtime filter — because non-publishable values can't enter the repo, everything under `decks/` is publishable by construction. This assumes branch protection prevents direct pushes to `main` without PR CI (which runs pre-commit).

Full deck authoring guide: `decks/README.md`.

## Branch Naming

`<namespace>/<short-description>` where namespace is one of: `post`, `deck`, `revise`, `typo`, `bugfix`, `design`, `infra`, `docs`, `release`.

## Key Config Files

- `_quarto.yml` — Site-wide Quarto configuration (navigation, themes, listing)
- `log/_metadata.yml` — Default metadata for all posts (author, license, freeze)
- `decks/_metadata.yml` — Default metadata for decks (`freeze: auto`, no citation)
- `decks/README.md` — Deck authoring guide (auto-excluded from render)
- `scripts/pre-commit.sh` — Single source of truth for validation logic
- `static/styles/vigil-{dark,light}.scss` — Post theme (dual mode, respects visitor scheme)
- `static/styles/vigil-reveal-{dark,light}.scss` — Deck theme (per-deck baked at render time)
