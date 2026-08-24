# terraform — Cloudflare zone configuration for lopes.id

The zone's configuration is code and lives here. It is not mirrored in prose
anywhere: the previous hand-written version of that mirror was wrong within two
days of being written, which is what prompted this.

## Layout

| File | Owns |
| ---- | ---- |
| `versions.tf` | Provider and HCP state backend |
| `variables.tf` | Zone and account identifiers |
| `zone-settings.tf` | TLS, HTTPS, Early Hints — asserted intent |
| `security.tf` | Bot settings and the deliberately empty WAF ruleset |
| `dns.tf` | DNS records — a transcript of what is live |

## Credentials

State lives in HCP Terraform (org `lopes-log`, workspace `lopes-id`, execution
mode **Local** — HCP stores and locks state, runs happen here). Authenticate once
with `terraform login`.

Cloudflare auth comes from `CLOUDFLARE_API_TOKEN` in the environment, never from
a variable or tfvars file. The Makefile sets it per target:

| Target | Token | Why |
| ------ | ----- | --- |
| `make tf-plan`, `make drift` | `CF_RO_TOKEN` | A plan cannot write even by mistake |
| `make tf-apply` | `CF_RW_TOKEN` | The only path that changes the zone |

`CF_RW_TOKEN` must never be added to GitHub. CI plans; it never applies.

## Intent vs transcript

The distinction matters when reading a diff:

- **`dns.tf`** is a transcript. A diff means this file is wrong — fix the file.
- **`zone-settings.tf` and `security.tf`** are asserted intent. A diff means the
  dashboard drifted from a decision on record — fix the zone, by applying.

## First run

```bash
make tf-init      # once, and after any change to versions.tf
make tf-plan      # read-only, safe to run any time
make drift        # same plan, reduced to an exit code for scripting
```
