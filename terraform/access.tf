# Preview domain and Zero Trust Access (Email OTP) configuration for lopes.id.
#
# Like zone-settings.tf and security.tf, this file is ASSERTED INTENT:
# - `preview.lopes.id` is registered as a custom domain on the `lopes-id`
#   Cloudflare Pages project (backed by the CNAME to `preview.lopes-id.pages.dev`
#   in dns.tf).
# - Every non-production / side hostname (`*.lopes-id.pages.dev`,
#   `lopes-id.pages.dev`, and `preview.lopes.id`) is gated behind Cloudflare
#   Zero Trust Access with Email One-Time Pin (OTP) restricted to
#   `var.access_email`.
# - Requests to `https://lopes.id` and `https://www.lopes.id` remain public
#   because Cloudflare Access evaluates the incoming HTTP Host header.

resource "cloudflare_pages_domain" "preview" {
  account_id   = var.account_id
  project_name = "lopes-id"
  name         = "preview.lopes.id"
}

resource "cloudflare_zero_trust_access_policy" "pages_preview_otp" {
  account_id = var.account_id
  name       = "Allow Members - Cloudflare Pages"
  decision   = "allow"

  include = [
    {
      email = {
        email = var.access_email
      }
    },
  ]
}

resource "cloudflare_zero_trust_access_application" "pages_preview" {
  account_id = var.account_id
  name       = "lopes-id - Cloudflare Pages"
  type       = "self_hosted"
  domain     = "*.lopes-id.pages.dev"

  destinations = [
    {
      type = "public"
      uri  = "*.lopes-id.pages.dev"
    },
    {
      type = "public"
      uri  = "lopes-id.pages.dev"
    },
    {
      type = "public"
      uri  = "preview.lopes.id"
    },
  ]

  session_duration           = "24h"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  enable_binding_cookie      = false
  http_only_cookie_attribute = true
  options_preflight_bypass   = false

  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.pages_preview_otp.id
      precedence = 1
    },
  ]
}
