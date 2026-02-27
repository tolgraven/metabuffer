(local base (require :metabuffer.buffer.base))

(local M {})

(fn M.new [nvim parent role]
  (local self (base.new nvim {:model parent.buffer :name (or role "ui")
                              :default-opts {:buflisted false :bufhidden "hide" :buftype "nofile"}}))
  (set self.parent parent)

  (fn self.update []
    (local out [])
    (each [_ src (ipairs self.parent.indices)]
      (table.insert out (string.format "%d\t%s" src self.parent.name)))
    (tset (. vim.bo self.buffer) :modifiable true)
    (vim.api.nvim_buf_set_lines self.buffer 0 -1 false out)
    (tset (. vim.bo self.buffer) :modifiable false))

  self)

M
