variable "zone_id" {
  type        = string
  description = "Cloudflare zone ID for lopes.id (set via CF_ZONE_ID in .env or terraform.tfvars)."
}

variable "account_id" {
  type        = string
  description = "Cloudflare account ID (set via CF_ACCOUNT_ID in .env or terraform.tfvars)."
}

variable "access_email" {
  type        = string
  description = "Email address allowed through Cloudflare Access OTP on preview and .pages.dev domains."
}
