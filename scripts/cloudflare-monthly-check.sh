#!/usr/bin/env bash
#
# The recurring health check for lopes.id: capture, fold, compare, probe.
#
# ACTIONS
# - Captures a Cloudflare snapshot and folds it into data/*.csv
# - Reports Terraform drift between the declared zone and the live one
# - Probes the live site for the two regressions that have actually happened
# - Prints a month-over-month traffic delta
#
# DESIGN
# Every check prints PASS or FAIL and the script keeps going. An early exit
# would hide later failures, and the point of a monthly check is to see the
# whole picture in one pass. The exit code is non-zero if anything failed, so it
# is still usable from cron.
#
# Two of the probes exist because declared state cannot answer the question.
# Terraform can prove early_hints is set to "off"; it cannot prove the edge has
# stopped acting on it. In August 2026 those disagreed for over 48 hours — the
# dashboard read off while Miami still served it. So the config is checked with
# `terraform plan` and the behaviour is checked with curl, because they are
# different questions and only one of them has ever been the problem.
#
# USAGE
#   ./scripts/cloudflare-monthly-check.sh [--label NAME] [--days N]
#
# AUTHOR: Joe Lopes <https://lopes.id>
# CREATED: 2026-08-24
# LICENSE: MIT
##

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABEL="monthly-$(date -u +%Y-%m)"
DAYS=30
SITE="https://lopes.id"
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36'
FAILED=0

usage() { sed -n '3,28p' "$0" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label) LABEL="$2"; shift 2 ;;
    --days)  DAYS="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
pass() { printf '  PASS  %s\n' "$*"; }
fail() { printf '  FAIL  %s\n' "$*"; FAILED=1; }

say "1. Capture"
if "${REPO_ROOT}/scripts/analytics-snapshot.sh" "$LABEL" --days "$DAYS" >/dev/null 2>/tmp/snap.err; then
  pass "snapshot captured ($LABEL, ${DAYS}d)"
else
  fail "snapshot failed"; sed 's/^/        /' /tmp/snap.err
fi

say "2. History"
if "${REPO_ROOT}/scripts/traffic-history.sh" 2>/tmp/hist.err; then
  pass "folded into data/"
else
  fail "traffic-history.sh failed"; sed 's/^/        /' /tmp/hist.err
fi

say "3. Configuration drift"
if [[ -d "${REPO_ROOT}/terraform" ]]; then
  ( cd "$REPO_ROOT" && make drift ) >/tmp/drift.out 2>&1
  case $? in
    0) pass "$(cat /tmp/drift.out)" ;;
    2) fail "zone differs from declared state — run 'make tf-plan'" ;;
    *) fail "terraform plan failed"; sed 's/^/        /' /tmp/drift.out ;;
  esac
else
  fail "terraform/ missing"
fi

say "4. Live behaviour"
# The soft-404 regression. A missing 404.html makes Cloudflare Pages serve an
# SPA fallback: HTTP 200 on every unknown path, each carrying ~400 relative
# links, which is how crawlers were handed an infinite fake site.
code=$(curl -s -o /dev/null -w '%{http_code}' -A "$UA" "${SITE}/totally/made/up/path/" || echo 000)
[[ "$code" == "404" ]] && pass "unknown paths return 404" \
                       || fail "unknown paths return ${code} — expected 404 (soft-404 regression)"

# Early Hints emits a `Link:` preload header. A static Quarto build gives it
# nothing to preload, so any Link header here means it is active again.
if curl -sI -A "$UA" "$SITE" 2>/dev/null | grep -qi '^link:'; then
  fail "Link: header present — Early Hints appears active again"
else
  pass "no Link: header — Early Hints inactive at the edge"
fi

# robots.txt must stay reachable: it is the first clause of any future block
# rule, so a crawler that is blocked can still read why.
[[ "$(curl -s -o /dev/null -w '%{http_code}' -A "$UA" "${SITE}/robots.txt")" == "200" ]] \
  && pass "robots.txt reachable" || fail "robots.txt not reachable"

# Non-production hostnames (preview.lopes.id and lopes-id.pages.dev) must redirect
# unauthenticated visitors to Cloudflare Zero Trust Access (302 -> cloudflareaccess.com).
for preview_host in "https://preview.lopes.id" "https://lopes-id.pages.dev"; do
  hdrs=$(curl -sI -A "$UA" "$preview_host" 2>/dev/null || true)
  p_code=$(printf '%s\n' "$hdrs" | awk 'NR==1 {print $2}')
  p_loc=$(printf '%s\n' "$hdrs" | awk 'tolower($1)=="location:" {print $2}' | tr -d '\r')
  if [[ "$p_code" == "302" && "$p_loc" == *"cloudflareaccess.com"* ]]; then
    pass "${preview_host} gated by Access (302 -> cloudflareaccess.com)"
  else
    fail "${preview_host} returned ${p_code:-000} (location: ${p_loc:-none}) — expected 302 to cloudflareaccess.com"
  fi
done

say "5. Traffic"
DAILY="${REPO_ROOT}/data/traffic-history.csv"
if [[ -s "$DAILY" ]]; then
  awk -F, 'NR>1 { gsub(/"/,"",$1); m=substr($1,1,7); r[m]+=$2; b[m]+=$4; n[m]++ }
    END {
      c=0; for (k in r) months[c++]=k
      # insertion sort: a handful of months, and it avoids a GNU-only asort()
      for (i=1;i<c;i++){ v=months[i]; j=i-1; while (j>=0 && months[j]>v){months[j+1]=months[j];j--}; months[j+1]=v }
      prev=""
      for (i=0;i<c;i++) { k=months[i]
        # Per-day, never totals. A partial month against a full one is the
        # comparison that overstates every result, and it has caught us before.
        avg = r[k]/n[k]
        d = (prev=="" ? "" : sprintf("  (%+.1f%%/day)", (avg-pavg)*100.0/pavg))
        printf "  %s  %11.0f requests/day  %6.1f GB/day  over %2d day%s%s\n", \
               k, avg, b[k]/n[k]/1073741824, n[k], (n[k]==1?" ":"s"), d
        prev=k; pavg=avg }
      if (c && n[months[c-1]] < 20)
        printf "  note: %s covers only %d days so far\n", months[c-1], n[months[c-1]]
    }' "$DAILY"
  # A monthly mean hides a step change: August 2026 averages ~3M requests/day
  # only because of the storm at the start of it. The recent window is what
  # says whether the site is healthy today.
  tail -n 7 "$DAILY" | awk -F, '{ gsub(/"/,"",$1); r+=$2; b+=$4; n++
      if (first=="") first=$1; last=$1 }
    END { if (n) printf "  last %d days (%s..%s)  %11.0f requests/day  %6.1f GB/day\n", \
                        n, first, last, r/n, b/n/1073741824 }'
else
  fail "no traffic history yet"
fi

say "Result"
[[ $FAILED -eq 0 ]] && { echo "  all checks passed"; exit 0; } || { echo "  one or more checks FAILED"; exit 1; }
