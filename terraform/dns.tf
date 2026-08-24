# DNS records for lopes.id.
#
# Unlike zone-settings.tf, this file is a TRANSCRIPT of the zone, not a
# statement of intent. If a plan wants to change something here, the fix is this
# file, not the zone — DNS is the one place where being wrong is immediately and
# publicly visible.
#
# ttl = 1 means "automatic", which is the only value Cloudflare accepts for a
# proxied record.

# The site itself, served by Cloudflare Pages.
resource "cloudflare_dns_record" "apex" {
  zone_id = var.zone_id
  name    = "lopes.id"
  type    = "CNAME"
  content = "lopes-id.pages.dev"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "www" {
  zone_id = var.zone_id
  name    = "www.lopes.id"
  type    = "CNAME"
  content = "lopes-id.pages.dev"
  proxied = true
  ttl     = 1
}

# Bluesky domain handle verification for @lopes.id. Deleting this silently
# breaks the handle — it reverts to the generated .bsky.social one.
resource "cloudflare_dns_record" "atproto" {
  zone_id = var.zone_id
  name    = "_atproto.lopes.id"
  type    = "TXT"
  content = "did=did:plc:zwmnxhj2bve5tmgsunl4ffp6"
  proxied = false
  ttl     = 1
  comment = "Bluesky custom handle"
}
