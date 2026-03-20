(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local prompt_mod (require :metabuffer.prompt.prompt))
(local modeindexer (require :metabuffer.modeindexer))
(local state (require :metabuffer.core.state))
(local all_matcher (require :metabuffer.matcher.all))
(local fuzzy_matcher (require :metabuffer.matcher.fuzzy))
(local regex_matcher (require :metabuffer.matcher.regex))
(local meta_buffer_mod (require :metabuffer.buffer.metabuffer))
(local meta_window_mod (require :metabuffer.window.metawindow))
(local statusline_mod (require :metabuffer.window.statusline))
(local expand_mod (require :metabuffer.context.expand))

(local M {})
(local STATUS_PROGRESS (. prompt_mod :STATUS_PROGRESS))
(local state-cases (. state :cases))
(local state-syntax-types (. state :syntax-types))

(fn session-busy?
  [session]
  (and session
       (or session.prompt-update-pending
           session.prompt-update-dirty
           session.lazy-refresh-pending
           session.lazy-refresh-dirty
           session.project-bootstrap-pending
           (and session.project-mode
                (not session.project-bootstrapped)))))

(fn status-fragment
  [group text]
  (if (or (= (type text) "nil") (= text ""))
      ""
      (.. "%#" group "#" (string.gsub text "%%" "%%%%"))))

(fn project-flag-fragment
  [name on?]
  (.. (status-fragment "MetaStatuslineKey" (if on? "+" "-"))
      (status-fragment (if on? "MetaStatuslineFlagOn" "MetaStatuslineFlagOff") name)))

(fn loading-fragment
  [session]
  (if (and session
           session.loading-indicator?
           (session-busy? session))
      (let [word "Working"
            phase (or session.loading-anim-phase 0)
            center (+ 1 (% phase (# word)))
            out []]
        (for [i 1 (# word)]
          (let [dist (math.abs (- i center))
                hl (if (= dist 0)
                       "MetaLoading6"
                       (= dist 1)
                       "MetaLoading5"
                       (= dist 2)
                       "MetaLoading4"
                       (= dist 3)
                       "MetaLoading3"
                       (= dist 4)
                       "MetaLoading2"
                       "MetaLoading1")]
            (table.insert out (status-fragment hl (string.sub word i i)))))
        (table.concat out ""))
      ""))

(fn project-flags-fragment
  [session]
  (if (and session session.project-mode)
      (let [parts []
            flags [(project-flag-fragment "hidden" (not (not session.effective-include-hidden)))
                   (project-flag-fragment "ignored" (not (not session.effective-include-ignored)))
                   (project-flag-fragment "deps" (not (not session.effective-include-deps)))
                   (project-flag-fragment "file" (not (not session.effective-include-files)))
                   (project-flag-fragment "binary" (not (not session.effective-include-binary)))
                   (project-flag-fragment "hex" (not (not session.effective-include-hex)))
                   (project-flag-fragment "prefilter" (not (not session.prefilter-mode)))
                   (project-flag-fragment "lazy" (not (not session.lazy-mode)))]]
        (each [_ frag (ipairs flags)]
          (when (> (# frag) 0)
            (table.insert parts frag)))
        (table.concat parts (status-fragment "MetaStatuslineMiddle" "  ")))
      ""))

(fn results-statusline-left
  [self]
  (let [session self.session
        buf self.buf.buffer
        modified? (and buf
                       (vim.api.nvim_buf_is_valid buf)
                       (. vim.bo buf :modified))
        modified-fragment (if modified?
                              (status-fragment "MetaStatuslineIndicator" "[+]")
                              "")
        loading (loading-fragment session)
        debug (or self.debug_out "")
        parts []]
    (when (> (# modified-fragment) 0)
      (table.insert parts modified-fragment))
    (when (> (# loading) 0)
      (table.insert parts loading))
    (when (> (# debug) 0)
      (table.insert parts (status-fragment "MetaStatuslineIndicator" debug)))
    (if (= (# parts) 0)
        ""
        (.. " " (table.concat parts (status-fragment "MetaStatuslineMiddle" "  "))))))

(fn results-statusline-right
  [self]
  (let [flags (project-flags-fragment self.session)]
    (if (> (# flags) 0)
        (.. " " flags)
        "")))

(fn line_of_index
  [buf idx]
  (or (. buf.indices (+ idx 1)) 1))

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
        (not (not (string.find probe query 1 true))))))

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

(fn nerd-font-enabled?
  []
  (or (= (. vim.g "meta#nerd_font") true)
      (= (. vim.g "meta#nerd_font") 1)
      (= vim.g.have_nerd_font true)
      (= vim.g.have_nerd_font 1)
      (= vim.g.nerd_font true)
      (= vim.g.nerd_font 1)))

(fn statusline-mode-state
  []
  (let [m (or (. (vim.api.nvim_get_mode) :mode) "")]
    (if (vim.startswith m "R")
        {:group "Replace" :label (if (nerd-font-enabled?) "R" "Replace")}
        (vim.startswith m "i")
        {:group "Insert" :label (if (nerd-font-enabled?) "𝐈" "Insert")}
        {:group "Normal" :label (if (nerd-font-enabled?) "𝗡" "Normal")})))

(fn prompt-statusline-text
  [self]
  (let [mode-state (statusline-mode-state)
        matcher (. (self.matcher) :name)
        matcher-suffix (statusline_mod.title-case matcher)
        case-mode (self.case)
        case-suffix (statusline_mod.title-case case-mode)
        hl-prefix (if (= self.buf.syntax-type "meta") "Meta" "Buffer")]
    (string.format
      "%%#MetaStatuslineMode%s# %s %%#MetaStatuslineIndicator# %d/%d %%#MetaStatuslineMiddle#%%=%%#MetaStatuslineMatcher%s# %s %%#MetaStatuslineKey#%s%%#MetaStatuslineCase%s# %s %%#MetaStatuslineKey#%s%%#MetaStatuslineSyntax%s# %s %%#MetaStatuslineKey#%s "
      (. mode-state :group)
      (. mode-state :label)
      (# self.buf.indices)
      (self.buf.line-count)
      matcher-suffix matcher "C^"
      case-suffix case-mode "C-o"
      hl-prefix (self.syntax) "Cs")))

(fn highlight-pattern->vim-query
  [pat]
  (if (= (type pat) "string")
      pat
      (= (type pat) "table")
      (let [parts []]
        (each [_ item (ipairs pat)]
          (let [item-pat (or (. item :pattern) "")]
            (when (~= item-pat "")
              (table.insert parts item-pat))))
        (if (> (# parts) 0)
            (table.concat parts "\\|")
            ""))
      ""))

(fn bang-token-completed?
  [prev next]
  (let [prev0 (or prev "")
        next0 (or next "")
        prev-n (# prev0)
        next-n (# next0)]
    (and (> prev-n 0)
         (> next-n prev-n)
         (vim.startswith next0 prev0)
         (= (string.sub prev0 prev-n prev-n) "!")
         (let [before (if (> prev-n 1)
                          (string.sub prev0 (- prev-n 1) (- prev-n 1))
                          "")]
           (and (~= before "\\")
                (or (= prev-n 1)
                    (not (not (string.find before "%s"))))))
         (let [added (string.sub next0 (+ prev-n 1) (+ prev-n 1))]
           (not (not (string.find added "%S")))))))

(fn ends-with-space?
  [s]
  (let [txt (or s "")
        n (# txt)]
    (and (> n 0)
         (not (not (string.find (string.sub txt n n) "%s"))))))

(fn last-token
  [s]
  (let [txt (or s "")
        n (# txt)]
    (if (or (= n 0) (ends-with-space? txt))
        nil
        (let [start (or (string.match txt ".*()%s%S+$") 1)]
          (string.sub txt start)))))

(fn negation-growth-broadens?
  [prev next]
  (let [prev0 (or prev "")
        next0 (or next "")]
    (if (or (= prev0 "")
            (not (vim.startswith next0 prev0))
            (<= (# next0) (# prev0))
            (ends-with-space? prev0))
        false
        (let [prev-tok (or (last-token prev0) "")
              next-tok (or (last-token next0) "")
              same-token? (and (~= prev-tok "")
                               (vim.startswith next-tok prev-tok))
              unescaped-bang? (and (> (# prev-tok) 0)
                                   (= (string.sub prev-tok 1 1) "!")
                                   (not (vim.startswith prev-tok "\\!")))]
          (and same-token? unescaped-bang?)))))

(fn unescaped-negated-token?
  [tok]
  (let [t (or tok "")]
    (and (> (# t) 1)
         (= (string.sub t 1 1) "!")
         (not (vim.startswith t "\\!")))))

(fn deletion-broadens?
  [prev next]
  (let [prev0 (or prev "")
        next0 (or next "")]
    (if (or (= next0 "")
            (not (vim.startswith prev0 next0))
            (>= (# next0) (# prev0)))
        true
        (let [prev-tok (or (last-token prev0) "")
              next-tok (or (last-token next0) "")
              same-token? (and (~= prev-tok "")
                               (~= next-tok "")
                               (vim.startswith prev-tok next-tok))
              negation-shrink? (and same-token?
                                    (unescaped-negated-token? prev-tok)
                                    (unescaped-negated-token? next-tok))]
          (not negation-shrink?)))))

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

  (set self.win (meta_window_mod.new nvim (vim.api.nvim_get_current_win)))
  (set self.status-win self.win)
  (set self.buf (meta_buffer_mod.new nvim (vim.api.nvim_get_current_buf)))
  (set self._filter-cache {})
  (set self._filter-cache-line-count (# self.buf.content))
    (let [prompt-on-term self.on-term]
      (fn clear-all-highlights
        []
        (let [matcher-mode (. self.mode :matcher)]
          (when matcher-mode
            (each [_ m (ipairs matcher-mode.candidates)]
              (when m
                (pcall m.remove-highlight m))))))

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
          (set self.text (table.concat active " && "))))

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
            pat (highlight-pattern->vim-query pat0)]
        (if (= pat "")
            ""
            (.. caseprefix pat))))))

      (fn self.refresh_statusline
        []
        (let [mode-state (statusline-mode-state)
              hl-prefix (if (= self.buf.syntax-type "meta") "Meta" "Buffer")]
          (self.status-win.set-statusline-state
            (. mode-state :group)
            (. mode-state :label)
            self.buf.name
            (# self.buf.indices)
            (self.buf.line-count)
            (self.selected_line)
            (results-statusline-left self)
            (results-statusline-right self)
            (. (self.matcher) :name)
            (self.case)
            hl-prefix
            (self.syntax))
          (when (and self.session
                     self.session.prompt-win
                     (vim.api.nvim_win_is_valid self.session.prompt-win))
            (pcall vim.api.nvim_set_option_value
                   "statusline"
                   (prompt-statusline-text self)
                   {:win self.session.prompt-win}))
          (vim.cmd "redrawstatus")))

      (fn self.on-init
        []
        (self.buf.set-name (if self.project-mode
                               (project-display-name)
                               (metabuffer-display-name self.buf.model)))
        (let [init-syntax (or (. vim.g "meta#syntax_on_init") "buffer")]
          (self.buf.apply-syntax (if (= init-syntax "meta") "meta" "buffer")))
        (set self.buf.visible-source-syntax-only (not (not cond.project-mode)))
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
          reset0? (or (= prev-text "")
                      (not (vim.startswith self.text prev-text))
                      (bang-token-completed? prev-text self.text)
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
                             (not (negation-growth-broadens? prev-text self.text))
                             (> (# prev-text) 0)
                             (> (# self.text) (# prev-text))
                             (<= (# prev-hits) narrow-reuse-threshold))
          shortened? (< (# self.text) (# prev-text))
          broaden-on-delete? (and shortened? (deletion-broadens? prev-text self.text))
          reset? (and reset0?
                      (not narrow-reuse?)
                      (or (not shortened?)
                          broaden-on-delete?))]
      (set (. self._selection-cache prev-cache-key) prev-line)
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
                  (let [next (vim.deepcopy cached)]
                  (when (< cached-line-count line-count)
                    (let [added0 []]
                      (var added added0)
                      (for [i (+ cached-line-count 1) line-count]
                        (table.insert added i))
                      (each [_ q (ipairs queries)]
                        (set added (matcher.filter matcher q added self.buf.content ignorecase)))
                      (each [_ idx (ipairs added)]
                        (table.insert next idx))
                      (set cached-line-count line-count)))
                  ;; Copy cached indices so future incremental updates cannot
                  ;; accidentally mutate cache entries by reference.
                  (set self.buf.indices (vim.deepcopy next))
                  (set (. self._filter-cache cache-key)
                       {:indices (vim.deepcopy next)
                        :line-count line-count
                        :full true})))
                (do
                  (var first reset?)
                  (each [_ q (ipairs queries)]
                    (self.buf.run-filter matcher q ignorecase first self.win.window)
                    (set first false))
                  (when reset?
                    (set (. self._filter-cache cache-key)
                         {:indices (vim.deepcopy self.buf.indices)
                          :line-count line-count
                          :full true}))))))
      (let [refs (or self.buf.source-refs [])
            file-filtered (apply-file-entry-filter
                            self.buf.indices
                            refs
                            self.file-query-lines
                            ignorecase
                            self.include-files
                            (> (# queries) 0))
            expanded (expand_mod.expanded-indices
                       self.session
                       file-filtered
                       refs
                       {:mode (or (and self.session self.session.expansion-mode) "none")
                        :read-file-lines-cached (or (and self.session self.session.read-file-lines-cached)
                                                    (fn [path _opts]
                                                      (vim.fn.readfile path)))
                        :around-lines (or vim.g.meta_context_around_lines 3)
                        :max-blocks (or vim.g.meta_context_max_blocks 24)})
            _ (set self.buf.indices expanded)
            hits-changed (if (= prev-hits self.buf.indices)
                             false
                             (if (~= (# prev-hits) (# self.buf.indices))
                                 true
                                 (not (vim.deep_equal prev-hits self.buf.indices))))
            needs-render? (or hits-changed broaden-on-delete?)]
      (when needs-render?
        (self.buf.render))
      (when needs-render?
        (let [preferred-line (or (. self._selection-cache cache-key) prev-line)
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
            (matcher.highlight matcher effective-query ignorecase self.win.window))))))
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
