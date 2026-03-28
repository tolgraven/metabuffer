(import-macros {: when-let} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))

(fn refresh-hooks
  [session]
  (or (and session session.refresh-hooks) {}))

(fn refresh-ui!
  [args]
  (let [session (. args :session)
        hooks (refresh-hooks session)
        refresh-lines (if (= (. args :refresh-lines) nil) true (clj.boolean (. args :refresh-lines)))]
    (when session
      (when (clj.boolean (. args :restore-view?))
        (when-let [f (. hooks :restore-view!)]
          (pcall f session)))
      (when-let [f (. hooks :statusline!)]
        (pcall f session))
      (when-let [f (. hooks :preview!)]
        (pcall f session))
      (when-let [f (. hooks :info!)]
        (pcall f session refresh-lines))
      (when-let [f (. hooks :context!)]
        (pcall f session))
      (when (clj.boolean (. args :refresh-signs?))
        (when-let [f (. hooks :refresh-change-signs!)]
          (pcall f session)))
      (when (clj.boolean (. args :capture-sign-baseline?))
        (when-let [f (. hooks :capture-sign-baseline!)]
          (pcall f session))))))

(fn refresh-selection-ui!
  [args]
  (let [session (. args :session)
        hooks (refresh-hooks session)]
    (when (and session (clj.boolean (. args :force-refresh?)))
      (when-let [f (. hooks :schedule-source-syntax-refresh!)]
        (pcall f session)))
    (refresh-ui! args)))

(fn refresh-project-info!
  [args]
  (let [session (. args :session)
        hooks (refresh-hooks session)]
    (when session
      (when (clj.boolean (. args :restore-view?))
        (when-let [f (. hooks :restore-view!)]
          (pcall f session)))
      (when-let [f (. hooks :statusline!)]
        (pcall f session))
      (when-let [f (. hooks :info!)]
        (pcall f session true))
      (when-let [f (. hooks :context!)]
        (pcall f session)))))

(fn reset-source-derived-ui!
  [args]
  (let [session (. args :session)]
    (when session
      (set session.info-render-sig nil)
      (set session.info-line-meta-range-key nil))))

{:name "core-events"
 :domain "core"
 :events
 {:on-query-update! {:handler refresh-ui! :priority 40}
  :on-selection-change! {:handler refresh-selection-ui! :priority 40}
  :on-session-ready! {:handler refresh-ui! :priority 40}
  :on-restore-ui! {:handler refresh-ui! :priority 40}
  :on-project-bootstrap! {:handler refresh-project-info! :priority 40}
  :on-project-complete! {:handler refresh-project-info! :priority 40}
  :on-source-switch! {:handler reset-source-derived-ui! :priority 30}}}
