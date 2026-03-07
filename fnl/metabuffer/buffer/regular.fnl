(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local base (require :metabuffer.buffer.base))
(local M {})

(fn M.new
  [nvim opts]
  "Public API: M.new."
  (base.new nvim (or opts {:name "buffer"})))

M
