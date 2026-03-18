(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(fn M.new
  [opts]
  "Build project-source orchestrator for eager/lazy pool construction."
  (let [{: settings : truthy? : selected-ref : canonical-path
         : current-buffer-path : path-under-root? : allow-project-path?
         : project-file-list : binary-file? : read-file-lines-cached : session-active?
         : lazy-streaming-allowed? : on-prompt-changed : apply-prompt-lines-now!
         : prompt-has-active-query? : now-ms : prompt-update-delay-ms
         : schedule-prompt-update! : restore-meta-view! : update-info-window} opts]

  (fn parse-prefilter-terms
    [query-lines ignorecase]
    (fn unclosed-pattern-delims?
      [token]
      (let [s (or token "")
            n (# s)]
        (var i 1)
        (var paren 0)
        (var bracket 0)
        (while (<= i n)
          (let [ch (string.sub s i i)]
            (if (= ch "%")
                (set i (+ i 2))
                (do
                  (if (= ch "(")
                      (set paren (+ paren 1))
                      (= ch ")")
                      (set paren (math.max 0 (- paren 1))))
                  (if (= ch "[")
                      (set bracket (+ bracket 1))
                      (= ch "]")
                      (set bracket (math.max 0 (- bracket 1))))
                  (set i (+ i 1))))))
        (or (> paren 0) (> bracket 0))))

    (fn regex-token?
      [token]
      (and (= (type token) "string")
           (~= token "")
           ;; keep single metachar tokens literal in all-mode/prefilter
           (not (string.match token "^[%?%*%+%|%.]$"))
           (not (unclosed-pattern-delims? token))
           (not (not (string.find token "[\\%[%]%(%)%+%*%?%|%.]")))
           (let [[ok] [(pcall vim.regex (.. "\\C" token))]]
             ok)))

    (fn prefilter-safe-token
      [tok]
      (let [raw (or tok "")
            escaped-neg? (vim.startswith raw "\\!")
            negated? (and (= (string.sub raw 1 1) "!")
                          (not escaped-neg?))
            body0 (if escaped-neg?
                      (string.sub raw 2)
                      negated?
                      (string.sub raw 2)
                      raw)
            anchor-start (and (> (# body0) 0)
                              (not (vim.startswith body0 "\\^"))
                              (= (string.sub body0 1 1) "^"))
            body1 (if anchor-start (string.sub body0 2) body0)
            anchor-end (and (> (# body1) 0)
                            (not (vim.endswith body1 "\\$"))
                            (= (string.sub body1 (# body1)) "$"))
            body2 (if anchor-end (string.sub body1 1 (- (# body1) 1)) body1)
            unescaped (-> body2
                          (string.gsub "\\\\!" "!")
                          (string.gsub "\\%^" "^")
                          (string.gsub "\\%$" "$"))]
        (if negated?
            nil
            ;; Prefilter must not create false negatives. Skip only tokens that
            ;; are true regex terms in all-mode; keep incomplete delimiter forms
            ;; like "(let" as safe literals.
            (if (regex-token? unescaped)
                nil
                (if (~= unescaped "") unescaped nil)))))
    (let [groups []]
      (each [_ line (ipairs (or query-lines []))]
        (let [trimmed (vim.trim (or line ""))]
          (when (~= trimmed "")
            (let [toks []]
              (each [_ tok (ipairs (vim.split trimmed "%s+"))]
                (when-let [needle (prefilter-safe-token tok)]
                  (table.insert toks (if ignorecase (string.lower needle) needle))))
              (when (> (# toks) 0)
                (table.insert groups toks))))))
      groups))

  (fn line-matches-prefilter?
    [line spec]
    (if (or (not spec) (not spec.groups) (= (# spec.groups) 0))
        true
        (let [probe0 (or line "")
              probe (if spec.ignorecase (string.lower probe0) probe0)]
          (var all-groups true)
          (each [_ grp (ipairs spec.groups)]
            (var grp-ok true)
            (each [_ tok (ipairs grp)]
              (when (and grp-ok (not (string.find probe tok 1 true)))
                (set grp-ok false)))
            (when (and all-groups (not grp-ok))
              (set all-groups false)))
          all-groups)))

  (fn reset-meta-indices!
    [meta]
    (let [all-indices []]
      (for [i 1 (# meta.buf.content)]
        (table.insert all-indices i))
      (set meta.buf.all-indices all-indices)
      (set meta.buf.indices (vim.deepcopy all-indices))))

  (fn push-file-entry-into-pool!
    [session path]
    (let [meta session.meta
          content meta.buf.content
          refs meta.buf.source-refs
          rel (vim.fn.fnamemodify path ":.")
          line ""]
      (table.insert content line)
      (table.insert refs {:path path
                          :lnum 1
                          :line (if (and (= (type rel) "string") (~= rel ""))
                                    rel
                                    path)
                          :kind "file-entry"
                          :open-lnum 1
                          :preview-lnum 1})))

  (fn all-project-file-paths
    [session include-hidden include-ignored include-deps include-binary]
    (let [root (vim.fn.getcwd)
          seen {}
          out []]
      (each [_ p (ipairs (project-file-list root include-hidden include-ignored include-deps))]
        (let [path (canonical-path p)]
          (when (and path
                     (= 1 (vim.fn.filereadable path))
                     (or include-binary (not (binary-file? path)))
                     (path-under-root? path root)
                     (not (. seen path)))
            (set (. seen path) true)
            (table.insert out path))))
      out))

  (fn set-single-source-content!
    [session show-separators]
    (let [meta session.meta]
      (set meta.buf.content (vim.deepcopy session.single-content))
      (set meta.buf.source-refs (vim.deepcopy session.single-refs))
      (set meta.buf.show-source-prefix false)
      (set meta.buf.show-source-separators show-separators)
      (reset-meta-indices! meta)))

  (fn normal-query-active?
    [session]
    (let [lines (or (and session.last-parsed-query session.last-parsed-query.lines) [])]
      (prompt-has-active-query? {:last-parsed-query {:lines lines}})))

  (fn file-only-mode?
    [session]
    (and session.project-mode
         session.effective-include-files
         (not (normal-query-active? session))))

  (fn set-file-entry-source-content!
    [session include-hidden include-ignored include-deps include-binary]
    (let [meta session.meta]
      (set meta.buf.content [])
      (set meta.buf.source-refs [])
      (each [_ path (ipairs (all-project-file-paths
                              session
                              include-hidden
                              include-ignored
                              include-deps
                              include-binary))]
        (push-file-entry-into-pool! session path))
      (set meta.buf.show-source-prefix true)
      (set meta.buf.show-source-separators true)
      (reset-meta-indices! meta)))

  (fn best-project-selection-index
    [session old-ref old-line]
    (let [meta session.meta
          refs (or meta.buf.source-refs [])
          old-ref-path (canonical-path (and old-ref old-ref.path))
          target-path (or old-ref-path (canonical-path (current-buffer-path session.source-buf)))
          target-lnum (or (and old-ref old-ref.lnum) old-line)
          fallback-idx (math.max 0 (- (meta.buf.closest-index old-line) 1))]
      (var match-idx nil)
      (when (and old-ref old-ref.path old-ref.lnum refs)
        (for [i 1 (# refs)]
          (let [r (. refs i)]
            (when (and (not match-idx)
                       r
                       (= (or (canonical-path r.path) "") (or old-ref-path ""))
                       (= (or r.lnum 0) (or old-ref.lnum 0)))
              (set match-idx i)))))
      ;; If exact ref misses, keep line continuity in current file.
      (when (and (not match-idx) target-path refs)
        (var best-idx nil)
        (var best-dist math.huge)
        (for [i 1 (# refs)]
          (let [r (. refs i)
                r-path (and r (canonical-path r.path))]
            (when (and r-path (= r-path target-path))
              (let [dist (math.abs (- (or r.lnum 1) (or target-lnum 1)))]
                (when (< dist best-dist)
                  (set best-dist dist)
                  (set best-idx i))))))
        (set match-idx best-idx))
      (math.max 0
                (math.min (if match-idx (- match-idx 1) fallback-idx)
                          (math.max 0 (- (# meta.buf.indices) 1))))))

  (fn schedule-lazy-refresh!
    [session]
    (when (and session (session-active? session) (not session.closing))
      (set session.lazy-refresh-dirty true)
      (when-not session.lazy-refresh-pending
        (set session.lazy-refresh-pending true)
        (vim.defer_fn
          (fn []
            (set session.lazy-refresh-pending false)
            (when (and session (session-active? session) session.lazy-refresh-dirty)
              (set session.lazy-refresh-dirty false)
              (when (and session.meta
                         session.meta.buf
                         (vim.api.nvim_buf_is_valid session.meta.buf.buffer))
                (if (and (not session.lazy-stream-done)
                         (not (prompt-has-active-query? session)))
                    (do
                      ;; During empty-query startup streaming, visible results stay stable.
                      ;; Avoid re-running the full filter/render path on every batch and
                      ;; update only progress/status UI until the stream completes.
                      (pcall session.meta.refresh_statusline)
                      (pcall update-info-window session))
                    (let [[ok err] [(pcall session.meta.on-update 0)]]
                      (if ok
                          (do
                            (pcall session.meta.refresh_statusline)
                            (pcall update-info-window session))
                          (when (and err (string.find (tostring err) "E565"))
                            (vim.defer_fn
                              (fn []
                                (when (and session
                                           (session-active? session)
                                           session.meta
                                           session.meta.buf
                                           (vim.api.nvim_buf_is_valid session.meta.buf.buffer))
                                  (pcall session.meta.on-update 0)
                                  (pcall session.meta.refresh_statusline)
                                  (pcall update-info-window session)))
                              1)))))))
            (when (and session (session-active? session) session.lazy-refresh-dirty)
              (schedule-lazy-refresh! session)))
          (math.max
            (or settings.project-lazy-refresh-min-ms 0)
            settings.project-lazy-refresh-debounce-ms)))))

  (fn push-file-into-pool!
    [session path lines prefilter]
    (if (or (not lines) (= (type lines) "nil"))
        0
        (let [meta session.meta
              content meta.buf.content
              refs meta.buf.source-refs
              start-n (# content)
              take (math.max 0 (- settings.project-max-total-lines start-n))
              has-prefilter (and prefilter prefilter.groups (> (# prefilter.groups) 0))]
          (if (<= take 0)
              0
              (do
                (var added 0)
                (if has-prefilter
                    (each [lnum line (ipairs lines)]
                      (when (and (< added take)
                                 (line-matches-prefilter? line prefilter))
                        (table.insert content line)
                        (table.insert refs {:path path :lnum lnum :line line})
                        (set added (+ added 1))))
                    (each [lnum line (ipairs lines)]
                      (when (< added take)
                        (table.insert content line)
                        (table.insert refs {:path path :lnum lnum :line line})
                        (set added (+ added 1)))))
                (when (> added 0)
                  (for [i (+ start-n 1) (# content)]
                    (table.insert meta.buf.all-indices i)))
                added)))))

  (fn open-project-buffer-paths
    [session root include-hidden include-deps]
    (let [out []
          seen {}
          current (canonical-path (current-buffer-path session.source-buf))]
      (each [_ buf (ipairs (vim.api.nvim_list_bufs))]
        (when (and (vim.api.nvim_buf_is_valid buf)
                   (= (. (. vim.bo buf) :buftype) "")
                   (truthy? (. (. vim.bo buf) :buflisted)))
          (let [name (canonical-path (vim.api.nvim_buf_get_name buf))]
            (when (and name
                       (or (not current) (~= name current))
                       (not (. seen name))
                       (= 1 (vim.fn.filereadable name))
                       (path-under-root? name root))
              (let [rel (vim.fn.fnamemodify name ":.")]
                (when (allow-project-path? rel include-hidden include-deps)
                  (set (. seen name) true)
                  (table.insert out name)))))))
      out))

  (fn estimate-lines-from-files
    [paths]
    (var bytes 0)
    (each [_ path (ipairs (or paths []))]
      (let [size (vim.fn.getfsize path)]
        (when (> size 0)
          (set bytes (+ bytes size)))))
    (math.floor (/ bytes 80)))

  (fn collect-project-sources
    [session include-hidden include-ignored include-deps include-binary include-hex include-files]
    (let [root (vim.fn.getcwd)
          current-path (current-buffer-path session.source-buf)
          file-cache (or session.preview-file-cache {})
          _ (set session.preview-file-cache file-cache)
          content []
          refs []]
      (when (file-only-mode? session)
        (let [meta session.meta]
          (each [_ path (ipairs (all-project-file-paths
                                  session
                                  include-hidden
                                  include-ignored
                                  include-deps
                                  include-binary))]
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
          {:content content :refs refs}))
      (var total-lines 0)
      (let [push-line! (fn [path lnum line]
                         (table.insert content line)
                         (table.insert refs {:path path :lnum lnum :line line})
                         (set total-lines (+ total-lines 1)))]
      ;; Include current buffer first.
      (each [i line (ipairs (or session.single-content []))]
        (push-line! (or current-path "[Current Buffer]") i line))
      (when (and current-path (= (type session.single-content) "table"))
        (set (. file-cache current-path) (vim.deepcopy session.single-content)))
      (when include-files
        (each [_ path (ipairs (all-project-file-paths
                                session
                                include-hidden
                                include-ignored
                                include-deps
                                include-binary))]
          (push-file-entry-into-pool! session path)))
      (each [_ path (ipairs (project-file-list root include-hidden include-ignored include-deps))]
        (let [rel (vim.fn.fnamemodify path ":.")]
          (when (and (< total-lines settings.project-max-total-lines)
                     (allow-project-path? rel include-hidden include-deps)
                     (or (not current-path) (~= (vim.fn.fnamemodify path ":p") (vim.fn.fnamemodify current-path ":p")))
                     (= 1 (vim.fn.filereadable path)))
            (let [size (vim.fn.getfsize path)]
              (when (and (>= size 0) (<= size settings.project-max-file-bytes))
                (let [lines (read-file-lines-cached path {:include-binary include-binary :hex-view include-hex})]
                  (when (= (type lines) "table")
                    (set (. file-cache path) lines)
                    (each [lnum line (ipairs lines)]
                      (when (< total-lines settings.project-max-total-lines)
                        (push-line! path lnum line))))))))))
        {:content content :refs refs})))

  (fn init-project-pool!
    [session prefilter]
      (let [root (vim.fn.getcwd)
          include-hidden session.effective-include-hidden
          include-ignored session.effective-include-ignored
          include-deps session.effective-include-deps
          include-binary session.effective-include-binary
          include-hex session.effective-include-hex
          include-files session.effective-include-files
          current (canonical-path (current-buffer-path session.source-buf))
          open-paths (open-project-buffer-paths session root include-hidden include-deps)
          all-paths (project-file-list root include-hidden include-ignored include-deps)
          file-entry-paths (if include-files
                               (all-project-file-paths
                                 session
                                 include-hidden
                                 include-ignored
                                 include-deps
                                 include-binary)
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
              include-binary)
            {:deferred-paths [] :estimated-lines 0})
          (do
      (set-single-source-content! session session.project-mode)
      (each [_ path (ipairs file-entry-paths)]
        (push-file-entry-into-pool! session path))
      ;; Prioritize nearby context by materializing already-open buffers first.
      (each [_ path (ipairs open-paths)]
        (let [p (canonical-path path)]
          (when (and p (= 1 (vim.fn.filereadable p)))
            (set (. deferred-seen p) true)
            (push-file-into-pool!
              session
              p
              (read-file-lines-cached p {:include-binary include-binary :hex-view include-hex})
              prefilter))))
      (each [_ path (ipairs all-paths)]
        (let [p (canonical-path path)]
          (when (and p
                     (not (. deferred-seen p))
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
    (set session.lazy-stream-done false)
    (set session.lazy-stream-next 1)
    (set session.lazy-stream-paths (or (. init :deferred-paths) []))
    (set session.lazy-stream-total (# session.lazy-stream-paths))
    (set session.lazy-prefilter prefilter)
    (let [stream-id session.lazy-stream-id]
    (fn run-batch
      []
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
            (let [path (. paths session.lazy-stream-next)
                  lines (and path
                             (read-file-lines-cached
                               path
                               {:include-binary session.effective-include-binary
                                :hex-view session.effective-include-hex}))
                  before (# session.meta.buf.content)]
              (when lines
                (push-file-into-pool! session path lines prefilter)
                (when (> (# session.meta.buf.content) before)
                  (set touched true)))
              (set consumed (+ consumed 1))
              (set session.lazy-stream-next (+ session.lazy-stream-next 1))))
          (when (or (> session.lazy-stream-next total)
                    (>= (# session.meta.buf.content) settings.project-max-total-lines))
            (set session.lazy-stream-done true))
          (when (and session.lazy-stream-done
                     session.meta
                     session.meta.buf
                     (not session.prompt-animating?)
                     (not session.startup-initializing))
            (set session.meta.buf.visible-source-syntax-only false)
            (pcall session.meta.buf.apply-source-syntax-regions)
            ;; Always force one final UI refresh when streaming settles so the
            ;; info pane leaves its loading/empty state even if the last batch
            ;; did not append any new visible lines.
            (pcall session.meta.refresh_statusline)
            (pcall update-info-window session true))
          (when touched
            (schedule-lazy-refresh! session))
          (when (and (not session.lazy-stream-done)
                     (= stream-id session.lazy-stream-id)
                     (session-active? session))
            (vim.defer_fn run-batch 17)))))
      (vim.defer_fn run-batch 0)))

  (fn apply-source-set!
    [session]
    "Apply full single/project source set based on current session flags."
    (let [meta session.meta
          old-ref (and session.project-mode (selected-ref meta))
          old-line (if (and meta.selected_index
                            (>= meta.selected_index 0)
                            (<= (+ meta.selected_index 1) (# meta.buf.indices)))
                       (math.max 1 (meta.selected_line))
                       (math.max 1 (or session.initial-source-line 1)))]
    (if session.project-mode
        (let [init (init-project-pool! session nil)]
          (if (lazy-preferred? session (or (. init :estimated-lines) 0))
              (start-project-stream! session nil init)
              (let [pool (collect-project-sources session
                                                  session.effective-include-hidden
                                                  session.effective-include-ignored
                                                  session.effective-include-deps
                                                  session.effective-include-binary
                                                  session.effective-include-hex
                                                  session.effective-include-files)]
                (set meta.buf.content pool.content)
                (set meta.buf.source-refs pool.refs)
                (set session.lazy-stream-done true)
                (when (and session.meta
                           session.meta.buf
                           (not session.prompt-animating?)
                           (not session.startup-initializing))
                  (set session.meta.buf.visible-source-syntax-only false)
                  (pcall session.meta.buf.apply-source-syntax-regions)))))
        (do
          (set session.lazy-stream-id (+ 1 (or session.lazy-stream-id 0)))
          (set session.lazy-stream-done true)
          (set-single-source-content! session false)))
    ;; Show source prefixes only when explicit file mode is enabled.
    (set meta.buf.show-source-prefix (and session.project-mode session.effective-include-files))
    (set meta.buf.show-source-separators session.project-mode)
    (reset-meta-indices! meta)
    (if session.project-mode
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
    (when (and session session.project-mode (not session.closing))
      (set session.source-set-rebuild-token (+ 1 (or session.source-set-rebuild-token 0)))
      (let [token session.source-set-rebuild-token]
        (set session.source-set-rebuild-pending true)
        (vim.defer_fn
          (fn []
            (when (and session (= token session.source-set-rebuild-token))
              (set session.source-set-rebuild-pending false))
            (when (and session
                       (= token session.source-set-rebuild-token)
                       session.project-mode
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
      (let [token session.project-bootstrap-token]
        (set session.project-bootstrap-pending true)
        (vim.defer_fn
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
                  (pcall session.meta.buf.render)
                  (restore-meta-view! session.meta session.source-view session update-info-window)
                  (pcall session.meta.refresh_statusline)
                  (pcall update-info-window session)))))
          (math.max 0 (or wait-ms session.project-bootstrap-delay-ms settings.project-bootstrap-delay-ms))))))

  {:schedule-lazy-refresh! schedule-lazy-refresh!
   :apply-source-set! apply-source-set!
   :schedule-source-set-rebuild! schedule-source-set-rebuild!
   :apply-minimal-source-set! apply-minimal-source-set!
   :schedule-project-bootstrap! schedule-project-bootstrap!}))

M
