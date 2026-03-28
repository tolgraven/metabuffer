.PHONY: all compile full check check-fnl check-lua test test-then-all test-profile

XDG_STATE_HOME := /tmp
XDG_DATA_HOME := /tmp
XDG_CACHE_HOME := /tmp
NVIM_APPNAME := metabuffer-make
NVIM_ENV = XDG_STATE_HOME="$(XDG_STATE_HOME)" XDG_DATA_HOME="$(XDG_DATA_HOME)" XDG_CACHE_HOME="$(XDG_CACHE_HOME)" NVIM_APPNAME="$(NVIM_APPNAME)"
QUIET ?= 0
PRIMARY_GOAL := $(firstword $(MAKECMDGOALS))
RAW_ARGS ?= $(filter-out $(PRIMARY_GOAL),$(MAKECMDGOALS))
FILE_ARGS ?= $(filter-out --,$(RAW_ARGS))
FNL_CHECK_ARGS = $(if $(strip $(filter %.fnl,$(FILE_ARGS))),$(filter %.fnl,$(FILE_ARGS)),$$(find fnl -name "*.fnl"))
LUA_CHECK_ARGS = $(if $(strip $(filter %.lua,$(FILE_ARGS))),$(filter %.lua,$(FILE_ARGS)),.)

# Default target: compile fennel to lua
all: compile

compile:
	@if [ "$(QUIET)" != "1" ]; then echo "[make] compiling fennel..."; fi
	@META_COMPILE_QUIET="$(QUIET)" $(NVIM_ENV) ./scripts/compile-fennel.sh

# Full local verification: lint fennel, then compile+test via `make test`.
full:
	@$(MAKE) --no-print-directory QUIET=1 check-fnl $(if $(strip $(FILE_ARGS)),-- $(FILE_ARGS),)
	@$(MAKE) --no-print-directory QUIET=1 test $(if $(strip $(FILE_ARGS)),-- $(FILE_ARGS),)
	@:

# Run all linters
check: check-fnl check-lua
	@:

# Run linter on all fennel files
check-fnl:
	@if [ "$(QUIET)" != "1" ]; then echo "[make] checking fennel-ls..."; fi
	@$(NVIM_ENV) fennel-ls --lint $(FNL_CHECK_ARGS)

# Run linter on all generated lua files (using root to pick up .luarc.json)
check-lua:
	@if [ "$(QUIET)" != "1" ]; then echo "[make] checking lua-language-server..."; fi
	@lua-language-server --check $(LUA_CHECK_ARGS)

# Run tests. Use 'make test' for all, 'make test -- file.lua' for one, TEST_JOBS=N for parallelism.
test: compile
	@if [ "$(QUIET)" != "1" ]; then echo "[make] running tests..."; fi
	@TEST_RUNNER_QUIET="$(QUIET)" TEST_FILE_TIMEOUT_MS="$${TEST_FILE_TIMEOUT_MS:-30000}" $(NVIM_ENV) ./scripts/test-mini.sh $(FILE_ARGS)

test-then-all: compile
	@if [ -z "$(strip $(FILE_ARGS))" ]; then \
		echo "error: make test-then-all requires at least one test selector or file" >&2; \
		exit 2; \
	fi
	@echo "[make] running selected tests first..."
	TEST_FILE_TIMEOUT_MS="$${TEST_FILE_TIMEOUT_MS:-30000}" TEST_JOBS="$${TEST_JOBS:-1}" $(NVIM_ENV) ./scripts/test-mini.sh --no-smoke $(FILE_ARGS)
	@echo "[make] selected tests passed; running full suite..."
	TEST_FILE_TIMEOUT_MS="$${TEST_FILE_TIMEOUT_MS:-30000}" $(NVIM_ENV) ./scripts/test-mini.sh

test-profile: compile
	@echo "[make] running tests with profiling..."
	TEST_FILE_TIMEOUT_MS="$${TEST_FILE_TIMEOUT_MS:-120000}" $(NVIM_ENV) ./scripts/test-mini.sh --profile $(FILE_ARGS)

# Catch-all target to allow passing arguments to 'make test'
%:
	@:
