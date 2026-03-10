#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT_DIR"

nvim --headless -u tests/minimal_init.lua -n -i NONE \
  -c "lua MiniTest.run_file('tests/prompt_filter_spec.lua')" \
  -c "qa!"
