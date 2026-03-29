(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})
(local animation-mod (require :metabuffer.window.animation))
(local prompt-buffer-mod (require :metabuffer.buffer.prompt))
(local events (require :metabuffer.events))
(local hooks-directive-mod (require :metabuffer.prompt.hooks_directive))
(local hooks-keymaps-mod (require :metabuffer.prompt.hooks_keymaps))
(local hooks-layout-mod (require :metabuffer.prompt.hooks_layout))
(local hooks-registry-mod (require :metabuffer.prompt.hooks_registry))
(local hooks-results-mod (require :metabuffer.prompt.hooks_results))
(local loading-mod (require :metabuffer.widgets.loading))
(local hooks-window-mod (require :metabuffer.prompt.hooks_window))

(fn M.new
  [opts]
  "Public API: M.new."
    (let [{: default-prompt-keymaps : active-by-prompt
         : default-main-keymaps
         : on-prompt-changed
         : maybe-sync-from-main!
         : schedule-scroll-sync! : maybe-restore-hidden-ui!
         : hide-visible-ui!
         : rebuild-source-set!
         : sign-mod} opts]
    (let [animation-enabled? (. animation-mod :enabled?)
          animation-duration-ms (. animation-mod :duration-ms)]
    (fn prompt-animation-delay-ms
      [session]
      (if (and animation-mod
               animation-enabled?
               (animation-enabled? session :prompt))
          (animation-duration-ms session :prompt 140)
          0))

    (fn switch-mode
  [session which]
      (let [meta session.meta]
        (fn mode-label
          [value]
          (if (= (type value) "table")
              (or (. value :name) (tostring value))
              (tostring value)))
        (let [old (mode-label ((. (. meta.mode which) :current)))]
        (meta.switch_mode which)
        (events.post :on-mode-switch!
          {:session session
           :kind which
           :old old
           :new (mode-label ((. (. meta.mode which) :current)))}
          {:supersede? true
           :dedupe-key (.. "on-mode-switch:" (tostring session.prompt-buf) ":" which)}))))

    (fn nvim-exiting?
      []
      (let [v (and vim.v (. vim.v :exiting))]
        (and (~= v nil)
             (~= v vim.NIL)
             (~= v 0)
             (~= v ""))))

    (fn session-prompt-valid?
  [session]
      (and (not (nvim-exiting?))
           session
           (not session.ui-hidden)
           (not session.closing)
           session.meta
           session.prompt-buf
           (vim.api.nvim_buf_is_valid session.prompt-buf)
           (= (. active-by-prompt session.prompt-buf) session)))

    (fn schedule-when-valid
  [session f]
      (vim.schedule
        (fn []
          (when (session-prompt-valid? session)
            (f)))))

    (fn option-prefix
      []
      (let [p (. vim.g "meta#prefix")]
        (if (and (= (type p) "string") (~= p ""))
            p
            "#")))

    (let [window-hooks (hooks-window-mod.new session-prompt-valid?)
          covered-by-new-window? (. window-hooks :covered-by-new-window?)
          transient-overlay-buffer? (. window-hooks :transient-overlay-buffer?)
          first-window-for-buffer (. window-hooks :first-window-for-buffer)
          capture-expected-layout! (. window-hooks :capture-expected-layout!)
          note-editor-size! (. window-hooks :note-editor-size!)
          note-global-editor-resize! (. window-hooks :note-global-editor-resize!)
          manual-prompt-resize? (. window-hooks :manual-prompt-resize?)
          schedule-restore-expected-layout! (. window-hooks :schedule-restore-expected-layout!)
          hidden-session-reachable? (. window-hooks :hidden-session-reachable?)]
      (var refresh-prompt-highlights! nil)
      (var schedule-loading-indicator! nil)
      (let [directive-hooks (hooks-directive-mod.new
                              {:option-prefix option-prefix
                               :highlight-prompt-like-line! (fn [buf ns row txt primary-hl]
                                                              (prompt-buffer-mod.highlight-like-line!
                                                                buf
                                                                ns
                                                                row
                                                                txt
                                                                primary-hl
                                                                option-prefix))})
            keymap-hooks (hooks-keymaps-mod.new
                           {:default-prompt-keymaps default-prompt-keymaps
                            :default-main-keymaps default-main-keymaps
                            :schedule-when-valid schedule-when-valid
                            :switch-mode switch-mode
                            :sign-mod sign-mod})
            hide-directive-help! (. directive-hooks :hide-directive-help!)
            maybe-show-directive-help! (. directive-hooks :maybe-show-directive-help!)
            maybe-trigger-directive-complete! (. directive-hooks :maybe-trigger-directive-complete!)
            apply-keymaps (. keymap-hooks :apply-keymaps)
            apply-emacs-insert-fallbacks (. keymap-hooks :apply-emacs-insert-fallbacks)
            apply-main-keymaps (. keymap-hooks :apply-main-keymaps)
            apply-results-edit-keymaps (. keymap-hooks :apply-results-edit-keymaps)
            begin-direct-results-edit! (. keymap-hooks :begin-direct-results-edit!)
            loading-hooks (loading-mod.new
                            {:session-prompt-valid? session-prompt-valid?
                             :animation-enabled? animation-enabled?
                             :animation-duration-ms animation-duration-ms
                             :refresh-prompt-highlights! (fn [session]
                                                           (refresh-prompt-highlights! session))})
            loading-scheduler (. loading-hooks :schedule-loading-indicator!)
            layout-hooks (hooks-layout-mod.new
                           {:session-prompt-valid? session-prompt-valid?
                            :capture-expected-layout! capture-expected-layout!
                            :note-editor-size! note-editor-size!
                            :note-global-editor-resize! note-global-editor-resize!
                            :manual-prompt-resize? manual-prompt-resize?
                            :schedule-restore-expected-layout! schedule-restore-expected-layout!
                            :refresh-prompt-highlights! (fn [session]
                                                          (refresh-prompt-highlights! session))
                            :rebuild-source-set! rebuild-source-set!})
            handle-global-resize! (. layout-hooks :handle-global-resize!)
            handle-wrap-option-set! (. layout-hooks :handle-wrap-option-set!)
            results-hooks (hooks-results-mod.new
                            {:active-by-prompt active-by-prompt
                             :sign-mod sign-mod
                             :maybe-sync-from-main! maybe-sync-from-main!
                             :schedule-scroll-sync! schedule-scroll-sync!
                             :maybe-restore-hidden-ui! maybe-restore-hidden-ui!
                             :hide-visible-ui! hide-visible-ui!
                             :rebuild-source-set! rebuild-source-set!
                             :covered-by-new-window? covered-by-new-window?
                             :transient-overlay-buffer? transient-overlay-buffer?
                             :first-window-for-buffer first-window-for-buffer
                             :hidden-session-reachable? hidden-session-reachable?
                             :begin-direct-results-edit! begin-direct-results-edit!})
            handle-results-cursor! (. results-hooks :handle-results-cursor!)
            handle-results-edit-enter! (. results-hooks :handle-results-edit-enter!)
            handle-results-text-changed! (. results-hooks :handle-results-text-changed!)
            handle-results-focus! (. results-hooks :handle-results-focus!)
            handle-overlay-winnew! (. results-hooks :handle-overlay-winnew!)
            handle-overlay-bufwinenter! (. results-hooks :handle-overlay-bufwinenter!)
            handle-selection-focus! (. results-hooks :handle-selection-focus!)
            handle-hidden-session-gc! (. results-hooks :handle-hidden-session-gc!)
            handle-results-leave! (. results-hooks :handle-results-leave!)
            handle-external-write! (. results-hooks :handle-external-write!)
            handle-scroll-sync! (. results-hooks :handle-scroll-sync!)
            handle-results-writecmd! (. results-hooks :handle-results-writecmd!)
            handle-results-wipeout! (. results-hooks :handle-results-wipeout!)]
        (set refresh-prompt-highlights!
             (fn [session]
               (prompt-buffer-mod.refresh-highlights!
                 session
                 {:option-prefix option-prefix
                  :session-prompt-valid? session-prompt-valid?
                  :schedule-loading-indicator! (fn [session]
                                                 (when schedule-loading-indicator!
                                                   (schedule-loading-indicator! session)))})))
        (set schedule-loading-indicator! loading-scheduler)

        (let [registry-hooks (hooks-registry-mod.new
                               {:active-by-prompt active-by-prompt
                                :on-prompt-changed on-prompt-changed
                                :session-prompt-valid? session-prompt-valid?
                                :schedule-when-valid schedule-when-valid
                                :prompt-animation-delay-ms prompt-animation-delay-ms
                                :refresh-prompt-highlights! (fn [session]
                                                              (refresh-prompt-highlights! session))
                                :schedule-loading-indicator! (fn [session]
                                                               (schedule-loading-indicator! session))
                                :maybe-show-directive-help! maybe-show-directive-help!
                                :maybe-trigger-directive-complete! maybe-trigger-directive-complete!
                                :hide-directive-help! hide-directive-help!
                                :apply-keymaps apply-keymaps
                                :apply-emacs-insert-fallbacks apply-emacs-insert-fallbacks
                                :apply-main-keymaps apply-main-keymaps
                                :apply-results-edit-keymaps apply-results-edit-keymaps
                                :capture-expected-layout! capture-expected-layout!
                                :handle-global-resize! handle-global-resize!
                                :handle-wrap-option-set! handle-wrap-option-set!
                                :handle-results-cursor! handle-results-cursor!
                                :handle-results-edit-enter! handle-results-edit-enter!
                                :handle-results-text-changed! handle-results-text-changed!
                                :handle-results-focus! handle-results-focus!
                                :handle-overlay-winnew! handle-overlay-winnew!
                                :handle-overlay-bufwinenter! handle-overlay-bufwinenter!
                                :handle-selection-focus! handle-selection-focus!
                                :handle-hidden-session-gc! handle-hidden-session-gc!
                                :handle-results-leave! handle-results-leave!
                                :handle-external-write! handle-external-write!
                                :handle-scroll-sync! handle-scroll-sync!
                                :handle-results-writecmd! handle-results-writecmd!
                                :handle-results-wipeout! handle-results-wipeout!})
              register! (. registry-hooks :register!)]
          {:register! register!
           :refresh! refresh-prompt-highlights!
           :loading! schedule-loading-indicator!}))))))

M
