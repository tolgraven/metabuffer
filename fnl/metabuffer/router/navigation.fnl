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

(fn refresh-windows!
  [deps session force-refresh]
  (let [{: refresh : windows} deps
        update-preview-window (. refresh :preview!)
        update-info-window (. refresh :info!)
        context-window (. windows :context)]
    (when session
      (set session.selection-refresh-force?
           (or force-refresh session.selection-refresh-force?))
      (when-not session.selection-refresh-pending
        (set session.selection-refresh-pending true)
        (vim.schedule
          (fn []
            (set session.selection-refresh-pending false)
            (let [force-refresh? (not (not session.selection-refresh-force?))]
              (set session.selection-refresh-force? false)
              (when force-refresh?
                (schedule-source-syntax-refresh! deps session))
              (pcall session.meta.refresh_statusline)
              (when update-preview-window
                (pcall update-preview-window session))
              (when update-info-window
                (pcall update-info-window session true))
              (when (and context-window context-window.update!)
                (pcall context-window.update! session)))))))))

(fn sync-selection-state!
  [deps session row]
  (let [meta session.meta
        max (# meta.buf.indices)]
    (if (<= max 0)
        (set meta.selected_index 0)
        (let [target-row (math.max 1 (math.min row max))
              next-index (- target-row 1)]
          (set meta.selected_index next-index)))
    (refresh-windows! deps session false)))

(fn sync-selection-to-row!
  [deps session row]
  (let [meta session.meta
        max (# meta.buf.indices)]
    (sync-selection-state! deps session row)
    (when (> max 0)
      (let [target-row (math.max 1 (math.min row max))]
        (when (vim.api.nvim_win_is_valid meta.win.window)
          (let [cursor (vim.api.nvim_win_get_cursor meta.win.window)
                col (or (. cursor 2) 0)]
            (when (or (~= (. cursor 1) target-row)
                      (~= col 0))
              (pcall vim.api.nvim_win_set_cursor meta.win.window [target-row 0]))))))))

(fn M.move-selection!
  [deps prompt-buf delta]
  (let [active-by-prompt (. (. deps :router) :active-by-prompt)
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
                             (pcall vim.api.nvim_win_set_cursor meta.win.window [row 0]))))
                       (refresh-windows! deps session false)))
            mode (. (vim.api.nvim_get_mode) :mode)]
        (if (and (= (type mode) "string") (vim.startswith mode "i"))
            (vim.schedule runner)
            (runner))))))

(fn M.scroll-main!
  [deps prompt-buf action]
  (let [active-by-prompt (. (. deps :router) :active-by-prompt)
        animation-mod (. (. deps :mods) :animation)
        session (. active-by-prompt prompt-buf)]
	    (when (and session (vim.api.nvim_win_is_valid session.meta.win.window))
	      (let [runner (fn []
	                     (let [{:row target-row :animated animated?}
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
	                                     new-lnum (if (= 1 new-top)
                                                    1
                                                    (math.max 1 (math.min (+ new-top row-off) line-count)))
	                                     target {:topline new-top :lnum new-lnum :col old-col :leftcol (or (. view :leftcol) 0)}
                                       animate? (and animation-mod
                                                     (animation-mod.enabled? session :scroll)
                                                     (> (animation-mod.duration-ms session :scroll 140) 0)
                                                     (not (= step 1)))]
                                     (if (and animation-mod
                                              animate?)
                                         (animation-mod.animate-scroll-view!
	                                       session
	                                       "smooth-scroll"
	                                       session.meta.win.window
	                                       view
	                                       target
	                                       (animation-mod.duration-ms session :scroll 140))
	                                     (vim.fn.winrestview target))
		                                 {:row new-lnum :animated animate?})))]
                         ;; Scroll commands derive an absolute target row.
                         ;; Keep the model and dependent UI in sync immediately,
                         ;; but don't force the real cursor to the destination
                         ;; before an in-flight view animation has moved there.
                         (if animated?
                             (sync-selection-state! deps session target-row)
                             (sync-selection-to-row! deps session target-row))))
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
