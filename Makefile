TEMPLATES_DIR := templates
OUTPUT_DIR := generated
MODEL_CONFIG := models.yaml

TEMPLATE_FILES := $(shell find $(TEMPLATES_DIR) -maxdepth 1 -type f)

MODEL_NAMES := $(shell yq '.[] | .name' $(MODEL_CONFIG))

ALL_OUTPUT_FILES := $(foreach name,$(MODEL_NAMES), \
                      $(patsubst $(TEMPLATES_DIR)/%,$(OUTPUT_DIR)/$(name)/%,$(TEMPLATE_FILES)))

# Docker Hub configuration
# Set DOCKERHUB_USERNAME as environment variable or pass it to make
# Example: export DOCKERHUB_USERNAME=yourusername
# Or: make docker-build DOCKERHUB_USERNAME=yourusername
DOCKERHUB_REPO ?= mobileclip
DOCKERHUB_TAG ?= latest
DOCKERHUB_USERNAME ?= weldawadyathink

.PHONY: dev generate list clean docker-build docker-push docker-build-push docker-login

dev:
  docker build -t fly-mobileclip-dev . && docker run --rm -it -p 8000:8000 fly-mobileclip-dev

deploy: generate
	@for name in $(MODEL_NAMES); do \
		echo "🔨 Fly deploy for $$name"; \
		cd $(OUTPUT_DIR)/$$name && fly deploy && cd ../..; \
	done
	@echo "✅ All models built successfully."

$(OUTPUT_DIR)/%/:
	@mkdir -p $@

generate: $(ALL_OUTPUT_FILES)
	@for name in $(MODEL_NAMES); do \
		cp -r common/* $(OUTPUT_DIR)/$$name; \
	done
	@echo "✅ All models generated successfully."

list:
	@echo "Discovered Models:"
	@$(foreach name,$(MODEL_NAMES),echo "  - $(name)";)
	@echo "Discovered Templates:"
	@$(foreach tpl,$(TEMPLATE_FILES),echo "  - $(notdir $(tpl))";)
	@echo "Will Generate:"
	@$(foreach file,$(ALL_OUTPUT_FILES),echo "  - $(file)";)

clean:
	@echo "🔥 Removing $(OUTPUT_DIR)..."
	@rm -rf $(OUTPUT_DIR)

docker-build: generate
	@if [ -z "$(DOCKERHUB_USERNAME)" ]; then \
		echo "❌ Error: DOCKERHUB_USERNAME is not set"; \
		echo "   Set it with: export DOCKERHUB_USERNAME=yourusername"; \
		echo "   Or pass it: make docker-build DOCKERHUB_USERNAME=yourusername"; \
		exit 1; \
	fi
	@for name in $(MODEL_NAMES); do \
		echo "🔨 Building Docker image for $$name..."; \
		IMAGE_NAME="$(DOCKERHUB_USERNAME)/$(DOCKERHUB_REPO):$$name-$(DOCKERHUB_TAG)"; \
		docker build -t $$IMAGE_NAME $(OUTPUT_DIR)/$$name; \
		echo "✅ Built $$IMAGE_NAME"; \
	done
	@echo "✅ All Docker images built successfully."

docker-push:
	@if [ -z "$(DOCKERHUB_USERNAME)" ]; then \
		echo "❌ Error: DOCKERHUB_USERNAME is not set"; \
		echo "   Set it with: export DOCKERHUB_USERNAME=yourusername"; \
		echo "   Or pass it: make docker-push DOCKERHUB_USERNAME=yourusername"; \
		exit 1; \
	fi
	@for name in $(MODEL_NAMES); do \
		echo "📤 Pushing Docker image for $$name..."; \
		IMAGE_NAME="$(DOCKERHUB_USERNAME)/$(DOCKERHUB_REPO):$$name-$(DOCKERHUB_TAG)"; \
		docker push $$IMAGE_NAME; \
		echo "✅ Pushed $$IMAGE_NAME"; \
	done
	@echo "✅ All Docker images pushed successfully."

docker-build-push: docker-build docker-push
	@echo "✅ All Docker images built and pushed successfully."

.SECONDEXPANSION:
$(ALL_OUTPUT_FILES): $(OUTPUT_DIR)/% : $$(TEMPLATES_DIR)/$$(notdir $$*) | $$(OUTPUT_DIR)/$$(dir $$*)
	$(eval MODEL_NAME := $(word 2,$(subst /, ,$@)))
	$(eval TEMPLATE_FILE_PATH := $(word 1,$^))

	@echo "🔨 Generating $@ from $(TEMPLATE_FILE_PATH)"

	@export $$(yq '.[] | select(.name == "$(MODEL_NAME)") | to_entries | .[] | .key + "=" + .value' models.yaml); \
	envsubst < "$(TEMPLATE_FILE_PATH)" > "$@"