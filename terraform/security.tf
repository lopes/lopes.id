# Bot and WAF configuration for lopes.id.
#
# This file mostly declares ABSENCE, which is unusual enough to explain. In
# August 2026 a request storm — peaking at 9.5M requests and 191 GB in one day —
# turned out to be almost entirely self-inflicted: Cloudflare Pages serves an
# SPA-style fallback when a build contains no 404.html, so every unknown path
# returned HTTP 200 with a 161 KB page full of RELATIVE links. Crawlers resolved
# those against the garbage prefix and walked an infinite fake URL tree.
#
# Honest crawling of ~100 posts costs about 495 requests a day. The other 99.85%
# did not exist independently of that defect. The fix was 404.qmd in the repo, not
# anything in this file.
#
# So the zone is deliberately clean, and the settings below say so explicitly.
# Without that, an empty configuration is indistinguishable from one nobody got
# around to writing — and a rule quietly reappearing looks exactly like a rule
# that was always meant to be there.

resource "cloudflare_bot_management" "this" {
  zone_id = var.zone_id

  # Bot Fight Mode: off. Measured at ~150-800 challenges/day against ~2M
  # unverified requests — 0.04%. It cannot be scoped, and it challenges uptime
  # monitors and RSS fetchers on the way past.
  fight_mode = false

  # AI scraper/crawler blocking: off. Blocking by category caught Bingbot,
  # because Cloudflare classifies Bingbot, Googlebot and Applebot as
  # multi-purpose — Search AND Training — so a Training block hits them even
  # with Search set to Allow. That cost ~46,000 blocked Bingbot requests/day for
  # about a day. The per-crawler toggles in the dashboard are a front-end to
  # this same managed rule, not an override on it.
  ai_bots_protection = "disabled"

  # AI Labyrinth (link maze): off. Feeding a maze to crawlers is the same
  # mistake the 404 bug made by accident — generating infinite fake URLs — only
  # on purpose. Not worth the egress.
  crawler_protection = "disabled"

  # Cloudflare-managed robots.txt: off. The repo ships its own robots.txt and two
  # systems owning one file means the edge silently wins.
  is_robots_txt_managed = false
}

# The custom firewall ruleset, declared empty on purpose.
#
# An earlier `block-training-crawlers` rule lived here and was removed once the
# root cause was understood. Declaring the ruleset with no rules — rather than
# omitting it — is what makes drift detection work: a rule added in the dashboard
# shows up as a diff instead of blending into an unmanaged corner of the zone.
#
# The rule that used to live here is preserved below verbatim, because it was
# deleted from Cloudflare on 2026-08-24 and this is now its only home. Both
# clauses above the user-agent list are load-bearing and must come back with it
# if blocking is ever reintroduced: /robots.txt stays reachable so a blocked
# crawler can still read the policy, and cf.verified_bot_category makes blocking
# a verified search engine impossible even if a future user-agent string
# collides. Cloudflare's own generated rule lacked that second guard, and its
# absence cost Bingbot ~46,000 blocked requests/day for about a day.
#
#   name:    block-training-crawlers
#   action:  block
#   enabled: false  (disabled 2026-08-19, deleted 2026-08-24)
#
#   (http.request.uri.path ne "/robots.txt")
#   and not (cf.verified_bot_category eq "Search Engine Crawler")
#   and (
#     http.user_agent contains "Amazonbot" or
#     http.user_agent contains "Bytespider" or
#     http.user_agent contains "ClaudeBot" or
#     http.user_agent contains "GPTBot" or
#     http.user_agent contains "meta-externalagent" or
#     http.user_agent contains "PetalBot"
#   )
resource "cloudflare_ruleset" "firewall_custom" {
  zone_id     = var.zone_id
  name        = "default"
  kind        = "zone"
  phase       = "http_request_firewall_custom"
  description = "Intentionally empty — see security.tf for why."
  rules       = []
}
