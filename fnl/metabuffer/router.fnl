(local meta_mod (require :metabuffer.meta))
(local prompt_window_mod (require :metabuffer.window.prompt))
(local meta_window_mod (require :metabuffer.window.metawindow))
(local floating_window_mod (require :metabuffer.window.floating))
(local preview_window_mod (require :metabuffer.window.preview))
(local info_window_mod (require :metabuffer.window.info))
(local base_buffer (require :metabuffer.buffer.base))
(local session_view (require :metabuffer.session.view))
(local debug (require :metabuffer.debug))
(local config (require :metabuffer.config))
(local query (require :metabuffer.query))
(local history_store (require :metabuffer.history_store))

(local M {})
(set M.instances {})
(set M.active-by-source {})
(set M.active-by-prompt {})
(var update-info-window nil)
(var apply-prompt-lines nil)
(var prompt-lines nil)
(var preview-window nil)
(var info-window nil)
(config.apply-router-defaults M vim)
(local truthy? query.truthy?)
(local parse-query-lines query.parse-query-lines)
(local parse-query-text query.parse-query-text)
(local query-lines-has-active? query.query-lines-has-active?)
(local history-list history_store.list)
(local push-history! (fn [text]
                       (history_store.push! text M.history-max)))
(local history-entry history_store.entry)
(local wipe-temp-buffers session_view.wipe-temp-buffers)
(local setup-state session_view.setup-state)
(local restore-meta-view! session_view.restore-meta-view!)

(fn debug-log [msg]
  (debug.log "router" msg))

(fn prompt-height []
  (or (tonumber vim.g.meta_prompt_height)
      (tonumber (. vim.g "meta#prompt_height"))
      7))

(fn persist-prompt-height! [session]
  (when (and session session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
    (let [[ok h] [(pcall vim.api.nvim_win_get_height session.prompt-win)]]
      (when (and ok h (> h 0))
        (set vim.g.meta_prompt_height h)
        (set (. vim.g "meta#prompt_height") h)))))

(fn info-height [session]
  (if (and session session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
      (let [p-row-col (vim.api.nvim_win_get_position session.prompt-win)
            p-row (. p-row-col 1)]
        (math.max 7 (- p-row 2)))
      (math.max 7 (- vim.o.lines (+ (prompt-height) 4)))))

(fn now-ms []
  (/ (vim.loop.hrtime) 1000000))

(fn prompt-update-delay-ms [session]
  (let [base (math.max 0 M.prompt-update-debounce-ms)
        n (if (and session session.meta session.meta.buf session.meta.buf.indices)
              (# session.meta.buf.indices)
              0)
        qlen (let [lines (prompt-lines session)
                   parsed (if session.project-mode
                              (parse-query-lines lines)
                              {:lines lines})
                   last-active (do
                                 (var s "")
                                 (each [_ line (ipairs (or (. parsed :lines) []))]
                                   (let [trimmed (vim.trim (or line ""))]
                                     (when (~= trimmed "")
                                       (set s trimmed))))
                                 s)]
               (# (or last-active "")))
        short-extra (if (<= qlen 1)
                        180
                        (if (<= qlen 2)
                            120
                            (if (<= qlen 3) 70 0)))
        scale (if (< n 2000)
                  0
                  (if (< n 10000)
                      2
                      (if (< n 50000) 6 10)))
        extra (if (and session session.project-mode (not session.lazy-stream-done)) 2 0)]
    (+ base short-extra scale extra)))

(fn prompt-has-active-query? [session]
  (let [parsed (parse-query-lines (prompt-lines session))]
    (var has false)
    (each [_ line (ipairs (or (. parsed :lines) []))]
      (when (and (not has) (~= (vim.trim (or line "")) ""))
        (set has true)))
    has))

(fn cancel-prompt-update! [session]
  (when (and session session.prompt-update-timer)
    (let [timer session.prompt-update-timer
          stopf (. timer :stop)
          closef (. timer :close)]
      (when stopf (pcall stopf timer))
      (when closef (pcall closef timer))
      (set session.prompt-update-timer nil)
      (set session.prompt-update-pending false))))

(fn begin-session-close! [session]
  (when session
    (set session.closing true)
    ;; Invalidate any queued prompt updates immediately.
    (set session.prompt-update-token (+ 1 (or session.prompt-update-token 0)))
    (set session.prompt-update-dirty false)
    (cancel-prompt-update! session)
    ;; Invalidate any queued preview updates immediately.
    (set session.preview-update-token (+ 1 (or session.preview-update-token 0)))
    (when session.preview-update-timer
      (let [timer session.preview-update-timer
            stopf (. timer :stop)
            closef (. timer :close)]
        (when stopf (pcall stopf timer))
        (when closef (pcall closef timer))
        (set session.preview-update-timer nil)))
    (set session.preview-update-pending false)
    ;; Drop pending lazy refresh/syntax refresh work.
    (set session.lazy-refresh-dirty false)
    (set session.lazy-refresh-pending false)
    (set session.syntax-refresh-dirty false)
    (set session.syntax-refresh-pending false)))

(fn schedule-prompt-update! [session wait-ms]
  (when session
    (cancel-prompt-update! session)
    (set session.prompt-update-pending true)
    (set session.prompt-update-token (+ 1 (or session.prompt-update-token 0)))
    (let [token session.prompt-update-token
          timer (vim.loop.new_timer)]
      (set session.prompt-update-timer timer)
      ((. timer :start)
       timer
       (math.max 0 wait-ms)
       0
       (vim.schedule_wrap
         (fn []
           (when (and session.prompt-update-timer (= session.prompt-update-timer timer))
             (cancel-prompt-update! session))
           (when (and session
                      session.prompt-buf
                      (= (. M.active-by-prompt session.prompt-buf) session)
                      (= token session.prompt-update-token)
                      session.prompt-update-dirty)
             (let [now (now-ms)
                   quiet-for (- now (or session.prompt-last-change-ms 0))
                   need-quiet (math.max 0 (prompt-update-delay-ms session))]
               (if (< quiet-for need-quiet)
                   ;; Still within active typing window: push matcher apply
                   ;; further out so prompt input remains fluid.
                   (schedule-prompt-update! session (math.max 1 (- need-quiet quiet-for)))
                   (do
                     (set session.prompt-update-dirty false)
                     (set session.prompt-last-apply-ms now)
                     (apply-prompt-lines session)))))))))))

(fn lnum-width-from-max-len [max-len]
  (+ (math.max 2 (or max-len 1)) 1))

(fn lnum-width-from-max-value [max-value]
  (lnum-width-from-max-len (# (tostring (math.max 1 (or max-value 1))))))

(fn lnum-cell [lnum width]
  (.. (string.rep " " (math.max 0 (- width (+ (# lnum) 1))))
      lnum
      " "))

(fn numeric-max [vals default]
  (let [fallback (or default 0)]
    (if (or (not vals) (= (# vals) 0))
        fallback
        (let [m0 (or (. vals 1) fallback)]
          (var m m0)
          (for [i 2 (# vals)]
            (when (> (. vals i) m)
              (set m (. vals i))))
          m))))

(set prompt-lines (fn [session]
  (if (and session (vim.api.nvim_buf_is_valid session.prompt-buf))
      (vim.api.nvim_buf_get_lines session.prompt-buf 0 -1 false)
      [])))

(fn prompt-text [session]
  (table.concat (prompt-lines session) "\n"))

(fn mark-prompt-buffer! [buf]
  (when (and buf (vim.api.nvim_buf_is_valid buf))
    ;; Best-effort disables for common auto-pairs/completion helpers.
    (pcall vim.api.nvim_buf_set_var buf "autopairs_enabled" false)
    (pcall vim.api.nvim_buf_set_var buf "AutoPairsDisabled" 1)
    (pcall vim.api.nvim_buf_set_var buf "delimitMate_enabled" 0)
    (pcall vim.api.nvim_buf_set_var buf "pear_tree_disable" 1)
    (pcall vim.api.nvim_buf_set_var buf "endwise_disable" 1)
    (pcall vim.api.nvim_buf_set_var buf "cmp_enabled" false)
    (pcall vim.api.nvim_buf_set_var buf "meta_prompt" true)))

(fn set-prompt-text! [session text]
  (when (and session (vim.api.nvim_buf_is_valid session.prompt-buf))
    (set session.last-prompt-text (or text ""))
    (local lines (if (= text "") [""] (vim.split text "\n" {:plain true})))
    (vim.api.nvim_buf_set_lines session.prompt-buf 0 -1 false lines)
    (let [row (# lines)
          col (# (. lines row))]
      (pcall vim.api.nvim_win_set_cursor session.prompt-win [row col]))))

(fn current-buffer-path [buf]
  (and buf
       (vim.api.nvim_buf_is_valid buf)
       (let [[ok name] [(pcall vim.api.nvim_buf_get_name buf)]]
         (when (and ok (= (type name) "string") (~= name ""))
           name))))

(fn meta-buffer-name [session]
  (if session.project-mode
      "Metabuffer"
      (let [original-name (current-buffer-path session.source-buf)
            base-name (if (and (= (type original-name) "string") (~= original-name ""))
                          (vim.fn.fnamemodify original-name ":t")
                          "[No Name]")]
        (.. base-name " • Metabuffer"))))

(fn ensure-source-refs! [meta]
  (when (not meta.buf.source-refs)
    (set meta.buf.source-refs []))
  (when (< (# meta.buf.source-refs) (# meta.buf.content))
    (let [path (or (current-buffer-path meta.buf.model) "[Current Buffer]")
          model-buf (and meta.buf.model
                         (vim.api.nvim_buf_is_valid meta.buf.model)
                         meta.buf.model)]
      (for [i (+ (# meta.buf.source-refs) 1) (# meta.buf.content)]
        (table.insert meta.buf.source-refs {:path path :lnum i :buf model-buf :line (. meta.buf.content i)}))))
  meta.buf.source-refs)

(fn selected-ref [meta]
  (let [src-idx (. meta.buf.indices (+ meta.selected_index 1))
        refs (or meta.buf.source-refs [])]
    (and src-idx (. refs src-idx))))

(fn hidden-path? [path]
  (let [parts (vim.split path "/" {:plain true})]
    (var hidden false)
    (each [_ p (ipairs parts)]
      (when (and (~= p "") (vim.startswith p "."))
        (set hidden true)))
    hidden))

(fn dep-path? [path]
  (let [parts (vim.split path "/" {:plain true})]
    (var dep false)
    (each [_ p (ipairs parts)]
      (when (. M.dep-dir-names p)
        (set dep true)))
    dep))

(fn allow-project-path? [rel include-hidden include-deps]
  (let [s (or rel "")]
    (if (or (= s "") (= s "."))
        false
        (if (or (vim.startswith s ".git/") (string.find s "/.git/" 1 true))
            false
            (if (and (not include-hidden) (hidden-path? s))
                false
                (if (and (not include-deps) (dep-path? s))
                    false
                    true))))))

(fn project-file-list [root include-hidden include-ignored include-deps]
  (if (= 1 (vim.fn.executable "rg"))
      (let [cmd ["rg" "--files" "--glob" "!.git"]
            _ (when include-hidden
                (table.insert cmd "--hidden"))
            _ (when include-ignored
                (table.insert cmd "--no-ignore")
                (table.insert cmd "--no-ignore-vcs")
                (table.insert cmd "--no-ignore-parent"))
            _ (when (not include-deps)
                (table.insert cmd "--glob")
                (table.insert cmd "!node_modules/**")
                (table.insert cmd "--glob")
                (table.insert cmd "!vendor/**")
                (table.insert cmd "--glob")
                (table.insert cmd "!.venv/**")
                (table.insert cmd "--glob")
                (table.insert cmd "!venv/**")
                (table.insert cmd "--glob")
                (table.insert cmd "!dist/**")
                (table.insert cmd "--glob")
                (table.insert cmd "!build/**")
                (table.insert cmd "--glob")
                (table.insert cmd "!target/**"))
            rel (vim.fn.systemlist cmd)]
        (vim.tbl_map
          (fn [p] (vim.fn.fnamemodify (.. root "/" p) ":p"))
          (or rel [])))
      (vim.fn.globpath root "**/*" true true)))

(fn ui-attached? []
  (> (# (vim.api.nvim_list_uis)) 0))

(fn lazy-streaming-allowed? [session]
  (and session
       session.project-mode
       (truthy? M.project-lazy-enabled)
       (or (not (truthy? M.project-lazy-disable-headless))
           (ui-attached?))))

(fn session-active? [session]
  (and session
       session.prompt-buf
       (= (. M.active-by-prompt session.prompt-buf) session)))

(fn canonical-path [path]
  (when (and (= (type path) "string") (~= path ""))
    (vim.fn.fnamemodify path ":p")))

(fn path-under-root? [path root]
  (let [p (canonical-path path)
        r (canonical-path root)]
    (and p r (vim.startswith p r))))

(fn read-file-lines-cached [path]
  (if (or (not path) (= 0 (vim.fn.filereadable path)))
      nil
      (let [size (vim.fn.getfsize path)
            mtime (vim.fn.getftime path)
            cache (or M.project-file-cache {})
            _ (set M.project-file-cache cache)
            cached (. cache path)]
        (if (or (< size 0) (> size M.project-max-file-bytes))
            nil
            (if (and (= (type cached) "table")
                     (= (. cached :size) size)
                     (= (. cached :mtime) mtime)
                     (= (type (. cached :lines)) "table"))
                (. cached :lines)
                (let [[ok lines] [(pcall vim.fn.readfile path)]]
                  (when (and ok (= (type lines) "table"))
                    (set (. cache path) {:size size :mtime mtime :lines lines})
                    lines)))))))

(set preview-window
  (preview_window_mod.new
    {:floating-window-mod floating_window_mod
     :selected-ref selected-ref
     :read-file-lines-cached read-file-lines-cached
     :is-active-session (fn [session]
                          (and session
                               session.prompt-buf
                               (= (. M.active-by-prompt session.prompt-buf) session)))
     :debug-log debug-log
     :source-switch-debounce-ms M.preview-source-switch-debounce-ms}))

(set info-window
  (info_window_mod.new
    {:floating-window-mod floating_window_mod
     :info-min-width M.info-min-width
     :info-max-width M.info-max-width
     :info-max-lines M.info-max-lines
     :info-height info-height
     :numeric-max numeric-max
     :lnum-width-from-max-len lnum-width-from-max-len
     :lnum-cell lnum-cell
     :debug-log debug-log
     :update-preview (fn [session]
                       (preview-window.maybe-update-for-selection! session))}))

(set update-info-window
  (fn [session refresh-lines]
    (info-window.update! session refresh-lines)))

(fn parse-prefilter-terms [query-lines ignorecase]
  (local groups [])
  (each [_ line (ipairs (or query-lines []))]
    (let [trimmed (vim.trim (or line ""))]
      (when (~= trimmed "")
        (local toks [])
        (each [_ tok (ipairs (vim.split trimmed "%s+"))]
          (when (~= tok "")
            (table.insert toks (if ignorecase (string.lower tok) tok))))
        (when (> (# toks) 0)
          (table.insert groups toks)))))
  groups)

(fn line-matches-prefilter? [line spec]
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

(fn schedule-lazy-refresh! [session]
  (when (and session (session-active? session) (not session.closing))
    (set session.lazy-refresh-dirty true)
    (when (not session.lazy-refresh-pending)
      (set session.lazy-refresh-pending true)
      (vim.defer_fn
        (fn []
          (set session.lazy-refresh-pending false)
          (when (and session (session-active? session) session.lazy-refresh-dirty)
            (set session.lazy-refresh-dirty false)
            (M.on-prompt-changed session.prompt-buf true))
          (when (and session (session-active? session) session.lazy-refresh-dirty)
            (schedule-lazy-refresh! session)))
        (math.max 20 (or M.project-lazy-refresh-debounce-ms 80))))))

(fn append-lines! [session lines refs]
  (when (and session lines refs (> (# lines) 0))
    (local meta session.meta)
    (each [_ line (ipairs lines)]
      (table.insert meta.buf.content line))
    (each [_ ref (ipairs refs)]
      (table.insert meta.buf.source-refs ref))
    (for [i (+ (# meta.buf.all-indices) 1) (# meta.buf.content)]
      (table.insert meta.buf.all-indices i))))

(fn push-file-into-pool! [session path lines prefilter]
  (if (or (not lines) (= (type lines) "nil"))
      0
      (let [meta session.meta
            content meta.buf.content
            refs meta.buf.source-refs
            start-n (# content)
            take (math.max 0 (- M.project-max-total-lines start-n))
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

(fn open-project-buffer-paths [session root include-hidden include-deps]
  (local out [])
  (local seen {})
  (local current (canonical-path (current-buffer-path session.source-buf)))
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
  out)

(fn estimate-lines-from-files [paths]
  (var bytes 0)
  (each [_ path (ipairs (or paths []))]
    (let [size (vim.fn.getfsize path)]
      (when (> size 0)
        (set bytes (+ bytes size)))))
  (math.floor (/ bytes 80)))

(fn collect-project-sources [session include-hidden include-ignored include-deps]
  (let [meta session.meta
        root (vim.fn.getcwd)
        current-path (current-buffer-path session.source-buf)
        file-cache (or session.preview-file-cache {})
        _ (set session.preview-file-cache file-cache)
        content []
        refs []]
    (var total-lines 0)
    (local push-line! (fn [path lnum line]
                     (table.insert content line)
                     (table.insert refs {:path path :lnum lnum :line line})
                     (set total-lines (+ total-lines 1))))
    ;; Include current buffer first.
    (each [i line (ipairs (or session.single-content []))]
      (push-line! (or current-path "[Current Buffer]") i line))
    (when (and current-path (= (type session.single-content) "table"))
      (set (. file-cache current-path) (vim.deepcopy session.single-content)))
    (each [_ path (ipairs (project-file-list root include-hidden include-ignored include-deps))]
      (let [rel (vim.fn.fnamemodify path ":.")]
        (when (and (< total-lines M.project-max-total-lines)
                   (allow-project-path? rel include-hidden include-deps)
                   (or (not current-path) (~= (vim.fn.fnamemodify path ":p") (vim.fn.fnamemodify current-path ":p")))
                   (= 1 (vim.fn.filereadable path)))
        (let [size (vim.fn.getfsize path)]
          (when (and (>= size 0) (<= size M.project-max-file-bytes))
            (let [[ok lines] [(pcall vim.fn.readfile path)]]
              (when (and ok (= (type lines) "table"))
                (set (. file-cache path) lines)
                (each [lnum line (ipairs lines)]
                  (when (< total-lines M.project-max-total-lines)
                    (push-line! path lnum line))))))))))
    {:content content :refs refs}))

(fn init-project-pool! [session prefilter]
  (local meta session.meta)
  (set meta.buf.content (vim.deepcopy session.single-content))
  (set meta.buf.source-refs (vim.deepcopy session.single-refs))
  (set meta.buf.show-source-prefix false)
  (set meta.buf.show-source-separators session.project-mode)
  (set meta.buf.all-indices [])
  (for [i 1 (# meta.buf.content)]
    (table.insert meta.buf.all-indices i))
  (set meta.buf.indices (vim.deepcopy meta.buf.all-indices))
  (let [root (vim.fn.getcwd)
        include-hidden session.effective-include-hidden
        include-ignored session.effective-include-ignored
        include-deps session.effective-include-deps
        current (canonical-path (current-buffer-path session.source-buf))
        open-paths (open-project-buffer-paths session root include-hidden include-deps)
        all-paths (project-file-list root include-hidden include-ignored include-deps)
        deferred []
        deferred-seen {}]
    ;; Prioritize nearby context by materializing already-open buffers first.
    (each [_ path (ipairs open-paths)]
      (let [p (canonical-path path)]
        (when (and p (= 1 (vim.fn.filereadable p)))
          (set (. deferred-seen p) true)
          (push-file-into-pool! session p (read-file-lines-cached p) prefilter))))
    (each [_ path (ipairs all-paths)]
      (let [p (canonical-path path)]
        (when (and p
                   (not (. deferred-seen p))
                   (or (not current) (~= p current)))
          (set (. deferred-seen p) true)
          (table.insert deferred p))))
    {:deferred-paths deferred :estimated-lines (estimate-lines-from-files deferred)}))

(fn lazy-preferred? [session estimated-lines]
  (and (lazy-streaming-allowed? session)
       (truthy? session.lazy-mode)
       (or (<= M.project-lazy-min-estimated-lines 0)
           (>= estimated-lines M.project-lazy-min-estimated-lines))))

(fn start-project-stream! [session prefilter init]
  (set session.lazy-stream-id (+ 1 (or session.lazy-stream-id 0)))
  (set session.lazy-stream-done false)
  (set session.lazy-stream-next 1)
  (set session.lazy-stream-paths (or (. init :deferred-paths) []))
  (set session.lazy-stream-total (# session.lazy-stream-paths))
  (set session.lazy-prefilter prefilter)
  (local stream-id session.lazy-stream-id)
  (fn run-batch []
    (when (and (session-active? session)
               (= stream-id session.lazy-stream-id)
               (not session.lazy-stream-done))
      (let [paths session.lazy-stream-paths
            total (# paths)
            chunk (math.max 1 (or M.project-lazy-chunk-size 8))]
        (var consumed 0)
        (var touched false)
        (while (and (< consumed chunk)
                    (<= session.lazy-stream-next total)
                    (< (# session.meta.buf.content) M.project-max-total-lines))
          (let [path (. paths session.lazy-stream-next)
                lines (and path (read-file-lines-cached path))
                before (# session.meta.buf.content)]
            (when lines
              (push-file-into-pool! session path lines prefilter)
              (when (> (# session.meta.buf.content) before)
                (set touched true)))
            (set consumed (+ consumed 1))
            (set session.lazy-stream-next (+ session.lazy-stream-next 1))))
        (if (or (> session.lazy-stream-next total)
                (>= (# session.meta.buf.content) M.project-max-total-lines))
            (set session.lazy-stream-done true))
        (when touched
          (schedule-lazy-refresh! session))
        (when (and (not session.lazy-stream-done)
                   (= stream-id session.lazy-stream-id)
                   (session-active? session))
          (vim.defer_fn run-batch 0)))))
  (vim.defer_fn run-batch 0))

(fn apply-source-set! [session]
  (local meta session.meta)
  (local old-ref (and session.project-mode (selected-ref meta)))
  (local old-line (if (and meta.selected_index
                           (>= meta.selected_index 0)
                           (<= (+ meta.selected_index 1) (# meta.buf.indices)))
                      (math.max 1 (meta.selected_line))
                      (math.max 1 (or session.initial-source-line 1))))
  (if session.project-mode
      (let [prefilter-active (and (truthy? M.project-lazy-prefilter-enabled)
                                  (~= session.prefilter-mode false))
            prefilter (when prefilter-active
                        {:groups (parse-prefilter-terms (or (. session.last-parsed-query :lines) [])
                                                        (session.meta.ignorecase))
                         :ignorecase (session.meta.ignorecase)})
            init (init-project-pool! session prefilter)]
        (if (lazy-preferred? session (or (. init :estimated-lines) 0))
            (start-project-stream! session prefilter init)
            (let [pool (collect-project-sources session session.effective-include-hidden session.effective-include-ignored session.effective-include-deps)]
              (set meta.buf.content pool.content)
              (set meta.buf.source-refs pool.refs)
              (set session.lazy-stream-done true))))
      (do
        (set session.lazy-stream-id (+ 1 (or session.lazy-stream-id 0)))
        (set session.lazy-stream-done true)
        (set meta.buf.content (vim.deepcopy session.single-content))
        (set meta.buf.source-refs (vim.deepcopy session.single-refs))))
  ;; Keep main results buffer as pure content lines; source context is shown
  ;; in the right floating info window.
  (set meta.buf.show-source-prefix false)
  (set meta.buf.show-source-separators session.project-mode)
  (set meta.buf.all-indices [])
  (for [i 1 (# meta.buf.content)]
    (table.insert meta.buf.all-indices i))
  (set meta.buf.indices (vim.deepcopy meta.buf.all-indices))
  (if session.project-mode
      (do
        (var match-idx nil)
        (local old-ref-path (canonical-path (and old-ref old-ref.path)))
        (local target-path (or old-ref-path (canonical-path (current-buffer-path session.source-buf))))
        (local target-lnum (or (and old-ref old-ref.lnum) old-line))
        (when (and old-ref old-ref.path old-ref.lnum meta.buf.source-refs)
          (for [i 1 (# meta.buf.source-refs)]
            (let [r (. meta.buf.source-refs i)]
              (when (and (not match-idx)
                         r
                         (= (or (canonical-path r.path) "") (or old-ref-path ""))
                         (= (or r.lnum 0) (or old-ref.lnum 0)))
                (set match-idx i)))))
        ;; If exact ref misses, keep line continuity in current file.
        (when (and (not match-idx) target-path meta.buf.source-refs)
          (var best-idx nil)
          (var best-dist math.huge)
          (for [i 1 (# meta.buf.source-refs)]
            (let [r (. meta.buf.source-refs i)
                  r-path (and r (canonical-path r.path))]
              (when (and r-path (= r-path target-path))
                (let [dist (math.abs (- (or r.lnum 1) (or target-lnum 1)))]
                  (when (< dist best-dist)
                    (set best-dist dist)
                    (set best-idx i))))))
          (set match-idx best-idx))
        (set meta.selected_index
             (math.max 0
                       (math.min (if match-idx (- match-idx 1) (- (meta.buf.closest-index old-line) 1))
                                 (math.max 0 (- (# meta.buf.indices) 1))))))
      (set meta.selected_index
           (math.max 0
                     (- (meta.buf.closest-index old-line) 1))))
  (set meta._prev_text "")
  (set meta._filter-cache {})
  (set meta._filter-cache-line-count (# meta.buf.content)))

(fn apply-minimal-source-set! [session]
  (local meta session.meta)
  (local old-line (if (and meta.selected_index
                           (>= meta.selected_index 0)
                           (<= (+ meta.selected_index 1) (# meta.buf.indices)))
                      (math.max 1 (meta.selected_line))
                      (math.max 1 (or session.initial-source-line 1))))
  (set session.lazy-stream-id (+ 1 (or session.lazy-stream-id 0)))
  (set session.lazy-stream-done true)
  (set meta.buf.content (vim.deepcopy session.single-content))
  (set meta.buf.source-refs (vim.deepcopy session.single-refs))
  (set meta.buf.show-source-prefix false)
  ;; Keep startup lightweight for empty project mode; separators/syntax blocks
  ;; become useful only after expanding to multi-file sources.
  (set meta.buf.show-source-separators false)
  (set meta.buf.all-indices [])
  (for [i 1 (# meta.buf.content)]
    (table.insert meta.buf.all-indices i))
  (set meta.buf.indices (vim.deepcopy meta.buf.all-indices))
  (set meta.selected_index
       (math.max 0
                 (- (meta.buf.closest-index old-line) 1)))
  (set meta._prev_text "")
  (set meta._filter-cache {})
  (set meta._filter-cache-line-count (# meta.buf.content)))

(fn schedule-project-bootstrap! [session wait-ms]
  (when (and session session.project-mode (not session.project-bootstrapped))
    (set session.project-bootstrap-token (+ 1 (or session.project-bootstrap-token 0)))
    (local token session.project-bootstrap-token)
    (set session.project-bootstrap-pending true)
    (vim.defer_fn
      (fn []
        (when (and session (= token session.project-bootstrap-token))
          (set session.project-bootstrap-pending false))
        (when (and session
                   (= token session.project-bootstrap-token)
                   session.project-mode
                   session.prompt-buf
                   (= (. M.active-by-prompt session.prompt-buf) session)
                   (not session.project-bootstrapped))
          (local has-query (prompt-has-active-query? session))
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
          (when (not has-query)
            (pcall session.meta.buf.render)
            (restore-meta-view! session.meta session.source-view)
            (pcall session.meta.refresh_statusline)
            (pcall update-info-window session))))
      (math.max 0 (or wait-ms session.project-bootstrap-delay-ms M.project-bootstrap-delay-ms 120)))))

(fn M._store_vars [meta]
  (set vim.b._meta_context (meta.store))
  (set vim.b._meta_indexes meta.buf.indices)
  (set vim.b._meta_updates meta.updates)
  (set vim.b._meta_source_bufnr meta.buf.model)
  meta)

(fn M._wrapup [meta]
  (vim.cmd "redraw|redrawstatus")
  (M._store_vars meta))

(fn remove-session [session]
  (when session
    (push-history! (or session.last-prompt-text
                       (if (and session.prompt-buf (vim.api.nvim_buf_is_valid session.prompt-buf))
                           (prompt-text session)
                           "")))
    (persist-prompt-height! session)
    (when session.augroup
      (pcall vim.api.nvim_del_augroup_by_id session.augroup))
    (when (and session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
      (pcall vim.api.nvim_win_close session.prompt-win true))
    (when (and session.prompt-buf (vim.api.nvim_buf_is_valid session.prompt-buf))
      (pcall vim.api.nvim_buf_delete session.prompt-buf {:force true}))
    (info-window.close-window! session)
    (preview-window.close-window! session)
    (when session.source-buf
      (set (. M.active-by-source session.source-buf) nil))
    (when session.prompt-buf
      (set (. M.active-by-prompt session.prompt-buf) nil))))

(set apply-prompt-lines (fn [session]
  (when (and session (not session.closing) (vim.api.nvim_buf_is_valid session.prompt-buf))
    (let [lines (vim.api.nvim_buf_get_lines session.prompt-buf 0 -1 false)]
      (set session.last-prompt-text (table.concat lines "\n"))
      (set session.prompt-last-applied-text session.last-prompt-text)
      (let [parsed (if session.project-mode
                       (parse-query-lines lines)
                       {:lines lines
                        :include-hidden nil
                        :include-ignored nil
                        :include-deps nil
                        :prefilter nil
                        :lazy nil})
            next-ignored (if (= (. parsed :include-ignored) nil)
                             session.include-ignored
                             (. parsed :include-ignored))
            next-deps (if (= (. parsed :include-deps) nil)
                          session.include-deps
                          (. parsed :include-deps))
            next-hidden (if (= (. parsed :include-hidden) nil)
                            session.include-hidden
                            (. parsed :include-hidden))
            next-prefilter (if (= (. parsed :prefilter) nil)
                               session.prefilter-mode
                               (. parsed :prefilter))
            next-lazy (if (= (. parsed :lazy) nil)
                          session.lazy-mode
                          (. parsed :lazy))
            changed (or (~= next-hidden session.effective-include-hidden)
                        (~= next-ignored session.effective-include-ignored)
                        (~= next-deps session.effective-include-deps)
                        (~= next-prefilter session.prefilter-mode)
                        (~= next-lazy session.lazy-mode))]
        (set session.effective-include-hidden next-hidden)
        (set session.effective-include-ignored next-ignored)
        (set session.effective-include-deps next-deps)
        (set session.prefilter-mode next-prefilter)
        (set session.lazy-mode next-lazy)
        (set session.last-parsed-query parsed)
        (set session.meta.debug_out
          (if session.project-mode
              (.. " ["
                  (if session.effective-include-hidden "+hidden" "-hidden")
                  " "
                  (if session.effective-include-ignored "+ignored" "-ignored")
                  " "
                  (if session.effective-include-deps "+deps" "-deps")
                  " "
                  (if session.prefilter-mode "+prefilter" "-prefilter")
                  " "
                  (if session.lazy-mode "+lazy" "-lazy")
                  "]")
              ""))
        (when (and session.project-mode changed)
          (apply-source-set! session))
        (session.meta.set-query-lines (. parsed :lines)))
      (let [[ok err] [(pcall session.meta.on-update 0)]]
        (if ok
            (do
              (session.meta.refresh_statusline)
              (update-info-window session))
            (when (string.find (tostring err) "E565")
              ;; Textlock race: retry right after current input cycle.
              (vim.defer_fn (fn []
                              (when (and session.meta
                                         (vim.api.nvim_buf_is_valid session.meta.buf.buffer))
                                (pcall session.meta.on-update 0)
                                (pcall session.meta.refresh_statusline)
                                (pcall update-info-window session)))
                            1))))))))

(fn M.on-prompt-changed [prompt-buf force event-tick]
  (let [session (. M.active-by-prompt prompt-buf)]
    (when (and session (not session.closing))
      (if (and (not force)
               event-tick
               (= event-tick (or session.prompt-last-event-tick -1)))
          nil
          (let [txt (prompt-text session)
                now (now-ms)]
            (when (and (not force) event-tick)
              (set session.prompt-last-event-tick event-tick))
            (if (and force
                     (< now (or session.prompt-force-block-until 0)))
                nil
                (if (and (not force) (= txt (or session.prompt-last-event-text "")))
                    (when session.prompt-update-pending
                      ;; Strict trailing-edge debounce: even if duplicate prompt events
                      ;; report the same text, re-arm from now while input continues.
                      (set session.prompt-last-change-ms now)
                      (set session.prompt-force-block-until (+ now (math.max 0 (prompt-update-delay-ms session))))
                      (schedule-prompt-update! session (prompt-update-delay-ms session)))
                    (do
                      ;; Prompt display state is independent; matcher query state updates only
                      ;; in deferred apply-prompt-lines.
                      (set session.prompt-last-event-text txt)
                      (set session.last-prompt-text txt)
                      (set session.prompt-update-dirty true)
                      (set session.prompt-last-change-ms now)
                      (when (not force)
                        ;; Hard block forced updates during active user input window.
                        (set session.prompt-force-block-until (+ now (math.max 0 (prompt-update-delay-ms session)))))
                      (set session.prompt-change-seq (+ 1 (or session.prompt-change-seq 0)))
                      ;; Keep empty :Meta! startup lightweight; only bootstrap full
                      ;; project sources once there is an active prompt query.
                      (when (and session.project-mode
                                 (not session.project-bootstrapped)
                                 (prompt-has-active-query? session))
                        ;; User started typing: expedite bootstrap instead of waiting
                        ;; for any longer idle startup timeout.
                        (schedule-project-bootstrap! session M.project-bootstrap-delay-ms))
                      ;; Avoid double post-typing updates in project mode while bootstrap is
                      ;; still pending; we'll schedule exactly one refresh once bootstrap ends.
                      (when (or (not session.project-mode) session.project-bootstrapped)
                        (if (and force session.prompt-update-pending)
                            ;; A trailing user-typing update is already queued; do not
                            ;; re-arm timers for forced/lazy refreshes.
                            nil
                            (let [delay (prompt-update-delay-ms session)]
                              (if (and force
                                       (= txt (or session.prompt-last-applied-text ""))
                                       (> (math.max 0 (or M.prompt-forced-coalesce-ms 0)) 0)
                                       (< (- (now-ms) (or session.prompt-last-apply-ms 0))
                                          (math.max 0 (or M.prompt-forced-coalesce-ms 0))))
                                  ;; Skip near-immediate forced refresh after a just-applied
                                  ;; identical prompt state (for example rapid backspace).
                                  nil
                                  (if (and force
                                           ;; Also block forced updates while prompt
                                           ;; input is still considered "active".
                                           (< (- (now-ms) (or session.prompt-last-change-ms 0))
                                              (math.max
                                                (math.max 0 (or M.prompt-update-idle-ms 0))
                                                (math.max 0 (or M.prompt-forced-coalesce-ms 0)))))
                                      nil
                                      (if (and force
                                               (> (math.max 0 (or M.prompt-update-idle-ms 0)) 0)
                                               (< (- (now-ms) (or session.prompt-last-change-ms 0))
                                                  (math.max 0 (or M.prompt-update-idle-ms 0))))
                                          ;; During active typing, defer forced refreshes to idle.
                                          (schedule-prompt-update! session (math.max delay M.prompt-update-idle-ms))
                                          (schedule-prompt-update! session delay)))))))))))))))

(fn finish-accept [session]
  (local curr session.meta)
  (set session.last-prompt-text (prompt-text session))
  (push-history! session.last-prompt-text)
  (apply-prompt-lines session)
  (begin-session-close! session)
  (pcall vim.cmd "stopinsert")
  (let [matcher (curr.matcher)]
    (when matcher
      (pcall matcher.remove-highlight matcher)))
  (pcall vim.cmd (.. "sign unplace * buffer=" curr.buf.buffer))
  (when (and (vim.api.nvim_win_is_valid session.origin-win)
             (vim.api.nvim_buf_is_valid session.origin-buf))
    (pcall vim.api.nvim_set_current_win session.origin-win)
    (pcall vim.api.nvim_win_set_buf session.origin-win session.origin-buf))
  (if session.project-mode
      (let [ref (selected-ref curr)]
        (when (and ref ref.path)
          (vim.cmd (.. "edit " (vim.fn.fnameescape ref.path)))
          (vim.api.nvim_win_set_cursor 0 [(math.max 1 (or ref.lnum 1)) 0])))
      (do
        (base_buffer.switch-buf curr.buf.model)
        (let [row (curr.selected_line)]
          (curr.win.set-row row true)
          (let [vq (curr.vim_query)]
            (when (~= vq "")
              (vim.api.nvim_win_set_cursor 0 [row 0])
              (let [pos (vim.fn.searchpos vq "cnW" row)
                    hit-row (. pos 1)
                    hit-col (. pos 2)]
                (when (and (= hit-row row) (> hit-col 0))
                  (vim.api.nvim_win_set_cursor 0 [row hit-col]))))))))
  (vim.cmd "normal! zv")
  (let [vq (curr.vim_query)]
    (when (~= vq "")
      (vim.fn.setreg "/" vq)
      (set vim.o.hlsearch true)))
  (wipe-temp-buffers curr)
  (remove-session session)
  (M._wrapup curr)
  curr)

(fn finish-cancel [session]
  (local curr session.meta)
  (begin-session-close! session)
  (set session.last-prompt-text (prompt-text session))
  (push-history! session.last-prompt-text)
  (pcall vim.cmd "stopinsert")
  (let [matcher (curr.matcher)]
    (when matcher
      (pcall matcher.remove-highlight matcher)))
  (pcall vim.cmd (.. "sign unplace * buffer=" curr.buf.buffer))
  (vim.cmd "silent! nohlsearch")
  (when (and (vim.api.nvim_win_is_valid session.origin-win)
             (vim.api.nvim_buf_is_valid session.origin-buf))
    (pcall vim.api.nvim_set_current_win session.origin-win)
    (pcall vim.api.nvim_win_set_buf session.origin-win session.origin-buf))
  (base_buffer.switch-buf curr.buf.model)
  (wipe-temp-buffers curr)
  (remove-session session)
  (M._wrapup curr)
  curr)

(fn M.finish [kind prompt-buf]
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (if (= kind "accept")
          (finish-accept session)
          (finish-cancel session)))))

(fn M.move-selection [prompt-buf delta]
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (let [runner (fn []
                     (let [meta session.meta
                           max (# meta.buf.indices)]
                       (when (> max 0)
                         (set meta.selected_index (math.max 0 (math.min (+ meta.selected_index delta) (- max 1))))
                         (let [row (+ meta.selected_index 1)]
                           (when (vim.api.nvim_win_is_valid meta.win.window)
                             (pcall vim.api.nvim_win_set_cursor meta.win.window [row 0])))
                         (pcall meta.refresh_statusline)
                         (pcall update-info-window session false))))
            mode (. (vim.api.nvim_get_mode) :mode)]
        (if (and (= (type mode) "string") (vim.startswith mode "i"))
            (vim.schedule runner)
            (runner))))))

(fn sync-selected-from-main-cursor! [session]
  (let [meta session.meta
        max (# meta.buf.indices)]
    (if (<= max 0)
        (set meta.selected_index 0)
        (when (vim.api.nvim_win_is_valid meta.win.window)
          (let [c (vim.api.nvim_win_get_cursor meta.win.window)
                row (. c 1)
                clamped (math.max 1 (math.min row max))]
            (when (~= row clamped)
              (pcall vim.api.nvim_win_set_cursor meta.win.window [clamped (. c 2)]))
            (set meta.selected_index (- clamped 1)))))))

(fn can-refresh-source-syntax? [session]
  (let [buf (and session session.meta session.meta.buf)]
    (and session
         session.project-mode
         buf
         buf.show-source-separators
         (= buf.syntax-type "buffer"))))

(fn schedule-source-syntax-refresh! [session]
  (when (can-refresh-source-syntax? session)
    (set session.syntax-refresh-dirty true)
    (when (not session.syntax-refresh-pending)
      (set session.syntax-refresh-pending true)
      (vim.defer_fn
        (fn []
          (set session.syntax-refresh-pending false)
          (when (and session
                     session.prompt-buf
                     (= (. M.active-by-prompt session.prompt-buf) session))
            (when session.syntax-refresh-dirty
              (set session.syntax-refresh-dirty false)
              (pcall session.meta.buf.apply-source-syntax-regions))
            ;; If additional scroll events arrived while refreshing, ensure we
            ;; run one trailing update.
            (when session.syntax-refresh-dirty
              (schedule-source-syntax-refresh! session))))
        80))))

(fn M.scroll-main [prompt-buf action]
  (let [session (. M.active-by-prompt prompt-buf)]
    (when (and session (vim.api.nvim_win_is_valid session.meta.win.window))
      (let [runner (fn []
                     (vim.api.nvim_win_call session.meta.win.window
                       (fn []
                         (let [line-count (vim.api.nvim_buf_line_count session.meta.buf.buffer)
                               win-height (math.max 1 (vim.api.nvim_win_get_height session.meta.win.window))
                               half-step (math.max 1 (math.floor (/ win-height 2)))
                               page-step (math.max 1 (- win-height 2))
                               step (if (or (= action "half-down") (= action "half-up")) half-step page-step)
                               dir (if (or (= action "half-down") (= action "page-down")) 1 -1)
                               max-top (math.max 1 (+ (- line-count win-height) 1))
                               view (vim.fn.winsaveview)
                               old-top (. view :topline)
                               old-lnum (. view :lnum)
                               old-col (or (. view :col) 0)
                               row-off (math.max 0 (- old-lnum old-top))
                               new-top (math.max 1 (math.min (+ old-top (* dir step)) max-top))
                               new-lnum (math.max 1 (math.min (+ new-top row-off) line-count))]
                           (set (. view :topline) new-top)
                           (set (. view :lnum) new-lnum)
                           (set (. view :col) old-col)
                           (vim.fn.winrestview view))))
                     (sync-selected-from-main-cursor! session)
                     (pcall session.meta.refresh_statusline)
                     (pcall update-info-window session false))
            mode (. (vim.api.nvim_get_mode) :mode)]
        (if (and (= (type mode) "string") (vim.startswith mode "i"))
            (vim.schedule runner)
            (runner))))))

(fn maybe-sync-from-main! [session force-refresh]
  (when (and session
             (not session.startup-initializing)
             (vim.api.nvim_win_is_valid session.meta.win.window)
             (vim.api.nvim_buf_is_valid session.prompt-buf)
             (= (vim.api.nvim_get_current_win) session.meta.win.window)
             (= (. M.active-by-prompt session.prompt-buf) session))
    (let [before session.meta.selected_index]
      (sync-selected-from-main-cursor! session)
      (when force-refresh
        (schedule-source-syntax-refresh! session))
      (when (or force-refresh (~= before session.meta.selected_index))
        (pcall session.meta.refresh_statusline)
        (pcall update-info-window session false)))))

(fn schedule-scroll-sync! [session]
  (when (and session (not session.scroll-sync-pending))
    (set session.scroll-sync-pending true)
    (vim.defer_fn
      (fn []
        (set session.scroll-sync-pending false)
        (maybe-sync-from-main! session true))
      20)))

(fn M.history-or-move [prompt-buf delta]
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (let [txt (prompt-text session)
            can-history (or (= txt "")
                            (= txt session.initial-prompt-text)
                            (= txt session.last-history-text))]
        (if can-history
            (let [h (history-list)
                  n (# h)]
              (when (> n 0)
                (set session.history-index (math.max 0 (math.min (+ session.history-index delta) n)))
                (if (= session.history-index 0)
                    (do
                      (set session.last-history-text "")
                      (set-prompt-text! session session.initial-prompt-text))
                    (let [entry (history-entry session session.history-index)]
                      (when entry
                        (set session.last-history-text entry)
                        (set-prompt-text! session entry))))))
            (M.move-selection prompt-buf delta))))))

(fn M.toggle-scan-option [prompt-buf which]
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (if (= which "ignored")
          (set session.include-ignored (not session.include-ignored))
          (if (= which "deps")
              (set session.include-deps (not session.include-deps))
              (when (= which "hidden")
                (set session.include-hidden (not session.include-hidden)))))
      (set session.effective-include-hidden session.include-hidden)
      (set session.effective-include-ignored session.include-ignored)
      (set session.effective-include-deps session.include-deps)
      (when session.project-mode
        (apply-source-set! session))
      (apply-prompt-lines session))))

(fn M.toggle-project-mode [prompt-buf]
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (set session.project-mode (not session.project-mode))
      (set session.meta.project-mode session.project-mode)
      (session.meta.buf.set-name (meta-buffer-name session))
      (apply-source-set! session)
      (apply-prompt-lines session))))

(fn register-prompt-hooks [session]
  (fn disable-cmp []
    (mark-prompt-buffer! session.prompt-buf)
    (let [[ok cmp] [(pcall require :cmp)]]
      (when ok
        (pcall cmp.setup.buffer {:enabled false})
        (pcall cmp.abort))))
  (fn switch-mode [which]
    (let [meta session.meta]
      (meta.switch_mode which)
      (pcall meta.refresh_statusline)))
  (fn apply-keymaps []
    (local opts {:buffer session.prompt-buf :silent true :noremap true :nowait true})
    (fn map! [m lhs rhs]
      (vim.keymap.set m lhs rhs opts))
    (fn map-rules! [rules]
      (each [_ r (ipairs rules)]
        (map! (. r 1) (. r 2) (. r 3))))
    (map-rules!
      [ [["n" "i"] "<CR>" (fn [] (M.finish "accept" session.prompt-buf))]
        ;; In insert mode, <Esc> should only leave insert mode.
        ;; Cancel/close only from normal mode.
        ["n" "<Esc>" (fn [] (M.finish "cancel" session.prompt-buf))]
        ["n" "<C-p>" (fn [] (M.move-selection session.prompt-buf -1))]
        ["n" "<C-n>" (fn [] (M.move-selection session.prompt-buf 1))]
        ["i" "<C-p>" (fn [] (M.move-selection session.prompt-buf -1))]
        ["i" "<C-n>" (fn [] (M.move-selection session.prompt-buf 1))]
        ["n" "<C-k>" (fn [] (M.move-selection session.prompt-buf -1))]
        ["n" "<C-j>" (fn [] (M.move-selection session.prompt-buf 1))]
        ["i" "<C-k>" (fn [] (M.move-selection session.prompt-buf -1))]
        ["i" "<C-j>" (fn [] (M.move-selection session.prompt-buf 1))]
        ["i" "<Up>" (fn [] (M.history-or-move session.prompt-buf 1))]
        ["i" "<Down>" (fn [] (M.history-or-move session.prompt-buf -1))]
        ["n" "<Up>" (fn [] (M.history-or-move session.prompt-buf 1))]
        ["n" "<Down>" (fn [] (M.history-or-move session.prompt-buf -1))]
        ;; Statusline keys: C^ (matcher), C_ (case), Cs (syntax)
        [["n" "i"] "<C-^>" (fn [] (switch-mode "matcher"))]
        [["n" "i"] "<C-6>" (fn [] (switch-mode "matcher"))]
        [["n" "i"] "<C-_>" (fn [] (switch-mode "case"))]
        [["n" "i"] "<C-/>" (fn [] (switch-mode "case"))]
        [["n" "i"] "<C-?>" (fn [] (switch-mode "case"))]
        [["n" "i"] "<C-->" (fn [] (switch-mode "case"))]
        [["n" "i"] "<C-o>" (fn [] (switch-mode "case"))]
        [["n" "i"] "<C-s>" (fn [] (switch-mode "syntax"))]
        ["n" "<C-g>" (fn [] (M.toggle-scan-option session.prompt-buf "ignored"))]
        ["n" "<C-l>" (fn [] (M.toggle-scan-option session.prompt-buf "deps"))]
        [["n" "i"] "<C-d>" (fn [] (M.scroll-main session.prompt-buf "half-down"))]
        [["n" "i"] "<C-u>" (fn [] (M.scroll-main session.prompt-buf "half-up"))]
        [["n" "i"] "<C-f>" (fn [] (M.scroll-main session.prompt-buf "page-down"))]
        [["n" "i"] "<C-b>" (fn [] (M.scroll-main session.prompt-buf "page-up"))]
        ;; keep project toggle available without conflicting with scroll/page keys
        [["n" "i"] "<C-t>" (fn [] (M.toggle-project-mode session.prompt-buf))] ]))
  (local aug (vim.api.nvim_create_augroup (.. "MetaPrompt" session.prompt-buf) {:clear true}))
  (set session.augroup aug)
  ;; Some environments/plugins do not reliably emit TextChangedI for this
  ;; scratch prompt buffer; keep a low-level line-change hook as a fallback.
  (vim.api.nvim_buf_attach session.prompt-buf false
    {:on_lines (fn [_ _ changedtick _ _ _ _ _]
                 ;; on_lines can fire before insert-state buffer text is fully
                 ;; visible; defer one tick so we observe the committed prompt.
                 (vim.schedule
                   (fn []
                     (when (and session.prompt-buf
                                (= (. M.active-by-prompt session.prompt-buf) session))
                       (M.on-prompt-changed session.prompt-buf false changedtick)))))
     :on_detach (fn []
                  (when session.prompt-buf
                    (set (. M.active-by-prompt session.prompt-buf) nil)))})
  ;; Prompt text updates: rely on post-change autocmds to avoid pre-edit race
  ;; behavior that can leave matcher one character behind while typing.
  (vim.api.nvim_create_autocmd ["TextChanged" "TextChangedI"]
    {:group aug
     :buffer session.prompt-buf
     :callback (fn [_]
                 (M.on-prompt-changed
                   session.prompt-buf
                   false
                   (vim.api.nvim_buf_get_changedtick session.prompt-buf)))})
  ;; Re-assert prompt maps when entering insert mode; this wins over late
  ;; plugin mappings (for example completion plugins).
  (vim.api.nvim_create_autocmd "InsertEnter"
    {:group aug
     :buffer session.prompt-buf
     :callback (fn [_]
                 (vim.schedule
                   (fn []
                     (disable-cmp)
                     (apply-keymaps))))})
  ;; Some statusline plugins or focus transitions (for example tmux pane
  ;; switches) can overwrite local statusline state. Re-apply ours when the
  ;; prompt window regains focus.
  (vim.api.nvim_create_autocmd ["BufEnter" "WinEnter" "FocusGained"]
    {:group aug
     :buffer session.prompt-buf
     :callback (fn [_]
                 (vim.schedule
                   (fn []
                     (when (and session.meta
                                (vim.api.nvim_buf_is_valid session.prompt-buf))
                       (pcall session.meta.refresh_statusline)))))})
  ;; Refresh mode segment when switching Insert/Normal/Replace in the prompt.
  (vim.api.nvim_create_autocmd ["ModeChanged" "InsertEnter" "InsertLeave"]
    {:group aug
     :buffer session.prompt-buf
     :callback (fn [_]
                 (vim.schedule
                   (fn []
                     (when (and session.meta
                                (vim.api.nvim_buf_is_valid session.prompt-buf))
                       (pcall session.meta.refresh_statusline)))))})
  ;; Recompute floating info rendering/width when editor windows resize.
  (vim.api.nvim_create_autocmd ["VimResized" "WinResized"]
    {:group aug
     :callback (fn [_]
                 (vim.schedule
                   (fn []
                     (when (and session.meta
                                (vim.api.nvim_buf_is_valid session.prompt-buf))
                       (pcall update-info-window session)))))})
  ;; Keep selection/status/info synced when user scrolls or moves in the
  ;; main meta window with regular motions/mouse while prompt is open.
  (vim.api.nvim_create_autocmd ["CursorMoved" "CursorMovedI"]
    {:group aug
     :buffer session.meta.buf.buffer
     :callback (fn [_]
                 (vim.schedule
                   (fn []
                     (maybe-sync-from-main! session))))})
  (vim.api.nvim_create_autocmd "WinScrolled"
    {:group aug
     :callback (fn [_]
                 (schedule-scroll-sync! session))})
  (disable-cmp)
  (mark-prompt-buffer! session.prompt-buf)
  (apply-keymaps)
  )

(fn M.start [query mode _meta project-mode]
  (let [parsed-query (parse-query-text query)
        query0 (. parsed-query :query)
        start-hidden (if (= (. parsed-query :include-hidden) nil)
                         (truthy? M.default-include-hidden)
                         (. parsed-query :include-hidden))
        start-ignored (if (= (. parsed-query :include-ignored) nil)
                          (truthy? M.default-include-ignored)
                          (. parsed-query :include-ignored))
        start-deps (if (= (. parsed-query :include-deps) nil)
                       (truthy? M.default-include-deps)
                       (. parsed-query :include-deps))
        start-prefilter (if (= (. parsed-query :prefilter) nil)
                            (truthy? M.project-lazy-prefilter-enabled)
                            (. parsed-query :prefilter))
        start-lazy (if (= (. parsed-query :lazy) nil)
                       (truthy? M.project-lazy-enabled)
                       (. parsed-query :lazy))
        query query0]
  (local source-buf (vim.api.nvim_get_current_buf))
  (when (. M.active-by-source source-buf)
    (remove-session (. M.active-by-source source-buf)))
  (let [origin-win (vim.api.nvim_get_current_win)
        origin-buf source-buf
        source-view (vim.fn.winsaveview)
        _ (set (. source-view :_meta_win_height) (vim.api.nvim_win_get_height origin-win))
        condition (setup-state query mode source-view)
        curr (meta_mod.new vim condition)]
    (set curr.project-mode (or project-mode false))
    (base_buffer.switch-buf curr.buf.buffer)
    (ensure-source-refs! curr)
    (let [initial-lines (if (and query (~= query ""))
                            (vim.split query "\n" {:plain true})
                            [""])
          prompt-win (prompt_window_mod.new vim {:height (prompt-height)})
          prompt-buf prompt-win.buffer
          session {:source-buf source-buf
                   :origin-win origin-win
                   :origin-buf origin-buf
                   :source-view source-view
                   :initial-source-line (math.max 1 (or (. source-view :lnum) (+ (or condition.selected-index 0) 1)))
                   :prompt-win prompt-win.window
                   :prompt-buf prompt-buf
                   :initial-prompt-text (table.concat initial-lines "\n")
                   :last-prompt-text (table.concat initial-lines "\n")
                   :last-history-text ""
                   :history-index 0
                   :prompt-update-pending false
                   :prompt-update-dirty false
                   :prompt-change-seq 0
                   :prompt-last-apply-ms 0
                   :prompt-last-event-text (table.concat initial-lines "\n")
                   :initial-query-active (query-lines-has-active? (. parsed-query :lines))
                   :startup-initializing true
                   :project-mode (or project-mode false)
                   :include-hidden start-hidden
                   :include-ignored start-ignored
                   :include-deps start-deps
                   :effective-include-hidden start-hidden
                   :effective-include-ignored start-ignored
                   :effective-include-deps start-deps
                   :project-bootstrap-pending false
                   :project-bootstrap-token 0
                   :project-bootstrap-delay-ms (if (query-lines-has-active? (. parsed-query :lines))
                                                   M.project-bootstrap-delay-ms
                                                   M.project-bootstrap-idle-delay-ms)
                   :project-bootstrapped (not (or project-mode false))
                   :prefilter-mode start-prefilter
                   :lazy-mode start-lazy
                   :last-parsed-query {:lines (if (and query (~= query ""))
                                                  (vim.split query "\n" {:plain true})
                                                  [""])
                                       :include-hidden start-hidden
                                       :include-ignored start-ignored
                                       :include-deps start-deps
                                       :prefilter start-prefilter
                                       :lazy start-lazy}
                   :single-content (vim.deepcopy curr.buf.content)
                   :single-refs (vim.deepcopy (or curr.buf.source-refs []))
                   :meta curr}]
      (local initial-query-active session.initial-query-active)
      (if session.project-mode
          (apply-minimal-source-set! session)
          (apply-source-set! session))
      (set curr.status-win (meta_window_mod.new vim prompt-win.window))
      ;; Statusline info should live in prompt window, not result split.
      (curr.win.set-statusline "")
      ;; Initialize/render after prompt split exists so we avoid an extra
      ;; post-split view correction pass that can visually "flash" scroll.
      (curr.on-init)
      ;; Ensure initial selection/view is anchored before attaching prompt
      ;; hooks that may sync from main-window cursor events.
      (when session.project-mode
        (restore-meta-view! curr session.source-view))
      (vim.api.nvim_buf_set_lines prompt-buf 0 -1 false initial-lines)
      (mark-prompt-buffer! prompt-buf)
      (register-prompt-hooks session)
      (set (. M.active-by-source source-buf) session)
      (set (. M.active-by-prompt prompt-buf) session)
      (when (not (and session.project-mode (not initial-query-active)))
        (apply-prompt-lines session))
      (vim.api.nvim_set_current_win prompt-win.window)
      (vim.cmd "startinsert")
      (vim.schedule (fn [] (set session.startup-initializing false)))
      (when (and session.project-mode (not initial-query-active))
        ;; Keep startup critical path lean; refresh auxiliary UI right after.
        (vim.schedule
          (fn []
            (when (= (. M.active-by-prompt session.prompt-buf) session)
              (pcall curr.refresh_statusline)
              (pcall update-info-window session)))))
      (when (and session.project-mode (not session.project-bootstrapped))
        (schedule-project-bootstrap! session session.project-bootstrap-delay-ms))
      (set (. M.instances source-buf) curr)
      curr))))

(fn M.sync [meta query]
  (when (not meta)
    (vim.notify "No Meta instance" vim.log.levels.WARN))
  (when meta
    (meta.set-query-lines (if (and query (~= query "")) [query] []))
    (meta.on-update 0)
    (M._store_vars meta)
    meta))

(fn M.push [meta]
  (if (not meta)
      (vim.notify "No Meta instance" vim.log.levels.WARN)
      (let [lines (vim.api.nvim_buf_get_lines meta.buf.buffer 0 -1 false)]
        (meta.buf.push-visible-lines lines))))

(fn M.entry_start [query _bang]
  (M.start query "start" nil _bang))

(fn M.entry_resume [query]
  (M.start query "resume" nil))

(fn M.entry_sync [query]
  (local key (vim.api.nvim_get_current_buf))
  (M.sync (. M.instances key) query))

(fn M.entry_push []
  (local key (vim.api.nvim_get_current_buf))
  (M.push (. M.instances key)))

(fn M.entry_cursor_word [resume]
  (local w (vim.fn.expand "<cword>"))
  (if resume
      (M.entry_resume w)
      (M.entry_start w false)))

M
