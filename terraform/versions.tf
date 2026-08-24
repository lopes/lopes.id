terraform {
  required_version = ">= 1.9"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }

  # HCP Terraform stores and locks state only. The workspace execution mode is
  # Local, so plan and apply run here and the Cloudflare token never leaves this
  # machine (or, in CI, the runner).
  cloud {
    organization = "lopes-log"

    workspaces {
      name = "lopes-id"
    }
  }
}

# Auth comes from the CLOUDFLARE_API_TOKEN environment variable, never from a
# variable or tfvars file. The Makefile sets it from CF_RO_TOKEN for read-only
# targets and CF_RW_TOKEN only for apply, so a plan cannot write even by mistake.
provider "cloudflare" {}
