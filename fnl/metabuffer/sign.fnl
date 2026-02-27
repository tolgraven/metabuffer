(local M {})

(fn M.buf-has-signs? [buf]
  (local out (vim.fn.execute (.. "sign place group=* buffer=" buf)))
  (> (# out) 2))

(fn M.refresh-dummy [buf]
  (pcall vim.cmd (.. "sign define MetaDummy"))
  (pcall vim.cmd (.. "sign unplace 9999 buffer=" buf))
  (pcall vim.cmd (.. "sign place 9999 line=1 name=MetaDummy buffer=" buf)))

M
