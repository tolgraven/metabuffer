(local router (require :metabuffer.router))

(local M {})

(fn M.setup []
  (vim.api.nvim_create_user_command "Meta"
    (fn [args] (router.entry_start args.args args.bang))
    {:nargs "?" :bang true})

  (vim.api.nvim_create_user_command "MetaResume"
    (fn [args] (router.entry_resume args.args))
    {:nargs "?"})

  (vim.api.nvim_create_user_command "MetaCursorWord"
    (fn [] (router.entry_cursor_word false))
    {:nargs 0})

  (vim.api.nvim_create_user_command "MetaResumeCursorWord"
    (fn [] (router.entry_cursor_word true))
    {:nargs 0})

  (vim.api.nvim_create_user_command "MetaSync"
    (fn [args] (router.entry_sync args.args))
    {:nargs "?"})

  (vim.api.nvim_create_user_command "MetaPush"
    (fn [] (router.entry_push))
    {:nargs 0})

  true)

M
