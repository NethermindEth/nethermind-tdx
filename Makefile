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

.PHONY: all build build-dev setup measure clean check-perms check-module submodules

# Default target
all: build

# Pull / update vendored submodules (currently: raiko2 at services/raiko2/src).
submodules: ## Initialize and update git submodules (raiko2)
	@git submodule update --init --recursive --remote services/raiko2/src

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
	$(WRAPPER) mkosi --force --image-id $$image_id --profile=$$profiles -I tdx-prover.conf


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
