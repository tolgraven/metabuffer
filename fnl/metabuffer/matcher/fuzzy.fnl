(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local base (require :metabuffer.matcher.base))

(local M {})

(fn mkpat
  [fmt esc q]
  (let [chars (vim.fn.split (or q "") "\\zs")
        out []]
    (each [_ ch (ipairs chars)]
      (let [e (esc ch)]
        (table.insert out (string.format fmt e e))))
    (table.concat out "")))

(fn M.new
  []
  "Public API: M.new."
  (base.new "fuzzy"
    {:also-highlight-per-char true
     :get-highlight-pattern (fn [_ query] (mkpat "%s[^%s]\\{-}" base.escape-vim-patterns query))
     :filter
      (fn [_ query indices candidates ignorecase]
        (let [pat (mkpat "%s[^%s]*" vim.pesc query)
              out []]
          (each [_ idx (ipairs indices)]
            (let [line (. candidates idx)
                  line1 (if ignorecase (string.lower line) line)
                  pat1 (if ignorecase (string.lower pat) pat)
                  ok (pcall string.find line1 pat1)]
              (when (and ok (string.find line1 pat1))
                (table.insert out idx))))
          out))}))

M
