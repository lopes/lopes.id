# lopes.id — task index.
#
# ACTIONS
# - Wraps the repo's build, validation, analytics and infrastructure commands
#   behind a single discoverable entry point.
#
# DESIGN
# Every target here is a thin wrapper. The real logic lives in scripts/ and
# terraform/, so each step stays runnable directly by path and this file never
# becomes the only way to do anything. `make help` is the default target.
#
# Targets whose backing file does not exist yet fail with the phase that
# delivers it, rather than a confusing "no such file" from the shell.
#
# USAGE
#   make help
#   make snapshot LABEL=monthly-2026-08
#
# AUTHOR: Joe Lopes <https://lopes.id>
# CREATED: 2026-08-21
# LICENSE: MIT
##

.DEFAULT_GOAL := help

SITE_DIR := _site
TF_DIR   := terraform
DAYS     ?= 7

.PHONY: help render preview check setup clean snapshot history monthly \
        tf-init tf-fmt tf-validate tf-plan tf-apply drift

help:  ## Show this help
	@grep -hE '^[a-z][a-z-]*:.*## ' $(MAKEFILE_LIST) \
	  | sed 's/:.*## /|/' \
	  | awk -F'|' '{printf "  %-13s %s\n", $$1, $$2}'

## --- site ---------------------------------------------------------------

render:  ## Build the static site into _site/
	quarto render --output-dir $(SITE_DIR)

preview:  ## Local dev server with live reload
	quarto preview

check:  ## Run the content validation gate (same as the pre-commit hook)
	bash scripts/pre-commit.sh

setup:  ## Install the git pre-commit hook
	./scripts/setup.sh

clean:  ## Remove build output and Quarto caches
	rm -rf $(SITE_DIR) _site-test .quarto

## --- analytics ----------------------------------------------------------

snapshot:  ## Capture a Cloudflare snapshot: make snapshot LABEL=x [DAYS=7]
	@test -n "$(LABEL)" || { echo "LABEL is required, e.g. make snapshot LABEL=monthly-2026-08"; exit 2; }
	./scripts/analytics-snapshot.sh $(LABEL) --days $(DAYS)

history:  ## Fold snapshots/ into the committed CSVs under data/
	@test -x scripts/traffic-history.sh || { echo "scripts/traffic-history.sh not present yet (Phase 3)"; exit 1; }
	./scripts/traffic-history.sh

monthly:  ## Full monthly check: snapshot, history, drift, live assertions
	@test -x scripts/cloudflare-monthly-check.sh || { echo "scripts/cloudflare-monthly-check.sh not present yet (Phase 3)"; exit 1; }
	./scripts/cloudflare-monthly-check.sh

## --- infrastructure -----------------------------------------------------

tf-init:  ## Initialise Terraform and the HCP state backend
	@test -d $(TF_DIR) || { echo "$(TF_DIR)/ not present yet (Phase 2)"; exit 1; }
	cd $(TF_DIR) && terraform init

tf-fmt:  ## Rewrite Terraform files into canonical format
	@test -d $(TF_DIR) || { echo "$(TF_DIR)/ not present yet (Phase 2)"; exit 1; }
	cd $(TF_DIR) && terraform fmt -recursive

tf-validate:  ## Check the Terraform configuration is internally valid
	@test -d $(TF_DIR) || { echo "$(TF_DIR)/ not present yet (Phase 2)"; exit 1; }
	cd $(TF_DIR) && terraform validate

tf-plan:  ## Show what Terraform would change on the live zone
	@test -d $(TF_DIR) || { echo "$(TF_DIR)/ not present yet (Phase 2)"; exit 1; }
	cd $(TF_DIR) && terraform plan

tf-apply:  ## Apply Terraform changes (needs CF_RW_TOKEN, local only)
	@test -d $(TF_DIR) || { echo "$(TF_DIR)/ not present yet (Phase 2)"; exit 1; }
	cd $(TF_DIR) && terraform apply

drift:  ## Report whether the live zone differs from the declared state
	@test -d $(TF_DIR) || { echo "$(TF_DIR)/ not present yet (Phase 2)"; exit 1; }
	@cd $(TF_DIR) && terraform plan -detailed-exitcode -no-color > /dev/null; \
	  case $$? in \
	    0) echo "no drift — the zone matches the declared state" ;; \
	    2) echo "DRIFT DETECTED — run 'make tf-plan' to see it"; exit 2 ;; \
	    *) echo "terraform plan failed"; exit 1 ;; \
	  esac
