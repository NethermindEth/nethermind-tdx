DOCKER?=docker
ENV_FILE?=.env

ifneq (,$(wildcard ./$(ENV_FILE)))
    include $(ENV_FILE)
    export
endif

.PHONY: azure-image-docker
azure-image-docker: generate-patches tdx-poky
	mkdir -p build && chmod 0777 ./build
	mkdir -p reproducible-build/artifacts && chmod 0777 reproducible-build/artifacts
	$(DOCKER) run -u root --rm --env-file $(ENV_FILE) -it -v $(CURDIR)/artifacts:/artifacts -v $(CURDIR)/build:/build tdx-poky
	chmod 0755 build reproducible-build/artifacts

.PHONY: tdx-poky
tdx-poky:
	$(DOCKER) build -t tdx-poky reproducible-build/

.PHONY: azure-image
azure-image: generate-patches
	./scripts/build.sh

.PHONY: setup-local
setup-local:
	./scripts/setup_yocto.sh

.PHONY: setup-git
setup-git:
	./scripts/setup_git.sh

.PHONY: setup-docker
setup-docker:
	./scripts/setup_docker.sh

.PHONY: generate-patches
generate-patches:
	./patches/generate_patches.sh
