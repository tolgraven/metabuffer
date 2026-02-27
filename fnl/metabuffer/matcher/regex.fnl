(local base (require :metabuffer.matcher.base))
(local util (require :metabuffer.util))

(local M {})

(fn M.new []
  (base.new "regex"
    {:get-highlight-pattern (fn [_ query] (util.convert2regex-pattern query))
     :filter
      (fn [_ query indices candidates ignorecase]
        (local patterns (util.split-input query))
        (var active (util.deepcopy indices))
        (each [_ pattern (ipairs patterns)]
          (local next [])
          (each [_ idx (ipairs active)]
            (local line (. candidates idx))
            (local probe (if ignorecase (string.lower line) line))
            (local p (if ignorecase (string.lower pattern) pattern))
            (local ok (pcall string.find probe p))
            (when (and ok (string.find probe p))
              (table.insert next idx)))
          (set active next))
        active)}))

M
