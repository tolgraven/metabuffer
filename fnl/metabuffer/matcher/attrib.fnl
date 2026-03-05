(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local base (require :metabuffer.matcher.base))
(local M {})

(fn M.new []
  (base.new "attrib"
    {:get-highlight-pattern (fn [_ query] query)
     :filter (fn [_ _ indices _ _] indices)}))

M
