TEMPLATES_DIR := templates
OUTPUT_DIR := generated
MODEL_CONFIG := models.yaml

TEMPLATE_FILES := $(shell find $(TEMPLATES_DIR) -maxdepth 1 -type f)

MODEL_NAMES := $(shell yq '.[] | .name' $(MODEL_CONFIG))

ALL_OUTPUT_FILES := $(foreach name,$(MODEL_NAMES), \
                      $(patsubst $(TEMPLATES_DIR)/%,$(OUTPUT_DIR)/$(name)/%,$(TEMPLATE_FILES)))

.PHONY: dev generate list clean

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

.SECONDEXPANSION:
$(ALL_OUTPUT_FILES): $(OUTPUT_DIR)/% : $$(TEMPLATES_DIR)/$$(notdir $$*) | $$(OUTPUT_DIR)/$$(dir $$*)
	$(eval MODEL_NAME := $(word 2,$(subst /, ,$@)))
	$(eval TEMPLATE_FILE_PATH := $(word 1,$^))

	@echo "🔨 Generating $@ from $(TEMPLATE_FILE_PATH)"

	@export $$(yq '.[] | select(.name == "$(MODEL_NAME)") | to_entries | .[] | .key + "=" + .value' models.yaml); \
	envsubst < "$(TEMPLATE_FILE_PATH)" > "$@"