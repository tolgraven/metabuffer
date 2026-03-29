(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local util (require :metabuffer.util))
(local M {})

(set M.default-hi-prefix "MetaSearchHit")
(set M.default-hi-char "MetaSearchHitFuzzyBetween")
(set M.default-match-priority (or vim.g.meta_search_match_priority 220))

(fn line-highlight-group
  [matcher-name idx default-group]
  (let [suffix (tostring (+ (% (math.max 0 (- (or idx 1) 1)) 6) 1))
        candidate (.. M.default-hi-prefix
                       (string.upper (string.sub matcher-name 1 1))
                       (string.sub matcher-name 2)
                       suffix)]
    (if (> (vim.fn.hlexists candidate) 0)
        candidate
        default-group)))

(fn per-line-item-group
  [idx fallback-group item-group]
  (let [generic-all "MetaSearchHitAll"
        generic-fuzzy "MetaSearchHitFuzzy"
        generic-regex "MetaSearchHitRegex"
        target (or item-group fallback-group)]
    (if (= target generic-all)
        (line-highlight-group "all" idx generic-all)
        (= target generic-fuzzy)
        (line-highlight-group "fuzzy" idx generic-fuzzy)
        (= target generic-regex)
        (line-highlight-group "regex" idx generic-regex)
        target)))

(fn delete-match!
  [id win]
  (if (and win (vim.api.nvim_win_is_valid win))
      (or (pcall vim.fn.matchdelete id win)
          (pcall vim.api.nvim_win_call win (fn [] (vim.fn.matchdelete id))))
      (pcall vim.fn.matchdelete id)))

(fn matchadd-in-window
  [group pattern win]
  (if (and win (vim.api.nvim_win_is_valid win))
      (let [[ok win-id] [(pcall vim.fn.matchadd group pattern M.default-match-priority -1 {:window win})]]
        (if ok
            win-id
            (vim.api.nvim_win_call win
              (fn []
                (vim.fn.matchadd group pattern M.default-match-priority)))))
      (vim.fn.matchadd group pattern M.default-match-priority)))

(fn remove-highlight!
  [self]
  (each [_ id (ipairs (or self.match-ids []))]
    (delete-match! id self.match-win))
  (set self.match-ids [])
  (when self.char-match-id
    (delete-match! self.char-match-id self.match-win)
    (set self.char-match-id nil))
  (set self.match-win nil))

(fn highlight-query!
  [self query ignorecase target-win]
  (remove-highlight! self)
  (when (and query (~= query ""))
    (let [group (.. M.default-hi-prefix (string.upper (string.sub self.name 1 1)) (string.sub self.name 2))
          case-prefix (if ignorecase "\\c" "\\C")
          win (or target-win (vim.api.nvim_get_current_win))]
      (set self.match-win win)
      (if (= (type query) "table")
          (each [idx item-query (ipairs query)]
            (let [item-pat (self.get-highlight-pattern self item-query)
                  item-group (line-highlight-group self.name idx group)]
              (if (= (type item-pat) "string")
                  (when (~= item-pat "")
                    (table.insert self.match-ids
                      (matchadd-in-window item-group (.. case-prefix item-pat) win)))
                  (when (= (type item-pat) "table")
                    (each [_ item (ipairs item-pat)]
                      (let [resolved-group (per-line-item-group idx item-group (. item :group))
                            resolved-pat (or (. item :pattern) "")]
                        (when (~= resolved-pat "")
                          (table.insert self.match-ids
                            (matchadd-in-window resolved-group (.. case-prefix resolved-pat) win)))))))))
          (let [pat (self.get-highlight-pattern self query)]
            (if (= (type pat) "string")
                (when (~= pat "")
                  (table.insert self.match-ids
                    (matchadd-in-window group (.. case-prefix pat) win)))
                (when (= (type pat) "table")
                  (each [_ item (ipairs pat)]
                    (let [item-group (or (. item :group) group)
                          item-pat (or (. item :pattern) "")]
                      (when (~= item-pat "")
                        (table.insert self.match-ids
                          (matchadd-in-window item-group (.. case-prefix item-pat) win)))))))))
      (when self.also-highlight-per-char
        (set self.char-match-id
          (matchadd-in-window M.default-hi-char (table.concat (vim.split (if (= (type query) "table")
                                                                             (table.concat query " ")
                                                                             query) "") "\\|") win))))))

(fn M.new
  [name opts]
  "Public API: M.new."
  (let [self {:name name
              :also-highlight-per-char (and opts opts.also-highlight-per-char)
              :match-ids []
              :char-match-id nil
              :match-win nil
              :get-highlight-pattern (or (and opts opts.get-highlight-pattern) (fn [_ _] ""))
              :filter (or (and opts opts.filter) (fn [_ _ _ _] []))}]

  (fn self.remove-highlight
  []
    (remove-highlight! self))

  ;; Keep method signature compatible with callers using
  ;; `matcher.highlight(matcher, query, ...)`.
  (fn self.highlight
  [_ query ignorecase target-win]
    (highlight-query! self query ignorecase target-win))

  self))

(fn M.escape-vim-patterns
  [text]
  "Public API: M.escape-vim-patterns."
  (util.escape-vim-pattern text))

M
