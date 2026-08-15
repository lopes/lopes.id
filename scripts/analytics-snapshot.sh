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

# Free-plan constraints discovered by probing this zone, worth stating because
# they shape every query below:
#   - httpRequestsAdaptiveGroups accepts a time range of at most 1 day.
#   - clientAsn, clientASNDescription, botScore, ja4 and jsDetectionPassed are
#     not accessible; ASN-based analysis needs a paid plan. Classification here
#     therefore relies on verifiedBotCategory + userAgent + clientCountryName.

# Who is verified as a declared crawler and who is not. The single most useful
# cut: it separates AI/search crawlers that announce themselves from traffic
# that does not.
Q_BOTCAT='query($zone:String!,$since:Time!,$until:Time!){viewer{zones(filter:{zoneTag:$zone}){
  httpRequestsAdaptiveGroups(limit:25,filter:{datetime_geq:$since,datetime_leq:$until},
    orderBy:[count_DESC]){count dimensions{verifiedBotCategory}}}}}'

# Which agents, and from where — the substitute for ASN on this plan.
Q_AGENT='query($zone:String!,$since:Time!,$until:Time!){viewer{zones(filter:{zoneTag:$zone}){
  httpRequestsAdaptiveGroups(limit:40,filter:{datetime_geq:$since,datetime_leq:$until},
    orderBy:[count_DESC]){count dimensions{userAgent}}}}}'

Q_COUNTRY='query($zone:String!,$since:Time!,$until:Time!){viewer{zones(filter:{zoneTag:$zone}){
  httpRequestsAdaptiveGroups(limit:30,filter:{datetime_geq:$since,datetime_leq:$until},
    orderBy:[count_DESC]){count dimensions{clientCountryName}}}}}'

# What is being hammered.
Q_PATH='query($zone:String!,$since:Time!,$until:Time!){viewer{zones(filter:{zoneTag:$zone}){
  httpRequestsAdaptiveGroups(limit:40,filter:{datetime_geq:$since,datetime_leq:$until},
    orderBy:[count_DESC]){count dimensions{clientRequestPath}}}}}'

# Who is reaching the analytics beacon specifically. This is the traffic that
# consumes an analytics quota, and it is a different population from the bulk
# zone traffic — most scrapers never execute the JS that fires it.
Q_BEACON='query($zone:String!,$since:Time!,$until:Time!){viewer{zones(filter:{zoneTag:$zone}){
  httpRequestsAdaptiveGroups(limit:30,filter:{datetime_geq:$since,datetime_leq:$until,
    clientRequestPath:"/cdn-cgi/rum"},orderBy:[count_DESC]){
    count dimensions{clientCountryName userAgent}}}}}'

# Daily totals — the before/after headline number.
Q_DAILY='query($zone:String!,$since:String!,$until:String!){viewer{zones(filter:{zoneTag:$zone}){
  httpRequests1dGroups(limit:31,filter:{date_geq:$since,date_leq:$until},orderBy:[date_ASC]){
    dimensions{date} sum{requests pageViews bytes} uniq{uniques}}}}}'

# Beacon-level view: what Web Analytics itself counted, tying the zone numbers
# back to the dashboard.
Q_RUM='query($acct:String!,$tag:String!,$since:Time!,$until:Time!){viewer{accounts(filter:{accountTag:$acct}){
  rumPageloadEventsAdaptiveGroups(limit:100,filter:{siteTag:$tag,datetime_geq:$since,datetime_leq:$until},
    orderBy:[count_DESC]){count dimensions{countryName userAgentBrowser}}}}}'

# Adaptive queries are capped at 1 day by the plan, so they always describe the
# most recent 24h regardless of --days. Only daily_totals spans the full window.
if date -v-1d >/dev/null 2>&1; then
  ADAPTIVE_SINCE=$(date -u -v-1d +%Y-%m-%dT%H:%M:%SZ)
else
  ADAPTIVE_SINCE=$(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%SZ)
fi

VARS=$(jq -nc --arg z "$CF_ZONE_ID" --arg s "$ADAPTIVE_SINCE" --arg u "$UNTIL" \
  '{zone:$z,since:$s,until:$u}')
VARS_DAILY=$(jq -nc --arg z "$CF_ZONE_ID" --arg s "${SINCE%%T*}" --arg u "${UNTIL%%T*}" \
  '{zone:$z,since:$s,until:$u}')

echo "snapshot '${LABEL}'" >&2
echo "  daily totals : ${SINCE} .. ${UNTIL} (${DAYS}d)" >&2
echo "  breakdowns   : ${ADAPTIVE_SINCE} .. ${UNTIL} (1d — plan limit)" >&2

{
  gql daily_totals        "$Q_DAILY"    "$VARS_DAILY"
  gql by_verified_bot     "$Q_BOTCAT"   "$VARS"
  gql by_user_agent       "$Q_AGENT"    "$VARS"
  gql by_country          "$Q_COUNTRY"  "$VARS"
  gql by_path             "$Q_PATH"     "$VARS"
  gql beacon_requests     "$Q_BEACON"   "$VARS"
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

# Summary for eyeballing. An empty section is reported explicitly: silence here
# would read as "no traffic" when it usually means the query failed.
section() {
  local title="$1" name="$2" filter="$3" body
  body=$(jq -r --arg n "$name" "
    (.queries[] | select(.name==\$n) | .data.viewer.zones[0].httpRequestsAdaptiveGroups?)
    // empty | ${filter}
  " "$OUT" 2>/dev/null || true)
  echo "${title}:" >&2
  if [[ -n "$body" ]]; then echo "$body" >&2; else
    echo "  (no data — check the errors above)" >&2; fi
  echo >&2
}

echo >&2
jq -r '(.queries[] | select(.name=="daily_totals") | .data.viewer.zones[0].httpRequests1dGroups?)
  // empty | .[] | "  \(.dimensions.date)  requests=\(.sum.requests)  pageviews=\(.sum.pageViews)  unique_ips=\(.uniq.uniques)"' \
  "$OUT" 2>/dev/null | { echo "daily totals:" >&2; cat >&2; echo >&2; }

section "traffic by verified bot category (last 24h)" by_verified_bot \
  '.[:10][] | "  \(.count)\t\(if .dimensions.verifiedBotCategory == "" then "(unverified)" else .dimensions.verifiedBotCategory end)"'
section "top user agents (last 24h)" by_user_agent \
  '.[:10][] | "  \(.count)\t\(.dimensions.userAgent[0:90])"'
section "top countries (last 24h)" by_country \
  '.[:10][] | "  \(.count)\t\(.dimensions.clientCountryName)"'
section "analytics beacon hits by country (last 24h)" beacon_requests \
  '.[:10][] | "  \(.count)\t\(.dimensions.clientCountryName)\t\(.dimensions.userAgent[0:60])"'
