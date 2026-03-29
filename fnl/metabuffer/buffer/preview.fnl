(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local base-buffer-mod (require :metabuffer.buffer.base))
(local events (require :metabuffer.events))
(local M {})

(fn apply-preview-scratch-opts!
  [buf]
  (base-buffer-mod.apply-buffer-opts!
    buf
    {:bufhidden "hide"
     :buftype "nofile"
     :swapfile false
     :modifiable false
     :filetype ""}))

(fn M.prepare-scratch-buffer!
  [buf]
  "Apply scratch preview buffer-local options to BUF. Returns BUF."
  (apply-preview-scratch-opts! buf))

(fn M.new-scratch
  [buf]
  "Register and prepare a scratch preview buffer. Returns BUF."
  (base-buffer-mod.register-managed-buffer!
    buf
    :preview
    "[Metabuffer Preview]"
    {:bufhidden "hide"
     :buftype "nofile"
     :swapfile false
     :modifiable false
     :filetype ""}
    {:transient? true}))

(fn M.mark-preview-buffer!
  [buf transient?]
  "Mark BUF as a preview-role buffer without changing real file buffer options."
  (when (and buf (vim.api.nvim_buf_is_valid buf))
    (events.send :on-buf-create!
                 {:buf buf
                  :role :preview
                  :transient? (if (= transient? nil) true (clj.boolean transient?))})))

(fn M.unmark-preview-buffer!
  [buf]
  "Emit preview teardown for BUF unless it is already a managed preview buffer."
  (when (and buf
             (vim.api.nvim_buf_is_valid buf)
             (not (= true (pcall vim.api.nvim_buf_get_var buf "meta_preview"))))
    (events.send :on-buf-teardown! {:buf buf :role :preview})))

M
