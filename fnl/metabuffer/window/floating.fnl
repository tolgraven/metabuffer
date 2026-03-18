(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local window-base (require :metabuffer.window.base))

(local M {})

(fn M.new
  [nvim buf opts]
  "Create a minimal floating window wrapper for auxiliary Meta UI."
  (let [{: width : height : col : row : relative : anchor : win : winblend} (or opts {})
        lines (- vim.o.lines 2)
        winblend (or winblend vim.g.meta_float_winblend 13)
        cfg {:relative (or relative "editor")
             :width (or width 20)
             :height (or height lines)
             :col (or col 100)
             :row (or row 1)
             :anchor (or anchor "NE")
             :style "minimal"}
        _ (when win
            (set (. cfg :win) win))
        win (vim.api.nvim_open_win buf false cfg)]
    (let [wo (. vim.wo win)]
      (set (. wo :winblend) winblend))
    (window-base.new nvim win [] {})))

M
