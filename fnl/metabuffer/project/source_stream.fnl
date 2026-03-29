(import-macros {: when-not} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local M {})
(local debug (require :metabuffer.debug))

(fn M.new
  [opts]
  "Build project-source streaming and bootstrap schedulers."
  (let [settings (. opts :settings)
        truthy? (. opts :truthy?)
        session-active? (. opts :session-active?)
        lazy-streaming-allowed? (. opts :lazy-streaming-allowed?)
        prompt-has-active-query? (. opts :prompt-has-active-query?)
        now-ms (. opts :now-ms)
        prompt-update-delay-ms (. opts :prompt-update-delay-ms)
        schedule-prompt-update! (. opts :schedule-prompt-update!)
        on-prompt-changed (. opts :on-prompt-changed)
        apply-prompt-lines-now! (. opts :apply-prompt-lines-now!)
        stream-next-path! (. opts :stream-next-path!)
        emit-source-pool-change! (. opts :emit-source-pool-change!)
        maybe-finish-project-stream! (. opts :maybe-finish-project-stream!)
        apply-source-set! (. opts :apply-source-set!)
        set-single-source-content! (. opts :set-single-source-content!)]
    (fn lazy-preferred?
      [session estimated-lines]
      (and (lazy-streaming-allowed? session)
           (truthy? session.lazy-mode)
           (or (and session.project-mode
                    (not session.project-bootstrapped)
                    (not (prompt-has-active-query? session)))
               (<= settings.project-lazy-min-estimated-lines 0)
               (>= estimated-lines settings.project-lazy-min-estimated-lines))))

    (fn start-project-stream!
      [session prefilter init]
      (set session.lazy-stream-id (+ 1 (or session.lazy-stream-id 0)))
      (set session.lazy-last-render-ms (now-ms))
      (debug.log :project-source
                 (.. "start-stream"
                      " stream-id=" (tostring (+ 1 (or session.lazy-stream-id 0)))
                      " bootstrapped=" (tostring (clj.boolean session.project-bootstrapped))
                      " token=" (tostring (or session.project-bootstrap-token 0))
                      " hits=" (tostring (# (or (and session.meta session.meta.buf session.meta.buf.indices) [])))))
      (set session.lazy-stream-done false)
      (set session.lazy-stream-next 1)
      (set session.lazy-stream-paths (or (. init :deferred-paths) []))
      (set session.lazy-stream-total (# session.lazy-stream-paths))
      (set session.lazy-prefilter prefilter)
      (let [stream-id session.lazy-stream-id
            run-batch0 nil]
        (var run-batch run-batch0)
        (set run-batch
             (fn []
               (when (and (session-active? session)
                          (= stream-id session.lazy-stream-id)
                          (not session.lazy-stream-done))
                 (let [paths session.lazy-stream-paths
                       total (# paths)
                       chunk (math.max 1 settings.project-lazy-chunk-size)
                       frame-budget (math.max 1 (or settings.project-lazy-frame-budget-ms 6))
                       batch-start (now-ms)]
                   (var consumed 0)
                   (var touched false)
                   (while (and (< consumed chunk)
                               (< (- (now-ms) batch-start) frame-budget)
                               (<= session.lazy-stream-next total)
                               (< (# session.meta.buf.content) settings.project-max-total-lines))
                     (let [path (. paths session.lazy-stream-next)]
                       (when (stream-next-path! session path prefilter)
                         (set touched true))
                       (set consumed (+ consumed 1))
                       (set session.lazy-stream-next (+ session.lazy-stream-next 1))))
                   (when (or (> session.lazy-stream-next total)
                             (>= (# session.meta.buf.content) settings.project-max-total-lines))
                     (set session.lazy-stream-done true))
                   (maybe-finish-project-stream! session)
                   (when touched
                     (emit-source-pool-change!
                       session
                       {:phase (if (prompt-has-active-query? session) nil :bootstrap)
                        :refresh-lines false}))
                   (when (and (not session.lazy-stream-done)
                              (= stream-id session.lazy-stream-id)
                              (session-active? session))
                     (vim.defer_fn run-batch 17))))))
        (vim.defer_fn run-batch 0)))

    (fn schedule-source-set-rebuild!
      [session wait-ms]
      "Cancel previous pending source-set rebuild and run latest one asynchronously."
      (when (and session (not session.closing))
        (set session.source-set-rebuild-token (+ 1 (or session.source-set-rebuild-token 0)))
        (let [token session.source-set-rebuild-token]
          (set session.source-set-rebuild-pending true)
          (vim.defer_fn
            (fn []
              (when (and session (= token session.source-set-rebuild-token))
                (set session.source-set-rebuild-pending false))
              (when (and session
                         (= token session.source-set-rebuild-token)
                         session.prompt-buf
                         (session-active? session)
                         (not session.closing))
                (apply-source-set! session)
                (if apply-prompt-lines-now!
                    (apply-prompt-lines-now! session)
                    (on-prompt-changed session.prompt-buf true))))
            (math.max 0 (or wait-ms 0))))))

    (fn apply-minimal-source-set!
      [session]
      "Apply minimal startup source set for empty project prompt."
      (let [meta session.meta
            old-line (if (and meta.selected_index
                              (>= meta.selected_index 0)
                              (<= (+ meta.selected_index 1) (# meta.buf.indices)))
                         (math.max 1 (meta.selected_line))
                         (math.max 1 (or session.initial-source-line 1)))]
        (set session.lazy-stream-id (+ 1 (or session.lazy-stream-id 0)))
        (set session.lazy-stream-done true)
        (set-single-source-content! session false)
        (set meta.selected_index (math.max 0 (- (meta.buf.closest-index old-line) 1)))
        (set meta._prev_text "")
        (set meta._filter-cache {})
        (set meta._filter-cache-line-count (# meta.buf.content))))

    (fn schedule-project-bootstrap!
      [session wait-ms]
      "Defer full project source expansion until startup/input conditions allow."
      (when (and session session.project-mode (not session.project-bootstrapped))
        (set session.project-bootstrap-token (+ 1 (or session.project-bootstrap-token 0)))
        (let [token session.project-bootstrap-token
              delay (math.max 0 (or wait-ms session.project-bootstrap-delay-ms settings.project-bootstrap-delay-ms 0))]
          (debug.log :project-source
                     (.. "schedule-bootstrap"
                          " token=" (tostring token)
                          " delay=" (tostring delay)
                          " hidden=" (tostring (clj.boolean session.ui-hidden))
                          " restoring=" (tostring (clj.boolean session.restoring-ui?))
                          " prompt=" (tostring (or session.prompt-last-event-text ""))))
          (set session.project-bootstrap-pending true)
          (let [run-bootstrap!
                (fn []
                  (when (and session (= token session.project-bootstrap-token))
                    (set session.project-bootstrap-pending false))
                  (when (and session
                             (= token session.project-bootstrap-token)
                             session.project-mode
                             session.prompt-buf
                             (session-active? session)
                             (not session.project-bootstrapped))
                    (let [has-query (prompt-has-active-query? session)]
                      (apply-source-set! session)
                      (emit-source-pool-change!
                        session
                        {:phase :bootstrap
                         :force? true
                         :refresh-lines true})
                      (set session.project-bootstrapped true)
                      (when has-query
                        (set session.prompt-update-dirty true)
                        (let [now (now-ms)
                              quiet-for (- now (or session.prompt-last-change-ms 0))
                              need-quiet (math.max 0 (prompt-update-delay-ms session))]
                          (if (< quiet-for need-quiet)
                              (schedule-prompt-update! session (math.max 1 (- need-quiet quiet-for)))
                              (schedule-prompt-update! session 0))))
                      (when-not has-query
                        (emit-source-pool-change!
                          session
                          {:phase :complete
                           :force? true
                           :restore-view? true
                           :refresh-lines true}))
                      (set session.project-mode-starting? false))))]
            (vim.defer_fn run-bootstrap! delay)))))

    {:lazy-preferred? lazy-preferred?
     :start-project-stream! start-project-stream!
     :schedule-source-set-rebuild! schedule-source-set-rebuild!
     :apply-minimal-source-set! apply-minimal-source-set!
     :schedule-project-bootstrap! schedule-project-bootstrap!}))

M
