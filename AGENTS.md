# AGENTS.md

This file provides guidance to AI coding agents (Gemini, Jetski, Claude, etc.) when working with code in this repository.

## Project Overview

Quarto-based static site for a professional knowledge base published at [lopes.id](https://lopes.id). Content covers information security, detection engineering, and automation.

## Build & Validation Commands

`make help` lists every target and is the intended entry point. The underlying scripts stay runnable by path.

> **Important:** Quarto is **not installed locally** — site rendering happens exclusively in GitHub Actions CI/CD (`integration.yml` for PR previews and `deploy.yml` for production). Use `make check` (`bash scripts/pre-commit.sh`) for local validation.

| Command | Purpose |
| ------- | ------- |
| `make check` | Content validation (same as the pre-commit hook) |
| `make setup` | Install git pre-commit hooks |
| `make render` / `make preview` | Build the site or serve with live reload *(CI only; Quarto is not installed locally)* |
| `make snapshot LABEL=x` | Capture Cloudflare analytics into `snapshots/` |
| `make history` | Fold snapshots into the committed CSVs in `data/` |
| `make monthly` | Full health check: capture, drift, live probes, traffic |
| `make tf-plan` / `make tf-apply` / `make drift` | Cloudflare zone & Access configuration |

There are no tests or linters beyond the pre-commit hook validation and `terraform fmt`/`validate`.

## Infrastructure

The Cloudflare zone and Zero Trust Access configuration are code, in `terraform/`, with state in HCP Terraform (org `lopes-log`, workspace `lopes-id`, execution mode Local).

**Cloudflare state changes go through `terraform/` — never the dashboard, never a bespoke script.** A dashboard edit leaves no diff, no PR, and no author, and the prose document that used to mirror those settings was wrong within two days. Cloudflare *queries* (analytics, snapshots) stay in `scripts/`: Terraform has no analytics data source, so there is no overlap to resolve.

Two tokens, split by blast radius: `CF_RO_TOKEN` for reads (snapshots, plan, CI drift) and `CF_RW_TOKEN` for local applies only. The write token must never be added to GitHub — CI plans, it never applies. The Makefile injects the right one per target. See `.env.example` and `terraform/README.md`.

Reading a diff depends on which file it is in:
- `dns.tf` is a transcript of the zone, so a diff means the file is wrong.
- `zone-settings.tf`, `security.tf`, and `access.tf` are asserted intent, so a diff means the zone or Access policy drifted and should be applied back.

Operational procedure lives in `docs/runbook-*.md`.

## Architecture

- **Static site generator**: Quarto, executed in GitHub Actions
- **Content**: Quarto Markdown (`.qmd`) files in `log/<post-slug>/index.qmd` and `decks/<deck-slug>/index.qmd`
- **Styling & Design System**: Custom WIRED-inspired "Vigil" theme in `static/styles/` (SCSS), dual dark/light mode; full design specification in `docs/design-system.md`
- **CI/CD**: GitHub Actions (`deploy.yml` for production Cloudflare Pages, `integration.yml` for PR validation + preview deploy to `preview.lopes.id`, `infra.yml` for Terraform plan and monthly drift)
- **Preview & Side-Domain Protection**: Cloudflare Zero Trust Access (`terraform/access.tf`) gates `preview.lopes.id`, `*.lopes-id.pages.dev`, and `lopes-id.pages.dev` behind Email OTP
- **Validation**: `scripts/pre-commit.sh` enforces content rules at commit time and in CI
- **Workspace Skills**: `.agents/skills/scaffold-deck/` scaffolds Reveal.js presentations from outlines, briefs, or existing blog posts

## Content Structure

Each post lives in its own directory under `log/`:

```text
log/post-slug/
  index.qmd      # Post content with YAML frontmatter
  og-*.webp      # Open Graph image
```

Required frontmatter fields: `title`, `description`, `image`. Image must be `.webp`.

## Validation Rules (pre-commit hook)

- Post slug (directory name under `log/`): max 50 chars
- Deck slug (directory name under `decks/`): max 50 chars
- Title: max 60 chars (posts and decks)
- Description: max 160 chars (posts and decks)
- Deck `tlp:` field required; only `clear`, `white`, `green` accepted (see Deck Publication Policy)
- Deck `format.revealjs.theme` must reference `vigil-reveal-{light,dark}.scss`
- Escape-hatch HTML for decks lives at `decks/<slug>/assets/<name>.html` (nowhere else under `decks/`)
- Non-`index.qmd` Markdown inside `log/<slug>/` or `decks/<slug>/` must be `_`-prefixed (Quarto's "don't render" convention) — otherwise it renders and leaks to the public site (and for `log/`, into the homepage listing and RSS feed)
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

- `_quarto.yml` — Site-wide Quarto configuration (navigation, themes, listing). Its `render:` list excludes `!docs/**`, `!terraform/**`, `!AGENTS.md`, and `!CHANGELOG.md`; directory exclusions must be written `"!docs/**"` (the `"!docs/"` form is accepted silently and does nothing, publishing every runbook to the live site)
- `log/_metadata.yml` — Default metadata for all posts (author, license, freeze)
- `decks/_metadata.yml` — Default metadata for decks (`freeze: auto`, no citation)
- `decks/README.md` — Deck authoring guide (auto-excluded from render)
- `.agents/skills/scaffold-deck/SKILL.md` — Agent skill for scaffolding Reveal.js decks
- `docs/design-system.md` — WIRED-inspired editorial design system specification
- `scripts/pre-commit.sh` — Single source of truth for validation logic
- `Makefile` — Task index; `make help` lists everything
- `terraform/` — Cloudflare zone and Access configuration; `terraform/README.md` explains the layout
- `docs/runbook-*.md` — Operational procedure (monthly check, traffic spike, zone restore)
- `data/*.csv` — Derived traffic history; the breakdowns file is not recoverable if lost
- `static/styles/vigil-{dark,light}.scss` — Post theme (dual mode, respects visitor scheme)
- `static/styles/vigil-reveal-{dark,light}.scss` — Deck theme (per-deck baked at render time)
