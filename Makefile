.PHONY: all compile check check-fnl check-lua test

# Default target: compile fennel to lua
all: compile

compile:
	@echo "[make] compiling fennel..."
	./scripts/compile-fennel.sh

# Run all linters
check: check-fnl check-lua

# Run linter on all fennel files
check-fnl:
	@echo "[make] checking fennel-ls..."
	fennel-ls --lint $$(find fnl -name "*.fnl")

# Run linter on all generated lua files (using root to pick up .luarc.json)
check-lua:
	@echo "[make] checking lua-language-server..."
	lua-language-server --check .

# Run tests. Use 'make test' for all tests or 'make test tests/some_test.lua' for specific ones.
test:
	@echo "[make] running tests..."
	./scripts/test-mini.sh $(filter-out $@,$(MAKECMDGOALS))

# Catch-all target to allow passing arguments to 'make test'
%:
	@:
