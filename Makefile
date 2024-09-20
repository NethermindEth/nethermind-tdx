DOCKER?=docker
ENV_FILE?=.env
BUILD_CONFIG?=dev

docker_envs = $()

ifneq (,$(wildcard ./$(ENV_FILE)))
# Local build
    include $(ENV_FILE)
    export

# Docker build
	docker_envs = $(foreach var,$(shell grep -v '^#' $(ENV_FILE) | grep -v '^\s*$$'),--env $(var))
endif

ifeq ($(DEBUG_TWEAKS_ENABLED),false)
    BUILD_CONFIG=release
endif

export BUILD_DIR=build/$(BUILD_CONFIG)
export ARTIFACTS_DIR=artifacts/$(BUILD_CONFIG)

.PHONY: setup-dirs
setup-dirs:
	mkdir -p $(BUILD_DIR)
	mkdir -p $(ARTIFACTS_DIR)

.PHONY: azure-image-docker
azure-image-docker: setup-dirs generate-patches tdx-poky
	sudo chmod 0777 $(BUILD_DIR)
	sudo chmod -R 0777 artifacts
	$(DOCKER) run \
		-u root \
		-it \
		--rm \
		$(call docker_envs) \
		--env BUILD_DIR=$(BUILD_DIR) \
		--env ARTIFACTS_DIR=$(ARTIFACTS_DIR) \
		-v $(CURDIR)/artifacts:/artifacts \
		-v $(CURDIR)/build:/build \
		tdx-poky
	sudo chmod 0755 $(BUILD_DIR)
	sudo chmod -R 0755 artifacts

.PHONY: tdx-poky
tdx-poky:
	$(DOCKER) build -t tdx-poky .

.PHONY: azure-image
azure-image: setup-dirs generate-patches
	./scripts/build.sh && \
	./scripts/measure.sh

.PHONY: run-local
run-local:
	./scripts/run_local.sh

.PHONY: deploy-azure
deploy-azure:
	./scripts/deploy_azure.sh

.PHONY: deploy-azure-non-tdx
deploy-azure-non-tdx:
	./scripts/deploy_azure_non_tdx.sh

.PHONY: start-swtpm
start-swtpm:
	./scripts/start_swtpm.sh

.PHONY: start-proxy
start-proxy:
	./scripts/start_proxy.sh

.PHONY: setup-local
setup-local:
	./scripts/setup_yocto.sh && \
	./scripts/setup_measured_boot.sh

.PHONY: setup-proxy
setup-proxy:
	./scripts/setup_proxy.sh

.PHONY: setup-git
setup-git:
	./scripts/setup_git.sh

.PHONY: setup-docker
setup-docker:
	./scripts/setup_docker.sh

.PHONY: setup-lighthouse
setup-lighthouse:
	./scripts/setup_lighthouse.sh

.PHONY: setup-go
setup-go:
	./scripts/setup_go.sh

.PHONY: generate-patches
generate-patches:
	./patches/generate_patches.sh
