(local base (require :metabuffer.window.base))
(local M {})

(fn M.new [nvim opts]
  (let [cfg (or opts {})
        height (or cfg.height 3)]
    (vim.cmd (.. "botright " (tostring height) "new"))
    (let [win (vim.api.nvim_get_current_win)
          buf (vim.api.nvim_get_current_buf)
          self (base.new nvim win [] {})]
      (tset (. vim.bo buf) :buftype "nofile")
      (tset (. vim.bo buf) :bufhidden "wipe")
      (tset (. vim.bo buf) :swapfile false)
      (tset (. vim.bo buf) :modifiable true)
      (tset (. vim.bo buf) :filetype "metabufferprompt")
      ;; Common nvim-cmp convention: buffer-local opt-out.
      (tset (. vim.b buf) :cmp_enabled false)
      (tset (. vim.wo win) :number false)
      (tset (. vim.wo win) :relativenumber false)
      (tset (. vim.wo win) :signcolumn "no")
      (tset (. vim.wo win) :foldcolumn "0")
      (tset (. vim.wo win) :spell false)
      (set self.buffer buf)
      self)))

M
