(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local base (require :metabuffer.matcher.base))
(local util (require :metabuffer.util))

(local M {})

(fn M.new
  []
  "Public API: M.new."
  (base.new "all"
    {:get-highlight-pattern
      (fn [_ query]
        (let [pats []]
          (each [_ p (ipairs (util.split-input query))]
            (table.insert pats (base.escape-vim-patterns p)))
          (.. "\\%(" (table.concat pats "\\|") "\\)")))
     :filter
      (fn [_ query indices candidates ignorecase]
        (let [words (util.split-input query)
              out []]
          (when ignorecase
            (each [i w (ipairs words)]
              (set (. words i) (string.lower w))))
          (each [_ idx (ipairs indices)]
            (let [line (. candidates idx)
                  probe (if ignorecase (string.lower line) line)]
              (var ok true)
              (each [_ w (ipairs words)]
                (when (and ok (not (string.find probe w 1 true)))
                  (set ok false)))
              (when ok
                (table.insert out idx))))
          out))}))

M
