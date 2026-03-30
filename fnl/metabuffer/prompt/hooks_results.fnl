(import-macros {: when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})
(local results-events-mod (require :metabuffer.prompt.hooks_results_events))
(local results-windows-mod (require :metabuffer.prompt.hooks_results_windows))

(fn M.new
  [opts]
  "Build prompt-hook callbacks for results-buffer and external window events."
  (let [active-by-prompt (. opts :active-by-prompt)
        sign-mod (. opts :sign-mod)
        maybe-sync-from-main! (. opts :maybe-sync-from-main!)
        schedule-scroll-sync! (. opts :schedule-scroll-sync!)
        maybe-restore-hidden-ui! (. opts :maybe-restore-hidden-ui!)
        hide-visible-ui! (. opts :hide-visible-ui!)
        rebuild-source-set! (. opts :rebuild-source-set!)
        covered-by-new-window? (. opts :covered-by-new-window?)
        transient-overlay-buffer? (. opts :transient-overlay-buffer?)
        first-window-for-buffer (. opts :first-window-for-buffer)
        hidden-session-reachable? (. opts :hidden-session-reachable?)
        begin-direct-results-edit! (. opts :begin-direct-results-edit!)]
    (let [event-hooks (results-events-mod.new
                        {:active-by-prompt active-by-prompt
                         :maybe-sync-from-main! maybe-sync-from-main!
                         :schedule-scroll-sync! schedule-scroll-sync!
                         :begin-direct-results-edit! begin-direct-results-edit!
                         :sign-mod sign-mod})
          session-active? (. event-hooks :session-active?)
          emit-query-refresh! (. event-hooks :emit-query-refresh!)
          handle-results-cursor! (. event-hooks :handle-results-cursor!)
          handle-results-edit-enter! (. event-hooks :handle-results-edit-enter!)
          handle-results-text-changed! (. event-hooks :handle-results-text-changed!)
          handle-selection-focus! (. event-hooks :handle-selection-focus!)
          handle-scroll-sync! (. event-hooks :handle-scroll-sync!)
          window-hooks (results-windows-mod.new
                         {:covered-by-new-window? covered-by-new-window?
                          :transient-overlay-buffer? transient-overlay-buffer?
                          :first-window-for-buffer first-window-for-buffer
                          :hidden-session-reachable? hidden-session-reachable?
                          :maybe-restore-hidden-ui! maybe-restore-hidden-ui!
                          :hide-visible-ui! hide-visible-ui!
                          :rebuild-source-set! rebuild-source-set!})
          handle-results-focus0! (. window-hooks :handle-results-focus!)
          handle-overlay-winnew0! (. window-hooks :handle-overlay-winnew!)
          handle-overlay-bufwinenter0! (. window-hooks :handle-overlay-bufwinenter!)
          handle-hidden-session-gc0! (. window-hooks :handle-hidden-session-gc!)
          handle-results-leave! (. window-hooks :handle-results-leave!)
          handle-external-write0! (. window-hooks :handle-external-write!)]

    (fn handle-results-focus!
      [session]
      (handle-results-focus0! session session-active?))

    (fn handle-overlay-winnew!
      [session]
      (handle-overlay-winnew0! session session-active?))

    (fn handle-overlay-bufwinenter!
      [session ev]
      (handle-overlay-bufwinenter0! session ev session-active?))

    (fn handle-hidden-session-gc!
      [router session]
      (handle-hidden-session-gc0! router session session-active?))

    (fn handle-external-write!
      [router session ev]
      (handle-external-write0! router session ev session-active? emit-query-refresh!))

    (fn handle-results-writecmd!
      [router session]
      (router.write-results session.prompt-buf))

    (fn handle-results-wipeout!
      [router session]
      (vim.schedule
        (fn []
          (router.results-buffer-wiped session.meta.buf.buffer))))

    {:handle-results-cursor! handle-results-cursor!
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
     :handle-results-wipeout! handle-results-wipeout!})))

M
