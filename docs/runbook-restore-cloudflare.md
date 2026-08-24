# Runbook: restoring the Cloudflare zone

Most of the zone is code and restores itself. This file covers the rest.

## What Terraform owns

Nine resources, in `terraform/`:

| Resource | Covers |
| -------- | ------ |
| `cloudflare_dns_record.apex` / `.www` | CNAMEs to `lopes-id.pages.dev` |
| `cloudflare_dns_record.atproto` | Bluesky handle verification TXT |
| `cloudflare_zone_setting.*` | `early_hints`, `always_use_https`, `min_tls_version`, `ssl` |
| `cloudflare_bot_management.this` | Bot Fight Mode, AI scraper blocking, AI Labyrinth, managed robots.txt |
| `cloudflare_ruleset.firewall_custom` | The custom WAF ruleset, declared empty |

Restoring them:

```bash
terraform login          # once, if state access is lost
make tf-init
make tf-plan             # read it before trusting it
make tf-apply
```

State lives in HCP Terraform (org `lopes-log`, workspace `lopes-id`, execution
mode **Local**). If the workspace itself is lost, recreate it as CLI-driven, set
execution mode to Local, then re-import each resource — see the import IDs below.

### Import ID formats

These differ per resource and are easy to get wrong:

```
cloudflare_dns_record      <zone_id>/<record_id>
cloudflare_zone_setting    <zone_id>/<setting_id>
cloudflare_bot_management  <zone_id>
cloudflare_ruleset         zones/<zone_id>/<ruleset_id>     # note the prefix
```

The ruleset needs the `zones/` discriminator; without it the provider fails with
`invalid discriminator segment`.

## Not codifiable — verify by hand

**AI Crawl Control per-category policies.** The API exposes `ai_search`,
`ai_training` and `ai_user` under `/zones/<id>/bot_management`, but the v5
provider's `cloudflare_bot_management` resource has no attributes for them. They
are invisible to `terraform plan` and will not drift-detect.

Expected: all three `disabled`. Check with:

```bash
set -a; . ./.env; set +a
curl -sS -H "Authorization: Bearer $CF_RO_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/bot_management" \
  | jq '{ai_search, ai_training, ai_user}'
```

Dashboard path: **Security → Settings → Bot traffic → Configure AI bot policies**.

One reason to actually check this: from **2026-09-15** Cloudflare blocks Training
and Agent by default for newly onboarded domains. `lopes.id` is not newly
onboarded and should be unaffected — but "should be" is exactly the kind of
assumption worth verifying once.

**Web Analytics.** A `cloudflare_web_analytics_site` resource exists and could
own this, but it is deliberately not managed: importing it risks disabling the
beacon on a bad plan, for little benefit. Verify it is on at
**Analytics → Web Analytics**, with automatic (edge) injection. The site tag
belongs in `.env` as `CF_SITE_TAG`.

**Cloudflare Pages.** Out of scope on purpose. `wrangler-action` in
`.github/workflows/deploy.yml` owns the deploy path, and importing the project
risks the one thing that must not break.

## Rebuilding on a fresh zone

1. Add the domain to Cloudflare, point the registrar at Cloudflare's nameservers.
2. Create the Pages project `lopes-id` and connect the repo.
3. Fill `terraform/terraform.tfvars` with the new zone and account IDs.
4. `make tf-init && make tf-plan && make tf-apply`.
5. Verify the two manual items above.
6. `make monthly` — the probes confirm the site behaves, not just that it is configured.

## The thing that is not restorable

`data/traffic-breakdowns.csv` cannot be rebuilt. The free plan caps adaptive
queries at 24 hours, so per-user-agent and per-country history exists only
because it was captured at the time. Losing that file loses the data permanently.
The daily totals in `traffic-history.csv` are recoverable from Cloudflare for as
long as its own retention allows; the breakdowns are not.
