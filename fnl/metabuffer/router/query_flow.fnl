(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local router_util_mod (require :metabuffer.router.util))
(local router_prompt_mod (require :metabuffer.router.prompt))
(local M {})

(fn choose-current-when-nil
  [query-mod value current]
  (query-mod.resolve-option value current))

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
  (when (or (not session.project-mode) session.project-bootstrapped)
    (when-not (and force session.prompt-update-pending)
      (if (and force (force-within-idle-window? settings session now))
          (schedule-update!
            prompt-scheduler-ctx
            session
            (math.max delay settings.prompt-update-idle-ms))
          (schedule-update! prompt-scheduler-ctx session delay)))))

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

(fn M.apply-prompt-lines!
  [deps session]
  (let [{: query-mod
         : project-source
         : update-info-window
         : merge-history-into-session!
         : save-current-prompt-tag!
         : restore-saved-prompt-tag!
         : open-saved-browser!}
        deps]
    (when (and session (not session.closing) (vim.api.nvim_buf_is_valid session.prompt-buf))
      (let [raw-lines (vim.api.nvim_buf_get_lines session.prompt-buf 0 -1 false)]
        (let [parsed (query-mod.parse-query-lines raw-lines)
              lines (. parsed :lines)
              consume-controls? (or (~= (. parsed :include-hidden) nil)
                                    (~= (. parsed :include-ignored) nil)
                                    (~= (. parsed :include-deps) nil)
                                    (~= (. parsed :prefilter) nil)
                                    (~= (. parsed :lazy) nil)
                                    (. parsed :history)
                                    (. parsed :saved-browser)
                                    (and (= (type (. parsed :save-tag)) "string")
                                         (~= (vim.trim (. parsed :save-tag)) ""))
                                    (and (= (type (. parsed :saved-tag)) "string")
                                         (~= (vim.trim (. parsed :saved-tag)) "")))
              effective-lines (if consume-controls? lines raw-lines)
              effective-text (table.concat effective-lines "\n")
              prompt-text (table.concat lines "\n")
              raw-text (table.concat raw-lines "\n")
              stripped? (and consume-controls? (~= prompt-text raw-text))
              _ (when stripped?
                  (let [cursor (if (and session.prompt-win
                                        (vim.api.nvim_win_is_valid session.prompt-win))
                                   (vim.api.nvim_win_get_cursor session.prompt-win)
                                   [1 0])
                        row (. cursor 1)
                        col (. cursor 2)]
                    (vim.api.nvim_buf_set_lines session.prompt-buf 0 -1 false effective-lines)
                    (when (and session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
                      (let [line (or (. effective-lines row) "")
                            max-col (# line)]
                        (pcall vim.api.nvim_win_set_cursor session.prompt-win [row (math.min col max-col)])))))
              _ (when (and (. parsed :history) merge-history-into-session!)
                  (merge-history-into-session! session))
              _ (when (and (= (type (. parsed :save-tag)) "string")
                           (~= (vim.trim (. parsed :save-tag)) "")
                           save-current-prompt-tag!)
                  (save-current-prompt-tag! session (. parsed :save-tag) prompt-text))
              _ (when (and (= (type (. parsed :saved-tag)) "string")
                           (~= (vim.trim (. parsed :saved-tag)) "")
                           restore-saved-prompt-tag!)
                  (restore-saved-prompt-tag! session (. parsed :saved-tag)))
              _ (when (and (. parsed :saved-browser)
                           open-saved-browser!)
                  (open-saved-browser! session))
              next-hidden (choose-current-when-nil query-mod (. parsed :include-hidden) session.include-hidden)
              next-ignored (choose-current-when-nil query-mod (. parsed :include-ignored) session.include-ignored)
              next-deps (choose-current-when-nil query-mod (. parsed :include-deps) session.include-deps)
              next-prefilter (choose-current-when-nil query-mod (. parsed :prefilter) session.prefilter-mode)
              next-lazy (choose-current-when-nil query-mod (. parsed :lazy) session.lazy-mode)
              prev-effective-text (or session.prompt-last-applied-text "")
              text-changed? (~= effective-text prev-effective-text)
              changed (or (~= next-hidden session.effective-include-hidden)
                          (~= next-ignored session.effective-include-ignored)
                          (~= next-deps session.effective-include-deps)
                          (~= next-prefilter session.prefilter-mode)
                          (~= next-lazy session.lazy-mode))
              pending-control? (= (. parsed :pending-control) true)
              skip-filter? (and pending-control? (not changed))]
          (set session.effective-include-hidden next-hidden)
          (set session.effective-include-ignored next-ignored)
          (set session.effective-include-deps next-deps)
          (set session.prefilter-mode next-prefilter)
          (set session.lazy-mode next-lazy)
          (set session.last-parsed-query parsed)
          (set session.last-prompt-text effective-text)
          (set session.prompt-last-applied-text effective-text)
          (set session.meta.debug_out
            (if session.project-mode
                (let [flags [(if session.effective-include-hidden "+hidden" "-hidden")
                             (if session.effective-include-ignored "+ignored" "-ignored")
                             (if session.effective-include-deps "+deps" "-deps")
                             (if session.prefilter-mode "+prefilter" "-prefilter")]]
                  (when-not session.lazy-mode
                    (table.insert flags "-lazy"))
                  (.. " [" (table.concat flags " ") "]"))
                ""))
          (when (or changed text-changed?)
            (invalidate-filter-cache! session))
          (when (and session.project-mode changed)
            (project-source.apply-source-set! session))
          (if skip-filter?
              (do
                (set session.prompt-last-applied-text raw-text)
                (session.meta.refresh_statusline)
                (update-info-window session))
              (do
                (session.meta.set-query-lines effective-lines)
                (let [[ok err] [(pcall session.meta.on-update 0)]]
                  (if ok
                      (do
                        (session.meta.refresh_statusline)
                        (update-info-window session))
                      (when (string.find (tostring err) "E565")
                        ;; Textlock race: retry right after current input cycle.
                        (vim.defer_fn
                          (fn []
                            (when (and session.meta
                                       (vim.api.nvim_buf_is_valid session.meta.buf.buffer))
                              (pcall session.meta.on-update 0)
                              (pcall session.meta.refresh_statusline)
                              (pcall update-info-window session)))
                          1)))))))))))

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
      (let [duplicate-event? (and (not force)
                                  event-tick
                                  (= event-tick (or session.prompt-last-event-tick -1)))]
        (when-not duplicate-event?
          (let [txt (router_util_mod.prompt-text session)
                now (router_prompt_mod.now-ms)
                delay (prompt-delay-ms settings query-mod session)
                parsed (query-mod.parse-query-lines
                         (vim.api.nvim_buf_get_lines session.prompt-buf 0 -1 false))
                pending-control? (= (. parsed :pending-control) true)]
            (when (and (not force) event-tick)
              (set session.prompt-last-event-tick event-tick))
            (if pending-control?
                (do
                  (router_prompt_mod.cancel-prompt-update! session)
                  (set session.prompt-update-dirty false)
                  (set session.prompt-last-event-text txt)
                  (set session.last-prompt-text txt)
                  (set session.prompt-last-change-ms now)
                  (set session.last-parsed-query parsed))
                (when-not (and force (< now (or session.prompt-force-block-until 0)))
                  (let [duplicate-text? (and (not force)
                                             (= txt (or session.prompt-last-event-text "")))]
                    (if duplicate-text?
                        (apply-duplicate-text-event! prompt-scheduler-ctx session now delay)
                        (apply-fresh-prompt-event!
                          query-mod
                          project-source
                          settings
                          prompt-scheduler-ctx
                          session
                          force
                          txt
                          now
                          delay)))))))))))

M
