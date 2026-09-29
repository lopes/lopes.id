# Runbook: monthly check

```bash
make monthly
```

Takes about a minute. Captures a snapshot, folds it into `data/`, compares the
zone against `terraform/`, probes the live site, and prints traffic.

Every check reports PASS or FAIL and the run continues — an early exit would
hide the rest. Exit code is non-zero if anything failed, so it is cron-safe.

## Reading the output

### 1. Capture / 2. History

A FAIL here is almost always the token. Check `CF_RO_TOKEN` in `.env` is present
and unexpired. A snapshot that partially fails still writes a file: the failing
query records Cloudflare's own error text rather than an empty result, so a
permissions problem can never be misread as "no traffic".

### 3. Configuration drift

FAIL means the live zone no longer matches `terraform/`. Someone changed
something in the dashboard, or a Cloudflare default moved.

```bash
make tf-plan          # see exactly what differs
```

Then decide which side is wrong:

- **The zone is wrong** (an accidental or forgotten dashboard edit) →
  `make tf-apply` to restore the declared state.
- **The change was intended** → update the `.tf` file, commit it with the reason,
  and apply. The commit message is the only record of *why*; Terraform records
  only *what*.

Never resolve drift by ignoring it. The point of declaring the zone is that
unexplained differences are visible.

### 4. Live behaviour

Four probes, each verifying live edge behaviour rather than declared state.

**`unknown paths return 404`** — the regression that caused the August 2026
request storm. Cloudflare Pages serves an SPA-style fallback when a build has no
`404.html`: every unknown path returns HTTP 200 with a full page of *relative*
links, and crawlers walk it into an infinite fake site. If this FAILs, check
`404.qmd` still exists and still renders. This is the single highest-value check
in the file.

**`no Link: header`** — Early Hints. A static Quarto build emits no
`Link: rel=preload` headers, so Early Hints can never hit; it was disabled after
running at a 0% hit rate. This probe is not redundant with check 3: in August the
stored value read `off` while some datacentres kept serving it for over 48 hours.
Terraform can prove what is *configured*. Only this can show what the edge is
*doing*.

**`robots.txt reachable`** — matters if blocking is ever reintroduced, because
the first clause of any block rule exempts `/robots.txt` so a blocked crawler can
still read why.

**`preview.lopes.id` and `lopes-id.pages.dev` gated by Access** — unauthenticated
requests to non-production / side hostnames must return HTTP `302` redirecting to
`cloudflareaccess.com` (Email OTP), while `https://lopes.id` remains public. If
this FAILs, check `terraform/access.tf` and run `make tf-plan`.

### 5. Traffic

Three lines. Per-month figures are **per day**, never totals — a partial month
against a full one overstates everything, and that comparison has produced a
fake +325.7% here.

The recent-window line is the one to read for health. A monthly mean carries
whatever happened earlier in the month; in August 2026 the mean said traffic was
*up* while it had in fact collapsed by 79%.

Roughly 500k–1M requests/day is normal for this site. Sustained growth past a few
million is worth investigating — see `runbook-traffic-spike.md`.

## When it fails in CI

The monthly GitHub Actions run only does check 3. Drift opens an issue titled
"Cloudflare drift detected" and comments on it thereafter rather than filing a
new one each month.
