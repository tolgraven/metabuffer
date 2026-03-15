(import-macros {: when-not} :io.gitlab.andreyorst.cljlib.core)

(local M {})

(fn can-refresh-source-syntax?
  [session]
  (let [buf (and session session.meta session.meta.buf)]
    (and session
         session.project-mode
         buf
         buf.show-source-separators
         buf.visible-source-syntax-only
         (= buf.syntax-type "buffer"))))

(fn schedule-source-syntax-refresh!
  [deps session]
  (let [{: router : timing} deps
        active-by-prompt (. router :active-by-prompt)
        source-syntax-refresh-debounce-ms (. timing :source-syntax-refresh-debounce-ms)]
    (when (can-refresh-source-syntax? session)
    (set session.syntax-refresh-dirty true)
    (when-not session.syntax-refresh-pending
      (set session.syntax-refresh-pending true)
      (vim.defer_fn
        (fn []
          (set session.syntax-refresh-pending false)
          (when (and session
                     session.prompt-buf
                     (= (. active-by-prompt session.prompt-buf) session))
            (when session.syntax-refresh-dirty
              (set session.syntax-refresh-dirty false)
              (pcall session.meta.buf.apply-source-syntax-regions))
            ;; If additional scroll events arrived while refreshing, ensure we
            ;; run one trailing update.
            (when session.syntax-refresh-dirty
              (schedule-source-syntax-refresh! deps session))))
        (or source-syntax-refresh-debounce-ms 80))))))

(fn M.move-selection!
  [deps prompt-buf delta]
  (let [{: router : refresh : windows} deps
        active-by-prompt (. router :active-by-prompt)
        update-preview-window (. refresh :preview!)
        update-info-window (. refresh :info!)
        context-window (. windows :context)
        session (. active-by-prompt prompt-buf)]
    (when session
      (let [runner (fn []
                     (let [meta session.meta
                           max (# meta.buf.indices)]
                       (when (> max 0)
                         (set meta.selected_index
                              (math.max 0 (math.min (+ meta.selected_index delta) (- max 1))))
                         (let [row (+ meta.selected_index 1)]
                           (when (vim.api.nvim_win_is_valid meta.win.window)
                             (pcall vim.api.nvim_win_set_cursor meta.win.window [row 0])))
                         (pcall meta.refresh_statusline)
                         (when update-preview-window
                           (pcall update-preview-window session))
                         (pcall update-info-window session false)
                         (when (and context-window context-window.update!)
                           (pcall context-window.update! session)))))
            mode (. (vim.api.nvim_get_mode) :mode)]
        (if (and (= (type mode) "string") (vim.startswith mode "i"))
            (vim.schedule runner)
            (runner))))))

(fn M.scroll-main!
  [deps prompt-buf action]
  (let [{: router : refresh : windows : mods} deps
        active-by-prompt (. router :active-by-prompt)
        update-preview-window (. refresh :preview!)
        update-info-window (. refresh :info!)
        context-window (. windows :context)
        session-view (. mods :session-view)
        animation-mod (. mods :animation)
        session (. active-by-prompt prompt-buf)]
	    (when (and session (vim.api.nvim_win_is_valid session.meta.win.window))
	      (let [runner (fn []
	                     (let [target-row
	                           (vim.api.nvim_win_call
	                             session.meta.win.window
	                             (fn []
	                               (let [line-count (vim.api.nvim_buf_line_count session.meta.buf.buffer)
	                                     win-height (math.max 1 (vim.api.nvim_win_get_height session.meta.win.window))
	                                     half-step (math.max 1 (math.floor (/ win-height 2)))
	                                     page-step (math.max 1 (- win-height 2))
	                                     step (if (or (= action "line-down") (= action "line-up"))
	                                              1
	                                              (or (= action "half-down") (= action "half-up"))
	                                              half-step
	                                              page-step)
	                                     dir (if (or (= action "line-down") (= action "half-down") (= action "page-down")) 1 -1)
	                                     max-top (math.max 1 (+ (- line-count win-height) 1))
	                                     view (vim.fn.winsaveview)
	                                     old-top (. view :topline)
	                                     old-lnum (. view :lnum)
	                                     old-col (or (. view :col) 0)
	                                     row-off (math.max 0 (- old-lnum old-top))
	                                     new-top (math.max 1 (math.min (+ old-top (* dir step)) max-top))
	                                     new-lnum (math.max 1 (math.min (+ new-top row-off) line-count))
	                                     target {:topline new-top :lnum new-lnum :col old-col :leftcol (or (. view :leftcol) 0)}]
	                                 (if (and animation-mod
	                                          (animation-mod.enabled? session :scroll)
	                                          (> (animation-mod.duration-ms session :scroll 140) 0)
	                                          (not (= step 1)))
	                                     (animation-mod.animate-view!
	                                       session
	                                       "smooth-scroll"
	                                       session.meta.win.window
	                                       view
	                                       target
	                                       (animation-mod.duration-ms session :scroll 140))
	                                     (vim.fn.winrestview target))
	                                 new-lnum)))]
	                       ;; Keep selection-dependent UI in sync with the target row
	                       ;; even when the scroll uses animation frames.
	                       (set session.meta.selected_index
	                            (math.max 0 (math.min (- target-row 1)
	                                                  (math.max 0 (- (# session.meta.buf.indices) 1)))))
	                       (pcall session.meta.refresh_statusline)
	                       (when update-preview-window
	                         (pcall update-preview-window session))
	                       (pcall update-info-window session false)
	                       (when (and context-window context-window.update!)
	                         (pcall context-window.update! session))))
	            mode (. (vim.api.nvim_get_mode) :mode)]
	        (if (and (= (type mode) "string") (vim.startswith mode "i"))
	            (vim.schedule runner)
            (runner))))))

(fn M.maybe-sync-from-main!
  [deps session force-refresh]
  (let [{: router : refresh : windows : mods} deps
        active-by-prompt (. router :active-by-prompt)
        update-preview-window (. refresh :preview!)
        update-info-window (. refresh :info!)
        context-window (. windows :context)
        session-view (. mods :session-view)]
    (session-view.maybe-sync-from-main!
    session
    force-refresh
    {:active-by-prompt active-by-prompt
     :schedule-source-syntax-refresh! (fn [s]
                                        (schedule-source-syntax-refresh! deps s))
     :update-preview-window! update-preview-window
     :update-info-window update-info-window
     :update-context-window! (fn [s]
                               (when (and context-window context-window.update!)
                                 (context-window.update! s)))})))

(fn M.schedule-scroll-sync!
  [deps session]
  (let [{: timing : mods} deps
        scroll-sync-debounce-ms (. timing :scroll-sync-debounce-ms)
        session-view (. mods :session-view)]
    (session-view.schedule-scroll-sync!
    session
    {:scroll-sync-debounce-ms scroll-sync-debounce-ms
     :maybe-sync-from-main! (fn [s force-refresh]
                              (M.maybe-sync-from-main! deps s force-refresh))})))

M
