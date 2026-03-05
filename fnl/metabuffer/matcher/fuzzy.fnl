(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local base (require :metabuffer.matcher.base))

(local M {})

(fn mkpat
  [fmt esc q]
  (local chars (vim.fn.split (or q "") "\\zs"))
  (local out [])
  (each [_ ch (ipairs chars)]
    (local e (esc ch))
    (table.insert out (string.format fmt e e)))
  (table.concat out ""))

(fn M.new
  []
  (base.new "fuzzy"
    {:also-highlight-per-char true
     :get-highlight-pattern (fn [_ query] (mkpat "%s[^%s]\\{-}" base.escape-vim-patterns query))
     :filter
      (fn [_ query indices candidates ignorecase]
        (local pat (mkpat "%s[^%s]*" vim.pesc query))
        (local out [])
        (each [_ idx (ipairs indices)]
          (local line (. candidates idx))
          (local line1 (if ignorecase (string.lower line) line))
          (local pat1 (if ignorecase (string.lower pat) pat))
          (local ok (pcall string.find line1 pat1))
          (when (and ok (string.find line1 pat1))
            (table.insert out idx)))
        out)}))

M
