(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local base (require :metabuffer.matcher.base))
(local util (require :metabuffer.util))

(local M {})

(fn M.new []
  (base.new "all"
    {:get-highlight-pattern
      (fn [_ query]
        (local pats [])
        (each [_ p (ipairs (util.split-input query))]
          (table.insert pats (base.escape-vim-patterns p)))
        (.. "\\%(" (table.concat pats "\\|") "\\)"))
     :filter
      (fn [_ query indices candidates ignorecase]
        (local words (util.split-input query))
        (when ignorecase
          (each [i w (ipairs words)]
            (set (. words i) (string.lower w))))
        (local out [])
        (each [_ idx (ipairs indices)]
          (local line (. candidates idx))
          (local probe (if ignorecase (string.lower line) line))
          (var ok true)
          (each [_ w (ipairs words)]
            (when (and ok (not (string.find probe w 1 true)))
              (set ok false)))
          (when ok
            (table.insert out idx)))
        out)}))

M
