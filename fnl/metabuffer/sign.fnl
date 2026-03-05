(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(fn M.buf-has-signs?
  [buf]
  "Public API: M.buf-has-signs?."
  (let [out (vim.fn.execute (.. "sign place group=* buffer=" buf))]
    (> (# out) 2)))

(fn M.refresh-dummy
  [buf]
  "Public API: M.refresh-dummy."
  (pcall vim.cmd "sign define MetaDummy")
  (pcall vim.cmd (.. "sign unplace 9999 buffer=" buf))
  (pcall vim.cmd (.. "sign place 9999 line=1 name=MetaDummy buffer=" buf)))

M
