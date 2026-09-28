# terraform — Cloudflare zone configuration for lopes.id

The zone's configuration is code and lives here. It is not mirrored in prose
anywhere: the previous hand-written version of that mirror was wrong within two
days of being written, which is what prompted this.

## Layout

| File | Owns |
| ---- | ---- |
| `versions.tf` | Provider and HCP state backend |
| `variables.tf` | Zone, account, and Access OTP email identifiers |
| `zone-settings.tf` | TLS, HTTPS, Early Hints — asserted intent |
| `security.tf` | Bot settings and the deliberately empty WAF ruleset |
| `access.tf` | Pages `preview.lopes.id` domain and Zero Trust Access OTP gate — asserted intent |
| `dns.tf` | DNS records — a transcript of what is live |

## Credentials

State lives in HCP Terraform (org `lopes-log`, workspace `lopes-id`, execution
mode **Local** — HCP stores and locks state, runs happen here). Authenticate once
with `terraform login` (or `TF_TOKEN_app_terraform_io` in `.env`).

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
- **`zone-settings.tf`, `security.tf`, and `access.tf`** are asserted intent. A
  diff means the dashboard drifted from a decision on record — fix the zone or
  Access policy, by applying.

## Preview & Zero Trust Access (`access.tf`)

- **DNS & Pages domain:** `preview.lopes.id` is a proxied CNAME (`dns.tf`) pointing to `preview.lopes-id.pages.dev` and registered on the `lopes-id` Pages project (`cloudflare_pages_domain.preview`). GitHub Actions (`.github/workflows/integration.yml`) deploys every PR to `--branch=preview`.
- **Access gate:** `cloudflare_zero_trust_access_application.pages_preview` gates `preview.lopes.id`, `*.lopes-id.pages.dev`, and `lopes-id.pages.dev` behind Cloudflare Zero Trust Access using the built-in **One-Time Pin (Email OTP)** identity provider.
- **How to get access:** Visit `https://preview.lopes.id`, enter the email configured in `CF_ACCESS_EMAIL` (`var.access_email`), and enter the 6-digit pin emailed by Cloudflare. The session cookie lasts 24 hours. To change or add allowed emails, edit `cloudflare_zero_trust_access_policy.pages_preview_otp` in `access.tf` and run `make tf-apply`.

## First run

```bash
make tf-init      # once, and after any change to versions.tf
make tf-plan      # read-only, safe to run any time
make drift        # same plan, reduced to an exit code for scripting
```
