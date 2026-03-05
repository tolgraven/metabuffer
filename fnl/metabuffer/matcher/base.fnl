(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local util (require :metabuffer.util))
(local M {})

(set M.default-hi-prefix "MetaSearchHit")
(set M.default-hi-char "MetaSearchHitFuzzyBetween")
(set M.default-match-priority (or vim.g.meta_search_match_priority 220))

(fn M.new [name opts]
  (local self {:name name
               :also-highlight-per-char (and opts opts.also-highlight-per-char)
               :match-id nil
               :char-match-id nil
               :match-win nil
               :get-highlight-pattern (or (and opts opts.get-highlight-pattern) (fn [_ _] ""))
               :filter (or (and opts opts.filter) (fn [_ _ _ _] []))})

  (fn delete-match [id win]
    (if (and win (vim.api.nvim_win_is_valid win))
        (or (pcall vim.fn.matchdelete id win)
            (pcall vim.api.nvim_win_call win (fn [] (vim.fn.matchdelete id))))
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
    (var id nil)
    (if (and win (vim.api.nvim_win_is_valid win))
        (let [[ok win-id] [(pcall vim.fn.matchadd group pattern M.default-match-priority -1 {:window win})]]
          (if ok
              win-id
              (vim.api.nvim_win_call win
                (fn []
                  (vim.fn.matchadd group pattern M.default-match-priority)))))
        (vim.fn.matchadd group pattern M.default-match-priority)))

  ;; Keep method signature compatible with callers using
  ;; `matcher.highlight(matcher, query, ...)`.
  (fn self.highlight [_ query ignorecase target-win]
    (self.remove-highlight)
    (when (and query (~= query ""))
      (let [pat (self.get-highlight-pattern self query)
            group (.. M.default-hi-prefix (string.upper (string.sub self.name 1 1)) (string.sub self.name 2))
            case-prefix (if ignorecase "\\c" "\\C")
            win (or target-win (vim.api.nvim_get_current_win))]
        (set self.match-win win)
        (set self.match-id (matchadd-in-window group (.. case-prefix pat) win))
        (when self.also-highlight-per-char
          (set self.char-match-id
            (matchadd-in-window M.default-hi-char (table.concat (vim.split query "") "\\|") win))))))

  self)

(fn M.escape-vim-patterns [text]
  (util.escape-vim-pattern text))

M
