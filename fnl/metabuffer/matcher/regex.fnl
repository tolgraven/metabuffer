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
          (local vim-pattern (.. (if ignorecase "\\c" "\\C") pattern))
          (var rx nil)
          (let [[ok rex] [(pcall vim.regex vim-pattern)]]
            (when ok
              (set rx rex)))
          (when rx
            (each [_ idx (ipairs active)]
              (local line (. candidates idx))
              (let [[s _e] [(rx:match_str line)]]
                (when s
                  (table.insert next idx)))))
          (set active next))
        active)}))

M
