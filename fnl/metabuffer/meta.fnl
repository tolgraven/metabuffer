(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local prompt_mod (require :metabuffer.prompt.prompt))
(local modeindexer (require :metabuffer.modeindexer))
(local state (require :metabuffer.core.state))
(local all_matcher (require :metabuffer.matcher.all))
(local fuzzy_matcher (require :metabuffer.matcher.fuzzy))
(local regex_matcher (require :metabuffer.matcher.regex))
(local meta_buffer_mod (require :metabuffer.buffer.metabuffer))
(local meta_window_mod (require :metabuffer.window.metawindow))
(local expand_mod (require :metabuffer.context.expand))
(local helper_mod (require :metabuffer.meta.helpers))

(local M {})
(local STATUS_PROGRESS (. prompt_mod :STATUS_PROGRESS))
(local state-cases (. state :cases))
(local state-syntax-types (. state :syntax-types))

(fn nvim-exiting?
  []
  (let [v (and vim.v (. vim.v :exiting))]
    (and (~= v nil)
         (~= v vim.NIL)
         (~= v 0)
         (~= v ""))))

(fn main-visible-source-indices
  [self base-indices rendered-indices]
  "Return visible base-hit source indices for the current main-window viewport.
   Falls back to the visible slice of `base-indices` when no rendered mapping is
   available. Expected output: [12 18 27]."
  (let [win (and self self.win self.win.window)
        total (# (or base-indices []))]
    (if (or (<= total 0)
            (not win)
            (not (vim.api.nvim_win_is_valid win)))
        []
        (let [view (vim.api.nvim_win_call win (fn [] (vim.fn.winsaveview)))
              top (math.max 1 (math.min total (or (. view :topline) 1)))
              height (math.max 1 (vim.api.nvim_win_get_height win))
              stop (math.min (math.max 1 (# (or rendered-indices [])))
                             (+ top height -1))
              base-ranks (let [out0 {}]
                           (each [i src (ipairs (or base-indices []))]
                             (when (and src (= (. out0 src) nil))
                               (set (. out0 src) i)))
                           out0)
              out []]
          (when (> stop 0)
            (each [i src (ipairs (or rendered-indices []))]
              (when (and (>= i top) (<= i stop))
                (when-let [rank (. base-ranks src)]
                  (table.insert out (. base-indices rank))))))
          (if (> (# out) 0)
              out
              (let [fallback-stop (math.min total (+ top height -1))
                    fallback []]
                (for [i top fallback-stop]
                  (let [src (. base-indices i)]
                    (when src
                      (table.insert fallback src))))
                fallback))))))

(fn line_of_index
  [buf idx]
  (or (. buf.indices (+ idx 1)) 1))

(fn union-query-indices
  [matcher queries candidates ignorecase]
  "Return sorted union of per-line query matches. Expected output: ascending source indices."
  (let [seen {}
        out []]
    (each [_ q (ipairs (or queries []))]
      (let [hits (matcher.filter matcher q (vim.fn.range 1 (# candidates)) candidates ignorecase)]
        (each [_ idx (ipairs hits)]
          (when-not (. seen idx)
            (set (. seen idx) true)
            (table.insert out idx)))))
    (table.sort out)
    out))

(fn ref-is-file-entry?
  [ref]
  (= (or (and ref ref.kind) "") "file-entry"))

(fn file-query-matches?
  [path q ignorecase]
  (let [probe0 (or path "")
        probe (if ignorecase (string.lower probe0) probe0)
        query0 (vim.trim (or q ""))
        query (if ignorecase (string.lower query0) query0)]
    (if (= query "")
        true
        (not= nil (string.find probe query 1 true)))))

(fn apply-file-entry-filter
  [indices refs file-query-lines ignorecase include-files regular-query-active?]
  (if (not include-files)
      indices
  (let [queries0 []]
    (each [_ q (ipairs (or file-query-lines []))]
      (let [trimmed (vim.trim (or q ""))]
        (when (~= trimmed "")
          (table.insert queries0 trimmed))))
    (let [queries queries0]
    (let [matches-all-queries? (fn [path]
                                 (if (= (# queries) 0)
                                     true
                                     (let [path0 (or path "")
                                           rel (if (~= path0 "") (vim.fn.fnamemodify path0 ":.") "")
                                           probe (if (~= rel "")
                                                     (.. rel " " path0)
                                                     path0)
                                           ok0 true]
                                       (var ok ok0)
                                       (each [_ q (ipairs queries)]
                                         (when (and ok (not (file-query-matches? probe q ignorecase)))
                                           (set ok false)))
                                       ok)))
          regular-set {}
          file-set {}
          regular-allowed? (or regular-query-active?
                               (= (# queries) 0))]
      (each [_ idx (ipairs (or indices []))]
        (let [ref (. refs idx)]
          (if (ref-is-file-entry? ref)
              nil
              (if regular-allowed?
                  (when (matches-all-queries? (and ref ref.path))
                    (set (. regular-set idx) true))
                  (set (. regular-set idx) true)))))
      (for [idx 1 (# refs)]
        (let [ref (. refs idx)]
          (when (ref-is-file-entry? ref)
            (if (= (# queries) 0)
                (set (. file-set idx) true)
                (let [path0 (or (and ref ref.path) "")
                      rel (if (~= path0 "") (vim.fn.fnamemodify path0 ":.") "")
                      path (or (and ref ref.line) rel path0 "")]
                  (when (matches-all-queries? path)
                    (set (. file-set idx) true)))))))
      (let [next []]
        (for [idx 1 (# refs)]
          (when (or (. regular-set idx) (. file-set idx))
            (table.insert next idx)))
        next))))))

(fn metabuffer-display-name
  [model-buf]
  (let [original-name (vim.api.nvim_buf_get_name model-buf)
        base-name (if (and (= (type original-name) "string") (~= original-name ""))
                      (vim.fn.fnamemodify original-name ":t")
                      "[No Name]")]
    (.. base-name " • Metabuffer")))

(fn project-display-name
  []
  "Metabuffer")

(fn M.new
  [nvim condition]
  "Construct Meta state and bind matcher/query/buffer runtime."
  (let [cond (or condition (state.default-condition ""))
        self (prompt_mod.new nvim)]

  (set self.condition cond)
  (set self.selected_index (or cond.selected-index 0))
  (set self._prev_text "")
  (set self.updates 0)
  (set self.debug_out "")
  (set self.prefix "# ")
  (set self.query-lines [])
  (set self._prev-ignorecase nil)
  (set self._prev-matcher nil)
  (set self._selection-cache {})
  (set self._lgrep-match-ids [])

  (set self.win (meta_window_mod.new nvim (vim.api.nvim_get_current_win)))
  (set self.status-win self.win)
  (set self.buf (meta_buffer_mod.new nvim (vim.api.nvim_get_current_buf)))
  (set self._filter-cache {})
  (set self._filter-cache-line-count (# self.buf.content))
  (set self._content-version-seen (or self.buf.content-version 0))
    (let [prompt-on-term self.on-term]
      (fn delete-win-match
        [win id]
        (if (and win (vim.api.nvim_win_is_valid win))
            (or (pcall vim.fn.matchdelete id win)
                (pcall vim.api.nvim_win_call win (fn [] (vim.fn.matchdelete id))))
            (pcall vim.fn.matchdelete id)))
      (fn apply-lgrep-highlights
        []
        (helper_mod.apply-lgrep-highlights! self delete-win-match :_lgrep-match-ids))
      (fn clear-all-highlights
        []
        (helper_mod.clear-all-highlights! self delete-win-match :_lgrep-match-ids))

  (set self.mode
       {:matcher (modeindexer.new [(all_matcher.new) (fuzzy_matcher.new) (regex_matcher.new)]
                                  (or cond.matcher-index 1)
                                  {:on-leave "remove-highlight"})
        :case (modeindexer.new state-cases (or cond.case-index 1) nil)
        :syntax (modeindexer.new state-syntax-types (or cond.syntax-index 1)
                                 {:on-active (fn [idx]
                                               (self.buf.apply-syntax
                                                (if (= (idx.current) "meta") "meta" "buffer")))})})

  (set self.text (or cond.text ""))
  (when (~= self.text "")
    (set self.query-lines [self.text]))
  (self.caret.set-locus (or cond.caret-locus (# self.text)))

  (fn self.matcher
    []
    ((. (. self.mode :matcher) :current)))

  (fn self.case
    []
    ((. (. self.mode :case) :current)))

  (fn self.syntax
    []
    ((. (. self.mode :syntax) :current)))

  (fn self.ignorecase
    []
    (state.ignorecase (self.case) self.text))

      (fn self.active-queries
        []
        (let [out []]
          (each [_ line (ipairs (or self.query-lines []))]
            (when (and (= (type line) "string") (~= (vim.trim line) ""))
              (table.insert out (vim.trim line))))
          out))

      (fn self.set-query-lines
        [lines]
        (set self.query-lines (or lines []))
        (let [active (self.active-queries)]
          (set self.text (table.concat active "\n"))))

  (fn self.selected_line
    []
    (line_of_index self.buf self.selected_index))

  (fn self.switch_mode
    [which]
    (let [mode_obj (. self.mode which)]
      (mode_obj.next)
      (set self._prev_text "")
      (self.on-update STATUS_PROGRESS)))

  (fn self.vim_query
    []
    (let [active (self.active-queries)
          q (. active (# active))]
      (if (or (not q) (= q ""))
      ""
      (let [caseprefix (if (self.ignorecase) "\\c" "\\C")
            matcher_obj (self.matcher)
            pat0 (matcher_obj.get-highlight-pattern matcher_obj q)
            pat (helper_mod.highlight-pattern->vim-query pat0)]
        (if (= pat "")
            ""
            (.. caseprefix pat))))))

      (fn self.refresh_statusline
        []
        (when-not (or (nvim-exiting?)
                      (and self.session
                           (or self.session.ui-hidden
                               self.session.closing)))
          (let [mode-state ((. helper_mod :statusline-mode-state))
                hl-prefix (if (= self.buf.syntax-type "meta") "Meta" "Buffer")]
            (self.status-win.set-statusline-state
              (. mode-state :group)
              (. mode-state :label)
              self.buf.name
              (# self.buf.indices)
              (self.buf.line-count)
              (self.selected_line)
              (helper_mod.results-statusline-left self)
              (helper_mod.results-statusline-right self)
              (. (self.matcher) :name)
              (self.case)
              hl-prefix
              (self.syntax)
              (helper_mod.results-middle-group self.session))
            (when (and self.session
                       self.session.prompt-win
                       (vim.api.nvim_win_is_valid self.session.prompt-win))
              (let [prompt-text (helper_mod.prompt-statusline-text self)]
                (when (~= self.session._last-prompt-statusline prompt-text)
                  (set self.session._last-prompt-statusline prompt-text)
                  (pcall vim.api.nvim_set_option_value
                         "statusline"
                         prompt-text
                         {:win self.session.prompt-win}))))
            (vim.cmd "redrawstatus"))))

      (fn self.on-init
        []
        (self.buf.set-name (if self.project-mode
                               (project-display-name)
                               (metabuffer-display-name self.buf.model)))
        (let [init-syntax (or (. vim.g "meta#syntax_on_init") "buffer")]
          (self.buf.apply-syntax (if (= init-syntax "meta") "meta" "buffer")))
        (set self.buf.visible-source-syntax-only (clj.boolean cond.project-mode))
    (clear-all-highlights)
    (self.buf.render)
    (let [line-count (vim.api.nvim_buf_line_count self.buf.buffer)
          line (math.max 1 (math.min (+ self.selected_index 1) line-count))
          source-view (or cond.source-view {})
          source-lnum (or (. source-view :lnum) line)
          source-topline (or (. source-view :topline) source-lnum)
          offset (math.max 0 (- source-lnum source-topline))
          topline (math.max 1 (math.min (- line offset) line-count))]
      (when (vim.api.nvim_win_is_valid self.win.window)
        (let [view (vim.fn.winsaveview)]
          (set (. view :lnum) line)
          (set (. view :topline) topline)
          (when (~= (. source-view :leftcol) nil)
            (set (. view :leftcol) (. source-view :leftcol)))
          (when (~= (. source-view :col) nil)
            (set (. view :col) (. source-view :col)))
          (vim.fn.winrestview view))))
        STATUS_PROGRESS)

  (fn self.on-redraw
    []
    (self.refresh_statusline)
    (self.redraw-prompt)
    STATUS_PROGRESS)

  (fn self.on-update
    [status]
      (let [queries (self.active-queries)
          prev-text self._prev_text
          prev-hits (vim.deepcopy (or self.buf.indices []))
          prev-rank (math.max 1 (+ self.selected_index 1))
          prev-line (line_of_index self.buf self.selected_index)
          anchor-line (or (and (= (# prev-hits) 0) self._no-hits-anchor-line)
                          prev-line)
          effective-query (table.concat queries "\n")
          matcher-name (. (self.matcher) :name)
          ignorecase (self.ignorecase)
          prev-ignorecase (if (= self._prev-ignorecase nil)
                              ignorecase
                              self._prev-ignorecase)
          prev-matcher-name (or self._prev-matcher matcher-name)
          prev-cache-key (.. prev-matcher-name "|" (if prev-ignorecase "1" "0") "|" (or prev-text ""))
          line-count (# self.buf.content)
          cache-grew? (> line-count self._filter-cache-line-count)
          cache-shrank? (< line-count self._filter-cache-line-count)
          cache-reset? cache-shrank?
          cache-key (.. matcher-name "|" (if ignorecase "1" "0") "|" effective-query)
          content-version (or self.buf.content-version 0)
          content-changed? (~= content-version (or self._content-version-seen 0))
          reset0? (or (= prev-text "")
                      (not (vim.startswith self.text prev-text))
                      (helper_mod.bang-token-completed? prev-text self.text)
                      ;; When backing cache is stale and we cannot reuse a cached
                      ;; query entry, recompute from full set to include new lines.
                      cache-grew?
                      cache-reset?
                      (~= self._prev-ignorecase ignorecase)
                      (~= self._prev-matcher matcher-name))
          ;; Fast path for narrowing edits: if the current hit set is already
          ;; small and the prompt grew, keep filtering only current hits.
          ;; This avoids full re-scans on every keystroke while narrowing.
          narrow-reuse-threshold (or vim.g.meta_narrow_reuse_threshold 400)
          narrow-reuse? (and reset0?
                             (vim.startswith self.text prev-text)
                             (= matcher-name "all")
                             (not ((. helper_mod :negation-growth-broadens?) prev-text self.text))
                             (> (# prev-text) 0)
                             (> (# self.text) (# prev-text))
                             (<= (# prev-hits) narrow-reuse-threshold))
          shortened? (< (# self.text) (# prev-text))
          broaden-on-delete? (and shortened? (helper_mod.deletion-broadens? prev-text self.text))
          reset? (and reset0?
                      (not narrow-reuse?)
                      (or (not shortened?)
                          broaden-on-delete?))]
      (set (. self._selection-cache prev-cache-key) anchor-line)
      (when cache-reset?
        (set self._filter-cache {})
        (set self._filter-cache-line-count line-count))
      (when cache-grew?
        (set self._filter-cache-line-count line-count))
      (set self._prev_text self.text)
      (set self._prev-ignorecase ignorecase)
      (set self._prev-matcher matcher-name)
      (set self.updates (+ self.updates 1))
      (when broaden-on-delete?
        ;; Ensure broaden-on-delete always starts from full candidate set.
        ;; This avoids sticky narrowed indices when cache/reuse paths race.
        (self.buf.reset-filter))
          (if (= (# queries) 0)
          (do
            (self.buf.reset-filter)
            (clear-all-highlights))
          (let [cached0 (. self._filter-cache cache-key)
                cached-obj? (and (= (type cached0) "table")
                                 (= (type (. cached0 :indices)) "table"))
                cached-full? (and cached-obj? (= (. cached0 :full) true))
                cached (if (and cached-obj? (not shortened?))
                           (when cached-full? (. cached0 :indices))
                           nil)
                cached-line-count0 (if cached-obj?
                                       (or (. cached0 :line-count) line-count)
                                       self._filter-cache-line-count)
                matcher (self.matcher)]
            (if cached
                (do
                  (var cached-line-count cached-line-count0)
                  ;; Extend cached results incrementally when project streaming
                  ;; appended lines since this cache entry was materialized.
                  (let [next (vim.deepcopy cached)
                        seen {}]
                    (each [_ idx (ipairs next)]
                      (set (. seen idx) true))
                    (when (< cached-line-count line-count)
                      (let [added-candidates []]
                        (for [i (+ cached-line-count 1) line-count]
                          (table.insert added-candidates (. self.buf.content i)))
                        (let [added-hits (union-query-indices matcher queries added-candidates ignorecase)]
                          (each [_ rel-idx (ipairs added-hits)]
                            (let [idx (+ cached-line-count rel-idx)]
                              (when-not (. seen idx)
                                (set (. seen idx) true)
                                (table.insert next idx)))))
                        (set cached-line-count line-count)))
                    ;; Copy cached indices so future incremental updates cannot
                    ;; accidentally mutate cache entries by reference.
                    (set self.buf.indices (vim.deepcopy next))
                    (set (. self._filter-cache cache-key)
                         {:indices (vim.deepcopy next)
                          :line-count line-count
                          :full true})))
                (do
                  (set self.buf.indices (union-query-indices matcher queries self.buf.content ignorecase))
                  (when reset?
                    (set (. self._filter-cache cache-key)
                         {:indices (vim.deepcopy self.buf.indices)
                          :line-count line-count
                          :full true}))))))
      (let [refs (or self.buf.source-refs [])
            expansion-mode (or (and self.session self.session.expansion-mode) "none")
            file-filtered (apply-file-entry-filter
                            self.buf.indices
                            refs
                            self.file-query-lines
                            ignorecase
                            self.include-files
                            (> (# queries) 0))
            visible-source-indices (if (= expansion-mode "none")
                                       []
                                       (main-visible-source-indices self file-filtered prev-hits))
            expanded (expand_mod.expanded-indices
                       self.session
                       file-filtered
                       refs
                       {:mode expansion-mode
                        :read-file-lines-cached (or (and self.session self.session.read-file-lines-cached)
                                                    (fn [path _opts]
                                                      (vim.fn.readfile path)))
                        :around-lines (or vim.g.meta_context_around_lines 3)
                        :max-blocks (or vim.g.meta_context_max_blocks 24)
                        :visible-source-indices visible-source-indices})
            _ (set self.buf.indices expanded)
            _ (if (= (# self.buf.indices) 0)
                  (set self._no-hits-anchor-line anchor-line)
                  (set self._no-hits-anchor-line nil))
            hits-changed (if (= prev-hits self.buf.indices)
                             false
                             (if (~= (# prev-hits) (# self.buf.indices))
                                 true
                                 (not (vim.deep_equal prev-hits self.buf.indices))))
            needs-render? (or hits-changed broaden-on-delete? content-changed?)]
      (when needs-render?
        (self.buf.render))
      (set self._content-version-seen content-version)
      (when needs-render?
        (let [preferred-line (or (. self._selection-cache cache-key) anchor-line)
              preferred-rank (math.max 1 (math.min prev-rank (# self.buf.indices)))]
        (var idx nil)
        (if broaden-on-delete?
            (set idx preferred-rank)
            (do
              (each [i src (ipairs self.buf.indices)]
                (when (and (not idx) (= src preferred-line))
                  (set idx i)))
              (when-not idx
                (set idx (self.buf.closest-index preferred-line)))))
        (when idx
          (set self.selected_index (- idx 1))
          (set (. self._selection-cache cache-key)
               (line_of_index self.buf self.selected_index))
          (when (vim.api.nvim_win_is_valid self.win.window)
            (vim.api.nvim_win_set_cursor self.win.window [idx 0])))))
      ;; Render can refresh/clear syntax regions; re-apply match highlights
      ;; afterward so visible hit highlighting remains stable.
      (let [matcher (self.matcher)]
        ;; Ensure stale matchadd patterns from previously active matcher modes
        ;; never linger in the results window.
        (each [_ m (ipairs (. (. self.mode :matcher) :candidates))]
          (when (and m (~= m matcher))
            (m.remove-highlight m)))
        (let [highlight-max-hits
              (or vim.g.meta_highlight_max_hits 40000)]
        (if (or (= (# queries) 0) (>= (# self.buf.indices) highlight-max-hits))
            (matcher.remove-highlight matcher)
            (matcher.highlight matcher queries ignorecase self.win.window)))
      (apply-lgrep-highlights))))
    status)

  (fn self.on-term
    [status]
    (clear-all-highlights)
    (prompt-on-term status))

  ;; Backward compatibility for callers using underscore names.
  (set self.on_init self.on-init)
  (set self.on_redraw self.on-redraw)
  (set self.on_update self.on-update)

  (fn self.store
    []
    {:text self.text
     :caret-locus (self.caret.get-locus)
     :selected-index self.selected_index
     :matcher-index (. (. self.mode :matcher) :index)
     :case-index (. (. self.mode :case) :index)
     :syntax-index (. (. self.mode :syntax) :index)
     :restored true})

    self)))

M
