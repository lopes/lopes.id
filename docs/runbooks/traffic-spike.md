# Runbook: traffic spike

Written after the August 2026 request storm, which peaked at **9.5M requests and
191 GB in a single day** and turned out to be almost entirely self-inflicted. The
order below is the order that would have found it fastest — which is not the
order it was actually found in.

## 0. Before anything: is it real traffic?

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://lopes.id/totally/made/up/path/
```

If that returns **200 instead of 404**, stop. The site is generating its own
traffic and nothing else matters until it is fixed.

A missing `404.html` makes Cloudflare Pages serve an SPA-style fallback: every
unknown path returns a full 161 KB page carrying ~400 **relative** links.
Crawlers resolve those against the garbage prefix, invent new garbage paths, and
walk an infinite tree. In August this manufactured **99.85%** of all traffic —
honest crawling of ~100 posts costs about 495 requests a day.

No Cloudflare setting can fix this. It is a build artifact problem.

## 1. Measure before changing anything

```bash
make snapshot LABEL=spike-before
```

Then again after any change, with **the same `--days`**. A 3-day "after"
compared against a 7-day "before" overstates the improvement. This is the single
easiest way to fool yourself.

## 2. Find the shape of it

```bash
make history
```

`data/traffic-history.csv` gives the daily series — look for whether this is a
step change or a ramp, and when it started. Check the *start* date, not the peak:
in August the investigation began on the 15th and the peak had been on the 2nd.
Two weeks of looking at an aftermath while believing it was the event.

`data/traffic-breakdowns.csv` gives per-user-agent and per-country cuts. These
are captured monthly precisely because the free plan caps adaptive queries at 24
hours — **they cannot be recovered retroactively.**

## 3. Distrust the dashboard aggregate

Cloudflare Web Analytics with "Exclude bots" on reported 33,840 visits and 33,840
pageviews — a ratio of exactly 1.000, which is not a number real humans produce.
Meanwhile the zone was serving ~2.7M requests/day. Both were correct; they count
different populations.

- **Zone analytics** counts every request at the edge.
- **Web Analytics / RUM** counts only clients that execute JavaScript.

A crawler that never runs JS is invisible to the second and dominant in the
first. If those two disagree wildly, that gap *is* the finding.

Note `/cdn-cgi/rum` is Cloudflare's own beacon. Third-party analytics posts to
its own domain and is structurally invisible to zone-level queries — which is how
a whole population of JS-executing traffic was missed for days.

## 4. Only now consider blocking

Three things worth knowing before touching a rule:

- **Blocked ≠ absent.** A block produces a 403 at the edge, not silence. Request
  totals will not fall. Bandwidth and origin load will.
- **Category blocking catches search engines.** Cloudflare classifies Bingbot,
  Googlebot and Applebot as multi-purpose — Search *and* Training — so blocking
  Training hits them even with Search set to Allow. This cost ~46,000 blocked
  Bingbot requests/day for about a day.
- **Country blocking hides bugs.** Blocking Singapore and China would have
  removed 2.4M requests/day and left the actual defect in place, producing a
  graph instead of an explanation.

Blocking is slow even when correct: the AI Crawler category decayed
632k → 242k → 65k → 577 per day across three days of sustained 403s.

If a rule is genuinely warranted, add it to `terraform/security.tf` — never the
dashboard — and keep both guard clauses documented there.

## 5. Check the edge, not just the config

```bash
make drift                                    # is the config what we declared?
curl -sI -A 'Mozilla/5.0' https://lopes.id | grep -i '^link:'   # is the edge obeying it?
```

These answer different questions. A setting can read `off` and still be served:
Early Hints stayed active in some datacentres for over 48 hours after being
disabled, with Los Angeles at 0% and Miami still at 20%. A global average hides
that completely.

## Still unexplained

Roughly **687,000 requests/day** of plain-Chrome user agents with no bot
verification and no explanation survived the fix. They are a separate question,
not a leftover from this one. `data/traffic-breakdowns.csv` accumulates the
evidence for whenever that gets picked up.
