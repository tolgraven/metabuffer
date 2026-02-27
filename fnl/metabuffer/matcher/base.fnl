(local util (require :metabuffer.util))
(local M {})

(set M.default-hi-prefix "MetaSearchHit")
(set M.default-hi-char "MetaSearchHitFuzzyBetween")

(fn M.new [name opts]
  (local self {:name name
               :also-highlight-per-char (and opts opts.also-highlight-per-char)
               :match-id nil
               :char-match-id nil
               :get-highlight-pattern (or (and opts opts.get-highlight-pattern) (fn [_ _] ""))
               :filter (or (and opts opts.filter) (fn [_ _ _ _] []))})

  (fn self.remove-highlight []
    (when self.match-id
      (pcall vim.fn.matchdelete self.match-id)
      (set self.match-id nil))
    (when self.char-match-id
      (pcall vim.fn.matchdelete self.char-match-id)
      (set self.char-match-id nil)))

  (fn self.highlight [query ignorecase]
    (self.remove-highlight)
    (when (and query (~= query ""))
      (let [pat (self.get-highlight-pattern self query)
            group (.. M.default-hi-prefix (string.upper (string.sub self.name 1 1)) (string.sub self.name 2))
            case-prefix (if ignorecase "\\c" "\\C")]
        (set self.match-id (vim.fn.matchadd group (.. case-prefix pat) 0))
        (when self.also-highlight-per-char
          (set self.char-match-id
            (vim.fn.matchadd M.default-hi-char (table.concat (vim.split query "") "\\|") 0))))))

  self)

(fn M.escape-vim-patterns [text]
  (util.escape-vim-pattern text))

M
