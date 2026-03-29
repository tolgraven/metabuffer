(import-macros {: if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local source-mod (require :metabuffer.source))
(local transform-mod (require :metabuffer.transform))
(local events (require :metabuffer.events))

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
    (when-not (and session.project-mode (not initial-query-active))
      (run-step! "finish-session-startup!/apply-prompt-lines"
        (fn [] (apply-prompt-lines session))))
    (run-step! "finish-session-startup!/emit-session-ready"
      (fn []
        (events.send :on-session-ready!
          {:session session
           :refresh-lines true
           :restore-view? (not startup-layout-unsettled?)
           :capture-sign-baseline? true})))
    (when session.project-mode
      (vim.defer_fn
        (fn []
          (when (startup-live?)
            (events.send :on-session-ready! {:session session :refresh-lines true}))
          ; (when (= (. active-by-prompt session.prompt-buf) session)
            ; (pcall update-info-window session true))
          )
        (or session.startup-ui-delay-ms 350)))
    (schedule-single-file-info-phases!)
    (vim.schedule
      (fn []
        (when (startup-live?)
          (set session.startup-initializing false)
          (when-not session.project-mode
            (set session.project-mode-starting? false))
          (events.send :on-session-ready! {:session session :refresh-lines false})
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
          (restore-startup-cursor! session))))
    (set (. instances session.instance-id) session)))

(fn expand-history-query
  [history-api start-query]
  (let [latest-history (history-api.history-latest nil)]
    (if (= start-query "!!")
        latest-history
        (= start-query "!$")
        (history-api.history-entry-token latest-history)
        (= start-query "!^!")
        (history-api.history-entry-tail latest-history)
        start-query)))

(fn start-option-value
  [parsed-query query-mod settings parsed-key settings-key]
  (if-some [v (. parsed-query parsed-key)]
    v
    (query-mod.truthy? (. settings settings-key))))

(fn prompt-query-text
  [parsed-query expanded-query]
  (let [query0 (. parsed-query :query)
        prompt-query0 (if (~= (. parsed-query :include-files) nil)
                          expanded-query
                          query0)]
    {:query query0
     :prompt-query (if (and (= (type prompt-query0) "string")
                            (~= prompt-query0 "")
                            (not (vim.endswith prompt-query0 " "))
                            (not (vim.endswith prompt-query0 "\n")))
                       (.. prompt-query0 " ")
                       prompt-query0)}))

(fn resolve-start-query-state
  [query history-api query-mod settings]
  (let [start-query (or query "")
        expanded-query (expand-history-query history-api start-query)
        parsed-query (query-mod.apply-default-source
                       (query-mod.parse-query-text expanded-query)
                       (query-mod.truthy? settings.default-include-lgrep))
        {: query : prompt-query} (prompt-query-text parsed-query expanded-query)
        start-transforms (transform-mod.enabled-map parsed-query nil settings)]
    {:parsed-query parsed-query
     :query query
     :prompt-query prompt-query
     :start-hidden (start-option-value parsed-query query-mod settings :include-hidden :default-include-hidden)
     :start-ignored (start-option-value parsed-query query-mod settings :include-ignored :default-include-ignored)
     :start-deps (start-option-value parsed-query query-mod settings :include-deps :default-include-deps)
     :start-binary (start-option-value parsed-query query-mod settings :include-binary :default-include-binary)
     :start-files (start-option-value parsed-query query-mod settings :include-files :default-include-files)
     :start-prefilter (start-option-value parsed-query query-mod settings :prefilter :project-lazy-prefilter-enabled)
     :start-lazy (start-option-value parsed-query query-mod settings :lazy :project-lazy-enabled)
     :start-expansion (or (. parsed-query :expansion) "none")
     :start-transforms start-transforms}))

(fn build-animation-settings
  [ui-animation ui-animation-prompt ui-animation-preview ui-animation-info ui-animation-loading ui-animation-scroll fast-test-startup?]
  {:enabled (and (not fast-test-startup?)
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
            :backend (or (. ui-animation-scroll :backend) "native")}})

(fn prompt-animates?
  [ui-animation ui-animation-prompt fast-test-startup?]
  (and (not fast-test-startup?)
       (. ui-animation :enabled)
       (not (= false (. ui-animation-prompt :enabled)))))

(fn prompt-start-height
  [router-util-mod prompt-animates?]
  (if prompt-animates?
      1
      (router-util-mod.prompt-height)))

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
                (resolve-start-query-state query history-api query-mod settings)]
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
                  (router-util-mod.clear-file-caches! router existing)
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
                      prompt-animates? (prompt-animates? ui-animation ui-animation-prompt fast-test-startup?)
                      animation-settings (build-animation-settings
                                           ui-animation
                                           ui-animation-prompt
                                           ui-animation-preview
                                           ui-animation-info
                                           ui-animation-loading
                                           ui-animation-scroll
                                           fast-test-startup?)
                      prompt-win (prompt-window-mod.new
                                   vim
                                   {:height (router-util-mod.prompt-height)
                                    :start-height (prompt-start-height router-util-mod prompt-animates?)
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
                               :project-lazy-refresh-min-ms settings.project-lazy-refresh-min-ms
                               :project-lazy-refresh-debounce-ms settings.project-lazy-refresh-debounce-ms
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
                    (set session.refresh-hooks (build-refresh-hooks deps))
                  (transform-mod.apply-flags! session start-transforms)
                  (transform-mod.apply-flags! curr start-transforms)
                  (let [start-wrap (let [persisted (router-util-mod.results-wrap-enabled?)]
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
                    (session-view.restore-meta-view! curr source-view session nil))

                  (let [initial-query-active session.initial-query-active]
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
                    curr))))))))))))))

(set (. M :project-start-selected-index) project-start-selected-index)

M
