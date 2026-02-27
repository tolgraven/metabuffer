#!/usr/bin/env sh
set -eu

if ! command -v nvim >/dev/null 2>&1; then
  echo "neovim not found" >&2
  exit 1
fi

# Keep vendored runtime code (for example lua/metabuffer/nfnl) intact.
mkdir -p lua plugin

NVIM_LOG_FILE="${NVIM_LOG_FILE:-/dev/null}" \
nvim --headless -u NONE -n \
  -i NONE \
  --cmd "set runtimepath^=." \
  -c "lua \
local function read_untrusted(path) \
  local f = io.open(path, 'rb') \
  if not f then return nil end \
  local s = f:read('*a') \
  f:close() \
  return s \
end \
if vim.secure and vim.secure.read then vim.secure.read = read_untrusted end \
local ok, err = pcall(function() \
  require('metabuffer.nfnl.api')['compile-all-files'](vim.fn.getcwd()) \
end) \
if not ok then \
  vim.api.nvim_err_writeln(err) \
  vim.cmd('cq') \
end" \
  -c "qa"
