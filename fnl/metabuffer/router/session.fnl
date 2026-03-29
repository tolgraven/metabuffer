(import-macros {: if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local transform-mod (require :metabuffer.transform))
(local events (require :metabuffer.events))
(local util (require :metabuffer.util))
(local session-state-mod (require :metabuffer.router.session_state))

(local M {})

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

(fn project-start-selected-index
  [project-mode mode source-view condition]
  (if (and project-mode (= mode "start"))
      (math.max 0 (- (or (. source-view :lnum)
                         (+ (or (. condition :selected-index) 0) 1))
                     1))
      (or (. condition :selected-index) 0)))

(fn hide-startup-cursor!
  [session]
  (util.hide-global-cursor! session :startup-cursor-hidden? :startup-saved-guicursor))

(fn restore-startup-cursor!
  [session]
  (util.restore-global-cursor! session :startup-cursor-hidden? :startup-saved-guicursor))

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

(fn build-refresh-hooks
  [deps]
  (let [windows (. deps :windows)
        session-view (. deps :session-view)
        update-preview-window (. deps :update-preview-window)
        update-info-window (. deps :update-info-window)
        refresh-source-syntax! (. deps :refresh-source-syntax!)
        context-window (. windows :context)
        preview-window (. windows :preview)
        info-window (. windows :info)
        sign-mod (. deps :sign-mod)]
    {:statusline! (fn [session]
                    (when (and session session.meta session.meta.refresh_statusline)
                      (pcall session.meta.refresh_statusline))
                    (when (and preview-window preview-window.refresh-statusline!)
                      (pcall preview-window.refresh-statusline! session))
                    (when (and info-window info-window.refresh-statusline!)
                      (pcall info-window.refresh-statusline! session)))
     :preview! (fn [session]
                 (when update-preview-window
                   (pcall update-preview-window session)))
     :restore-view! (fn [session]
                      (when (and session session.meta)
                        (pcall session-view.restore-meta-view! session.meta session.source-view session nil)))
     :info! (fn [session refresh-lines]
              (when update-info-window
                (pcall update-info-window session refresh-lines)))
     :context! (fn [session]
                 (when (and context-window context-window.update!)
                   (pcall context-window.update! session)))
     :source-syntax! (fn [session immediate?]
                       (when refresh-source-syntax!
                         (pcall refresh-source-syntax! session immediate?)))
     :refresh-change-signs! (fn [session]
                              (when (and sign-mod sign-mod.refresh-change-signs!)
                                (pcall sign-mod.refresh-change-signs! session)))
     :capture-sign-baseline! (fn [session]
                               (when (and sign-mod sign-mod.capture-baseline!)
                                 (pcall sign-mod.capture-baseline! session)))
     :loading! (fn [session]
                (when (and session
                           session.prompt-hooks
	                           session.prompt-hooks.loading!)
	                  (pcall session.prompt-hooks.loading! session)))}))

(fn prompt-hook-opts
  [deps]
  (let [router (. deps :router)
        project-source (. deps :project-source)]
    {:default-prompt-keymaps router.prompt-keymaps
     :default-main-keymaps router.main-keymaps
     :active-by-prompt router.active-by-prompt
     :on-prompt-changed (. deps :on-prompt-changed)
     :update-info-window (. deps :update-info-window)
     :update-preview-window (. deps :update-preview-window)
     :maybe-sync-from-main! (. deps :maybe-sync-from-main!)
     :schedule-scroll-sync! (. deps :schedule-scroll-sync!)
     :maybe-restore-hidden-ui! (. deps :maybe-restore-hidden-ui!)
     :hide-visible-ui! (. deps :hide-visible-ui!)
     :rebuild-source-set! (fn [s]
                            (when (and project-source project-source.apply-source-set!)
                              (project-source.apply-source-set! s)))
     :sign-mod (. deps :sign-mod)}))

(fn register-prompt-hooks!
  [deps session]
  (let [router (. deps :router)
        prompt-hooks-mod (. (. deps :mods) :prompt-hooks)
        hooks (prompt-hooks-mod.new (prompt-hook-opts deps))]
    (set session.prompt-hooks hooks)
    (hooks.register! router session)))

(fn session-startup-live?
  [active-by-prompt prompt-buf session]
  (and (= (. active-by-prompt prompt-buf) session)
       (not session.ui-hidden)
       (not session.closing)))

(fn restore-active-main-view!
  [active-by-prompt session]
  (when (and (session-startup-live? active-by-prompt session.prompt-buf session)
             session.meta
             session.meta.win
             (vim.api.nvim_win_is_valid session.meta.win.window))
    (events.send :on-restore-view! {:session session})))

(fn prompt-enter-duration-ms
  [animation-mod session ui-animation-prompt-ms]
  (if (and animation-mod
           (animation-mod.enabled? session :prompt))
      (animation-mod.duration-ms session :prompt (or ui-animation-prompt-ms 140))
      0))

(fn prompt-float-config
  [session prompt-win height]
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

(fn maybe-ensure-preview-window!
  [preview-window session]
  (when (and preview-window preview-window.ensure-window!)
    (run-step! "activate-session-ui/ensure-preview-window"
      (fn [] (preview-window.ensure-window! session)))))

(fn apply-initial-prompt-layout!
  [session prompt-win]
  (when (and prompt-win (vim.api.nvim_win_is_valid prompt-win))
    (run-step! "activate-session-ui/initial-prompt-layout"
      (fn []
        (if session.prompt-floating?
            (pcall vim.api.nvim_win_set_config prompt-win (prompt-float-config session prompt-win 1))
            (pcall vim.api.nvim_win_set_height prompt-win 1))))))

(fn maybe-focus-prompt-after-start!
  [startup-live? session]
  (when (and (startup-live?) (not vim.g.meta_test_no_startinsert))
    (pcall vim.api.nvim_set_current_win session.prompt-win)))

(fn handoff-animated-prompt!
  [startup-live? session prompt-window-mod]
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
      (set session.prompt-floating? false))))

(fn finish-prompt-enter-animation!
  [active-by-prompt session prompt-window-mod]
  (when-not (session-startup-live? active-by-prompt session.prompt-buf session)
    (restore-startup-cursor! session))
  (set session.prompt-animating? false)
  (handoff-animated-prompt!
    (fn [] (session-startup-live? active-by-prompt session.prompt-buf session))
    session
    prompt-window-mod)
  (restore-active-main-view! active-by-prompt session)
  (events.send :on-session-ready! {:session session :refresh-lines true})
  (vim.schedule
    (fn []
      (restore-active-main-view! active-by-prompt session)))
  (maybe-focus-prompt-after-start!
    (fn [] (session-startup-live? active-by-prompt session.prompt-buf session))
    session))

(fn maybe-animate-prompt-enter!
  [deps session prompt-win]
  (let [active-by-prompt (. (. deps :router) :active-by-prompt)
        animation-mod (. (. deps :mods) :animation)
        prompt-window-mod (. (. deps :mods) :prompt-window)
        ui-animation-prompt-ms (. (. (. deps :ui) :animation) :prompt :ms)]
    (when (and session.animate-enter?
               animation-mod
               prompt-win
               (vim.api.nvim_win_is_valid prompt-win)
               (animation-mod.enabled? session :prompt)
               session.prompt-animating?)
      (vim.schedule
        (fn []
          (when (and (session-startup-live? active-by-prompt session.prompt-buf session)
                     session.prompt-animating?
                     prompt-win
                     (vim.api.nvim_win_is_valid prompt-win))
            (let [target-height (math.max 1 (or session.prompt-target-height 1))
                  duration (prompt-enter-duration-ms animation-mod session ui-animation-prompt-ms)
                  done! (fn [_]
                          (finish-prompt-enter-animation! active-by-prompt session prompt-window-mod))]
              (if session.prompt-floating?
                  (animation-mod.animate-float!
                    session
                    "prompt-enter"
                    prompt-win
                    (prompt-float-config session prompt-win 1)
                    (prompt-float-config session prompt-win target-height)
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
                    {:done! done!})))))))))

(fn schedule-initial-prompt-focus!
  [deps session initial-lines]
  (let [active-by-prompt (. (. deps :router) :active-by-prompt)
        animation-mod (. (. deps :mods) :animation)
        ui-animation-prompt-ms (. (. (. deps :ui) :animation) :prompt :ms)]
    (vim.defer_fn
      (fn []
        (when (and (session-startup-live? active-by-prompt session.prompt-buf session)
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
          (restore-active-main-view! active-by-prompt session)))
      (prompt-enter-duration-ms animation-mod session ui-animation-prompt-ms))))

(fn activate-session-ui!
  [deps session initial-lines]
  (let [router (. deps :router)
        mods (. deps :mods)
        active-by-source router.active-by-source
        active-by-prompt router.active-by-prompt
        animation-mod (. mods :animation)
        preview-window (. (. deps :windows) :preview)
        sync-prompt-buffer-name! (. deps :sync-prompt-buffer-name!)
        prompt-buf session.prompt-buf
        prompt-win session.prompt-win]
    (run-step! "activate-session-ui/sync-prompt-buffer-name"
      (fn [] (sync-prompt-buffer-name! session)))
    (run-step! "activate-session-ui/hide-startup-cursor"
      (fn [] (hide-startup-cursor! session)))
    (run-step! "activate-session-ui/set-prompt-lines"
      (fn [] (vim.api.nvim_buf_set_lines prompt-buf 0 -1 false initial-lines)))
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
    (maybe-ensure-preview-window! preview-window session)
    (apply-initial-prompt-layout! session prompt-win)
    (maybe-animate-prompt-enter! deps session prompt-win)
    (schedule-initial-prompt-focus! deps session initial-lines)))

(fn emit-session-ready!
  [session refresh-lines restore-view? capture-sign-baseline?]
  (events.send :on-session-ready!
    {:session session
     :refresh-lines refresh-lines
     :restore-view? restore-view?
     :capture-sign-baseline? capture-sign-baseline?}))

(fn maybe-apply-start-query!
  [apply-prompt-lines session initial-query-active]
  (when-not (and session.project-mode (not initial-query-active))
    (run-step! "finish-session-startup!/apply-prompt-lines"
      (fn [] (apply-prompt-lines session)))))

(fn schedule-project-startup-refresh!
  [session startup-live?]
  (when session.project-mode
    (vim.defer_fn
      (fn []
        (when (startup-live?)
          (emit-session-ready! session true nil nil)))
      (or session.startup-ui-delay-ms 350))))

(fn schedule-startup-finalize!
  [project-source session startup-live?]
  (vim.schedule
    (fn []
      (when (startup-live?)
        (set session.startup-initializing false)
        (when-not session.project-mode
          (set session.project-mode-starting? false))
        (emit-session-ready! session false nil nil)
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
                (events.send :on-source-syntax-refresh!
                  {:session session
                   :immediate? true}))))
          (or session.startup-ui-delay-ms 320))
        (when (and session.project-mode (not session.project-bootstrapped))
          (project-source.schedule-project-bootstrap! session 17)))
      (when-not (startup-live?)
        (restore-startup-cursor! session)))))

(fn finish-session-startup!
  [deps curr session initial-query-active]
  (let [project-source (. deps :project-source)
        apply-prompt-lines (. deps :apply-prompt-lines)
        active-by-prompt (. (. deps :router) :active-by-prompt)
        instances (. (. deps :router) :instances)
        startup-layout-unsettled? (clj.boolean session.prompt-animating?)]
    (fn startup-live?
      []
      (and (= (. active-by-prompt session.prompt-buf) session)
           (not session.ui-hidden)
           (not session.closing)))
    (fn schedule-single-file-info-phases!
      []
      (when-not session.project-mode
        (vim.defer_fn
          (fn []
            (when (startup-live?)
              (set session.single-file-info-fetch-ready true)
              (set session.single-file-info-ready true)
              (events.send :on-session-ready! {:session session :refresh-lines true})))
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
    (run-step! "finish-session-startup!/on-init"
      (fn [] (curr.on-init)))
    (maybe-apply-start-query! apply-prompt-lines session initial-query-active)
    (run-step! "finish-session-startup!/emit-session-ready"
      (fn []
        (emit-session-ready! session true (not startup-layout-unsettled?) true)))
    (schedule-project-startup-refresh! session startup-live?)
    (schedule-single-file-info-phases!)
    (schedule-startup-finalize! project-source session startup-live?)
    (set (. instances session.instance-id) session)))

(fn session-state-helpers
  [deps]
  (let [mods (. deps :mods)]
    (session-state-mod.new
      {:history-api (. deps :history-api)
       :history-store (. deps :history-store)
       :query-mod (. deps :query-mod)
       :router (. deps :router)
       :router-util-mod (. mods :router-util)
       :session-view (. deps :session-view)
       :prompt-window-mod (. mods :prompt-window)})))

(fn prepare-fresh-meta-buffer!
  [curr]
  (set curr.buf.keep-modifiable true)
  (let [bo (. vim.bo curr.buf.buffer)]
    (set (. bo :buftype) "acwrite")
    (set (. bo :modifiable) true)
    (set (. bo :readonly) false)
    (set (. bo :bufhidden) "hide"))
  (pcall vim.api.nvim_buf_set_var curr.buf.buffer "meta_manual_edit_active" false)
  (pcall vim.api.nvim_buf_set_var curr.buf.buffer "meta_internal_render" false)
  (pcall curr.buf.render))

(fn attach-start-session-ui!
  [deps curr session source-view project-mode]
  (let [router-util-mod (. (. deps :mods) :router-util)
        session-view (. deps :session-view)
        origin-win session.origin-win
        start-wrap (let [persisted (router-util-mod.results-wrap-enabled?)]
                     (if (~= persisted nil)
                         persisted
                         (let [[ok wrap?] [(pcall vim.api.nvim_get_option_value "wrap" {:win origin-win})]]
                           (and ok (clj.boolean wrap?)))))]
    (when (vim.api.nvim_win_is_valid origin-win)
      (router-util-mod.silent-win-set-buf! origin-win curr.buf.buffer))
    (when (and curr.win curr.win.window (vim.api.nvim_win_is_valid curr.win.window))
      (pcall vim.api.nvim_set_option_value "wrap" (clj.boolean start-wrap) {:win curr.win.window})
      (pcall vim.api.nvim_set_option_value "linebreak" (clj.boolean start-wrap) {:win curr.win.window}))
    (when-not project-mode
      (session-view.restore-meta-view! curr source-view session nil))))

(fn finalize-started-session!
  [deps curr session initial-lines source-buf]
  (let [launching-by-source (. (. deps :router) :launching-by-source)
        initial-query-active session.initial-query-active]
    (set curr.session session)
    (set curr.buf.session session)
    (activate-session-ui! deps session initial-lines)
    (events.send :on-session-start! {:session session})
    (finish-session-startup!
      deps
      curr
      session
      initial-query-active)
    (set (. launching-by-source source-buf) nil)
    (show-launch-message! session)
    curr))

(fn launch-new-session!
  [deps query mode project-mode prompt-query parsed-query start-hidden start-ignored start-deps start-binary start-files start-prefilter start-lazy start-expansion start-transforms source-buf]
  (let [router (. deps :router)
        mods (. deps :mods)
        meta-mod (. mods :meta)
        router-util-mod (. mods :router-util)
        session-state (session-state-helpers deps)
        ui-animation (. (. deps :ui) :animation)
        origin-win (vim.api.nvim_get_current_win)
        origin-buf source-buf
        source-view (vim.fn.winsaveview)
        _ (set (. source-view :_meta_win_height) (vim.api.nvim_win_get_height origin-win))
        condition ((. session-state :build-session-condition) query mode source-view project-mode)
        curr (meta-mod.new vim condition)
        fast-test-startup? (clj.boolean vim.g.meta_test_running)
        initial-lines (if (and prompt-query (~= prompt-query ""))
                          (vim.split prompt-query "\n" {:plain true})
                          [""])
        prompt-win ((. session-state :build-prompt-window)
                     router
                     origin-win
                     ((. session-state :prompt-animates?) ui-animation fast-test-startup?))
        prompt-buf prompt-win.buffer
        session ((. session-state :build-session-state)
                  deps
                  curr
                  source-buf
                  origin-win
                  origin-buf
                  source-view
                  condition
                  prompt-win
                  prompt-buf
                  initial-lines
                  parsed-query
                  project-mode
                  start-hidden
                  start-ignored
                  start-deps
                  start-binary
                  start-files
                  start-prefilter
                  start-lazy
                  start-expansion
                  start-transforms
                  fast-test-startup?)]
    (set curr.project-mode (or project-mode false))
    (router-util-mod.ensure-source-refs! curr)
    (prepare-fresh-meta-buffer! curr)
    (set session.refresh-hooks (build-refresh-hooks deps))
    (transform-mod.apply-flags! session start-transforms)
    (transform-mod.apply-flags! curr start-transforms)
    (attach-start-session-ui! deps curr session source-view project-mode)
    (finalize-started-session! deps curr session initial-lines source-buf)))

(fn M.start!
  [deps query mode _meta project-mode]
  (let [router (. deps :router)
        remove-session! (. deps :remove-session!)
        active-by-source router.active-by-source
        session-state (session-state-helpers deps)
        settings router
        launching-by-source (. router :launching-by-source)
        maybe-restore-hidden-ui! (. deps :maybe-restore-hidden-ui!)]
    (let [current-buf (vim.api.nvim_get_current_buf)
          current-session (current-session-for-buffer router current-buf)]
      (if (and current-session
               (existing-visible-meta current-session))
          (existing-visible-meta current-session)
          (let [{: parsed-query
                 : query
                 : prompt-query
                 : start-hidden
                 : start-ignored
                 : start-deps
                 : start-binary
                 : start-files
                 : start-prefilter
                 : start-lazy
                 : start-expansion
		                 : start-transforms}
                ((. session-state :resolve-start-query-state) query settings)
                source-buf (vim.api.nvim_get_current_buf)
                existing (. active-by-source source-buf)
                already-launching? (and (. launching-by-source source-buf)
                                        existing
                                        (= (clj.boolean existing.project-mode) (clj.boolean project-mode)))
                restored (and (not already-launching?)
                              ((. session-state :restored-hidden-session)
                                router
                                maybe-restore-hidden-ui!
                                source-buf
                                existing
                                project-mode))]
            (if already-launching?
                (or existing
                    (existing-visible-meta existing))
                (if restored
                    restored
                    (do
                      (set (. launching-by-source source-buf) true)
                      (when (and existing (not existing.ui-hidden))
                        (remove-session! existing))
                      (launch-new-session!
                        deps
                        query
                        mode
                        project-mode
                        prompt-query
                        parsed-query
                        start-hidden
                        start-ignored
                        start-deps
                        start-binary
                        start-files
                        start-prefilter
                        start-lazy
                        start-expansion
                        start-transforms
                        source-buf)))))))))

(set (. M :project-start-selected-index) project-start-selected-index)

M
