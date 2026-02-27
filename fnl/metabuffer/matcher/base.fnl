(local util (require :metabuffer.util))
(local M {})

(set M.default-hi-prefix "MetaSearchHit")
(set M.default-hi-char "MetaSearchHitFuzzyBetween")

(fn M.new [name opts]
  (local self {:name name
               :also-highlight-per-char (and opts opts.also-highlight-per-char)
               :match-id nil
               :char-match-id nil
               :match-win nil
               :get-highlight-pattern (or (and opts opts.get-highlight-pattern) (fn [_ _] ""))
               :filter (or (and opts opts.filter) (fn [_ _ _ _] []))})

  (fn delete-match [id win]
    (if win
        (pcall vim.fn.matchdelete id win)
        (pcall vim.fn.matchdelete id)))

  (fn self.remove-highlight []
    (when self.match-id
      (delete-match self.match-id self.match-win)
      (set self.match-id nil))
    (when self.char-match-id
      (delete-match self.char-match-id self.match-win)
      (set self.char-match-id nil))
    (set self.match-win nil))

  (fn matchadd-in-window [group pattern win]
    (let [[ok id] (pcall vim.fn.matchadd group pattern 0 -1 {:window win})]
      (if ok
          id
          (vim.fn.matchadd group pattern 0))))

  (fn self.highlight [query ignorecase]
    (self.remove-highlight)
    (when (and query (~= query ""))
      (let [pat (self.get-highlight-pattern self query)
            group (.. M.default-hi-prefix (string.upper (string.sub self.name 1 1)) (string.sub self.name 2))
            case-prefix (if ignorecase "\\c" "\\C")
            win (vim.api.nvim_get_current_win)]
        (set self.match-win win)
        (set self.match-id (matchadd-in-window group (.. case-prefix pat) win))
        (when self.also-highlight-per-char
          (set self.char-match-id
            (matchadd-in-window M.default-hi-char (table.concat (vim.split query "") "\\|") win))))))

  self)

(fn M.escape-vim-patterns [text]
  (util.escape-vim-pattern text))

M
