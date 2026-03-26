(import-macros {: if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local source-mod (require :metabuffer.source))
(local transform-mod (require :metabuffer.transform))
(local events (require :metabuffer.events))

(local M {})

(fn silent-win-set-buf!
  [win buf]
  "Attach buffer to a window without emitting the normal file info message."
  (when (and win buf
             (vim.api.nvim_win_is_valid win)
             (vim.api.nvim_buf_is_valid buf))
    (or (pcall vim.api.nvim_win_call
               win
               (fn []
                 (vim.cmd (.. "silent keepalt noautocmd buffer " buf))))
        (pcall vim.api.nvim_win_set_buf win buf))))

(fn launch-source-label
  [session]
  (if session.project-mode
      (.. "Project mode in dir " (vim.fn.fnamemodify (vim.fn.getcwd) ":~"))
      (let [path0 (and session.origin-buf
                       (vim.api.nvim_buf_is_valid session.origin-buf)
                       (vim.api.nvim_buf_get_name session.origin-buf))
            path (or path0 "")]
        (if (~= path "")
            (vim.fn.fnamemodify path ":t")
            "[No Name]"))))

(fn show-launch-message!
  [session]
  (when session
    (vim.schedule
      (fn []
        (vim.api.nvim_echo
          [[(.. "Metabuffer • "
                 (launch-source-label session)
                 " • instance "
                 (tostring (or session.instance-id "?")))
            "ModeMsg"]]
          true
          {})))))

(fn run-step!
  [label f]
  "Run startup step F and rethrow with LABEL for clearer launch failures."
  (let [[ok res] [(xpcall f debug.traceback)]]
    (if ok
        res
        (error (.. label ": " res)))))

(fn startup-ui-delay-ms
  [animate-enter? animation-settings]
  (let [settings (or animation-settings {})
        global-enabled? (and animate-enter? (not (= false (. settings :enabled))))
        global-scale (or (. settings :time-scale) 1.0)
        prompt-settings (or (. settings :prompt) {})
        info-settings (or (. settings :info) {})
        prompt-ms (if (and global-enabled? (not (= false (. prompt-settings :enabled))))
                      (math.max 0 (math.floor (+ 0.5 (* (or (. prompt-settings :ms) 140)
                                                         global-scale
                                                         (or (. prompt-settings :time-scale) 1.0)))))
                      0)
        info-ms (if (and global-enabled? (not (= false (. info-settings :enabled))))
                    (math.max 0 (math.floor (+ 0.5 (* (or (. info-settings :ms) 220)
                                                       global-scale
                                                       (or (. info-settings :time-scale) 1.0)))))
                    0)]
    (math.max prompt-ms info-ms)))

(fn project-start-selected-index
  [project-mode mode source-view condition]
  (if (and project-mode (= mode "start"))
      (math.max 0 (- (or (. source-view :lnum)
                         (+ (or (. condition :selected-index) 0) 1))
                     1))
      (or (. condition :selected-index) 0)))

(fn hide-startup-cursor!
  [session]
  (when (and session (not session.startup-cursor-hidden?))
    (let [[ok current] [(pcall vim.api.nvim_get_option_value "guicursor" {:scope "global"})]]
      (set session.startup-saved-guicursor (if ok current vim.o.guicursor))
      (set session.startup-cursor-hidden? true)
      (pcall vim.api.nvim_set_option_value "guicursor" "a:ver0" {:scope "global"}))))

(fn restore-startup-cursor!
  [session]
  (when (and session session.startup-cursor-hidden?)
    (let [value (or session.startup-saved-guicursor vim.o.guicursor)]
      (set session.startup-cursor-hidden? false)
      (set session.startup-saved-guicursor nil)
      (pcall vim.api.nvim_set_option_value "guicursor" value {:scope "global"}))))

(fn current-session-for-buffer
  [router buf]
  (or (. (. router :active-by-source) buf)
      (. (. router :active-by-prompt) buf)
      (let [found0 nil]
        (var found found0)
        (each [_ session (pairs (or (. router :active-by-prompt) {}))]
          (when (and (not found) session)
            (let [meta-buf (and session.meta session.meta.buf session.meta.buf.buffer)]
              (when (or (= buf meta-buf)
                        (= buf session.prompt-buf)
                        (= buf session.preview-buf)
                        (= buf session.info-buf)
                        (= buf session.history-browser-buf)
                        (= buf session.source-buf)
                        (= buf session.origin-buf))
                (set found session)))))
        found)))

(fn existing-visible-meta
  [session]
  (and session
       (not session.ui-hidden)
       (not session.closing)
       session.meta))

(fn register-prompt-hooks!
  [deps session]
    (let [router (. deps :router)
        mods (. deps :mods)
        windows (. deps :windows)
        prompt-hooks-mod (. mods :prompt-hooks)
        router-util-mod (. mods :router-util)
        active-by-prompt router.active-by-prompt
        on-prompt-changed (. deps :on-prompt-changed)
        update-info-window (. deps :update-info-window)
        update-preview-window (. deps :update-preview-window)
        maybe-sync-from-main! (. deps :maybe-sync-from-main!)
        schedule-scroll-sync! (. deps :schedule-scroll-sync!)
        maybe-restore-hidden-ui! (. deps :maybe-restore-hidden-ui!)
        hide-visible-ui! (. deps :hide-visible-ui!)
        preview-window (. windows :preview)
        context-window (. windows :context)
        project-source (. deps :project-source)
        sign-mod (. deps :sign-mod)
        hooks
        (prompt-hooks-mod.new
          {:mark-prompt-buffer! router-util-mod.mark-prompt-buffer!
           :default-prompt-keymaps router.prompt-keymaps
           :default-main-keymaps router.main-keymaps
           :active-by-prompt active-by-prompt
           :on-prompt-changed on-prompt-changed
           :update-info-window update-info-window
           :update-preview-window update-preview-window
           :maybe-sync-from-main! maybe-sync-from-main!
           :schedule-scroll-sync! schedule-scroll-sync!
           :maybe-restore-hidden-ui! maybe-restore-hidden-ui!
           :hide-visible-ui! hide-visible-ui!
           :maybe-refresh-preview-statusline! (fn [s]
                                               (when (and preview-window
                                                          preview-window.refresh-statusline!)
                                                 (preview-window.refresh-statusline! s)))
           :update-context-window! (fn [s]
                                     (when (and context-window context-window.update!)
                                       (context-window.update! s)))
           :rebuild-source-set! (fn [s]
                                  (when (and project-source project-source.apply-source-set!)
                                    (project-source.apply-source-set! s)))
           :sign-mod sign-mod})]
    (set session.prompt-hooks hooks)
    (hooks.register! router session)))

(fn activate-session-ui!
  [deps session initial-lines]
  (let [router (. deps :router)
        mods (. deps :mods)
        router-util-mod (. mods :router-util)
        active-by-source router.active-by-source
        active-by-prompt router.active-by-prompt
        animation-mod (. mods :animation)
        prompt-window-mod (. mods :prompt-window)
        preview-window (. (. deps :windows) :preview)
        update-info-window (. deps :update-info-window)
        session-view (. deps :session-view)
        sync-prompt-buffer-name! (. deps :sync-prompt-buffer-name!)
        ui-animation-prompt-ms (. (. (. deps :ui) :animation) :prompt :ms)
        prompt-buf session.prompt-buf
        prompt-win session.prompt-win]
    (fn startup-live?
      []
      (and (= (. active-by-prompt prompt-buf) session)
           (not session.ui-hidden)
           (not session.closing)))
    (fn restore-main-view!
      []
      (when (and (startup-live?)
                 session.meta
                 session.meta.win
                 (vim.api.nvim_win_is_valid session.meta.win.window))
        (session-view.restore-meta-view! session.meta session.source-view session update-info-window)))
    (fn prompt-enter-duration-ms
      []
      (if (and animation-mod
               (animation-mod.enabled? session :prompt))
          (animation-mod.duration-ms session :prompt (or ui-animation-prompt-ms 140))
          0))
    (fn prompt-float-config
      [height]
      (let [host-win (or session.origin-win
                         (and session.meta session.meta.win session.meta.win.window)
                         prompt-win)
            host-width (if (and host-win (vim.api.nvim_win_is_valid host-win))
                           (vim.api.nvim_win_get_width host-win)
                           vim.o.columns)
            host-height (if (and host-win (vim.api.nvim_win_is_valid host-win))
                            (vim.api.nvim_win_get_height host-win)
                            (- vim.o.lines 2))]
        {:relative "win"
         :win host-win
         :anchor "SW"
         :row host-height
         :col 0
         :width host-width
         :height (math.max 1 height)
         :style "minimal"}))
    (fn schedule-layout-refresh!
      []
      (when (and session.project-mode update-info-window)
        (let [base-delay (if (and animation-mod (animation-mod.enabled? session :prompt))
                             (animation-mod.duration-ms session :prompt (or ui-animation-prompt-ms 140))
                             0)]
          (fn refresh-after!
            [delay]
            (vim.defer_fn
              (fn []
                (when (startup-live?)
                  (pcall update-info-window session true)))
              delay))
          (refresh-after! (+ 24 base-delay)))))
    (run-step! "activate-session-ui/sync-prompt-buffer-name"
      (fn [] (sync-prompt-buffer-name! session)))
    (run-step! "activate-session-ui/hide-startup-cursor"
      (fn [] (hide-startup-cursor! session)))
    (run-step! "activate-session-ui/set-prompt-lines"
      (fn [] (vim.api.nvim_buf_set_lines prompt-buf 0 -1 false initial-lines)))
    (run-step! "activate-session-ui/mark-prompt-buffer"
      (fn [] (router-util-mod.mark-prompt-buffer! prompt-buf)))
    (run-step! "activate-session-ui/register-prompt-hooks"
      (fn [] (register-prompt-hooks! deps session)))
    (set (. active-by-source session.source-buf) session)
    (set (. active-by-prompt prompt-buf) session)
    (when (and animation-mod
               (= (animation-mod.animation-backend session :scroll) "mini")
               (animation-mod.supports-backend? "mini"))
      (animation-mod.ensure-mini-global! session))
    (when (and session.animate-enter?
               animation-mod
               prompt-win
               (vim.api.nvim_win_is_valid prompt-win)
               (animation-mod.enabled? session :prompt)
               (not session.prompt-animated?))
      (set session.prompt-animated? true)
      (set session.prompt-animating? true))
    (when (and preview-window preview-window.ensure-window!)
      (run-step! "activate-session-ui/ensure-preview-window"
        (fn [] (preview-window.ensure-window! session))))
    (when (and prompt-win (vim.api.nvim_win_is_valid prompt-win))
      (run-step! "activate-session-ui/initial-prompt-layout"
        (fn []
          (if session.prompt-floating?
              (pcall vim.api.nvim_win_set_config prompt-win (prompt-float-config 1))
              (pcall vim.api.nvim_win_set_height prompt-win 1)))))
    (when (and session.animate-enter?
               animation-mod
               prompt-win
               (vim.api.nvim_win_is_valid prompt-win)
               (animation-mod.enabled? session :prompt)
               session.prompt-animating?)
      (vim.schedule
        (fn []
          (when (and (startup-live?)
                     session.prompt-animating?
                     prompt-win
                     (vim.api.nvim_win_is_valid prompt-win))
            (fn done!
              [_]
              (when-not (startup-live?)
                (restore-startup-cursor! session))
              (set session.prompt-animating? false)
              (when (and (startup-live?)
                         session.prompt-floating?
                         prompt-window-mod
                         prompt-window-mod.handoff-to-split!)
                (let [split (prompt-window-mod.handoff-to-split!
                              vim
                              session.prompt-window
                              {:origin-win session.origin-win
                               :window-local-layout session.window-local-layout
                               :height (math.max 1 (or session.prompt-target-height 1))})]
                  (set session.prompt-window split)
                  (set session.prompt-win split.window)
                  (set session.prompt-floating? false)
                  (pcall session.meta.refresh_statusline)))
              (when (and preview-window preview-window.update!)
                (pcall preview-window.update! session))
              (pcall update-info-window session)
              (restore-main-view!)
              (vim.schedule
                (fn []
                  (restore-main-view!)))
              (when (and (startup-live?) (not vim.g.meta_test_no_startinsert))
                (pcall vim.api.nvim_set_current_win session.prompt-win)))
            (let [target-height (math.max 1 (or session.prompt-target-height 1))
                  duration (prompt-enter-duration-ms)]
               (if session.prompt-floating?
                   (animation-mod.animate-float!
                     session
                     "prompt-enter"
                     prompt-win
                     (prompt-float-config 1)
                     (prompt-float-config target-height)
                     0
                     0
                     duration
                     {:done! done!
                      :kind :prompt})
                   (animation-mod.animate-win-height-stepwise!
                     session
                     "prompt-enter"
                     prompt-win
                     1
                     target-height
                     duration
                     {:done! done!})))))))
    (schedule-layout-refresh!)
    (vim.defer_fn
      (fn []
        (when (and (startup-live?)
                   session.prompt-win
                   (vim.api.nvim_win_is_valid session.prompt-win))
          (let [row (math.max 1 (# initial-lines))
                line (or (. initial-lines row) "")
                col (# line)]
            (pcall vim.api.nvim_win_set_cursor session.prompt-win [row col]))
          (when-not vim.g.meta_test_no_startinsert
            (pcall vim.api.nvim_set_current_win session.prompt-win)
            (pcall vim.cmd "startinsert!")))
        (when-not session.prompt-animated?
          (restore-main-view!)))
      (prompt-enter-duration-ms))))

(fn finish-session-startup!
  [deps curr session initial-query-active]
  (let [project-source (. deps :project-source)
        sign-mod (. deps :sign-mod)
        session-view (. deps :session-view)
        apply-prompt-lines (. deps :apply-prompt-lines)
        update-preview-window (. deps :update-preview-window)
        update-info-window (. deps :update-info-window)
        context-window (. (. deps :windows) :context)
        active-by-prompt (. (. deps :router) :active-by-prompt)
        instances (. (. deps :router) :instances)
        startup-layout-unsettled? (clj.boolean session.prompt-animating?)]
    (fn startup-live?
      []
      (and (= (. active-by-prompt session.prompt-buf) session)
           (not session.ui-hidden)
           (not session.closing)))
    (fn schedule-aux-ui-refresh!
      []
      (vim.schedule
        (fn []
          (when (startup-live?)
            (pcall curr.refresh_statusline)
            (when update-preview-window
              (pcall update-preview-window session))
            (pcall update-info-window session true)
            (when (and context-window context-window.update!)
              (pcall context-window.update! session))))))
    (fn schedule-single-file-info-phases!
      []
      (when-not session.project-mode
        (vim.defer_fn
          (fn []
            (when (startup-live?)
              (set session.single-file-info-fetch-ready true)
              (set session.single-file-info-ready true)
              (pcall update-info-window session true)))
          (or session.startup-ui-delay-ms 320))))
    (run-step!
      (if session.project-mode
          "finish-session-startup!/apply-minimal-source-set"
          "finish-session-startup!/apply-source-set")
      (fn []
        (if session.project-mode
            (project-source.apply-minimal-source-set! session)
            (project-source.apply-source-set! session))))
    (set curr.status-win curr.win)
    (run-step! "finish-session-startup!/disable-airline"
      (fn [] (events.send :on-win-create! {:win curr.win.window :role :main})))
    (run-step! "finish-session-startup!/refresh-statusline"
      (fn [] (pcall curr.refresh_statusline)))
    (run-step! "finish-session-startup!/on-init"
      (fn [] (curr.on-init)))
    (when sign-mod
      (run-step! "finish-session-startup!/capture-sign-baseline"
        (fn [] (pcall sign-mod.capture-baseline! session))))
    (when (and session.project-mode (not startup-layout-unsettled?))
      (run-step! "finish-session-startup!/restore-meta-view-project"
        (fn [] (session-view.restore-meta-view! curr session.source-view session update-info-window))))
    (when-not (and session.project-mode (not initial-query-active))
      (run-step! "finish-session-startup!/apply-prompt-lines"
        (fn [] (apply-prompt-lines session))))
    (when (and (not session.project-mode) (not startup-layout-unsettled?))
      (run-step! "finish-session-startup!/restore-meta-view-regular"
        (fn [] (session-view.restore-meta-view! curr session.source-view session update-info-window))))
    (when (and update-preview-window (not startup-layout-unsettled?))
      (run-step! "finish-session-startup!/update-preview-window"
        (fn [] (pcall update-preview-window session))))
    (run-step! "finish-session-startup!/update-info-window"
      (fn [] (pcall update-info-window session true)))
    (when session.project-mode
      (vim.defer_fn
        (fn []
          (when (startup-live?)
            (pcall update-info-window session true))
          ; (when (= (. active-by-prompt session.prompt-buf) session)
            ; (pcall update-info-window session true))
          )
        (or session.startup-ui-delay-ms 350)))
    (schedule-single-file-info-phases!)
    (vim.schedule
      (fn []
        (if (startup-live?)
            (do
              (set session.startup-initializing false)
              (when-not session.project-mode
                (set session.project-mode-starting? false))
              (pcall update-info-window session)
              (vim.defer_fn
                (fn []
                  (when (startup-live?)
                    (set session.animate-enter? false)
                    (restore-startup-cursor! session)
                    (when (and session.project-mode
                               session.meta
                               session.meta.buf
                               session.lazy-stream-done)
                      (set session.meta.buf.visible-source-syntax-only false)
                      (pcall session.meta.buf.apply-source-syntax-regions))))
                (or session.startup-ui-delay-ms 320))
              (when (and session.project-mode (not session.project-bootstrapped))
                (project-source.schedule-project-bootstrap! session 17)))
            (restore-startup-cursor! session))))
    (when (or (and session.project-mode (not initial-query-active))
              (and context-window context-window.update!))
      (schedule-aux-ui-refresh!))
    (set (. instances session.instance-id) session)))

(fn M.start!
  [deps query mode _meta project-mode]
  (let [router (. deps :router)
        mods (. deps :mods)
        ui (. deps :ui)
        ui-animation (. ui :animation)
        ui-animation-prompt (. ui-animation :prompt)
        ui-animation-preview (. ui-animation :preview)
        ui-animation-info (. ui-animation :info)
        ui-animation-loading (. ui-animation :loading)
        ui-animation-scroll (. ui-animation :scroll)
        history-api (. deps :history-api)
        query-mod (. deps :query-mod)
        remove-session! (. deps :remove-session!)
        active-by-source router.active-by-source
        session-view (. deps :session-view)
        meta-mod (. mods :meta)
        router-util-mod (. mods :router-util)
        prompt-window-mod (. mods :prompt-window)
        history-store (. deps :history-store)
        read-file-lines-cached (. deps :read-file-lines-cached)
        settings router
        next-instance-id! (. deps :next-instance-id!)
        launching-by-source (. router :launching-by-source)
        maybe-restore-hidden-ui! (. deps :maybe-restore-hidden-ui!)]
    (pcall vim.cmd "silent! nohlsearch")
    (let [current-buf (vim.api.nvim_get_current_buf)
          current-session (current-session-for-buffer router current-buf)]
      (if (and current-session
               (existing-visible-meta current-session))
          (existing-visible-meta current-session)
          (let [start-query (or query "")
          latest-history (history-api.history-latest nil)
          expanded-query (if (= start-query "!!")
                             latest-history
                             (= start-query "!$")
                             (history-api.history-entry-token latest-history)
                             (= start-query "!^!")
                             (history-api.history-entry-tail latest-history)
                             start-query)
          parsed-query (query-mod.apply-default-source
                         (query-mod.parse-query-text expanded-query)
                         (query-mod.truthy? settings.default-include-lgrep))
          query0 (. parsed-query :query)
          prompt-query (if (~= (. parsed-query :include-files) nil)
                           expanded-query
                           query0)
          prompt-query (if (and (= (type prompt-query) "string")
                                (~= prompt-query "")
                                (not (vim.endswith prompt-query " "))
                                (not (vim.endswith prompt-query "\n")))
                           (.. prompt-query " ")
                           prompt-query)
          start-hidden (if-some [v (. parsed-query :include-hidden)]
                               v
                               (query-mod.truthy? settings.default-include-hidden))
          start-ignored (if-some [v (. parsed-query :include-ignored)]
                                v
                                (query-mod.truthy? settings.default-include-ignored))
          start-deps (if-some [v (. parsed-query :include-deps)]
                             v
                             (query-mod.truthy? settings.default-include-deps))
          start-binary (if-some [v (. parsed-query :include-binary)]
                               v
                               (query-mod.truthy? settings.default-include-binary))
          start-files (if-some [v (. parsed-query :include-files)]
                              v
                              (query-mod.truthy? settings.default-include-files))
          start-prefilter (if-some [v (. parsed-query :prefilter)]
                                  v
                                  (query-mod.truthy? settings.project-lazy-prefilter-enabled))
          start-lazy (if-some [v (. parsed-query :lazy)]
                             v
                             (query-mod.truthy? settings.project-lazy-enabled))
          start-expansion (or (. parsed-query :expansion) "none")
          start-transforms (transform-mod.enabled-map parsed-query nil settings)
          query query0]
      (let [source-buf (vim.api.nvim_get_current_buf)
            existing (. active-by-source source-buf)]
        (if (and (. launching-by-source source-buf)
                 existing
                 (= (clj.boolean existing.project-mode) (clj.boolean project-mode)))
            (or existing
                (existing-visible-meta existing))
            (if (and existing
                  existing.ui-hidden
                  maybe-restore-hidden-ui!
                 existing.meta
                 existing.meta.buf
                 (= (clj.boolean existing.project-mode) (clj.boolean project-mode))
                 (= source-buf existing.meta.buf.buffer))
                (do
                  (maybe-restore-hidden-ui! existing true)
                  existing.meta)
                (do
                  (set (. launching-by-source source-buf) true)
                   (when (and existing (not existing.ui-hidden))
                    (remove-session! existing))
                  (let [origin-win (vim.api.nvim_get_current_win)
                    origin-buf source-buf
                    source-view (vim.fn.winsaveview)
                    _ (set (. source-view :_meta_win_height) (vim.api.nvim_win_get_height origin-win))
                    condition (session-view.setup-state query mode source-view)
                    _ (set condition.selected-index
                           (project-start-selected-index project-mode mode source-view condition))
                    curr (meta-mod.new vim condition)]

                 (set curr.project-mode (or project-mode false))
                 (router-util-mod.ensure-source-refs! curr)
                 (set curr.buf.keep-modifiable true)
                 (let [fast-test-startup? (clj.boolean vim.g.meta_test_running)]
                   (let [bo (. vim.bo curr.buf.buffer)]
                     (set (. bo :buftype) "acwrite")
                     (set (. bo :modifiable) true)
                     (set (. bo :readonly) false)
                     (set (. bo :bufhidden) "hide"))
                   (pcall vim.api.nvim_buf_set_var curr.buf.buffer "meta_manual_edit_active" false)
                   (pcall vim.api.nvim_buf_set_var curr.buf.buffer "meta_internal_render" false)
                   (pcall curr.buf.render)
                   (let [initial-lines (if (and prompt-query (~= prompt-query ""))
                                         (vim.split prompt-query "\n" {:plain true})
                                         [""])
                      prompt-animates? (and (not fast-test-startup?)
                                            (. ui-animation :enabled)
                                            (not (= false (. ui-animation-prompt :enabled))))
                      animation-settings {:enabled (and (not fast-test-startup?)
                                                        (not (= false (. ui-animation :enabled))))
                                          :backend (or (. ui-animation :backend) "native")
                                          :time-scale (or (. ui-animation :time-scale) 1.0)
                                          :prompt {:enabled (not (= false (. ui-animation-prompt :enabled)))
                                                   :ms (. ui-animation-prompt :ms)
                                                   :time-scale (or (. ui-animation-prompt :time-scale) 1.0)
                                                   :backend (or (. ui-animation-prompt :backend) "native")}
                                          :preview {:enabled (not (= false (. ui-animation-preview :enabled)))
                                                    :ms (. ui-animation-preview :ms)
                                                    :time-scale (or (. ui-animation-preview :time-scale) 1.0)}
                                          :info {:enabled (not (= false (. ui-animation-info :enabled)))
                                                 :ms (. ui-animation-info :ms)
                                                 :time-scale (or (. ui-animation-info :time-scale) 1.0)
                                                 :backend (or (. ui-animation-info :backend) "native")}
                                          :loading {:enabled (not (= false (. ui-animation-loading :enabled)))
                                                    :ms (. ui-animation-loading :ms)
                                                    :time-scale (or (. ui-animation-loading :time-scale) 1.0)}
                                          :scroll {:enabled (not (= false (. ui-animation-scroll :enabled)))
                                                   :ms (. ui-animation-scroll :ms)
                                                   :time-scale (or (. ui-animation-scroll :time-scale) 1.0)
                                                   :backend (or (. ui-animation-scroll :backend) "native")}}
                      prompt-win (prompt-window-mod.new
                                   vim
                                   {:height (router-util-mod.prompt-height)
                                    :start-height (if prompt-animates? 1 (router-util-mod.prompt-height))
                                    :floating? prompt-animates?
                                    :window-local-layout settings.window-local-layout
                                    :origin-win origin-win})
                      prompt-buf prompt-win.buffer
                      session {:source-buf source-buf
                               :origin-win origin-win
                               :origin-buf origin-buf
                               :source-view source-view
                               :initial-source-line (math.max 1 (or (. source-view :lnum) (+ (or condition.selected-index 0) 1)))
                               :prompt-window prompt-win
                               :prompt-win prompt-win.window
                               :prompt-target-height (router-util-mod.prompt-height)
                               :prompt-buf prompt-buf
                               :prompt-floating? prompt-win.floating?
                               :window-local-layout settings.window-local-layout
                               :prompt-keymaps settings.prompt-keymaps
                               :main-keymaps settings.main-keymaps
                               :prompt-fallback-keymaps settings.prompt-fallback-keymaps
                               :info-file-entry-view (or settings.info-file-entry-view "meta")
                               :initial-prompt-text (table.concat initial-lines "\n")
                               :last-prompt-text (table.concat initial-lines "\n")
                               :last-history-text ""
                               :history-index 0
                               :history-cache (vim.deepcopy (history-store.list))
                               :prompt-update-pending false
                               :prompt-update-dirty false
                               :prompt-change-seq 0
                               :prompt-last-apply-ms 0
                               :prompt-last-event-text (table.concat initial-lines "\n")
                               :initial-query-active (query-mod.query-lines-has-active? (. parsed-query :lines))
                               :startup-initializing true
                               :prompt-animating? false
                               :animate-enter? (and (not fast-test-startup?)
                                                    (clj.boolean (. ui-animation :enabled)))

                               :startup-ui-delay-ms (startup-ui-delay-ms
                                                      (clj.boolean (. ui-animation :enabled))
                                                      animation-settings)
                               :loading-indicator? (clj.boolean (. ui :loading-indicator))
                               :animation-settings animation-settings
                               :project-mode (or project-mode false)
                               :project-mode-starting? (clj.boolean project-mode)
                               :read-file-lines-cached read-file-lines-cached
                               :include-hidden start-hidden
                               :include-ignored start-ignored
                               :include-deps start-deps
                               :include-binary start-binary
                               :include-files start-files
                               :default-include-lgrep (query-mod.truthy? settings.default-include-lgrep)
                               :effective-include-hidden start-hidden
                               :effective-include-ignored start-ignored
                               :effective-include-deps start-deps
                               :effective-include-binary start-binary
                               :effective-include-files start-files
                               :transform-flags (vim.deepcopy start-transforms)
                               :effective-transforms (vim.deepcopy start-transforms)
                               :active-source-key (source-mod.query-source-key parsed-query)
                               :project-bootstrap-pending false
                               :project-bootstrap-token 0
                               :project-bootstrap-delay-ms (if (query-mod.query-lines-has-active? (. parsed-query :lines))
                                                               settings.project-bootstrap-delay-ms
                                                               settings.project-bootstrap-idle-delay-ms)
                               :project-bootstrapped (not (or project-mode false))
                               :prefilter-mode start-prefilter
                               :lazy-mode start-lazy
                               :expansion-mode start-expansion
                               :project-source-syntax-chunk-lines settings.project-source-syntax-chunk-lines
                               :last-parsed-query (vim.tbl_extend
                                                    "force"
                                                    {:lines (or (. parsed-query :lines) [""])
                                                     :lgrep-lines (or (. parsed-query :lgrep-lines) [])
                                                     :include-hidden start-hidden
                                                     :include-ignored start-ignored
                                                     :include-deps start-deps
                                                     :include-binary start-binary
                                                     :include-files start-files
                                                     :file-lines (or (. parsed-query :file-lines) [])
                                                     :prefilter start-prefilter
                                                     :lazy start-lazy
                                                     :expansion start-expansion}
                                                    (transform-mod.compat-view start-transforms))
                               :file-query-lines (or (. parsed-query :file-lines) [])
                               :single-content (vim.deepcopy curr.buf.content)
                               :single-refs (vim.deepcopy (or curr.buf.source-refs []))
                               :instance-id (next-instance-id!)
                               :meta curr}]
                  (transform-mod.apply-flags! session start-transforms)
                  (transform-mod.apply-flags! curr start-transforms)
                  (let [start-wrap (let [persisted (router-util-mod.results-wrap-enabled?)]
                                     (if (~= persisted nil)
                                         persisted
                                         (let [[ok wrap?] [(pcall vim.api.nvim_get_option_value "wrap" {:win origin-win})]]
                                           (and ok (clj.boolean wrap?)))))]
                  (when (vim.api.nvim_win_is_valid origin-win)
                    (silent-win-set-buf! origin-win curr.buf.buffer))
                  (when (and curr.win curr.win.window (vim.api.nvim_win_is_valid curr.win.window))
                    (pcall vim.api.nvim_set_option_value "wrap" (clj.boolean start-wrap) {:win curr.win.window})
                    (pcall vim.api.nvim_set_option_value "linebreak" (clj.boolean start-wrap) {:win curr.win.window}))
                  (when-not project-mode
                    (session-view.restore-meta-view! curr source-view session nil))

                  (let [initial-query-active session.initial-query-active]
                    (set curr.session session)
                    (set curr.buf.session session)
                    (activate-session-ui! deps session initial-lines)
                    (finish-session-startup!
                      deps
                      curr
                      session
                      initial-query-active)
                    (set (. launching-by-source source-buf) nil)
                    (show-launch-message! session)
                    curr))))))))))))))

(set (. M :project-start-selected-index) project-start-selected-index)

M
