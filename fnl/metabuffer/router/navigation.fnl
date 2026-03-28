(import-macros {: when-not} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local events (require :metabuffer.events))

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

(fn hide-scroll-cursor!
  [session]
  (when (and session (not session.scroll-cursor-hidden?))
    (let [[ok current] [(pcall vim.api.nvim_get_option_value "guicursor" {:scope "global"})]]
      (set session.scroll-saved-guicursor (if ok current vim.o.guicursor))
      (set session.scroll-cursor-hidden? true)
      (pcall vim.api.nvim_set_option_value "guicursor" "a:ver0" {:scope "global"}))))

(fn restore-scroll-cursor!
  [session]
  (when (and session session.scroll-cursor-hidden?)
    (let [value (or session.scroll-saved-guicursor vim.o.guicursor)]
      (set session.scroll-cursor-hidden? false)
      (set session.scroll-saved-guicursor nil)
      (pcall vim.api.nvim_set_option_value "guicursor" value {:scope "global"}))))

(fn apply-source-syntax-refresh!
  [session]
  (when (can-refresh-source-syntax? session)
    (pcall session.meta.buf.apply-source-syntax-regions)))

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
                (apply-source-syntax-refresh! session))
              ;; If additional scroll events arrived while refreshing, ensure we
              ;; run one trailing update.
              (when session.syntax-refresh-dirty
                (schedule-source-syntax-refresh! deps session))))
        (or source-syntax-refresh-debounce-ms 80))))))

(fn M.refresh-source-syntax!
  [deps session immediate?]
  (if immediate?
      (apply-source-syntax-refresh! session)
      (schedule-source-syntax-refresh! deps session)))

(fn refresh-windows!
  [deps session force-refresh]
  (let [{: router} deps
        timing (or (. deps :timing) {})
        active-by-prompt (. router :active-by-prompt)
        selection-refresh-debounce-ms (or (. timing :selection-refresh-debounce-ms) 12)]
    (when session
      (set session.selection-refresh-force?
           (or force-refresh session.selection-refresh-force?))
      (set session.selection-refresh-token
           (+ 1 (or session.selection-refresh-token 0)))
      (when-not session.selection-refresh-pending
        (set session.selection-refresh-pending true)
        (vim.defer_fn
          (fn []
            (set session.selection-refresh-pending false)
            (when (and session
                       session.prompt-buf
                       (= (. active-by-prompt session.prompt-buf) session))
              (let [token session.selection-refresh-token
                    force-refresh? (clj.boolean session.selection-refresh-force?)]
                (set session.selection-refresh-force? false)
                (when (= token session.selection-refresh-token)
                  (events.send :on-selection-change!
                    {:session session
                     :line-nr (+ 1 (or session.meta.selected_index 0))
                     :force-refresh? force-refresh?
                     :refresh-lines true}))
                (restore-scroll-cursor! session)
                (when (~= token session.selection-refresh-token)
                  (refresh-windows! deps session false)))))
          selection-refresh-debounce-ms)))))

(fn set-selected-index!
  [session row]
  (let [meta session.meta
        max (# meta.buf.indices)]
    (if (<= max 0)
        (set meta.selected_index 0)
        (let [target-row (math.max 1 (math.min row max))
              next-index (- target-row 1)]
          (set meta.selected_index next-index)))))

(fn sync-selection-state!
  [deps session row]
  (set-selected-index! session row)
  (refresh-windows! deps session false))

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

(fn effective-scroll-target
  [win restore-view target]
  "Resolve the effective final winsaveview after Neovim applies window constraints."
  (vim.api.nvim_win_call
    win
    (fn []
      (let [original (vim.deepcopy restore-view)]
        (pcall vim.fn.winrestview target)
        (let [effective (vim.fn.winsaveview)]
          (pcall vim.fn.winrestview original)
          effective)))))

(fn scroll-command-text
  [action]
  "Return a normal-mode scroll command for the given Meta scroll action."
  (if (= action "line-down")
      "\5"
      (if (= action "line-up")
          "\25"
          (if (= action "half-down")
              "\4"
              (if (= action "half-up")
                  "\21"
                  (if (= action "page-down")
                      "\6"
                      "\2"))))))

(fn M.move-selection!
  [deps prompt-buf delta]
  (let [active-by-prompt (. (. deps :router) :active-by-prompt)
        session (. active-by-prompt prompt-buf)]
    (when session
      (let [runner (fn []
                    (hide-scroll-cursor! session)
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
      (let [runner
            (fn []
              (hide-scroll-cursor! session)
              (let [return-win (vim.api.nvim_get_current_win)
                    return-mode (. (vim.api.nvim_get_mode) :mode)
                    result
                    (vim.api.nvim_win_call
                      session.meta.win.window
                      (fn []
                        (let [line-count (vim.api.nvim_buf_line_count session.meta.buf.buffer)
                              win-height (math.max 1 (vim.api.nvim_win_get_height session.meta.win.window))
                              half-step (math.max 1 (math.floor (/ win-height 2)))
                              page-step (math.max 1 (- win-height 2))
                              step (if (or (= action "line-down") (= action "line-up"))
                                       1
                                       (if (or (= action "half-down") (= action "half-up"))
                                           half-step
                                           page-step))
                              dir (if (or (= action "line-down") (= action "half-down") (= action "page-down")) 1 -1)
                              max-top (math.max 1 (+ (- line-count win-height) 1))
                              view (vim.fn.winsaveview)
                              logical-view (or session.scroll-command-view view)
                              old-top (. logical-view :topline)
                              old-lnum (. logical-view :lnum)
                              old-col (or (. logical-view :col) 0)
                              new-top0 (math.max 1 (math.min (+ old-top (* dir step)) max-top))
                              new-lnum0 (math.max 1 (math.min (+ old-lnum (* dir step)) line-count))
                              ;; Clamp: if the boundary is closer than the
                              ;; computed target, snap there instead.
                              new-lnum (if (and (= dir -1)
                                                (< (- old-lnum 1) (- old-lnum new-lnum0)))
                                           1
                                           (and (= dir 1)
                                                (< (- line-count old-lnum) (- new-lnum0 old-lnum)))
                                           line-count
                                           new-lnum0)
                              new-top (if (= new-lnum 1)
                                         1
                                         (= new-lnum line-count)
                                         max-top
                                         new-top0)
                              target0 {:topline new-top :lnum new-lnum :col old-col :leftcol (or (. logical-view :leftcol) 0)}
                              target (effective-scroll-target session.meta.win.window view target0)
                              animate? (and animation-mod
                                            (animation-mod.enabled? session :scroll)
                                            (> (animation-mod.duration-ms session :scroll 140) 0)
                                            (not (= step 1)))
                              mini-scroll? (and animate?
                                                (= (animation-mod.animation-backend session :scroll) "mini")
                                                (animation-mod.supports-backend? "mini"))
                              finish! (fn []
                                        (when (and session
                                                   session.prompt-buf
                                                   (= (. active-by-prompt session.prompt-buf) session))
                                          (set session.scroll-animating? false)
                                          (set session.scroll-command-view nil)
                                          (M.maybe-sync-from-main! deps session true)
                                          (restore-scroll-cursor! session)))]
                          (set session.scroll-command-view target)
                          (if mini-scroll?
                              (do
                                (set session.scroll-animating? true)
                                (animation-mod.animate-scroll-action-mini!
                                  session
                                  session.meta.win.window
                                  (animation-mod.duration-ms session :scroll 140)
                                  (fn []
                                    (vim.cmd (.. "normal! " (scroll-command-text action))))
                                  {:return-win return-win
                                   :return-mode return-mode
                                   :done! finish!})
                                {:row (or (. target :lnum) new-lnum) :animated true})
                              (if animate?
                                  (do
                                    (set session.scroll-animating? true)
                                    (animation-mod.animate-scroll-view!
                                      session
                                      "smooth-scroll"
                                      session.meta.win.window
                                      view
                                      target
                                      (animation-mod.duration-ms session :scroll 140)
                                      {:return-win return-win
                                       :return-mode return-mode
                                       :done! finish!})
                                    {:row (or (. target :lnum) new-lnum) :animated true})
                                  (do
                                    (vim.fn.winrestview target)
                                    (set session.scroll-animating? false)
                                    (set session.scroll-command-view nil)
                                    {:row (or (. target :lnum) new-lnum) :animated false}))))))
                    target-row (. result :row)
                    animated? (. result :animated)]
                (if animated?
                    (do
                      (set-selected-index! session target-row)
                      (events.send :on-selection-change!
                        {:session session
                         :line-nr (+ 1 (or session.meta.selected_index 0))
                         :refresh-lines false}))
                    (sync-selection-to-row! deps session target-row))))]
        (let [mode (. (vim.api.nvim_get_mode) :mode)]
          (if (and (= (type mode) "string") (vim.startswith mode "i"))
              (vim.schedule runner)
              (runner)))))))

(fn M.maybe-sync-from-main!
  [deps session force-refresh]
  (let [{: router : mods} deps
        active-by-prompt (. router :active-by-prompt)
        session-view (. mods :session-view)]
    (session-view.maybe-sync-from-main!
    session
    force-refresh
    {:active-by-prompt active-by-prompt
     :schedule-source-syntax-refresh! (fn [s]
                                        (schedule-source-syntax-refresh! deps s))})))

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
