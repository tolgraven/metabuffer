(local window-base (require :metabuffer.window.base))

(local M {})

(fn M.new [nvim buf opts]
  (local lines (- vim.o.lines 2))
  (local cfg {:relative "editor"
              :width (or (and opts opts.width) 20)
              :height (or (and opts opts.height) lines)
              :col (or (and opts opts.col) 100)
              :row (or (and opts opts.row) 1)
              :anchor "NE"
              :style "minimal"})
  (local win (vim.api.nvim_open_win buf false cfg))
  (tset (. vim.wo win) :winblend 25)
  (window-base.new nvim win [] {}))

M
