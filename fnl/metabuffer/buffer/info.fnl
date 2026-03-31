(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local base-buffer-mod (require :metabuffer.buffer.base))
(local M {})

(fn apply-info-buffer-opts!
  [buf]
  (base-buffer-mod.apply-buffer-opts!
    buf
    {:buftype "nofile"
     :bufhidden "wipe"
     :swapfile false
     :modifiable false
     :filetype ""}))

(fn M.prepare-buffer!
  [buf]
  "Apply Meta info buffer-local options to BUF. Returns BUF."
  (apply-info-buffer-opts! buf))

(fn M.new
  [buf]
  "Register and prepare an info buffer. Returns BUF."
  (base-buffer-mod.register-managed-buffer!
    buf
    :info
    "[Metabuffer Info]"
    {:buftype "nofile"
     :bufhidden "wipe"
     :swapfile false
     :modifiable false
     :filetype ""}
    nil))

M
