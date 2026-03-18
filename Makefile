.PHONY: all compile check check-fnl check-lua test test-profile

XDG_STATE_HOME := /tmp
XDG_DATA_HOME := /tmp
XDG_CACHE_HOME := /tmp
NVIM_APPNAME := metabuffer-make
NVIM_ENV = XDG_STATE_HOME="$(XDG_STATE_HOME)" XDG_DATA_HOME="$(XDG_DATA_HOME)" XDG_CACHE_HOME="$(XDG_CACHE_HOME)" NVIM_APPNAME="$(NVIM_APPNAME)"
PRIMARY_GOAL := $(firstword $(MAKECMDGOALS))
FILE_ARGS ?= $(filter-out $(PRIMARY_GOAL),$(MAKECMDGOALS))
FNL_CHECK_ARGS = $(if $(strip $(filter %.fnl,$(FILE_ARGS))),$(filter %.fnl,$(FILE_ARGS)),$$(find fnl -name "*.fnl"))
LUA_CHECK_ARGS = $(if $(strip $(filter %.lua,$(FILE_ARGS))),$(filter %.lua,$(FILE_ARGS)),.)

# Default target: compile fennel to lua
all: compile

compile:
	@echo "[make] compiling fennel..."
	$(NVIM_ENV) ./scripts/compile-fennel.sh

# Run all linters
check: check-fnl check-lua
	@:

# Run linter on all fennel files
check-fnl:
	@echo "[make] checking fennel-ls..."
	$(NVIM_ENV) fennel-ls --lint $(FNL_CHECK_ARGS)

# Run linter on all generated lua files (using root to pick up .luarc.json)
check-lua:
	@echo "[make] checking lua-language-server..."
	lua-language-server --check $(LUA_CHECK_ARGS)

# Run tests. Use 'make test' for all tests or 'make test tests/some_test.lua' for specific ones.
test:
	@echo "[make] running tests..."
	$(NVIM_ENV) ./scripts/test-mini.sh $(FILE_ARGS)

test-profile:
	@echo "[make] running tests with profiling..."
	$(NVIM_ENV) ./scripts/test-mini.sh --profile $(FILE_ARGS)

# Catch-all target to allow passing arguments to 'make test'
%:
	@:
