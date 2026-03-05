(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(fn M.split-input
  [text]
  "Public API: M.split-input."
  (let [out []]
    (each [_ tok (ipairs (vim.split (or text "") "%s+" {:trimempty true}))]
      (table.insert out tok))
    out))

(fn M.convert2regex-pattern
  [text]
  "Public API: M.convert2regex-pattern."
  (table.concat (M.split-input text) "\\|"))

(fn M.assign-content
  [buf lines]
  "Public API: M.assign-content."
  (let [view (vim.fn.winsaveview)]
    (let [bo (. vim.bo buf)]
      (set (. bo :modifiable) true))
    (vim.api.nvim_buf_set_lines buf 0 -1 false lines)
    (let [bo (. vim.bo buf)]
      (set (. bo :modifiable) false))
    (vim.fn.winrestview view)))

(fn M.escape-vim-pattern
  [text]
  "Public API: M.escape-vim-pattern."
  (vim.fn.escape (or text "") "\\^$~.*[]"))

(fn M.query-is-lower
  [query]
  "Public API: M.query-is-lower."
  (= (string.lower (or query "")) (or query "")))

(fn M.buf-valid?
  [buf]
  "Public API: M.buf-valid?."
  (and buf (vim.api.nvim_buf_is_valid buf)))

(fn M.win-valid?
  [win]
  "Public API: M.win-valid?."
  (and win (vim.api.nvim_win_is_valid win)))

(fn M.deepcopy
  [x]
  "Public API: M.deepcopy."
  (vim.deepcopy x))

(fn M.clamp
  [n lo hi]
  "Public API: M.clamp."
  (math.max lo (math.min hi n)))

(fn M.buf-lines
  [buf]
  "Public API: M.buf-lines."
  (vim.api.nvim_buf_get_lines buf 0 -1 false))

(fn M.cursor
  []
  "Public API: M.cursor."
  (vim.api.nvim_win_get_cursor 0))

(fn M.set-cursor
  [row col]
  "Public API: M.set-cursor."
  (vim.api.nvim_win_set_cursor 0 [row (or col 0)]))

M
