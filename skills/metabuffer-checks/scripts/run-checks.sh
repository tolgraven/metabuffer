#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../.." && pwd)"

usage() {
  cat <<'EOF'
Usage:
  run-checks.sh [--with-headless] [--profile] [project-dir]

Flags:
  --with-headless  Also run a basic headless nvim setup + Meta/Meta! invocation check.
  --profile        Write basic profiling artifacts for startup and Meta/Meta! timings.
  -h, --help       Show this help.
EOF
}

with_headless=0
with_profile=0
target_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-headless)
      with_headless=1
      shift
      ;;
    --profile)
      with_profile=1
      with_headless=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "[metabuffer-checks] unknown flag: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "$target_dir" ]]; then
        echo "[metabuffer-checks] unexpected extra arg: $1" >&2
        usage >&2
        exit 1
      fi
      target_dir="$1"
      shift
      ;;
  esac
done

target_dir="${target_dir:-$repo_root}"

if [[ -d "$target_dir/metabuffer" && -f "$target_dir/metabuffer/scripts/compile-fennel.sh" ]]; then
  target_dir="$target_dir/metabuffer"
fi

if [[ ! -f "$target_dir/scripts/watch-fennel.sh" || ! -f "$target_dir/scripts/compile-fennel.sh" || ! -f "$target_dir/scripts/smoke-meta.sh" ]]; then
  echo "[metabuffer-checks] could not find required scripts under: $target_dir" >&2
  echo "Expected: scripts/watch-fennel.sh, scripts/compile-fennel.sh, scripts/smoke-meta.sh" >&2
  exit 1
fi

cd "$target_dir"

run_headless_meta_check() {
  echo "[metabuffer-checks] headless: nvim setup + Meta + Meta!"
  nvim --headless -u NONE -n -i NONE \
    --cmd "set runtimepath^=." \
    -c "lua \
local ok, err = pcall(function() \
  require('metabuffer').setup() \
  local r = require('metabuffer.router') \
  vim.cmd('enew') \
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {'alpha', 'beta', 'gamma', 'Meta status'}) \
  r.entry_start('', false) \
  r.finish('cancel', vim.api.nvim_get_current_buf()) \
  r.entry_start('', true) \
  r.finish('cancel', vim.api.nvim_get_current_buf()) \
end) \
if not ok then \
  vim.api.nvim_err_writeln(err) \
  vim.cmd('cq') \
end" \
    -c "qa!"
}

run_basic_profile() {
  local profile_dir
  profile_dir="$target_dir/.cache/metabuffer-checks"
  mkdir -p "$profile_dir"

  echo "[metabuffer-checks] profile: startup -> $profile_dir/startuptime.log"
  nvim --headless -u NONE -n -i NONE --startuptime "$profile_dir/startuptime.log" +qa >/dev/null 2>&1

  echo "[metabuffer-checks] profile: Meta timings -> $profile_dir/meta-profile.log"
  PROFILE_OUT="$profile_dir/meta-profile.log" \
    nvim --headless -u NONE -n -i NONE \
      --cmd "set runtimepath^=." \
      -c "lua \
local out = os.getenv('PROFILE_OUT') \
local function ms_from(start_ns) \
  return ((vim.loop.hrtime() - start_ns) / 1000000.0) \
end \
local lines = {} \
local ok, err = pcall(function() \
  local t0 = vim.loop.hrtime() \
  require('metabuffer').setup() \
  table.insert(lines, string.format('setup_ms=%.3f', ms_from(t0))) \
  local r = require('metabuffer.router') \
  vim.cmd('enew') \
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {'alpha', 'beta', 'gamma', 'Meta status'}) \
  local t1 = vim.loop.hrtime() \
  r.entry_start('', false) \
  r.finish('cancel', vim.api.nvim_get_current_buf()) \
  table.insert(lines, string.format('meta_ms=%.3f', ms_from(t1))) \
  local t2 = vim.loop.hrtime() \
  r.entry_start('', true) \
  r.finish('cancel', vim.api.nvim_get_current_buf()) \
  table.insert(lines, string.format('meta_bang_ms=%.3f', ms_from(t2))) \
end) \
if not ok then \
  table.insert(lines, 'error=' .. tostring(err)) \
  vim.api.nvim_err_writeln(err) \
  vim.fn.writefile(lines, out) \
  vim.cmd('cq') \
end \
vim.fn.writefile(lines, out)" \
      -c "qa!"

  echo "[metabuffer-checks] profile written:"
  echo "  - $profile_dir/startuptime.log"
  echo "  - $profile_dir/meta-profile.log"
}

echo "[metabuffer-checks] lint: ./scripts/watch-fennel.sh --once"
./scripts/watch-fennel.sh --once

echo "[metabuffer-checks] compile: ./scripts/compile-fennel.sh"
./scripts/compile-fennel.sh

echo "[metabuffer-checks] smoke: ./scripts/smoke-meta.sh"
./scripts/smoke-meta.sh

if [[ "$with_headless" -eq 1 ]]; then
  run_headless_meta_check
fi

if [[ "$with_profile" -eq 1 ]]; then
  run_basic_profile
fi

echo "[metabuffer-checks] all checks passed"
