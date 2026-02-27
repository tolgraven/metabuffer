(local handle (require :metabuffer.handle))
(local M {})

(fn M.new [nvim win opts-to-stash opts]
  (local self (handle.new nvim win win opts-to-stash opts))
  (set self.window win)

  (fn self.set-statusline [text]
    (tset (. vim.wo self.window) :statusline text))

  (fn self.set-cursor [row col]
    (vim.api.nvim_win_set_cursor self.window [row (or col 0)]))

  (fn self.set-row [row addjump]
    (if addjump
      (vim.cmd (.. ":" (tostring row)))
      (self.set-cursor row)))

  (fn self.set-col [col]
    (let [cur (vim.api.nvim_win_get_cursor self.window)]
      (self.set-cursor (. cur 1) col)))

  (fn self.set-buf [buf]
    (vim.api.nvim_win_set_buf self.window buf))

  self)

M
