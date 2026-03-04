(local handle (require :metabuffer.handle))
(local util (require :metabuffer.util))

(local M {})

(fn M.new-buffer []
  (vim.api.nvim_create_buf false false))

(fn M.switch-buf [buf]
  (when (and buf (vim.api.nvim_buf_is_valid buf))
    (vim.cmd (.. "noautocmd keepjumps buffer " buf)))
  (vim.api.nvim_get_current_buf))

(fn M.new [nvim opts]
  (local model (or (. opts :model) (vim.api.nvim_get_current_buf)))
  (local target (or (. opts :buffer) (M.new-buffer)))
  (local base (handle.new nvim target model [] (or (. opts :default-opts) {})))
  (local self base)

  (set self.buffer target)
  (set self.model model)
  (set self.name (or (. opts :name) "buffer"))
  (set self.content (util.buf-lines model))
  (set self.indices [])
  (for [i 1 (# self.content)]
    (table.insert self.indices i))
  (set self.all-indices (util.deepcopy self.indices))

  (fn self.line-count [] (# self.content))

  (fn self.source-line-nr [index]
    (let [line (. self.indices index)]
      (and line (+ line 0))))

  (fn self.closest-index [line-nr]
    (var candidate nil)
    (var dist math.huge)
    (each [i v (ipairs self.indices)]
      (local d (math.abs (- v line-nr)))
      (when (< d dist)
        (set dist d)
        (set candidate i)))
    (or candidate 1))

  (fn self.reset-filter []
    (set self.indices (util.deepcopy self.all-indices)))

  (fn self.run-filter [matcher query ignorecase run-clean target-win]
    (when run-clean (self.reset-filter))
    (set self.indices (matcher.filter matcher query self.indices self.content ignorecase))
    (if (< (# self.indices) 1000)
        (matcher.highlight matcher query ignorecase target-win)
        (matcher.remove-highlight matcher)))

  (fn self.update []
    (local view (vim.fn.winsaveview))
    (let [bo (. vim.bo self.buffer)]
      (set (. bo :modifiable) true))
    (local out [])
    (each [_ idx (ipairs self.indices)]
      (table.insert out (. self.content idx)))
    (vim.api.nvim_buf_set_lines self.buffer 0 -1 false out)
    (let [bo (. vim.bo self.buffer)]
      (set (. bo :modifiable) false))
    (vim.fn.winrestview view))

  (fn self.activate [target-buf]
    (M.switch-buf (or target-buf self.buffer)))

  (fn self.unique-name [base-name]
    (local base (or base-name "buffer"))
    (var n 1)
    (var candidate base)
    (while (and (> (vim.fn.bufnr candidate) 0)
                (~= (vim.fn.bufnr candidate) self.buffer))
      (set n (+ n 1))
      (set candidate (.. base " [" n "]")))
    candidate)

  (fn self.set-name [buf-name]
    (local target-name (self.unique-name buf-name))
    (let [[ok err] [(pcall vim.api.nvim_buf_set_name self.buffer target-name)]]
      (if ok
          (set self.name target-name)
          ;; Last-resort fallback keeps plugin functional even if name APIs
          ;; reject a candidate due to race/collision.
          (set self.name (.. (or buf-name "buffer") " [" self.buffer "]")))))

  self)

M
