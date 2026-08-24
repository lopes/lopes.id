# docs

Operational documentation for lopes.id. Nothing here is rendered into the site —
`_quarto.yml` excludes this directory from the project glob.

| Path | What it is |
| ---- | ---------- |
| `runbooks/monthly-check.md` | `make monthly`: what it checks and how to read it |
| `runbooks/traffic-spike.md` | What to do when request volume jumps |
| `runbooks/restore-cloudflare.md` | Rebuilding the zone, and what Terraform cannot own |

## Where configuration actually lives

Cloudflare zone state is **code**, in `terraform/`. It is deliberately not
documented here, and should not be: the previous version of this directory was a
prose mirror of the dashboard, and it was wrong about the WAF rule within two days
of being written. A document describing state drifts; a `terraform plan` cannot.

Runbooks describe **procedure**. `terraform/` describes **state**. Where a runbook
does mention a setting, it is one Terraform provably cannot own — listed under
"Not codifiable" in `restore-cloudflare.md`.

Cloudflare *queries* stay in `scripts/`. Terraform is a desired-state engine with
no analytics data source, so the two do not overlap: every script here talks to
`client/v4/graphql`, and Terraform talks only to the REST configuration API.
