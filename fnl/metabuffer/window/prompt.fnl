(local base (require :metabuffer.window.base))
(local M {})

(fn M.new [nvim]
  (vim.cmd "botright new")
  (base.new nvim (vim.api.nvim_get_current_win) [] {}))

M
