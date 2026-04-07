(import-macros {: when-not} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local events (require :metabuffer.events))
(local util (require :metabuffer.util))

(local M {})

(fn session-active-for-prompt?
  [active-by-prompt session]
  (and session
       session.prompt-buf
       (= (. active-by-prompt session.prompt-buf) session)))

(fn results-window-valid?
  [session]
  (and session
       session.meta
       session.meta.win
       (vim.api.nvim_win_is_valid session.meta.win.window)))

(fn current-mode-insert?
  []
  (let [mode (. (vim.api.nvim_get_mode) :mode)]
    (and (= (type mode) "string") (vim.startswith mode "i"))))

(fn run-mode-safe!
  [runner]
  (if (current-mode-insert?)
      (vim.schedule runner)
      (runner)))

(fn can-refresh-source-syntax?
  [session include-full?]
  (let [buf (and session session.meta session.meta.buf)]
    (and session
         session.project-mode
         buf
         buf.show-source-separators
         (or include-full? buf.visible-source-syntax-only)
         (= buf.syntax-type "buffer"))))

(fn hide-scroll-cursor!
  [session]
  (util.hide-global-cursor! session :scroll-cursor-hidden? :scroll-saved-guicursor))

(fn restore-scroll-cursor!
  [session]
  (util.restore-global-cursor! session :scroll-cursor-hidden? :scroll-saved-guicursor))

(fn apply-source-syntax-refresh!
  [session include-full?]
  (when (can-refresh-source-syntax? session include-full?)
    (pcall session.meta.buf.apply-source-syntax-regions)))

(fn mark-source-syntax-dirty!
  [session]
  (set session.syntax-refresh-dirty true))

(fn apply-dirty-source-syntax-refresh!
  [session]
  (when session.syntax-refresh-dirty
    (set session.syntax-refresh-dirty false)
    (apply-source-syntax-refresh! session false)))

(fn rerun-source-syntax-refresh?
  [session]
  session.syntax-refresh-dirty)

(fn source-syntax-refresh-delay-ms
  [deps]
  (or (. (. deps :timing) :source-syntax-refresh-debounce-ms) 80))

(fn schedule-source-syntax-refresh!
  [deps session]
  (let [active-by-prompt (. (. deps :router) :active-by-prompt)]
  (when (can-refresh-source-syntax? session false)
    (mark-source-syntax-dirty! session)
    (when-not session.syntax-refresh-pending
      (set session.syntax-refresh-pending true)
      (vim.defer_fn
        (fn []
          (set session.syntax-refresh-pending false)
          (when (session-active-for-prompt? active-by-prompt session)
            (apply-dirty-source-syntax-refresh! session)
            ;; If additional scroll events arrived while refreshing, ensure we
            ;; run one trailing update.
            (when (rerun-source-syntax-refresh? session)
              (schedule-source-syntax-refresh! deps session))))
        (source-syntax-refresh-delay-ms deps))))))

(fn M.refresh-source-syntax!
  [deps session immediate?]
  (if immediate?
      (apply-source-syntax-refresh! session true)
      (schedule-source-syntax-refresh! deps session)))

(fn mark-selection-refresh-pending!
  [session force-refresh]
  (set session.selection-refresh-force?
       (or force-refresh session.selection-refresh-force?))
  (set session.selection-refresh-token
       (+ 1 (or session.selection-refresh-token 0))))

(fn selection-refresh-delay-ms
  [deps]
  (or (. (or (. deps :timing) {}) :selection-refresh-debounce-ms) 12))

(fn emit-selection-change!
  [session force-refresh?]
  (events.send :on-selection-change!
    {:session session
     :line-nr (+ 1 (or session.meta.selected_index 0))
     :force-refresh? force-refresh?
     :refresh-lines true}))

(fn refresh-windows!
  [deps session force-refresh]
  (let [active-by-prompt (. (. deps :router) :active-by-prompt)]
    (when session
    (mark-selection-refresh-pending! session force-refresh)
    (when-not session.selection-refresh-pending
      (set session.selection-refresh-pending true)
      (vim.defer_fn
        (fn []
          (set session.selection-refresh-pending false)
          (when (session-active-for-prompt? active-by-prompt session)
            (let [token session.selection-refresh-token
                  force-refresh? (clj.boolean session.selection-refresh-force?)]
              (set session.selection-refresh-force? false)
              (when (= token session.selection-refresh-token)
                (emit-selection-change! session force-refresh?))
              (restore-scroll-cursor! session)
              (when (~= token session.selection-refresh-token)
                (refresh-windows! deps session false)))))
        (selection-refresh-delay-ms deps))))))

(fn set-selected-index!
  [session row]
  (let [meta session.meta
        max (# meta.buf.indices)]
    (if (<= max 0)
        (set meta.selected_index 0)
        (let [target-row (math.max 1 (math.min row max))
              next-index (- target-row 1)]
          (set meta.selected_index next-index)))))

(fn sync-results-cursor!
  [session row]
  (let [meta session.meta
        max (# meta.buf.indices)]
    (when (> max 0)
      (let [target-row (math.max 1 (math.min row max))]
        (when (results-window-valid? session)
          (let [cursor (vim.api.nvim_win_get_cursor meta.win.window)
                col (or (. cursor 2) 0)]
            (when (or (~= (. cursor 1) target-row)
                      (~= col 0))
              (pcall vim.api.nvim_win_set_cursor meta.win.window [target-row 0]))))))))

(fn sync-selection-state!
  [deps session row]
  (set-selected-index! session row)
  (refresh-windows! deps session false))

(fn sync-selection-to-row!
  [deps session row]
  (sync-selection-state! deps session row)
  (sync-results-cursor! session row))

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

(fn target-step
  [action win-height]
  (let [half-step (math.max 1 (math.floor (/ win-height 2)))
        page-step (math.max 1 (- win-height 2))]
    (if (or (= action "line-down") (= action "line-up"))
        1
        (if (or (= action "half-down") (= action "half-up"))
            half-step
            page-step))))

(fn target-direction
  [action]
  (if (or (= action "line-down")
          (= action "half-down")
          (= action "page-down"))
      1
      -1))

(fn clamp-scroll-lnum
  [dir line-count old-lnum new-lnum0]
  (if (and (= dir -1)
           (< (- old-lnum 1) (- old-lnum new-lnum0)))
      1
      (and (= dir 1)
           (< (- line-count old-lnum) (- new-lnum0 old-lnum)))
      line-count
      new-lnum0))

(fn scroll-target-view
  [session action]
  (let [line-count (vim.api.nvim_buf_line_count session.meta.buf.buffer)
        win-height (math.max 1 (vim.api.nvim_win_get_height session.meta.win.window))
        step (target-step action win-height)
        dir (target-direction action)
        max-top (math.max 1 (+ (- line-count win-height) 1))
        view (vim.fn.winsaveview)
        logical-view (or session.scroll-command-view view)
        old-top (. logical-view :topline)
        old-lnum (. logical-view :lnum)
        old-col (or (. logical-view :col) 0)
        new-top0 (math.max 1 (math.min (+ old-top (* dir step)) max-top))
        new-lnum0 (math.max 1 (math.min (+ old-lnum (* dir step)) line-count))
        new-lnum (clamp-scroll-lnum dir line-count old-lnum new-lnum0)
        new-top (if (= new-lnum 1)
                    1
                    (= new-lnum line-count)
                    max-top
                    new-top0)
        target0 {:topline new-top :lnum new-lnum :col old-col :leftcol (or (. logical-view :leftcol) 0)}]
    {:line-count line-count
     :step step
     :view view
     :target (effective-scroll-target session.meta.win.window view target0)
     :row new-lnum}))

(fn finish-scroll!
  [deps active-by-prompt session]
  (when (session-active-for-prompt? active-by-prompt session)
    (set session.scroll-animating? false)
    (set session.scroll-command-view nil)
    (M.maybe-sync-from-main! deps session true)
    (restore-scroll-cursor! session)))

(fn scroll-animation-mode
  [animation-mod session step]
  (let [animate? (and animation-mod
                      (animation-mod.enabled? session :scroll)
                      (> (animation-mod.duration-ms session :scroll 140) 0)
                      (not (= step 1)))
        mini-scroll? (and animate?
                          (= (animation-mod.animation-backend session :scroll) "mini")
                          (animation-mod.supports-backend? "mini"))]
    {:animate? animate? :mini-scroll? mini-scroll?}))

(fn execute-scroll!
  [deps animation-mod active-by-prompt session action]
  (let [return-win (vim.api.nvim_get_current_win)
        return-mode (. (vim.api.nvim_get_mode) :mode)]
    (vim.api.nvim_win_call
      session.meta.win.window
      (fn []
        (let [{: step : view : target : row} (scroll-target-view session action)
              {: animate? : mini-scroll?} (scroll-animation-mode animation-mod session step)
              done! (fn []
                      (finish-scroll! deps active-by-prompt session))]
          (set session.scroll-command-view target)
          (if mini-scroll?
              (do
                (set session.scroll-animating? true)
                 (animation-mod.animate-scroll-action-mini!
                   session
                   session.meta.win.window
                   (animation-mod.duration-ms session :scroll 140)
                   (fn []
                     (pcall vim.cmd (.. "silent! normal! " (scroll-command-text action))))
                   {:return-win return-win
                    :return-mode return-mode
                    :done! done!})
                {:row (or (. target :lnum) row) :animated true})
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
                       :done! done!})
                    {:row (or (. target :lnum) row) :animated true})
                  (do
                    (vim.fn.winrestview target)
                    (set session.scroll-animating? false)
                    (set session.scroll-command-view target)
                    {:row (or (. target :lnum) row) :animated false}))))))))

(fn apply-scroll-selection!
  [deps session result]
  (let [target-row (. result :row)
        animated? (. result :animated)]
    (if animated?
        (set-selected-index! session target-row)
        (do
          (sync-selection-to-row! deps session target-row)
          (M.maybe-sync-from-main! deps session true)
          (restore-scroll-cursor! session)))))

(fn move-selection-runner
  [deps session delta]
  (fn []
    (hide-scroll-cursor! session)
    (let [meta session.meta
          max (# meta.buf.indices)]
      (when (> max 0)
        (set meta.selected_index
             (math.max 0 (math.min (+ meta.selected_index delta) (- max 1))))
        (let [row (+ meta.selected_index 1)]
          (when (results-window-valid? session)
            (pcall vim.api.nvim_win_set_cursor meta.win.window [row 0]))))
      (refresh-windows! deps session false))))

(fn scroll-main-runner
  [deps active-by-prompt animation-mod session action]
  (fn []
    (hide-scroll-cursor! session)
    (apply-scroll-selection!
      deps
      session
      (execute-scroll! deps animation-mod active-by-prompt session action))))

(fn M.move-selection!
  [deps prompt-buf delta]
  (let [active-by-prompt (. (. deps :router) :active-by-prompt)
        session (. active-by-prompt prompt-buf)]
    (when session
      (run-mode-safe! (move-selection-runner deps session delta)))))

(fn M.scroll-main!
  [deps prompt-buf action]
  (let [active-by-prompt (. (. deps :router) :active-by-prompt)
        animation-mod (. (. deps :mods) :animation)
        session (. active-by-prompt prompt-buf)]
    (when (results-window-valid? session)
      (run-mode-safe!
        (scroll-main-runner deps active-by-prompt animation-mod session action)))))

(fn M.maybe-sync-from-main!
  [deps session force-refresh]
  (let [{: router : mods} deps
        active-by-prompt (. router :active-by-prompt)
        session-view (. mods :session-view)]
    (when (and session-view session-view.maybe-sync-from-main!)
      (session-view.maybe-sync-from-main!
        session
        force-refresh
        {:active-by-prompt active-by-prompt
         :schedule-source-syntax-refresh! (fn [s]
                                            (schedule-source-syntax-refresh! deps s))}))))

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
