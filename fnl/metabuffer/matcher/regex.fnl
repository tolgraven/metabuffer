(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local base (require :metabuffer.matcher.base))
(local util (require :metabuffer.util))

(local M {})

(fn M.new
  []
  "Public API: M.new."
  (base.new "regex"
    {:get-highlight-pattern (fn [_ query] (util.convert2regex-pattern query))
     :filter
      (fn [_ query indices candidates ignorecase]
        (let [patterns (util.split-input query)]
          (var active (util.deepcopy indices))
          (each [_ pattern (ipairs patterns)]
            (let [next []
                  vim-pattern (.. (if ignorecase "\\c" "\\C") pattern)]
              (var rx nil)
              (let [[ok rex] [(pcall vim.regex vim-pattern)]]
                (when ok
                  (set rx rex)))
              (when rx
                (each [_ idx (ipairs active)]
                  (let [line (. candidates idx)
                        [s _e] [(rx:match_str line)]]
                    (when s
                      (table.insert next idx))))
                (set active next)))
          active))}))

M
