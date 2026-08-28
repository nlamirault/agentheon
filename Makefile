# SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
# SPDX-License-Identifier: Apache-2.0

BANNER = P R O J E C T  N A M E

SHELL = /bin/bash -o pipefail

DIR = $(shell pwd)

WEB_DIR = web
PNPM = pnpm --dir $(WEB_DIR)

# Colors for terminal output
NO_COLOR=\033[0m
OK_COLOR=\033[32;01m
ERROR_COLOR=\033[31;01m
WARN_COLOR=\033[33;01m
INFO_COLOR=\033[36m
WHITE_COLOR=\033[1m
MAKE_COLOR=\033[33;01m%-20s\033[0m

.DEFAULT_GOAL := help

# Define common messages
# OK=[✅]
# KO=[🔴]
# WARN=[⚠️]
# INFO=[🔵]
OK=[🟢]
KO=[🔴]
WARN=[🟠]
INFO=[🔵]


.PHONY: help
help:
	@echo -e "$(OK_COLOR)      $(BANNER)$(NO_COLOR)"
	@echo "------------------------------------------------------------------"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make ${INFO_COLOR}<target>${NO_COLOR}\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  ${INFO_COLOR}%-25s${NO_COLOR} %s\n", $$1, $$2 } /^##@/ { printf "\n${WHITE_COLOR}%s${NO_COLOR}\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""

guard-%:
	@if [ "${${*}}" = "" ]; then \
		echo -e "$(ERROR_COLOR)Environment variable $* not set$(NO_COLOR)"; \
		exit 1; \
	fi

check-%:
	@if $$(hash $* 2> /dev/null); then \
		echo -e "$(OK_COLOR)$(OK)$(NO_COLOR) $*"; \
	else \
		echo -e "$(ERROR_COLOR)$(KO)$(NO_COLOR) $*"; \
	fi

##@ Hermes

.PHONY: hermes-profiles
hermes-profiles: check-hermes ## Generate a Hermes agent profile for each agent (agents/*.md)
	@echo -e "$(INFO)$(INFO_COLOR)[Hermes] Generating profiles $(NO_COLOR)"
	@./hack/gen-hermes-profiles.sh

.PHONY: install
install: ## Install all agents into $$HERMES_HOME (file-drop; no hermes CLI required)
	@echo -e "$(INFO)$(INFO_COLOR)[Agentheon] Installing profiles $(NO_COLOR)"
	@./agentheon.sh install

.PHONY: install-dry-run
install-dry-run: ## Preview what agentheon.sh install would write (no changes)
	@./agentheon.sh install --dry-run

##@ Website

.PHONY: web-install
web-install: check-pnpm ## Install website dependencies (pnpm)
	@echo -e "$(INFO)$(INFO_COLOR)[Website] Installing dependencies $(NO_COLOR)"
	@$(PNPM) install

.PHONY: web-dev
web-dev: check-pnpm ## Start the Astro dev server
	@echo -e "$(INFO)$(INFO_COLOR)[Website] Starting dev server $(NO_COLOR)"
	@$(PNPM) run dev

.PHONY: web-build
web-build: check-pnpm ## Build the website (static output in web/dist)
	@echo -e "$(INFO)$(INFO_COLOR)[Website] Building $(NO_COLOR)"
	@$(PNPM) run build

.PHONY: web-preview
web-preview: check-pnpm ## Preview the production build locally
	@echo -e "$(INFO)$(INFO_COLOR)[Website] Previewing build $(NO_COLOR)"
	@$(PNPM) run preview

.PHONY: web-clean
web-clean: ## Remove website build artifacts (dist, .astro)
	@echo -e "$(INFO)$(INFO_COLOR)[Website] Cleaning artifacts $(NO_COLOR)"
	@rm -rf $(WEB_DIR)/dist $(WEB_DIR)/.astro

##@ Misc

.PHONY: clean
clean: web-clean ## Clean project
	@echo -e "$(INFO)$(INFO_COLOR)[Clean] Processing $(NO_COLOR)"
