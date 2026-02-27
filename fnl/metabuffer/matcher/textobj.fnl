(local base (require :metabuffer.matcher.base))
(local M {})

(fn M.new []
  (base.new "textobj"
    {:get-highlight-pattern (fn [_ query] query)
     :filter (fn [_ _ indices _ _] indices)}))

M
