#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT_DIR"

nvim --headless -u NONE -n -i NONE \
  --cmd "set runtimepath^=." \
  -c "lua \
local ok, err = pcall(function() \
  require('metabuffer').setup() \
  vim.cmd('enew') \
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {'alpha', 'beta', 'gamma'}) \
  require('metabuffer.router').entry_start('', true) \
  require('metabuffer.router').finish('cancel', vim.api.nvim_get_current_buf()) \
end) \
if not ok then \
  vim.api.nvim_err_writeln(err) \
  vim.cmd('cq') \
end" \
  -c "qa!"

