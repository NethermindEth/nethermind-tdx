.DEFAULT_GOAL := help

VERSION := $(shell git describe --tags --always --dirty="-dev")
SHELL := /usr/bin/env bash
WRAPPER := scripts/env_wrapper.sh

##@ Help

# Awk script from https://github.com/paradigmxyz/reth/blob/main/Makefile
.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: v
v: ## Show the version
	@echo "Version: ${VERSION}"

##@ Build

build build-dev: check-module

# Known image variants:
#   taiko-tdx-prover  - current taiko / raiko2 / shasta build (default)
#   surge-tdx-prover  - legacy surge / raiko / pacaya build (snapshotted from
#                       commit 338f176)
SUPPORTED_IMAGES := taiko-tdx-prover surge-tdx-prover

check-module:
ifndef IMAGE
	$(error IMAGE is not set. Please specify IMAGE=<image> when running make build or make build-dev. Supported: $(SUPPORTED_IMAGES))
endif
	@case " $(SUPPORTED_IMAGES) " in \
		*" $(IMAGE) "*) ;; \
		*) echo "Error: unknown IMAGE='$(IMAGE)'. Supported: $(SUPPORTED_IMAGES)"; exit 1 ;; \
	esac

.PHONY: all build build-dev setup measure clean check-perms check-module

# Default target
all: build

# Ensure repo was cloned with correct permissions
check-perms: ## Check repository permissions
	@scripts/check_perms.sh

# Setup dependencies (Linux only)
setup: ## Install dependencies (Linux only)
	@scripts/setup_deps.sh

# Build module
build: check-perms setup ## Build the specified module
	@if [ "$(AZURE)" = "true" ] && [ "$(GCP)" = "true" ]; then \
		echo "Error: Cannot set both AZURE=true and GCP=true at the same time"; \
		exit 1; \
	fi; \
	case "$(IMAGE)" in \
		surge-tdx-prover) variant_profile="surge" ;; \
		taiko-tdx-prover) variant_profile="taiko" ;; \
	esac; \
	profiles="$$variant_profile"; \
	image_id="$(IMAGE)"; \
	if [ "$(DEV)" = "true" ]; then profiles="$$profiles,devtools"; image_id="$(IMAGE)-dev"; fi; \
	if [ "$(AZURE)" = "true" ]; then profiles="$$profiles,azure"; fi; \
	if [ "$(GCP)" = "true" ]; then profiles="$$profiles,gcp"; fi; \
	if [ "$(GCP)" = "true" ] && [ "$(DEV)" = "true" ]; then image_id="$(IMAGE)-gcp-dev"; fi; \
	$(WRAPPER) mkosi --force --image-id $$image_id --profile=$$profiles -I tdx-prover.conf


##@ Release

# GitHub repository hosting the releases.
RELEASE_REPO := NethermindEth/nethermind-tdx

download: ## Download VHD + measurements from a release tag into build/. Usage: make download TAG=v0.1.0 [IMAGE=taiko-tdx-prover-dev]
ifndef TAG
	$(error TAG is not set. Usage: make download TAG=v0.1.0)
endif
	@mkdir -p build
	@IMAGE_FILTER="$(or $(IMAGE),taiko-tdx-prover-dev)"; \
	echo "Fetching release $(TAG) from $(RELEASE_REPO) (filter: $$IMAGE_FILTER)..."; \
	assets=$$(gh api "repos/$(RELEASE_REPO)/releases/tags/$(TAG)" \
		--jq '.assets[] | select(.name | startswith("'"$$IMAGE_FILTER"'")) | "\(.name) \(.browser_download_url)"'); \
	if [ -z "$$assets" ]; then \
		echo "Error: no assets matching '$$IMAGE_FILTER' found in release $(TAG)."; \
		echo "Available assets:"; \
		gh api "repos/$(RELEASE_REPO)/releases/tags/$(TAG)" --jq '.assets[].name'; \
		exit 1; \
	fi; \
	echo "$$assets" | while IFS=' ' read -r name url; do \
		case "$$name" in \
			*.vhd|*.tar.gz|*.measurements.json|*.gcp_measurements.json|*.SHA256SUMS) \
				echo "  Downloading $$name ..."; \
				curl -fsSL -o "build/$$name" "$$url"; \
				;; \
		esac; \
	done; \
	echo "Done. Files in build/:"; \
	ls -lh build/*"$$IMAGE_FILTER"* 2>/dev/null || true

##@ Utilities

measure: ## Export TDX measurements for the built EFI file
	@$(WRAPPER) measured-boot $(FILE) build/measurements.json --direct-uki
	echo "Measurements exported to build/measurements.json"

measure-gcp: ## Export TDX measurements for GCP
	@$(WRAPPER) dstack-mr -uki $(FILE) -json > build/gcp_measurements.json
	echo "GCP Measurements exported to build/gcp_measurements.json"

# Clean build artifacts
clean: ## Remove cache and build artifacts
	rm -rf build/ mkosi.builddir/ mkosi.cache/ lima-nix/
	@REPO_DIR="$$(pwd)"; \
	REPO_HASH="$$(echo -n "$$REPO_DIR" | sha256sum | cut -c1-8)"; \
	LIMA_VM="tee-builder-$$REPO_HASH"; \
	if command -v limactl >/dev/null 2>&1 && limactl list | grep -q "^$$LIMA_VM"; then \
		echo "Stopping and deleting Lima VM '$$LIMA_VM'..."; \
		limactl stop "$$LIMA_VM" || true; \
		limactl delete "$$LIMA_VM" || true; \
	fi
