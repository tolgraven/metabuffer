(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local handle (require :metabuffer.handle))
(local util (require :metabuffer.util))
(local events (require :metabuffer.events))

(local M {})

(fn M.new-buffer
  []
  "Public API: M.new-buffer."
  (let [buf (vim.api.nvim_create_buf false false)]
    (events.send :on-buf-create! {:buf buf :role :meta})
    buf))

(fn M.switch-buf
  [buf]
  "Public API: M.switch-buf."
  (when (and buf (vim.api.nvim_buf_is_valid buf))
    (vim.cmd (.. "noautocmd keepjumps buffer " buf)))
  (vim.api.nvim_get_current_buf))

(fn M.apply-buffer-opts!
  [buf opts]
  "Apply generic buffer-local OPTS to BUF. Returns BUF."
  (when (and buf (vim.api.nvim_buf_is_valid buf))
    (let [bo (. vim.bo buf)]
      (each [name value (pairs (or opts {}))]
        (set (. bo name) value))))
  buf)

(fn M.clear-modified!
  [buf]
  "Clear modified state for BUF when it is still valid. Returns BUF."
  (when (and buf (vim.api.nvim_buf_is_valid buf))
    (pcall vim.api.nvim_set_option_value "modified" false {:buf buf}))
  buf)

(fn M.register-managed-buffer!
  [buf role name opts event-extra]
  "Register BUF as managed Meta buffer ROLE, assign NAME, and apply OPTS. Returns BUF."
  (events.send :on-buf-create!
               (vim.tbl_extend "force"
                               {:buf buf :role role}
                               (or event-extra {})))
  (when (and (= (type name) "string") (~= name ""))
    (util.set-buffer-name! buf name))
  (M.apply-buffer-opts! buf opts))

(fn line-count
  [self]
  (# self.content))

(fn source-line-nr
  [self index]
  (let [line (. self.indices index)]
    (and line (+ line 0))))

(fn closest-index
  [self line-nr]
  (var candidate nil)
  (var dist math.huge)
  (each [i v (ipairs self.indices)]
    (let [d (math.abs (- v line-nr))]
      (when (< d dist)
        (set dist d)
        (set candidate i))))
  (or candidate 1))

(fn reset-filter!
  [self]
  (set self.indices (util.deepcopy self.all-indices)))

(fn run-filter!
  [self matcher query ignorecase run-clean target-win]
  (when run-clean
    (reset-filter! self))
  (set self.indices (matcher.filter matcher query self.indices self.content ignorecase))
  (if (< (# self.indices) 1000)
      (matcher.highlight matcher query ignorecase target-win)
      (matcher.remove-highlight matcher)))

(fn update-buffer-lines!
  [self]
  (let [view (vim.fn.winsaveview)
        out []]
    (let [bo (. vim.bo self.buffer)]
      (set (. bo :modifiable) true))
    (each [_ idx (ipairs self.indices)]
      (table.insert out (. self.content idx)))
    (vim.api.nvim_buf_set_lines self.buffer 0 -1 false out)
    (let [bo (. vim.bo self.buffer)]
      (set (. bo :modifiable) false))
    (vim.fn.winrestview view)))

(fn activate-buffer!
  [self target-buf]
  (M.switch-buf (or target-buf self.buffer)))

(fn unique-buffer-name
  [self base-name]
  (let [base (or base-name "buffer")]
    (var n 1)
    (var candidate base)
    (while (and (> (vim.fn.bufnr candidate) 0)
                (~= (vim.fn.bufnr candidate) self.buffer))
      (set n (+ n 1))
      (set candidate (.. base " [" n "]")))
    candidate))

(fn set-buffer-name!
  [self buf-name]
  (let [target-name (unique-buffer-name self buf-name)
        [ok] [(pcall vim.api.nvim_buf_set_name self.buffer target-name)]]
    (if ok
        (set self.name target-name)
        (set self.name (.. (or buf-name "buffer") " [" self.buffer "]")))))

(fn M.new
  [nvim opts]
  "Public API: M.new."
  (let [model (or (. opts :model) (vim.api.nvim_get_current_buf))
        target (or (. opts :buffer) (M.new-buffer))
        self (handle.new nvim target model [] (or (. opts :default-opts) {}))]
    (set self.buffer target)
    (set self.model model)
    (set self.name (or (. opts :name) "buffer"))
    (set self.content (util.buf-lines model))
    (set self.indices [])
    (for [i 1 (# self.content)]
      (table.insert self.indices i))
    (set self.all-indices (util.deepcopy self.indices))

  (fn self.line-count
  [] (line-count self))

  (fn self.source-line-nr
  [index]
    (source-line-nr self index))

  (fn self.closest-index
  [line-nr]
    (closest-index self line-nr))

  (fn self.reset-filter
  []
    (reset-filter! self))

  (fn self.run-filter
  [matcher query ignorecase run-clean target-win]
    (run-filter! self matcher query ignorecase run-clean target-win))

  (fn self.update
  []
    (update-buffer-lines! self))

  (fn self.activate
  [target-buf]
    (activate-buffer! self target-buf))

  (fn self.unique-name
  [base-name]
    (unique-buffer-name self base-name))

  (fn self.set-name
  [buf-name]
    ;; Last-resort fallback keeps plugin functional even if name APIs
    ;; reject a candidate due to race/collision.
    (set-buffer-name! self buf-name))

    self))

M
