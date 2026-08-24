# docs

Operational documentation for lopes.id. Nothing here is rendered into the site —
`_quarto.yml` excludes this directory from the project glob.

| Path | What it is |
| ---- | ---------- |
| `runbooks/monthly-check.md` | The recurring health check: what `make monthly` does and how to read it |
| `runbooks/traffic-spike.md` | What to do when request volume jumps, generalised from the August 2026 incident |
| `runbooks/restore-cloudflare.md` | Rebuilding the zone, and the settings Terraform cannot own |

## Where configuration actually lives

Cloudflare zone state is **code**, in `terraform/`. It is not documented here and
must not be — a prose mirror of a dashboard goes stale, which is exactly how the
previous version of this directory failed. Runbooks describe *procedure*;
`terraform/` describes *state*.

Cloudflare *queries* (analytics, snapshots) stay in `scripts/`. Terraform is a
desired-state engine and has no analytics data source, so the two do not overlap.
