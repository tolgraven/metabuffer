(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local prompt_mod (require :metabuffer.prompt.prompt))
(local prompt_action_mod (require :metabuffer.prompt.action))
(local modeindexer (require :metabuffer.modeindexer))
(local state (require :metabuffer.core.state))
(local all_matcher (require :metabuffer.matcher.all))
(local fuzzy_matcher (require :metabuffer.matcher.fuzzy))
(local regex_matcher (require :metabuffer.matcher.regex))
(local meta_buffer_mod (require :metabuffer.buffer.metabuffer))
(local meta_window_mod (require :metabuffer.window.metawindow))
(local util (require :metabuffer.util))

(local M {})

(fn line_of_index [buf idx]
  (or (. buf.indices (+ idx 1)) 1))

(fn metabuffer-display-name [model-buf]
  (let [original-name (vim.api.nvim_buf_get_name model-buf)
        base-name (if (and (= (type original-name) "string") (~= original-name ""))
                      (vim.fn.fnamemodify original-name ":t")
                      "[No Name]")]
    (.. base-name " • Metabuffer")))

(fn project-display-name []
  "Metabuffer")

(fn nerd-font-enabled? []
  (or (= (. vim.g "meta#nerd_font") true)
      (= (. vim.g "meta#nerd_font") 1)
      (= vim.g.have_nerd_font true)
      (= vim.g.have_nerd_font 1)
      (= vim.g.nerd_font true)
      (= vim.g.nerd_font 1)))

(fn statusline-mode-state []
  (let [m (or (. (vim.api.nvim_get_mode) :mode) "")]
    (if (vim.startswith m "R")
        {:group "Replace" :label (if (nerd-font-enabled?) "R" "Replace")}
        (vim.startswith m "i")
        {:group "Insert" :label (if (nerd-font-enabled?) "𝐈" "Insert")}
        {:group "Normal" :label (if (nerd-font-enabled?) "𝗡" "Normal")})))

(fn M.new [nvim condition]
  (local cond (or condition (state.default-condition "")))
  (local self (prompt_mod.new nvim))

  (set self.condition cond)
  (set self.selected_index (or cond.selected-index 0))
  (set self._prev_text "")
  (set self.updates 0)
  (set self.debug_out "")
  (set self.prefix "# ")
  (set self.query-lines [])
  (set self._prev-ignorecase nil)
  (set self._prev-matcher nil)

  (set self.action prompt_action_mod.DEFAULT_ACTION)

  (set self.win (meta_window_mod.new nvim (vim.api.nvim_get_current_win)))
  (set self.status-win self.win)
  (set self.buf (meta_buffer_mod.new nvim (vim.api.nvim_get_current_buf)))
  (set self._filter-cache {})
  (set self._filter-cache-line-count (# self.buf.content))
  (local prompt-on-term self.on-term)
  (fn clear-all-highlights []
    (let [matcher-mode (. self.mode :matcher)]
      (when matcher-mode
        (each [_ m (ipairs matcher-mode.candidates)]
          (when m
            (pcall m.remove-highlight m))))))

  (set self.mode
       {:matcher (modeindexer.new [(all_matcher.new) (fuzzy_matcher.new) (regex_matcher.new)]
                                  (or cond.matcher-index 1)
                                  {:on-leave "remove-highlight"})
        :case (modeindexer.new state.cases (or cond.case-index 1) nil)
        :syntax (modeindexer.new state.syntax-types (or cond.syntax-index 1)
                                 {:on-active (fn [idx]
                                               (self.buf.apply-syntax
                                                (if (= (idx.current) "meta") "meta" "buffer")))})})

  (set self.text (or cond.text ""))
  (when (~= self.text "")
    (set self.query-lines [self.text]))
  (self.caret.set-locus (or cond.caret-locus (# self.text)))

  (fn self.matcher []
    ((. (. self.mode :matcher) :current)))

  (fn self.case []
    ((. (. self.mode :case) :current)))

  (fn self.syntax []
    ((. (. self.mode :syntax) :current)))

  (fn self.ignorecase []
    (state.ignorecase (self.case) self.text))

  (fn self.active-queries []
    (local out [])
    (each [_ line (ipairs (or self.query-lines []))]
      (when (and (= (type line) "string") (~= (vim.trim line) ""))
        (table.insert out (vim.trim line))))
    out)

  (fn self.set-query-lines [lines]
    (set self.query-lines (or lines []))
    (local active (self.active-queries))
    (set self.text (table.concat active " && ")))

  (fn self.selected_line []
    (line_of_index self.buf self.selected_index))

  (fn self.switch_mode [which]
    (let [mode_obj (. self.mode which)]
      (mode_obj.next)
      (set self._prev_text "")
      (self.on-update prompt_mod.STATUS_PROGRESS)))

  (fn self.vim_query []
    (let [active (self.active-queries)
          q (. active (# active))]
      (if (or (not q) (= q ""))
      ""
      (let [caseprefix (if (self.ignorecase) "\\c" "\\C")
            matcher_obj (self.matcher)
            pat (matcher_obj.get-highlight-pattern matcher_obj q)]
        (.. caseprefix pat)))))

  (fn self.refresh_statusline []
    (local mode-state (statusline-mode-state))
    (local hl_prefix (if (= self.buf.syntax-type "meta") "Meta" "Buffer"))
    (self.status-win.set-statusline-state
      (. mode-state :group)
      (. mode-state :label)
      self.buf.name
      (# self.buf.indices)
      (self.buf.line-count)
      (self.selected_line)
      self.debug_out
      (. (self.matcher) :name)
      (self.case)
      hl_prefix
      (self.syntax))
    (vim.cmd "redrawstatus"))

  (fn self.on-init []
    (self.buf.set-name (if self.project-mode
                           (project-display-name)
                           (metabuffer-display-name self.buf.model)))
    (local init-syntax (or (. vim.g "meta#syntax_on_init") "buffer"))
    (self.buf.apply-syntax (if (= init-syntax "meta") "meta" "buffer"))
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
    prompt_mod.STATUS_PROGRESS)

  (fn self.on-redraw []
    (self.refresh_statusline)
    (self.redraw-prompt)
    prompt_mod.STATUS_PROGRESS)

  (fn self.on-update [status]
    (let [queries (self.active-queries)
          prev-text self._prev_text
          prev-hits self.buf.indices
          prev-line (line_of_index self.buf self.selected_index)
          matcher-name (. (self.matcher) :name)
          ignorecase (self.ignorecase)
          line-count (# self.buf.content)
          cache-grew? (> line-count self._filter-cache-line-count)
          cache-shrank? (< line-count self._filter-cache-line-count)
          cache-reset? cache-shrank?
          cache-key (.. matcher-name "|" (if ignorecase "1" "0") "|" (table.concat queries "\n"))
          reset? (or (= prev-text "")
                     (not (vim.startswith self.text prev-text))
                     ;; When backing cache is stale and we cannot reuse a cached
                     ;; query entry, recompute from full set to include new lines.
                     cache-grew?
                     cache-reset?
                     (~= self._prev-ignorecase ignorecase)
                     (~= self._prev-matcher matcher-name))]
      (when cache-reset?
        (set self._filter-cache {})
        (set self._filter-cache-line-count line-count))
      (when cache-grew?
        (set self._filter-cache-line-count line-count))
      (set self._prev_text self.text)
      (set self._prev-ignorecase ignorecase)
      (set self._prev-matcher matcher-name)
      (set self.updates (+ self.updates 1))
      (if (= (# queries) 0)
          (do
            (self.buf.reset-filter)
            (clear-all-highlights))
          (let [cached0 (. self._filter-cache cache-key)
                cached-obj? (and (= (type cached0) "table")
                                 (= (type (. cached0 :indices)) "table"))
                cached (if cached-obj?
                           (. cached0 :indices)
                           (when (= (type cached0) "table") cached0))
                cached-line-count0 (if cached-obj?
                                       (or (. cached0 :line-count) line-count)
                                       self._filter-cache-line-count)
                matcher (self.matcher)]
            (if cached
                (do
                  (var cached-line-count cached-line-count0)
                  ;; Extend cached results incrementally when project streaming
                  ;; appended lines since this cache entry was materialized.
                  (local next (vim.deepcopy cached))
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
                       {:indices (vim.deepcopy next) :line-count line-count}))
                (do
                  (var first reset?)
                  (each [_ q (ipairs queries)]
                    (self.buf.run-filter matcher q ignorecase first self.win.window)
                    (set first false))
                  (set (. self._filter-cache cache-key)
                       {:indices (vim.deepcopy self.buf.indices)
                        :line-count line-count})))))
      (local hits-changed (if (= prev-hits self.buf.indices)
                              false
                              (if (~= (# prev-hits) (# self.buf.indices))
                                  true
                                  (not (vim.deep_equal prev-hits self.buf.indices)))))
      (when hits-changed
        (self.buf.render))
      (when hits-changed
        (var idx nil)
        (each [i src (ipairs self.buf.indices)]
          (when (and (not idx) (= src prev-line))
            (set idx i)))
        (when (not idx)
          (set idx (self.buf.closest-index prev-line)))
        (when idx
          (set self.selected_index (- idx 1))
          (when (vim.api.nvim_win_is_valid self.win.window)
            (vim.api.nvim_win_set_cursor self.win.window [idx 0]))))
      ;; Render can refresh/clear syntax regions; re-apply match highlights
      ;; afterward so visible hit highlighting remains stable.
      (let [matcher (self.matcher)]
        (if (or (= (# queries) 0) (>= (# self.buf.indices) 1000))
            (matcher.remove-highlight matcher)
            (matcher.highlight matcher self.text ignorecase self.win.window))))
    status)

  (fn self.on-term [status]
    (clear-all-highlights)
    (prompt-on-term status))

  ;; Backward compatibility for callers using underscore names.
  (set self.on_init self.on-init)
  (set self.on_redraw self.on-redraw)
  (set self.on_update self.on-update)

  (fn self.store []
    {:text self.text
     :caret-locus (self.caret.get-locus)
     :selected-index self.selected_index
     :matcher-index (. (. self.mode :matcher) :index)
     :case-index (. (. self.mode :case) :index)
     :syntax-index (. (. self.mode :syntax) :index)
     :restored true})

  self)

M
