(local prompt_mod (require :metabuffer.prompt.prompt))
(local prompt_action_mod (require :metabuffer.prompt.action))
(local modeindexer (require :metabuffer.modeindexer))
(local state (require :metabuffer.core.state))
(local action (require :metabuffer.action))
(local all_matcher (require :metabuffer.matcher.all))
(local fuzzy_matcher (require :metabuffer.matcher.fuzzy))
(local regex_matcher (require :metabuffer.matcher.regex))
(local meta_buffer_mod (require :metabuffer.buffer.metabuffer))
(local meta_window_mod (require :metabuffer.window.metawindow))
(local util (require :metabuffer.util))

(local M {})

(fn line_of_index [buf idx]
  (or (. buf.indices (+ idx 1)) 1))

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

  (set self.action prompt_action_mod.DEFAULT_ACTION)
  (self.action.register_from_rules action.DEFAULT_ACTION_RULES)
  (self.keymap.register_from_rules nvim action.DEFAULT_ACTION_KEYMAP)
  (when (= (type (. vim.g "meta#custom_mappings")) "table")
    (self.keymap.register_from_rules nvim (. vim.g "meta#custom_mappings")))

  (set self.win (meta_window_mod.new nvim (vim.api.nvim_get_current_win)))
  (set self.status-win self.win)
  (set self.buf (meta_buffer_mod.new nvim (vim.api.nvim_get_current_buf)))
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
                                                (if (= (idx.current) "meta") "meta" nil)))})})

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
    (local mode_name (if (= self.insert-mode prompt_mod.INSERT_MODE_REPLACE) "replace" "insert"))
    (local hl_prefix (if (= self.buf.syntax-type "meta") "Meta" "Buffer"))
    (self.status-win.set-statusline-state
      (string.upper (string.sub mode_name 1 1))
      "# " self.text
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
    (local init-syntax (or (. vim.g "meta#syntax_on_init") "buffer"))
    (self.buf.apply-syntax (if (= init-syntax "meta") "meta" "buffer"))
    (clear-all-highlights)
    (self.buf.render)
    (let [line (math.max 1 (math.min (+ self.selected_index 1) (vim.api.nvim_buf_line_count self.buf.buffer)))]
      (when (vim.api.nvim_win_is_valid self.win.window)
        (vim.api.nvim_win_set_cursor self.win.window [line 0])))
    prompt_mod.STATUS_PROGRESS)

  (fn self.on-redraw []
    (self.refresh_statusline)
    (self.redraw-prompt)
    prompt_mod.STATUS_PROGRESS)

  (fn self.on-update [status]
    (let [queries (self.active-queries)
          prev_text self._prev_text
          prev_hits (util.deepcopy self.buf.indices)
          prev_line (line_of_index self.buf self.selected_index)
          _reset_if (or (= prev_text "") (not (vim.startswith self.text prev_text)))]
      (set self._prev_text self.text)
      (set self.updates (+ self.updates 1))
      (if (= (# queries) 0)
          (do
            (self.buf.reset-filter)
            (clear-all-highlights))
          (do
            (var first true)
            (each [_ q (ipairs queries)]
              (self.buf.run-filter (self.matcher) q (self.ignorecase) first self.win.window)
              (set first false))))
      (self.buf.render)
      (when (not (vim.deep_equal prev_hits self.buf.indices))
        (var idx nil)
        (each [i src (ipairs self.buf.indices)]
          (when (and (not idx) (= src prev_line))
            (set idx i)))
        (when (not idx)
          (set idx (self.buf.closest-index prev_line)))
        (when idx
          (set self.selected_index (- idx 1))
          (when (vim.api.nvim_win_is_valid self.win.window)
            (vim.api.nvim_win_set_cursor self.win.window [idx 0])))))
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
