(import-macros {: when-let : when-not} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local events (require :metabuffer.events))

(fn refresh-hooks
  [session]
  (or (and session session.refresh-hooks) {}))

(fn source-refresh-state
  [session]
  (or (and session session.source-refresh-state) {}))

(fn valid-session-buffer?
  [session]
  (and session
       session.meta
       session.meta.buf
       (vim.api.nvim_buf_is_valid session.meta.buf.buffer)))

(fn prompt-query-active?
  [session]
  (let [lines (or (and session.last-parsed-query session.last-parsed-query.lines) [])]
    (var active? false)
    (each [_ line (ipairs lines)]
      (when (and (not active?) (~= (vim.trim (or line "")) ""))
        (set active? true)))
    active?))

(fn rebuild-visible-indices!
  [session]
  (let [meta (and session session.meta)]
    (when meta
      (let [all-indices []]
        (for [i 1 (# meta.buf.content)]
          (table.insert all-indices i))
        (set meta.buf.all-indices all-indices)
        (set meta.buf.indices (vim.deepcopy all-indices))))))

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
      (when-let [f (. hooks :source-syntax!)]
        (pcall f session false)))
    (refresh-ui! args)))

(fn refresh-project-info!
  [args]
  (let [session (. args :session)
        hooks (refresh-hooks session)]
    (when session
      (when-let [f (. hooks :loading!)]
        (pcall f session))
      (when (clj.boolean (. args :restore-view?))
        (when-let [f (. hooks :restore-view!)]
          (pcall f session)))
      (when-let [f (. hooks :statusline!)]
        (pcall f session))
      (when-let [f (. hooks :info!)]
        (pcall f session true))
      (when-let [f (. hooks :context!)]
        (pcall f session)))))

(fn refresh-statusline-only!
  [args]
  (let [session (. args :session)
        hooks (refresh-hooks session)]
    (when session
      (when-let [f (. hooks :statusline!)]
        (pcall f session)))))

(fn reset-source-derived-ui!
  [args]
  (let [session (. args :session)]
    (when session
      (set session.info-render-sig nil)
      (set session.info-line-meta-range-key nil))))

(fn restore-view-only!
  [args]
  (let [session (. args :session)
        hooks (refresh-hooks session)]
    (when session
      (when-let [f (. hooks :restore-view!)]
        (pcall f session)))))

(fn refresh-source-syntax-only!
  [args]
  (let [session (. args :session)
        hooks (refresh-hooks session)]
    (when session
      (when-let [f (. hooks :source-syntax!)]
        (pcall f session (clj.boolean (. args :immediate?)))))))

(fn update-source-pool-now!
  [session args]
  (let [phase (. args :phase)
        refresh-lines (if (= (. args :refresh-lines) nil) false (clj.boolean (. args :refresh-lines)))
        restore-view? (clj.boolean (. args :restore-view?))
        phase-only? (clj.boolean (. args :phase-only?))
        query-active? (prompt-query-active? session)
        streaming-idle? (and (not session.lazy-stream-done) (not query-active?))
        now (math.floor (/ (vim.uv.hrtime) 1000000))
        force? (clj.boolean (. args :force?))]
    (when (valid-session-buffer? session)
      (if streaming-idle?
          (let [last-render-ms (or session.lazy-last-render-ms 0)
                render-interval-ms 500
                should-render? (or force? (>= (- now last-render-ms) render-interval-ms))]
            (when should-render?
              (set session.lazy-last-render-ms now)
              (set session.meta.buf.visible-source-syntax-only false)
              (rebuild-visible-indices! session)
              (when restore-view?
                (restore-view-only! {:session session}))
              (pcall session.meta.buf.render))
            (events.send :on-project-bootstrap!
              {:session session
               :refresh-lines refresh-lines
               :restore-view? (and restore-view? should-render?)}))
          (do
            (when-not phase-only?
              (let [[ok err] [(pcall session.meta.on-update 0)]]
                (if ok
                    (events.send :on-query-update!
                      {:session session
                       :query (or session.prompt-last-applied-text "")
                       :refresh-lines refresh-lines})
                    (when (and err (string.find (tostring err) "E565"))
                      (vim.defer_fn
                        (fn []
                          (when (valid-session-buffer? session)
                            (pcall session.meta.on-update 0)
                            (events.send :on-query-update!
                              {:session session
                               :query (or session.prompt-last-applied-text "")
                               :refresh-lines refresh-lines})))
                        1)))))
            (when (= phase :bootstrap)
              (events.send :on-project-bootstrap!
                {:session session
                 :refresh-lines refresh-lines
                 :restore-view? restore-view?}))
            (when (= phase :complete)
              (when (and (not query-active?) restore-view?)
                (restore-view-only! {:session session}))
              (events.send :on-project-complete!
                {:session session
                 :refresh-lines refresh-lines
                 :restore-view? restore-view?})))))))

(fn schedule-source-pool-refresh!
  [args]
  (let [session (. args :session)]
    (when session
      (let [state (source-refresh-state session)
            pending (or (. state :pending) {})
            merged {:refresh-lines (or (. pending :refresh-lines)
                                       (clj.boolean (. args :refresh-lines)))
                    :restore-view? (or (. pending :restore-view?)
                                       (clj.boolean (. args :restore-view?)))
                    :force? (or (. pending :force?)
                                (clj.boolean (. args :force?)))
                    :phase-only? (or (. pending :phase-only?)
                                      (clj.boolean (. args :phase-only?)))
                    :phase (or (. args :phase) (. pending :phase))}]
        (set (. state :pending) merged)
        (set session.source-refresh-state state)
        (if (clj.boolean (. merged :force?))
            (do
              (set (. state :pending) nil)
              (set (. state :scheduled?) false)
              (update-source-pool-now! session merged))
            (do
              (set (. state :dirty?) true)
              (when-not (. state :scheduled?)
                (set (. state :scheduled?) true)
                (vim.defer_fn
                  (fn []
                    (when session
                      (set (. state :scheduled?) false)
                      (when (. state :dirty?)
                        (set (. state :dirty?) false)
                        (let [next-args (or (. state :pending) {})]
                          (set (. state :pending) nil)
                          (update-source-pool-now! session next-args))
                        (when (. state :dirty?)
                          (schedule-source-pool-refresh! {:session session})))))
                  (math.max
                    (or session.project-lazy-refresh-min-ms
                        0)
                    (or session.project-lazy-refresh-debounce-ms
                        17))))))))))

{:name "core-events"
 :domain "core"
 :events
 {:on-source-pool-change! {:handler schedule-source-pool-refresh! :priority 35}
  :on-query-update! {:handler refresh-ui! :priority 40}
  :on-selection-change! {:handler refresh-selection-ui! :priority 40}
  :on-session-ready! {:handler refresh-ui! :priority 40}
  :on-restore-ui! {:handler refresh-ui! :priority 40}
  :on-restore-view! {:handler restore-view-only! :priority 40}
  :on-source-syntax-refresh! {:handler refresh-source-syntax-only! :priority 40}
  :on-mode-switch! {:handler refresh-statusline-only! :priority 40}
  :on-prompt-focus! {:handler refresh-statusline-only! :priority 40}
  :on-loading-state! {:handler refresh-statusline-only! :priority 40}
  :on-project-bootstrap! {:handler refresh-project-info! :priority 40}
  :on-project-complete! {:handler refresh-project-info! :priority 40}
  :on-source-switch! {:handler reset-source-derived-ui! :priority 30}}}
