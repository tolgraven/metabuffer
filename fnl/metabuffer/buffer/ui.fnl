(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local base (require :metabuffer.buffer.base))
(local M {})

(fn role-buffer-name
  [role]
  "Build a stable name for hidden UI support buffers."
  (let [txt (or role "Ui")
        first (string.sub txt 1 1)
        rest (string.sub txt 2)]
    (.. "[Metabuffer "
        (string.upper first)
        rest
        "]")))

(fn M.new
  [nvim parent role]
  "Public API: M.new."
  (let [self (base.new nvim {:model parent.buffer :name (or role "ui")
                             :default-opts {:buflisted false :bufhidden "hide" :buftype "nofile" :swapfile false}})]
    (set self.parent parent)
    (self.set-name (role-buffer-name role))

    (fn self.update
      []
      (let [out []]
        (each [_ src (ipairs self.parent.indices)]
          (table.insert out (string.format "%d\t%s" src self.parent.name)))
        (let [bo (. vim.bo self.buffer)]
          (set (. bo :modifiable) true))
        (vim.api.nvim_buf_set_lines self.buffer 0 -1 false out)
        (let [bo (. vim.bo self.buffer)]
          (set (. bo :modifiable) false))))

    self))

M
