(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local M {})
(local debug (require :metabuffer.debug))
(local source-mod (require :metabuffer.source))
(local source-helper-mod (require :metabuffer.project.source_helpers))

(fn M.new
  [opts]
  "Build project-source orchestrator for eager/lazy pool construction."
  (let [{: settings : truthy? : selected-ref : canonical-path
         : current-buffer-path : allow-project-path?
         : project-file-list : binary-file? : read-file-view-cached : session-active?
         : lazy-streaming-allowed? : on-prompt-changed : apply-prompt-lines-now!
         : prompt-has-active-query? : now-ms : prompt-update-delay-ms
         : schedule-prompt-update!} opts
        helpers (source-helper-mod.new opts)
        reset-meta-indices! (. helpers :reset-meta-indices!)
        push-file-entry-into-pool! (. helpers :push-file-entry-into-pool!)
        include-file-path? (. helpers :include-file-path?)
        all-project-file-paths (. helpers :all-project-file-paths)
        results-wrap-width (. helpers :results-wrap-width)
        single-source-view (. helpers :single-source-view)
        set-single-source-content! (. helpers :set-single-source-content!)
        normal-query-active? (. helpers :normal-query-active?)
        current-file-filter (. helpers :current-file-filter)
        file-only-mode? (. helpers :file-only-mode?)
        set-query-source-content! (. helpers :set-query-source-content!)
        set-file-entry-source-content! (. helpers :set-file-entry-source-content!)
        best-project-selection-index (. helpers :best-project-selection-index)
        push-file-into-pool! (. helpers :push-file-into-pool!)
        current-project-prefilter (. helpers :current-project-prefilter)
        open-project-buffer-paths (. helpers :open-project-buffer-paths)
        estimate-lines-from-files (. helpers :estimate-lines-from-files)
        project-view-opts (. helpers :project-view-opts)
        cached-project-view (. helpers :cached-project-view)
        set-project-pool! (. helpers :set-project-pool!)
        enable-full-source-syntax! (. helpers :enable-full-source-syntax!)
        emit-source-pool-change! (. helpers :emit-source-pool-change!)
        maybe-finish-project-stream! (. helpers :maybe-finish-project-stream!)]

  (fn stream-next-path!
    [session path prefilter]
    (let [before (# session.meta.buf.content)
          view (cached-project-view session path (results-wrap-width session))]
      (when view
        (push-file-into-pool! session path view prefilter)
        (> (# session.meta.buf.content) before))))

  (fn collect-project-sources
    [session include-hidden include-ignored include-deps include-binary include-files prefilter]
    "Collect eager project-mode content/ref pools. Returns {:content [] :refs []}."
    (let [root (vim.fn.getcwd)
          current-path (current-buffer-path session.source-buf)
          wrap-width (results-wrap-width session)
          file-filter (current-file-filter session)
          file-cache (or session.preview-file-cache {})
          _ (set session.preview-file-cache file-cache)
          content []
          refs []]
      (if (file-only-mode? session)
          (do
            (each [_ path (ipairs (all-project-file-paths
                                    session
                                    include-hidden
                                    include-ignored
                                    include-deps
                                    include-binary
                                    file-filter))]
              (table.insert content "")
              (table.insert refs {:path path
                                  :lnum 1
                                  :line (let [rel (vim.fn.fnamemodify path ":.")]
                                          (if (and (= (type rel) "string") (~= rel ""))
                                              rel
                                              path))
                                  :kind "file-entry"
                                  :open-lnum 1
                                  :preview-lnum 1}))
            {:content content :refs refs})
          (let [pool-session {:meta {:buf {:content content
                                           :source-refs refs
                                           :all-indices []}}}]
            ;; Include current buffer first.
            (push-file-into-pool!
              pool-session
              (or current-path "[Current Buffer]")
              (single-source-view session)
              prefilter)
            (when current-path
              (set (. file-cache current-path) (single-source-view session)))
            (when include-files
              (when-not (normal-query-active? session)
                (each [_ path (ipairs (all-project-file-paths
                                        session
                                        include-hidden
                                        include-ignored
                                        include-deps
                                        include-binary
                                        file-filter))]
                  (push-file-entry-into-pool! session path))))
            (each [_ path (ipairs (project-file-list root include-hidden include-ignored include-deps))]
              (let [rel (vim.fn.fnamemodify path ":.")]
                (when (and (< (# content) settings.project-max-total-lines)
                            (allow-project-path? rel include-hidden include-deps)
                            (include-file-path? path file-filter)
                            (or include-binary
                                (not (binary-file? path)))
                           (or (not current-path) (~= (vim.fn.fnamemodify path ":p") (vim.fn.fnamemodify current-path ":p")))
                           (= 1 (vim.fn.filereadable path)))
                  (let [size (vim.fn.getfsize path)]
                    (when (and (>= size 0) (<= size settings.project-max-file-bytes))
                      (let [view (read-file-view-cached
                                   path
                                   (project-view-opts session wrap-width))]
                        (when (= (type view) "table")
                          (set (. file-cache path) view)
                          (push-file-into-pool! pool-session path view prefilter))))))))
            {:content content :refs refs}))))

  (fn init-project-pool!
    [session prefilter]
      (let [root (vim.fn.getcwd)
          include-hidden session.effective-include-hidden
          include-ignored session.effective-include-ignored
          include-deps session.effective-include-deps
          include-binary session.effective-include-binary
          wrap-width (results-wrap-width session)
          include-files session.effective-include-files
          file-filter (current-file-filter session)
          current (canonical-path (current-buffer-path session.source-buf))
          open-paths (open-project-buffer-paths session root include-hidden include-deps)
          all-paths (project-file-list root include-hidden include-ignored include-deps)
          file-entry-paths (if (and include-files (not (normal-query-active? session)))
                               (all-project-file-paths
                                 session
                                 include-hidden
                                 include-ignored
                                 include-deps
                                  include-binary
                                  file-filter)
                               [])
          deferred []
          deferred-seen {}]
      (if (file-only-mode? session)
          (do
            (set-file-entry-source-content!
              session
              include-hidden
              include-ignored
              include-deps
              include-binary
              file-filter)
            {:deferred-paths [] :estimated-lines 0})
          (do
      (set-single-source-content! session session.project-mode)
      (each [_ path (ipairs file-entry-paths)]
        (push-file-entry-into-pool! session path))
      ;; Prioritize nearby context by materializing already-open buffers first.
      (each [_ path (ipairs open-paths)]
        (let [p (canonical-path path)]
          (when (and p
                     (= 1 (vim.fn.filereadable p))
                     (include-file-path? p file-filter))
            (set (. deferred-seen p) true)
            (push-file-into-pool!
              session
              p
              (cached-project-view session p wrap-width)
              prefilter))))
      (each [_ path (ipairs all-paths)]
        (let [p (canonical-path path)]
          (when (and p
                     (not (. deferred-seen p))
                      (include-file-path? p file-filter)
                      (or include-binary
                          (not (binary-file? p)))
                      (or (not current) (~= p current)))
            (set (. deferred-seen p) true)
            (table.insert deferred p))))
      {:deferred-paths deferred :estimated-lines (estimate-lines-from-files deferred)}))))

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

  (fn apply-source-set!
    [session]
    "Apply full single/project source set based on current session flags."
    (let [meta session.meta
          query-source-key (source-mod.query-source-key session.last-parsed-query)
          query-source? (clj.boolean query-source-key)
          old-ref (and session.project-mode (selected-ref meta))
          prefilter (current-project-prefilter session)
          old-line (if (and meta.selected_index
                            (>= meta.selected_index 0)
                            (<= (+ meta.selected_index 1) (# meta.buf.indices)))
                       (math.max 1 (meta.selected_line))
                       (math.max 1 (or session.initial-source-line 1)))]
    (debug.log :project-source
               (.. "apply-source-set"
                    " project=" (tostring (clj.boolean session.project-mode))
                    " source=" (tostring query-source-key)
                    " bootstrapped=" (tostring (clj.boolean session.project-bootstrapped))
                    " pending=" (tostring (clj.boolean session.project-bootstrap-pending))
                    " stream-done=" (tostring (clj.boolean session.lazy-stream-done))
                    " prompt=" (tostring (or session.prompt-last-applied-text ""))))
    (if query-source?
        (do
          (set session.lazy-stream-id (+ 1 (or session.lazy-stream-id 0)))
          (set session.lazy-stream-done true)
          (set-query-source-content! session))
        session.project-mode
        (let [init (init-project-pool! session prefilter)]
          (if (lazy-preferred? session (or (. init :estimated-lines) 0))
              (start-project-stream! session prefilter init)
              (let [pool (collect-project-sources session
                                                  session.effective-include-hidden
                                                  session.effective-include-ignored
                                                  session.effective-include-deps
                                                  session.effective-include-binary
                                                  session.effective-include-files
                                                  prefilter)]
                (set-project-pool! session pool)
                (set session.lazy-stream-done true)
                (enable-full-source-syntax! session))))
        (do
          (set session.lazy-stream-id (+ 1 (or session.lazy-stream-id 0)))
          (set session.lazy-stream-done true)
          (set-single-source-content! session false)))
    ;; Show source prefixes only when explicit file mode is enabled.
    (when-not query-source?
      (set meta.buf.show-source-prefix (and session.project-mode session.effective-include-files))
      (set meta.buf.show-source-separators session.project-mode))
    (set session.active-source-key query-source-key)
    (set meta.buf.visible-source-syntax-only (clj.boolean (or session.project-mode query-source?)))
    (reset-meta-indices! meta)
    (if query-source?
        (set meta.selected_index (if (> (# meta.buf.indices) 0) 0 0))
        session.project-mode
        (set meta.selected_index (best-project-selection-index session old-ref old-line))
        (set meta.selected_index
             (math.max 0
                       (- (meta.buf.closest-index old-line) 1))))
      (set meta._prev_text "")
      (set meta._filter-cache {})
      (set meta._filter-cache-line-count (# meta.buf.content))))

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
    ;; Keep startup lightweight for empty project mode; separators/syntax blocks
    ;; become useful only after expanding to multi-file sources.
    (set-single-source-content! session false)
      (set meta.selected_index
           (math.max 0
                     (- (meta.buf.closest-index old-line) 1)))
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
                    ;; Avoid a bootstrap-triggered filter/view update for plain `:Meta!`
                    ;; with empty prompt; defer filtering until the user types.
                    (when has-query
                      ;; If user typed while bootstrap was pending, force-path guards can
                      ;; suppress the immediate refresh and leave results stale.
                      ;; Drive the pending prompt apply directly through the trailing-edge
                      ;; timer path so early keystrokes are always honored.
                      (set session.prompt-update-dirty true)
                      (let [now (now-ms)
                            quiet-for (- now (or session.prompt-last-change-ms 0))
                            need-quiet (math.max 0 (prompt-update-delay-ms session))]
                        (if (< quiet-for need-quiet)
                            (schedule-prompt-update! session (math.max 1 (- need-quiet quiet-for)))
                            (schedule-prompt-update! session 0))))
                    ;; Keep selection/view stable even when no prompt filter is applied.
                    (when-not has-query
                      (emit-source-pool-change!
                        session
                        {:phase :complete
                         :force? true
                         :restore-view? true
                         :refresh-lines true}))
                    (set session.project-mode-starting? false))))]
          (vim.defer_fn run-bootstrap! delay)))))

  (let [api {:apply-source-set! apply-source-set!
             :schedule-source-set-rebuild! schedule-source-set-rebuild!
             :apply-minimal-source-set! apply-minimal-source-set!
             :schedule-project-bootstrap! schedule-project-bootstrap!}]
    api)))

M
