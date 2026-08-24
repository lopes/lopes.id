#!/usr/bin/env bash
#
# Folds captured Cloudflare snapshots into two small committed CSVs.
#
# ACTIONS
# - Reads every snapshots/*.json and appends to data/traffic-history.csv
#   (one row per complete day) and data/traffic-breakdowns.csv (one row per
#   snapshot per dimension value).
# - Idempotent: re-running over the same snapshots leaves both files unchanged.
#
# DESIGN
# Raw snapshots are ~64 KB each and git-ignored, so without this the repo keeps
# no history at all. The daily file answers "how much traffic, over months".
#
# The breakdowns file exists because of a Free-plan limit: httpRequestsAdaptive-
# Groups accepts a window of at most 24 hours, so per-user-agent and per-country
# cuts CANNOT be recovered retroactively. A question asked in November about
# September is unanswerable unless the answer was captured in September. That is
# the whole reason this file is committed rather than derived on demand.
#
# Partial days are skipped. The capture day is always incomplete — the day is
# not over — and folding it in would show a fake cliff at the end of every
# series. This has caught us before.
#
# Where a date appears in more than one snapshot, the most recent capture wins.
#
# USAGE
#   ./scripts/traffic-history.sh [--snapshots DIR] [--out DIR]
#
# AUTHOR: Joe Lopes <https://lopes.id>
# CREATED: 2026-08-24
# LICENSE: MIT
##

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNAPDIR="${REPO_ROOT}/snapshots"
OUTDIR="${REPO_ROOT}/data"

usage() { sed -n '3,30p' "$0" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --snapshots) SNAPDIR="$2"; shift 2 ;;
    --out)       OUTDIR="$2"; shift 2 ;;
    -h|--help)   usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

command -v jq >/dev/null || { echo "missing dependency: jq" >&2; exit 1; }

shopt -s nullglob
SNAPSHOTS=("$SNAPDIR"/*.json)
(( ${#SNAPSHOTS[@]} )) || { echo "no snapshots in ${SNAPDIR}" >&2; exit 1; }

mkdir -p "$OUTDIR"
DAILY="${OUTDIR}/traffic-history.csv"
BREAK="${OUTDIR}/traffic-breakdowns.csv"

# Both files are built by a single slurped jq pass over every snapshot, so
# de-duplication and ordering happen inside jq and the result does not depend on
# shell locale or sort flags. Re-running is therefore byte-stable.
#
# `captured` is the full window.until timestamp, not just its date: two
# snapshots taken on the same day are two distinct 24-hour observations, and
# collapsing them to a date silently merged them.

# Daily totals. The capture instant is carried only so the newest reading of a
# date wins, then dropped — a date's totals are a property of that date, not of
# when they happened to be read.
jq -s -r '
  [ .[]
    | .window.until as $u
    | ( .queries[] | select(.name=="daily_totals")
        | .data?.viewer?.zones[0]?.httpRequests1dGroups? ) // empty
    | .[]
    | select(.dimensions.date < ($u | split("T")[0]))   # skip the partial capture day
    | { date: .dimensions.date, captured: $u,
        r: .sum.requests, p: .sum.pageViews, b: .sum.bytes, u: .uniq.uniques }
  ]
  | group_by(.date) | map(max_by(.captured))
  | sort_by(.date)[]
  | [.date, .r, .p, .b, .u] | @csv
' "${SNAPSHOTS[@]}" > /tmp/th_daily.$$

# One row per dimension value per capture. Dimension names are deliberately
# tool-neutral, so a rename on Cloudflare's side does not rewrite months of
# history.
jq -s -r '
  [ .[]
    | .window.until as $u
    | . as $snap
    | [ {q:"by_verified_bot", d:"verified_bot", k:"verifiedBotCategory"},
        {q:"by_user_agent",   d:"user_agent",   k:"userAgent"},
        {q:"by_country",      d:"country",      k:"clientCountryName"},
        {q:"by_path",         d:"path",         k:"clientRequestPath"} ][]
    | . as $spec
    | ( ( $snap.queries[] | select(.name==$spec.q)
          | .data?.viewer?.zones[0]?.httpRequestsAdaptiveGroups? ) // empty )
    | .[]
    | { captured: $u, dimension: $spec.d,
        value: ( .dimensions[$spec.k] | if . == null or . == "" then "(unverified)" else . end ),
        count: .count }
  ]
  | group_by([.captured, .dimension, .value]) | map(max_by(.count))
  | sort_by([.captured, .dimension, .value])[]
  | [.captured, .dimension, .value, .count] | @csv
' "${SNAPSHOTS[@]}" > /tmp/th_break.$$

{ echo 'date,requests,pageviews,bytes,uniques'; cat /tmp/th_daily.$$; } > "$DAILY"
{ echo 'captured,dimension,value,count';        cat /tmp/th_break.$$; } > "$BREAK"
rm -f /tmp/th_daily.$$ /tmp/th_break.$$

echo "wrote ${DAILY#$REPO_ROOT/}    $(( $(wc -l < "$DAILY") - 1 )) rows" >&2
echo "wrote ${BREAK#$REPO_ROOT/} $(( $(wc -l < "$BREAK") - 1 )) rows" >&2
