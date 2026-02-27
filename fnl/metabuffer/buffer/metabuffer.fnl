(local base (require :metabuffer.buffer.base))
(local ui (require :metabuffer.buffer.ui))

(local M {})

(set M.default-opts {:buflisted false :bufhidden "hide" :buftype "nofile"})

(fn M.new [nvim model]
  (local self (base.new nvim {:model model :name "meta" :default-opts M.default-opts}))
  (set self.syntax-type "buffer")
  (set self.indexbuf (ui.new nvim self "indexes"))

  (fn self.syntax []
    (if (and (= self.syntax-type "buffer") (~= (. (. vim.bo self.model) :syntax) ""))
        (. (. vim.bo self.model) :syntax)
        "metabuffer"))

  (fn self.apply-syntax [syntax-type]
    (when syntax-type (set self.syntax-type syntax-type))
    (tset (. vim.bo self.buffer) :syntax (self.syntax)))

  (fn self.update []
    (self.render))

  (fn self.render []
    (local view (vim.fn.winsaveview))
    (tset (. vim.bo self.buffer) :modifiable true)
    (local out [])
    (each [_ idx (ipairs self.indices)]
      (table.insert out (. self.content idx)))
    (vim.api.nvim_buf_set_lines self.buffer 0 -1 false out)
    (tset (. vim.bo self.buffer) :modifiable false)
    (vim.fn.winrestview view)
    (self.indexbuf.update))

  (fn self.push-visible-lines [visible]
    (local n (math.min (# visible) (# self.indices)))
    (for [i 1 n]
      (let [src (. self.indices i)
            old (vim.api.nvim_buf_get_lines self.model (- src 1) src false)
            old-line (. old 1)
            new-line (. visible i)]
        (when (~= old-line new-line)
          (vim.api.nvim_buf_set_lines self.model (- src 1) src false [new-line])
          (tset self.content src new-line)))))

  self)

M
