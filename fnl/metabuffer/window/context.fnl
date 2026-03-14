(local M {})

(fn close-window!
  [session]
  (when (and session.context-win (vim.api.nvim_win_is_valid session.context-win))
    (pcall vim.api.nvim_win_close session.context-win true))
  (set session.context-win nil)
  (set session.context-buf nil))

(fn M.new
  [_opts]
  {:update! close-window!
   :close-window! close-window!})

M
