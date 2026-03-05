(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local meta_mod (require :metabuffer.meta))
(local prompt_window_mod (require :metabuffer.window.prompt))
(local meta_window_mod (require :metabuffer.window.metawindow))
(local floating_window_mod (require :metabuffer.window.floating))
(local preview_window_mod (require :metabuffer.window.preview))
(local info_window_mod (require :metabuffer.window.info))
(local project_source_mod (require :metabuffer.project.source))
(local base_buffer (require :metabuffer.buffer.base))
(local session_view (require :metabuffer.session.view))
(local debug (require :metabuffer.debug))
(local config (require :metabuffer.config))
(local query_mod (require :metabuffer.query))
(local history_store (require :metabuffer.history_store))
(local prompt_hooks_mod (require :metabuffer.prompt.hooks))

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
(local push-history! (fn [text]
                       (history_store.push! text M.history-max)))

(fn debug-log
  [msg]
  (debug.log "router" msg))

(fn prompt-height
  []
  (or (tonumber vim.g.meta_prompt_height)
      (tonumber (. vim.g "meta#prompt_height"))
      7))

(fn persist-prompt-height!
  [session]
  (when (and session session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
    (let [[ok h] [(pcall vim.api.nvim_win_get_height session.prompt-win)]]
      (when (and ok h (> h 0))
        (set vim.g.meta_prompt_height h)
        (set (. vim.g "meta#prompt_height") h)))))

(fn info-height
  [session]
  (if (and session session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
      (let [p-row-col (vim.api.nvim_win_get_position session.prompt-win)
            p-row (. p-row-col 1)]
        (math.max 7 (- p-row 2)))
      (math.max 7 (- vim.o.lines (+ (prompt-height) 4)))))

(fn now-ms
  []
  (/ (vim.loop.hrtime) 1000000))

(fn prompt-update-delay-ms
  [session]
  (let [base (math.max 0 M.prompt-update-debounce-ms)
        n (if (and session session.meta session.meta.buf session.meta.buf.indices)
              (# session.meta.buf.indices)
              0)
        short-extra-ms (or M.prompt-short-query-extra-ms [180 120 70])
        size-thresholds (or M.prompt-size-scale-thresholds [2000 10000 50000])
        size-extra (or M.prompt-size-scale-extra [0 2 6 10])
        qlen (let [lines (prompt-lines session)
                   parsed (if session.project-mode
                              (query_mod.parse-query-lines lines)
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
                        (or (. short-extra-ms 1) 180)
                        (if (<= qlen 2)
                            (or (. short-extra-ms 2) 120)
                            (if (<= qlen 3) (or (. short-extra-ms 3) 70) 0)))
        scale (if (< n (or (. size-thresholds 1) 2000))
                  (or (. size-extra 1) 0)
                  (if (< n (or (. size-thresholds 2) 10000))
                      (or (. size-extra 2) 2)
                      (if (< n (or (. size-thresholds 3) 50000))
                          (or (. size-extra 3) 6)
                          (or (. size-extra 4) 10))))
        extra (if (and session session.project-mode (not session.lazy-stream-done)) 2 0)]
    (+ base short-extra scale extra)))

(fn prompt-has-active-query?
  [session]
  (let [parsed (query_mod.parse-query-lines (prompt-lines session))]
    (var has false)
    (each [_ line (ipairs (or (. parsed :lines) []))]
      (when (and (not has) (~= (vim.trim (or line "")) ""))
        (set has true)))
    has))

(fn cancel-prompt-update!
  [session]
  (when (and session session.prompt-update-timer)
    (let [timer session.prompt-update-timer
          stopf (. timer :stop)
          closef (. timer :close)]
      (when stopf (pcall stopf timer))
      (when closef (pcall closef timer))
      (set session.prompt-update-timer nil)
      (set session.prompt-update-pending false))))

(fn begin-session-close!
  [session]
  "Cancel all queued/async session work before window teardown."
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

(fn schedule-prompt-update!
  [session wait-ms]
  "Schedule trailing-edge prompt application and coalesce rapid edits."
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

(set prompt-lines (fn [session]
  (if (and session (vim.api.nvim_buf_is_valid session.prompt-buf))
      (vim.api.nvim_buf_get_lines session.prompt-buf 0 -1 false)
      [])))

(fn prompt-text
  [session]
  (table.concat (prompt-lines session) "\n"))

(fn mark-prompt-buffer!
  [buf]
  (when (and buf (vim.api.nvim_buf_is_valid buf))
    ;; Best-effort disables for common auto-pairs/completion helpers.
    (pcall vim.api.nvim_buf_set_var buf "autopairs_enabled" false)
    (pcall vim.api.nvim_buf_set_var buf "AutoPairsDisabled" 1)
    (pcall vim.api.nvim_buf_set_var buf "delimitMate_enabled" 0)
    (pcall vim.api.nvim_buf_set_var buf "pear_tree_disable" 1)
    (pcall vim.api.nvim_buf_set_var buf "endwise_disable" 1)
    (pcall vim.api.nvim_buf_set_var buf "cmp_enabled" false)
    (pcall vim.api.nvim_buf_set_var buf "meta_prompt" true)))

(fn set-prompt-text!
  [session text]
  (when (and session (vim.api.nvim_buf_is_valid session.prompt-buf))
    (set session.last-prompt-text (or text ""))
    (local lines (if (= text "") [""] (vim.split text "\n" {:plain true})))
    (vim.api.nvim_buf_set_lines session.prompt-buf 0 -1 false lines)
    (let [row (# lines)
          col (# (. lines row))]
      (pcall vim.api.nvim_win_set_cursor session.prompt-win [row col]))))

(fn current-buffer-path
  [buf]
  (and buf
       (vim.api.nvim_buf_is_valid buf)
       (let [[ok name] [(pcall vim.api.nvim_buf_get_name buf)]]
         (when (and ok (= (type name) "string") (~= name ""))
           name))))

(fn meta-buffer-name
  [session]
  (if session.project-mode
      "Metabuffer"
      (let [original-name (current-buffer-path session.source-buf)
            base-name (if (and (= (type original-name) "string") (~= original-name ""))
                          (vim.fn.fnamemodify original-name ":t")
                          "[No Name]")]
        (.. base-name " • Metabuffer"))))

(fn ensure-source-refs!
  [meta]
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

(fn selected-ref
  [meta]
  (let [src-idx (. meta.buf.indices (+ meta.selected_index 1))
        refs (or meta.buf.source-refs [])]
    (and src-idx (. refs src-idx))))

(fn hidden-path?
  [path]
  (let [parts (vim.split path "/" {:plain true})]
    (var hidden false)
    (each [_ p (ipairs parts)]
      (when (and (~= p "") (vim.startswith p "."))
        (set hidden true)))
    hidden))

(fn dep-path?
  [path]
  (let [parts (vim.split path "/" {:plain true})]
    (var dep false)
    (each [_ p (ipairs parts)]
      (when (. M.dep-dir-names p)
        (set dep true)))
    dep))

(fn allow-project-path?
  [rel include-hidden include-deps]
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

(fn project-file-list
  [root include-hidden include-ignored include-deps]
  "Collect project file paths using rg (or glob fallback)."
  (let [rg-bin (or M.project-rg-bin "rg")]
    (if (= 1 (vim.fn.executable rg-bin))
        (let [cmd [rg-bin]
              _ (each [_ arg (ipairs (or M.project-rg-base-args []))]
                  (table.insert cmd arg))
              _ (when include-hidden
                  (table.insert cmd "--hidden"))
              _ (when include-ignored
                  (each [_ arg (ipairs (or M.project-rg-include-ignored-args []))]
                    (table.insert cmd arg)))
              _ (when (not include-deps)
                  (each [_ glob (ipairs (or M.project-rg-deps-exclude-globs []))]
                    (table.insert cmd "--glob")
                    (table.insert cmd glob)))
            rel (vim.fn.systemlist cmd)]
          (vim.tbl_map
            (fn [p] (vim.fn.fnamemodify (.. root "/" p) ":p"))
            (or rel [])))
        (vim.fn.globpath root (or M.project-fallback-glob-pattern "**/*") true true))))

(fn ui-attached?
  []
  (> (# (vim.api.nvim_list_uis)) 0))

(fn lazy-streaming-allowed?
  [session]
  (and session
       session.project-mode
       (query_mod.truthy? M.project-lazy-enabled)
       (or (not (query_mod.truthy? M.project-lazy-disable-headless))
           (ui-attached?))))

(fn session-active?
  [session]
  (and session
       session.prompt-buf
       (= (. M.active-by-prompt session.prompt-buf) session)))

(fn canonical-path
  [path]
  (when (and (= (type path) "string") (~= path ""))
    (vim.fn.fnamemodify path ":p")))

(fn path-under-root?
  [path root]
  (let [p (canonical-path path)
        r (canonical-path root)]
    (and p r (vim.startswith p r))))

(fn read-file-lines-cached
  [path]
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
     :debug-log debug-log
     :update-preview (fn [session]
                       (preview-window.maybe-update-for-selection! session))}))

(set update-info-window
  (fn [session refresh-lines]
    (info-window.update! session refresh-lines)))

(local project-source
  (project_source_mod.new
    {:settings M
     :truthy? query_mod.truthy?
     :selected-ref selected-ref
     :canonical-path canonical-path
     :current-buffer-path current-buffer-path
     :path-under-root? path-under-root?
     :allow-project-path? allow-project-path?
     :project-file-list project-file-list
     :read-file-lines-cached read-file-lines-cached
     :session-active? session-active?
     :lazy-streaming-allowed? lazy-streaming-allowed?
     :on-prompt-changed (fn [prompt-buf force]
                          (M.on-prompt-changed prompt-buf force))
     :prompt-has-active-query? prompt-has-active-query?
     :now-ms now-ms
     :prompt-update-delay-ms prompt-update-delay-ms
     :schedule-prompt-update! schedule-prompt-update!
     :restore-meta-view! session_view.restore-meta-view!
     :update-info-window update-info-window}))

(fn M._store_vars
  [meta]
  (set vim.b._meta_context (meta.store))
  (set vim.b._meta_indexes meta.buf.indices)
  (set vim.b._meta_updates meta.updates)
  (set vim.b._meta_source_bufnr meta.buf.model)
  meta)

(fn M._wrapup
  [meta]
  (vim.cmd "redraw|redrawstatus")
  (M._store_vars meta))

(fn remove-session
  [session]
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
                       (query_mod.parse-query-lines lines)
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
          (project-source.apply-source-set! session))
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

(fn M.on-prompt-changed
  [prompt-buf force event-tick]
  "Entry point for prompt edits; keeps typing fast by deferring matcher work."
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
                        (project-source.schedule-project-bootstrap! session M.project-bootstrap-delay-ms))
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

(fn finish-accept
  [session]
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
  (session_view.wipe-temp-buffers curr)
  (remove-session session)
  (M._wrapup curr)
  curr)

(fn finish-cancel
  [session]
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
  (session_view.wipe-temp-buffers curr)
  (remove-session session)
  (M._wrapup curr)
  curr)

(fn M.finish
  [kind prompt-buf]
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (if (= kind "accept")
          (finish-accept session)
          (finish-cancel session)))))

(fn M.move-selection
  [prompt-buf delta]
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

(fn sync-selected-from-main-cursor!
  [session]
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

(fn can-refresh-source-syntax?
  [session]
  (let [buf (and session session.meta session.meta.buf)]
    (and session
         session.project-mode
         buf
         buf.show-source-separators
         (= buf.syntax-type "buffer"))))

(fn schedule-source-syntax-refresh!
  [session]
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
        (or M.source-syntax-refresh-debounce-ms 80)))))

(fn M.scroll-main
  [prompt-buf action]
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

(fn maybe-sync-from-main!
  [session force-refresh]
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

(fn schedule-scroll-sync!
  [session]
  (when (and session (not session.scroll-sync-pending))
    (set session.scroll-sync-pending true)
    (vim.defer_fn
      (fn []
        (set session.scroll-sync-pending false)
        (maybe-sync-from-main! session true))
      (or M.scroll-sync-debounce-ms 20))))

(fn M.history-or-move
  [prompt-buf delta]
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (let [txt (prompt-text session)
            can-history (or (= txt "")
                            (= txt session.initial-prompt-text)
                            (= txt session.last-history-text))]
        (if can-history
            (let [h (history_store.list)
                  n (# h)]
              (when (> n 0)
                (set session.history-index (math.max 0 (math.min (+ session.history-index delta) n)))
                (if (= session.history-index 0)
                    (do
                      (set session.last-history-text "")
                      (set-prompt-text! session session.initial-prompt-text))
                    (let [entry (history_store.entry session session.history-index)]
                      (when entry
                        (set session.last-history-text entry)
                        (set-prompt-text! session entry))))))
            (M.move-selection prompt-buf delta))))))

  (fn M.toggle-scan-option
    [prompt-buf which]
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (if
        (= which "ignored")
        (set session.include-ignored (not session.include-ignored))
        (= which "deps")
        (set session.include-deps (not session.include-deps))
        (= which "hidden")
        (set session.include-hidden (not session.include-hidden)))
      (set session.effective-include-hidden session.include-hidden)
      (set session.effective-include-ignored session.include-ignored)
      (set session.effective-include-deps session.include-deps)
      (when session.project-mode
        (project-source.apply-source-set! session))
      (apply-prompt-lines session))))

(fn M.toggle-project-mode
  [prompt-buf]
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (set session.project-mode (not session.project-mode))
      (set session.meta.project-mode session.project-mode)
      (session.meta.buf.set-name (meta-buffer-name session))
      (project-source.apply-source-set! session)
      (apply-prompt-lines session))))

(fn register-prompt-hooks
  [session]
  (let [hooks
        (prompt_hooks_mod.new
          {:mark-prompt-buffer! mark-prompt-buffer!
           :default-prompt-keymaps M.default-prompt-keymaps
           :active-by-prompt M.active-by-prompt
           :on-prompt-changed M.on-prompt-changed
           :update-info-window update-info-window
           :maybe-sync-from-main! maybe-sync-from-main!
           :schedule-scroll-sync! schedule-scroll-sync!})]
    (hooks.register! M session)))

(fn M.start
  [query mode _meta project-mode]
  "Create a Meta session and wire prompt/result/project orchestration."
  (let [parsed-query (query_mod.parse-query-text query)
        query0 (. parsed-query :query)
        start-hidden (if (= (. parsed-query :include-hidden) nil)
                         (query_mod.truthy? M.default-include-hidden)
                         (. parsed-query :include-hidden))
        start-ignored (if (= (. parsed-query :include-ignored) nil)
                          (query_mod.truthy? M.default-include-ignored)
                          (. parsed-query :include-ignored))
        start-deps (if (= (. parsed-query :include-deps) nil)
                       (query_mod.truthy? M.default-include-deps)
                       (. parsed-query :include-deps))
        start-prefilter (if (= (. parsed-query :prefilter) nil)
                            (query_mod.truthy? M.project-lazy-prefilter-enabled)
                            (. parsed-query :prefilter))
        start-lazy (if (= (. parsed-query :lazy) nil)
                       (query_mod.truthy? M.project-lazy-enabled)
                       (. parsed-query :lazy))
        query query0]
  (local source-buf (vim.api.nvim_get_current_buf))
  (when (. M.active-by-source source-buf)
    (remove-session (. M.active-by-source source-buf)))
  (let [origin-win (vim.api.nvim_get_current_win)
        origin-buf source-buf
        source-view (vim.fn.winsaveview)
        _ (set (. source-view :_meta_win_height) (vim.api.nvim_win_get_height origin-win))
        condition (session_view.setup-state query mode source-view)
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
                   :initial-query-active (query_mod.query-lines-has-active? (. parsed-query :lines))
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
                   :project-bootstrap-delay-ms (if (query_mod.query-lines-has-active? (. parsed-query :lines))
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
          (project-source.apply-minimal-source-set! session)
          (project-source.apply-source-set! session))
      (set curr.status-win (meta_window_mod.new vim prompt-win.window))
      ;; Statusline info should live in prompt window, not result split.
      (curr.win.set-statusline "")
      ;; Initialize/render after prompt split exists so we avoid an extra
      ;; post-split view correction pass that can visually "flash" scroll.
      (curr.on-init)
      ;; Ensure initial selection/view is anchored before attaching prompt
      ;; hooks that may sync from main-window cursor events.
      (when session.project-mode
        (session_view.restore-meta-view! curr session.source-view))
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
        (project-source.schedule-project-bootstrap! session session.project-bootstrap-delay-ms))
      (set (. M.instances source-buf) curr)
      curr))))

(fn M.sync
  [meta query]
  (when (not meta)
    (vim.notify "No Meta instance" vim.log.levels.WARN))
  (when meta
    (meta.set-query-lines (if (and query (~= query "")) [query] []))
    (meta.on-update 0)
    (M._store_vars meta)
    meta))

(fn M.push
  [meta]
  (if (not meta)
      (vim.notify "No Meta instance" vim.log.levels.WARN)
      (let [lines (vim.api.nvim_buf_get_lines meta.buf.buffer 0 -1 false)]
        (meta.buf.push-visible-lines lines))))

(fn M.entry_start
  [query _bang]
  (M.start query "start" nil _bang))

(fn M.entry_resume
  [query]
  (M.start query "resume" nil))

(fn M.entry_sync
  [query]
  (local key (vim.api.nvim_get_current_buf))
  (M.sync (. M.instances key) query))

(fn M.entry_push
  []
  (local key (vim.api.nvim_get_current_buf))
  (M.push (. M.instances key)))

(fn M.entry_cursor_word
  [resume]
  (local w (vim.fn.expand "<cword>"))
  (if resume
      (M.entry_resume w)
      (M.entry_start w false)))

M
