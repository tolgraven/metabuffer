(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local router_util_mod (require :metabuffer.router.util))
(local router_prompt_mod (require :metabuffer.router.prompt))
(local M {})

(fn choose-current-when-nil
  [value current]
  (if-some [v value] v current))

(fn prompt-delay-ms
  [settings query-mod session]
  (router_prompt_mod.prompt-update-delay-ms
    settings
    query-mod
    router_util_mod.prompt-lines
    session))

(fn prompt-has-active-query?
  [query-mod session]
  (router_prompt_mod.prompt-has-active-query?
    query-mod
    router_util_mod.prompt-lines
    session))

(fn schedule-update!
  [prompt-scheduler-ctx session delay]
  (router_prompt_mod.schedule-prompt-update!
    prompt-scheduler-ctx
    session
    delay))

(fn recent-identical-forced-refresh?
  [settings session txt now]
  (and (= txt (or session.prompt-last-applied-text ""))
       (> (math.max 0 (or settings.prompt-forced-coalesce-ms 0)) 0)
       (< (- now (or session.prompt-last-apply-ms 0))
          (math.max 0 (or settings.prompt-forced-coalesce-ms 0)))))

(fn force-blocked-by-active-input?
  [settings session now]
  (< (- now (or session.prompt-last-change-ms 0))
     (math.max
       (math.max 0 (or settings.prompt-update-idle-ms 0))
       (math.max 0 (or settings.prompt-forced-coalesce-ms 0)))))

(fn force-within-idle-window?
  [settings session now]
  (and (> (math.max 0 (or settings.prompt-update-idle-ms 0)) 0)
       (< (- now (or session.prompt-last-change-ms 0))
          (math.max 0 (or settings.prompt-update-idle-ms 0)))))

(fn queue-update-after-edit!
  [settings prompt-scheduler-ctx session force txt now delay]
  (when-not (and force session.prompt-update-pending)
    (if (and force (force-within-idle-window? settings session now))
        (schedule-update!
          prompt-scheduler-ctx
          session
          (math.max delay settings.prompt-update-idle-ms))
        (schedule-update! prompt-scheduler-ctx session delay))))

(fn apply-fresh-prompt-event!
  [query-mod project-source settings prompt-scheduler-ctx session force txt now delay]
  (set session.prompt-last-event-text txt)
  (set session.last-prompt-text txt)
  (set session.prompt-update-dirty true)
  (set session.prompt-last-change-ms now)
  (when-not force
    (set session.prompt-force-block-until (+ now (math.max 0 delay))))
  (set session.prompt-change-seq (+ 1 (or session.prompt-change-seq 0)))
  (when (and session.project-mode
             (not session.project-bootstrapped)
             (prompt-has-active-query? query-mod session))
    (project-source.schedule-project-bootstrap! session settings.project-bootstrap-delay-ms))
  (queue-update-after-edit! settings prompt-scheduler-ctx session force txt now delay))

(fn apply-duplicate-text-event!
  [prompt-scheduler-ctx session now delay]
  (set session.prompt-last-change-ms now)
  (set session.prompt-force-block-until (+ now (math.max 0 delay)))
  (set session.prompt-update-dirty true)
  (schedule-update! prompt-scheduler-ctx session delay))

(fn invalidate-filter-cache!
  [session]
  (when (and session session.meta)
    (set session.meta._prev_text "")
    (set session.meta._filter-cache {})
    (set session.meta._filter-cache-line-count (# session.meta.buf.content))))

(fn source-flags-changed?
  [session parsed]
  (let [next-hidden (choose-current-when-nil (. parsed :include-hidden) session.include-hidden)
        next-ignored (choose-current-when-nil (. parsed :include-ignored) session.include-ignored)
        next-deps (choose-current-when-nil (. parsed :include-deps) session.include-deps)
        next-binary (choose-current-when-nil (. parsed :include-binary) session.include-binary)
        next-hex (choose-current-when-nil (. parsed :include-hex) session.include-hex)
        next-files (choose-current-when-nil (. parsed :include-files) session.include-files)]
    (or (~= next-hidden session.effective-include-hidden)
        (~= next-ignored session.effective-include-ignored)
        (~= next-deps session.effective-include-deps)
        (~= next-binary session.effective-include-binary)
        (~= next-hex session.effective-include-hex)
        (~= next-files session.effective-include-files))))

(fn render-flags-changed?
  [session parsed]
  (let [next-prefilter (choose-current-when-nil (. parsed :prefilter) session.prefilter-mode)
        next-lazy (choose-current-when-nil (. parsed :lazy) session.lazy-mode)
        next-expansion (choose-current-when-nil (. parsed :expansion) session.expansion-mode)]
    (or (~= next-prefilter session.prefilter-mode)
        (~= next-lazy session.lazy-mode)
        (~= next-expansion session.expansion-mode))))

(fn refresh-session-ui!
  [session update-preview-window update-info-window context-window refresh-change-signs! capture-sign-baseline!]
  (session.meta.refresh_statusline)
  (when update-preview-window
    (update-preview-window session))
  (update-info-window session)
  (when (and context-window context-window.update!)
    (context-window.update! session))
  (when refresh-change-signs!
    (refresh-change-signs! session))
  (when capture-sign-baseline!
    (capture-sign-baseline! session)))

(fn retry-textlock-update!
  [session update-preview-window update-info-window context-window refresh-change-signs! capture-sign-baseline!]
  (vim.defer_fn
    (fn []
      (when (and session.meta
                 (vim.api.nvim_buf_is_valid session.meta.buf.buffer))
        (pcall session.meta.on-update 0)
        (pcall refresh-session-ui!
               session
               update-preview-window
               update-info-window
               context-window
               refresh-change-signs!
               capture-sign-baseline!)))
    1))

(fn run-meta-update!
  [session update-preview-window update-info-window context-window refresh-change-signs! capture-sign-baseline!]
  (let [[ok err] [(pcall session.meta.on-update 0)]]
    (if ok
        (refresh-session-ui!
          session
          update-preview-window
          update-info-window
          context-window
          refresh-change-signs!
          capture-sign-baseline!)
        (when (string.find (tostring err) "E565")
          (retry-textlock-update!
            session
            update-preview-window
            update-info-window
            context-window
            refresh-change-signs!
            capture-sign-baseline!)))))

(fn consume-visible-control-token?
  [query-mod tok]
  (let [parsed (query-mod.parse-query-lines [(or tok "")])]
    (and (or (~= (. parsed :include-hidden) nil)
             (~= (. parsed :include-ignored) nil)
             (~= (. parsed :include-deps) nil)
             (~= (. parsed :include-binary) nil)
             (~= (. parsed :include-hex) nil)
             (~= (. parsed :prefilter) nil)
             (~= (. parsed :lazy) nil)
             (. parsed :history)
             (. parsed :saved-browser)
             (and (= (type (. parsed :save-tag)) "string")
                  (~= (vim.trim (. parsed :save-tag)) ""))
             (and (= (type (. parsed :saved-tag)) "string")
                  (~= (vim.trim (. parsed :saved-tag)) "")))
         (= (. parsed :include-files) nil)
         (= (. parsed :include-binary) nil)
         (= (. parsed :include-hex) nil))))

(fn consume-visible-controls-lines
  [query-mod raw-lines]
  (let [out []]
    (each [_ line (ipairs (or raw-lines []))]
      (let [parts (vim.split (or line "") "%s+" {:trimempty true})
            kept []]
        (each [_ tok (ipairs parts)]
          (when-not (consume-visible-control-token? query-mod tok)
            (table.insert kept tok)))
        (table.insert out (table.concat kept " "))))
    out))

(fn M.apply-prompt-lines!
  [deps session]
  (let [{: query-mod
         : project-source
         : update-preview-window
         : update-info-window
         : context-window
         : refresh-change-signs!
         : capture-sign-baseline!
         : settings
         : merge-history-into-session!
         : save-current-prompt-tag!
         : restore-saved-prompt-tag!
         : open-saved-browser!}
        deps]
    (when (and session
               (not session.closing)
               (vim.api.nvim_buf_is_valid session.prompt-buf)
               (not session._rewriting-visible-controls))
      (let [raw-lines (vim.api.nvim_buf_get_lines session.prompt-buf 0 -1 false)]
        (let [parsed (query-mod.parse-query-lines raw-lines)
              lines (. parsed :lines)
              consume-visible-controls? false
              effective-lines lines
              effective-text (table.concat effective-lines "\n")
              next-hidden (choose-current-when-nil (. parsed :include-hidden) session.include-hidden)
              next-ignored (choose-current-when-nil (. parsed :include-ignored) session.include-ignored)
              next-deps (choose-current-when-nil (. parsed :include-deps) session.include-deps)
              next-binary (choose-current-when-nil (. parsed :include-binary) session.include-binary)
              next-hex (choose-current-when-nil (. parsed :include-hex) session.include-hex)
              next-files (choose-current-when-nil (. parsed :include-files) session.include-files)
              next-prefilter (choose-current-when-nil (. parsed :prefilter) session.prefilter-mode)
              next-lazy (choose-current-when-nil (. parsed :lazy) session.lazy-mode)
              next-expansion (choose-current-when-nil (. parsed :expansion) session.expansion-mode)
              schedule-source-set-rebuild! (. project-source :schedule-source-set-rebuild!)
              apply-source-set! (. project-source :apply-source-set!)
              prev-effective-text (or session.prompt-last-applied-text "")
              text-changed? (~= effective-text prev-effective-text)
              source-changed? (source-flags-changed? session parsed)
              render-changed? (render-flags-changed? session parsed)
              changed (or source-changed? render-changed?)]
          (when (and (. parsed :history) merge-history-into-session!)
            (merge-history-into-session! session))
          (when (and (= (type (. parsed :save-tag)) "string")
                     (~= (vim.trim (. parsed :save-tag)) "")
                     save-current-prompt-tag!)
            (save-current-prompt-tag! session (. parsed :save-tag) effective-text))
          (when (and (= (type (. parsed :saved-tag)) "string")
                     (~= (vim.trim (. parsed :saved-tag)) "")
                     restore-saved-prompt-tag!)
            (restore-saved-prompt-tag! session (. parsed :saved-tag)))
          (when (and (. parsed :saved-browser)
                     open-saved-browser!)
            (open-saved-browser! session))
          (set session.effective-include-hidden next-hidden)
          (set session.effective-include-ignored next-ignored)
          (set session.effective-include-deps next-deps)
          (set session.effective-include-binary next-binary)
          (set session.effective-include-hex next-hex)
          (set session.effective-include-files next-files)
          (set session.include-hidden next-hidden)
          (set session.include-ignored next-ignored)
          (set session.include-deps next-deps)
          (set session.include-binary next-binary)
          (set session.include-hex next-hex)
          (set session.include-files next-files)
          (set session.prefilter-mode next-prefilter)
          (set session.lazy-mode next-lazy)
          (set session.expansion-mode next-expansion)
          (set session.last-parsed-query parsed)
          (set session.file-query-lines (or (. parsed :file-lines) []))
          (set session.last-prompt-text effective-text)
          (set session.prompt-last-applied-text effective-text)
          (set session.meta.file-query-lines (or (. parsed :file-lines) []))
          (set session.meta.include-binary next-binary)
          (set session.meta.include-hex next-hex)
          (set session.meta.include-files next-files)
          (when consume-visible-controls?
            (let [visible-lines (consume-visible-controls-lines query-mod raw-lines)
                  visible-text (table.concat visible-lines "\n")
                  raw-text (table.concat raw-lines "\n")]
              (when (~= visible-text raw-text)
                (set session._rewriting-visible-controls true)
                (vim.api.nvim_buf_set_lines session.prompt-buf 0 -1 false visible-lines)
                (set session._rewriting-visible-controls false))))
          (set session.meta.debug_out "")
          (when (or changed text-changed?)
            (invalidate-filter-cache! session))
          (when (and session.meta session.meta.buf (vim.api.nvim_buf_is_valid session.meta.buf.buffer))
            (pcall vim.api.nvim_buf_set_var session.meta.buf.buffer "meta_manual_edit_active" false))
          (when (and session.project-mode source-changed?)
            (if schedule-source-set-rebuild!
                (schedule-source-set-rebuild! session 0)
                (when apply-source-set!
                  (apply-source-set! session))))
          (session.meta.set-query-lines effective-lines)
          (if (and session.project-mode source-changed? (not text-changed?))
              (refresh-session-ui!
                session
                update-info-window
                context-window
                refresh-change-signs!
                capture-sign-baseline!)
          (run-meta-update!
            session
            update-preview-window
            update-info-window
            context-window
            refresh-change-signs!
                capture-sign-baseline!))))))
      )

(fn M.on-prompt-changed!
  [deps prompt-buf force event-tick]
  "Entry point for prompt edits; keeps typing fast by deferring matcher work."
  (let [{: active-by-prompt
         : query-mod
         : project-source
         : settings
         : prompt-scheduler-ctx}
        deps
        session (. active-by-prompt prompt-buf)]
    (when (and session (not session.closing))
      (let [lines (router_util_mod.prompt-lines session)
            parsed (query-mod.parse-query-lines lines)
            effective-text (table.concat (or (. parsed :lines) []) "\n")
            pure-flag-edit? (and (~= effective-text (or session.prompt-last-event-text ""))
                                 (= effective-text (or session.prompt-last-applied-text ""))
                                 (or (source-flags-changed? session parsed)
                                     (render-flags-changed? session parsed)))
            now (router_prompt_mod.now-ms)
            delay (prompt-delay-ms settings query-mod session)]
        (when (and (not force) event-tick)
          (set session.prompt-last-event-tick event-tick))
        (set session.prompt-update-dirty true)
        (when-not force
          (set session.prompt-last-change-ms now)
          (set session.prompt-force-block-until (+ now (math.max 0 delay))))
        (when-not force
          (set session.prompt-change-seq (+ 1 (or session.prompt-change-seq 0))))
        (when (and session.project-mode
                   (not session.project-bootstrapped)
                   (prompt-has-active-query? query-mod session))
          (project-source.schedule-project-bootstrap! session settings.project-bootstrap-delay-ms))
        (if pure-flag-edit?
            (do
              (set session.prompt-last-event-text effective-text)
              (set session.last-prompt-text effective-text)
              (set session.prompt-last-change-ms now)
              (set session.prompt-update-dirty false)
              (router_prompt_mod.cancel-prompt-update! session)
              (M.apply-prompt-lines! deps session))
            (queue-update-after-edit! settings prompt-scheduler-ctx session force "" now delay))))))

M
