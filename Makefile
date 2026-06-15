# --- Configuration ---------------------------------------------------------
BLUE  := \033[36m
BOLD  := \033[1m
RESET := \033[0m

CONF  := nrweb.conf
JEMDOC_SRC := $(shell find . -name '*.jemdoc' -type f | sort | sed 's|^\./||')
PREVIEW_HOST := 127.0.0.1
PREVIEW_PORT := 8001

.DEFAULT_GOAL := help

# --- Helpers (auto-install if missing) ------------------------------------
ensure = @command -v $(1) >/dev/null 2>&1 || \
	{ printf "$(BLUE)$(1) not found, installing...$(RESET)\n" && $(2); }

# --- Targets --------------------------------------------------------------
.PHONY: install jemdoc update preview clean help

install: ## install all dependencies (requires Rust/Cargo)
	@command -v cargo >/dev/null 2>&1 || { printf "cargo not found, install Rust first: https://rustup.rs\n"; exit 1; }
	@printf "$(BLUE)Installing jemdoc-rs...$(RESET)\n"
	@cargo install jemdoc-rs
	@printf "$(BLUE)Installing static-web-server...$(RESET)\n"
	@cargo install static-web-server

jemdoc: ## generate all jemdoc pages
	$(call ensure,jemdoc-rs,cargo install jemdoc-rs)
	@printf "$(BLUE)Generating jemdoc webpage...$(RESET)\n"
	@jemdoc-rs -c $(CONF) $(JEMDOC_SRC)

update: ## compile only new or modified jemdoc files
	$(call ensure,jemdoc-rs,cargo install jemdoc-rs)
	@git add $(JEMDOC_SRC)
	@for f in $$({ git diff --name-only HEAD -- '*.jemdoc'; git diff --cached --name-only --diff-filter=A -- '*.jemdoc'; } | sort -u) ; do \
		if [ -f "$$f" ]; then \
			printf "$(BLUE)Compiling $$f...$(RESET)\n"; \
			jemdoc-rs -c $(CONF) "$$f"; \
		fi; \
	done
	@git reset -q

preview: ## preview the webpage locally
	$(call ensure,static-web-server,cargo install static-web-server)
	@printf "$(BLUE)Starting local web server on http://$(PREVIEW_HOST):$(PREVIEW_PORT)...$(RESET)\n"
	@static-web-server --host $(PREVIEW_HOST) --port $(PREVIEW_PORT) --root . --redirect-trailing-slash true & \
	pid=$$!; \
	trap 'printf "\n$(BLUE)Local web server stopped.$(RESET)\n"; kill $$pid 2>/dev/null; wait $$pid 2>/dev/null; exit 130' INT TERM; \
	wait $$pid

clean: ## clean generated files and directories
	@printf "$(BLUE)Cleaning project...$(RESET)\n"
	@git clean -d -X -f

help: ## display this help message
	@printf "$(BOLD)Usage:$(RESET)\n"
	@printf "  make $(BLUE)<target>$(RESET)\n\n"
	@printf "$(BOLD)Targets:$(RESET)\n"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(BLUE)%-10s$(RESET) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
