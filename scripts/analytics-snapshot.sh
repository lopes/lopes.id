#!/usr/bin/env bash
#
# Captures a reproducible Cloudflare analytics snapshot for lopes.id.
#
# USAGE
#   ./scripts/analytics-snapshot.sh <label> [--days N] [--out DIR]
#
#   ./scripts/analytics-snapshot.sh pre-fix
#   ./scripts/analytics-snapshot.sh post-fix-day7
#
# Run the SAME command before and after a traffic change so the snapshots are
# comparable. Window length is what makes or breaks the comparison: a 3-day
# "after" measured against a 7-day "before" overstates the improvement.
#
# CONFIGURATION
# Reads credentials from the environment, or from a .env file at the repo root
# (git-ignored). See .env.example for how to obtain each value.

set -euo pipefail

API='https://api.cloudflare.com/client/v4/graphql'
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DAYS=7
OUTDIR="${REPO_ROOT}/snapshots"
LABEL=''

usage() { sed -n '3,18p' "$0" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --days) DAYS="$2"; shift 2 ;;
    --out)  OUTDIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) LABEL="$1"; shift ;;
  esac
done

# Environment wins over .env, so a one-off override doesn't require editing the file.
if [[ -f "${REPO_ROOT}/.env" ]]; then
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# || -z "${line// }" ]] && continue
    key="${line%%=*}"; key="${key// }"
    [[ -n "${!key:-}" ]] && continue          # already set in the environment
    val="${line#*=}"; val="${val%\"}"; val="${val#\"}"; val="${val%\'}"; val="${val#\'}"
    export "$key=$val"
  done < "${REPO_ROOT}/.env"
fi

[[ -n "$LABEL" ]] || { usage; exit 2; }
for tool in curl jq; do
  command -v "$tool" >/dev/null || { echo "missing dependency: $tool" >&2; exit 1; }
done
: "${CF_TOKEN:?not set — see .env.example}"
: "${CF_ZONE_ID:?not set — see .env.example}"
: "${CF_ACCOUNT_ID:?not set — see .env.example}"

# BSD (macOS) and GNU date disagree on relative-date syntax.
if date -v-1d >/dev/null 2>&1; then
  SINCE=$(date -u -v-"${DAYS}"d +%Y-%m-%dT%H:%M:%SZ)
else
  SINCE=$(date -u -d "${DAYS} days ago" +%Y-%m-%dT%H:%M:%SZ)
fi
UNTIL=$(date -u +%Y-%m-%dT%H:%M:%SZ)

mkdir -p "$OUTDIR"
OUT="${OUTDIR}/$(date -u +%Y-%m-%d)-${LABEL}.json"

# Runs one GraphQL query. A failed query is recorded with Cloudflare's own error
# text rather than an empty result, so a permissions problem can never be
# misread as "no traffic".
gql() {
  local name="$1" query="$2" vars="$3" resp errors
  resp=$(curl -sS "$API" \
    -H "Authorization: Bearer ${CF_TOKEN}" \
    -H 'Content-Type: application/json' \
    --data "$(jq -nc --arg q "$query" --argjson v "$vars" '{query:$q,variables:$v}')") || {
      echo "  ! ${name}: request failed" >&2
      jq -nc --arg n "$name" '{name:$n,error:"request failed"}'; return 0; }

  errors=$(jq -c '.errors // "none"' <<<"$resp")
  if [[ "$errors" != '"none"' ]]; then
    echo "  ! ${name}: $(jq -rc '[.[].message] | join("; ")' <<<"$errors")" >&2
    jq -nc --arg n "$name" --argjson e "$errors" '{name:$n,error:$e}'
  else
    echo "  + ${name}" >&2
    jq -c --arg n "$name" '{name:$n,data:.data}' <<<"$resp"
  fi
}

# Records the plan's real retention limits, so results are read against actual
# constraints rather than assumed ones.
Q_SETTINGS='query($zone:String!){viewer{zones(filter:{zoneTag:$zone}){settings{
  maxDuration maxNumberOfFields maxPageSize notOlderThan}}}}'

# The rule-defining query: which networks generate the requests. Web Analytics
# reports country and user agent but never ASN, and a WAF rule wants the ASN.
Q_ASN='query($zone:String!,$since:Time!,$until:Time!){viewer{zones(filter:{zoneTag:$zone}){
  httpRequestsAdaptiveGroups(limit:100,filter:{datetime_geq:$since,datetime_leq:$until},
    orderBy:[count_DESC]){count dimensions{clientAsn clientCountryName}}}}}'

# What is being hammered, and with which user agent.
Q_PATH='query($zone:String!,$since:Time!,$until:Time!){viewer{zones(filter:{zoneTag:$zone}){
  httpRequestsAdaptiveGroups(limit:100,filter:{datetime_geq:$since,datetime_leq:$until},
    orderBy:[count_DESC]){count dimensions{clientRequestPath userAgent}}}}}'

# Daily totals — the before/after headline number.
Q_DAILY='query($zone:String!,$since:String!,$until:String!){viewer{zones(filter:{zoneTag:$zone}){
  httpRequests1dGroups(limit:31,filter:{date_geq:$since,date_leq:$until},orderBy:[date_ASC]){
    dimensions{date} sum{requests pageViews bytes} uniq{uniques}}}}}'

# Beacon-level view: what Web Analytics itself counted, tying the zone numbers
# back to the dashboard.
Q_RUM='query($acct:String!,$tag:String!,$since:Time!,$until:Time!){viewer{accounts(filter:{accountTag:$acct}){
  rumPageloadEventsAdaptiveGroups(limit:100,filter:{siteTag:$tag,datetime_geq:$since,datetime_leq:$until},
    orderBy:[count_DESC]){count dimensions{countryName userAgentBrowser}}}}}'

VARS=$(jq -nc --arg z "$CF_ZONE_ID" --arg s "$SINCE" --arg u "$UNTIL" \
  '{zone:$z,since:$s,until:$u}')
VARS_DAILY=$(jq -nc --arg z "$CF_ZONE_ID" --arg s "${SINCE%%T*}" --arg u "${UNTIL%%T*}" \
  '{zone:$z,since:$s,until:$u}')

echo "snapshot '${LABEL}': ${SINCE} .. ${UNTIL} (${DAYS}d)" >&2

{
  gql settings         "$Q_SETTINGS" "$(jq -nc --arg z "$CF_ZONE_ID" '{zone:$z}')"
  gql requests_by_asn  "$Q_ASN"      "$VARS"
  gql requests_by_path "$Q_PATH"     "$VARS"
  gql daily_totals     "$Q_DAILY"    "$VARS_DAILY"
  if [[ -n "${CF_SITE_TAG:-}" ]]; then
    gql rum_pageloads "$Q_RUM" "$(jq -nc --arg a "$CF_ACCOUNT_ID" --arg t "$CF_SITE_TAG" \
      --arg s "$SINCE" --arg u "$UNTIL" '{acct:$a,tag:$t,since:$s,until:$u}')"
  else
    echo "  - rum_pageloads skipped (CF_SITE_TAG unset)" >&2
  fi
} | jq -s --arg label "$LABEL" --arg since "$SINCE" --arg until "$UNTIL" --argjson days "$DAYS" \
      '{label:$label,window:{since:$since,until:$until,days:$days},queries:.}' > "$OUT"

echo "wrote ${OUT}" >&2
echo >&2

# Top ASNs, printed for eyeballing — this is what the WAF rule gets built from.
# An empty result is reported explicitly: silence here would read as "no traffic"
# when it usually means the query failed.
top_asns=$(jq -r '
  (.queries[] | select(.name=="requests_by_asn") | .data.viewer.zones[0].httpRequestsAdaptiveGroups?)
  // empty
  | .[:15][]
  | "  \(.count)\tAS\(.dimensions.clientAsn)\t\(.dimensions.clientCountryName)"
' "$OUT" 2>/dev/null || true)

echo "top networks by request count:" >&2
if [[ -n "$top_asns" ]]; then
  echo "$top_asns" >&2
else
  echo "  (no data — check the errors above and the token's permissions)" >&2
fi
