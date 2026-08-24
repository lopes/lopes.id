# Zone settings, one resource per setting.
#
# Unlike DNS below, these are ASSERTED INTENT, not a transcript of the zone. A
# diff here is a finding, not an error in this file — it means the dashboard and
# the decision on record disagree, and the decision wins.

# Early Hints is the reason much of this exists. It was disabled on 2026-08-19
# after the request-storm investigation found it running at a 0% cache hit rate:
# it caches `Link: rel=preload` headers from the origin, and a static Quarto
# build emits none, so it could never hit. Turning it off exposed a second
# problem — the dashboard read "off" while some datacentres kept firing for over
# 48 hours (Los Angeles 0%, Miami still 20%). A declared value plus `terraform
# plan` is the only way to answer "is it actually off?" without trusting a
# toggle that has already lied once.
resource "cloudflare_zone_setting" "early_hints" {
  zone_id    = var.zone_id
  setting_id = "early_hints"
  value      = "off"
}

resource "cloudflare_zone_setting" "always_use_https" {
  zone_id    = var.zone_id
  setting_id = "always_use_https"
  value      = "on"
}

resource "cloudflare_zone_setting" "min_tls_version" {
  zone_id    = var.zone_id
  setting_id = "min_tls_version"
  value      = "1.2"
}

resource "cloudflare_zone_setting" "ssl" {
  zone_id    = var.zone_id
  setting_id = "ssl"
  value      = "full"
}
