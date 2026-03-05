(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(fn M.split-input
  [text]
  (let [out []]
    (each [_ tok (ipairs (vim.split (or text "") "%s+" {:trimempty true}))]
      (table.insert out tok))
    out))

(fn M.convert2regex-pattern
  [text]
  (table.concat (M.split-input text) "\\|"))

(fn M.assign-content
  [buf lines]
  (local view (vim.fn.winsaveview))
  (let [bo (. vim.bo buf)]
    (set (. bo :modifiable) true))
  (vim.api.nvim_buf_set_lines buf 0 -1 false lines)
  (let [bo (. vim.bo buf)]
    (set (. bo :modifiable) false))
  (vim.fn.winrestview view))

(fn M.escape-vim-pattern
  [text]
  (vim.fn.escape (or text "") "\\^$~.*[]"))

(fn M.query-is-lower
  [query]
  (= (string.lower (or query "")) (or query "")))

(fn M.buf-valid?
  [buf]
  (and buf (vim.api.nvim_buf_is_valid buf)))

(fn M.win-valid?
  [win]
  (and win (vim.api.nvim_win_is_valid win)))

(fn M.deepcopy
  [x]
  (vim.deepcopy x))

(fn M.clamp
  [n lo hi]
  (math.max lo (math.min hi n)))

(fn M.buf-lines
  [buf]
  (vim.api.nvim_buf_get_lines buf 0 -1 false))

(fn M.cursor
  []
  (vim.api.nvim_win_get_cursor 0))

(fn M.set-cursor
  [row col]
  (vim.api.nvim_win_set_cursor 0 [row (or col 0)]))

M
