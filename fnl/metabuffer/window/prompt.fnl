(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local base (require :metabuffer.window.base))
(local M {})

(fn M.new
  [nvim opts]
  "Create the bottom prompt window used by Meta interactive input."
  (let [cfg (or opts {})
        height (or cfg.height 3)]
    (vim.cmd (.. "botright " (tostring height) "new"))
    (let [win (vim.api.nvim_get_current_win)
          buf (vim.api.nvim_get_current_buf)
          self (base.new nvim win [] {})]
      (pcall vim.api.nvim_win_set_height win height)
      (let [bo (. vim.bo buf)]
        (set (. bo :buftype) "nofile")
        (set (. bo :bufhidden) "wipe")
        (set (. bo :swapfile) false)
        (set (. bo :modifiable) true)
        (set (. bo :filetype) "metabufferprompt"))
      ;; Common nvim-cmp convention: buffer-local opt-out.
      (let [b (. vim.b buf)
            wo (. vim.wo win)]
        (set (. b :cmp_enabled) false)
        (set (. wo :winfixheight) true)
        (set (. wo :number) false)
        (set (. wo :relativenumber) false)
        (set (. wo :signcolumn) "no")
        (set (. wo :foldcolumn) "0")
        (set (. wo :spell) false))
      (set self.buffer buf)
      self)))

M
