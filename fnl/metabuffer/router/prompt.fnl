(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(fn last-non-empty-trimmed
  [lines]
  (let [n (# (or lines []))]
    (let [step (fn step [idx]
                 (if (<= idx 0)
                     ""
                     (let [trimmed (vim.trim (or (. lines idx) ""))]
                       (if (~= trimmed "")
                           trimmed
                           (step (- idx 1))))))]
      (step n))))

(fn any-active-line?
  [lines]
  (let [n (# (or lines []))]
    (let [step (fn step [idx]
                 (if (> idx n)
                     false
                     (let [trimmed (vim.trim (or (. lines idx) ""))]
                       (if (~= trimmed "")
                           true
                           (step (+ idx 1))))))]
      (step 1))))

(fn M.now-ms
  []
  (/ (vim.loop.hrtime) 1000000))

(fn M.prompt-update-delay-ms
  [settings query-mod prompt-lines session]
  (let [base (math.max 0 settings.prompt-update-debounce-ms)
        n (if (and session session.meta session.meta.buf session.meta.buf.indices)
              (# session.meta.buf.indices)
              0)
        short-extra-ms (or settings.prompt-short-query-extra-ms [180 120 70])
        size-thresholds (or settings.prompt-size-scale-thresholds [2000 10000 50000])
        size-extra (or settings.prompt-size-scale-extra [0 2 6 10])
        qlen (let [lines (prompt-lines session)
                   parsed (if session.project-mode
                              (query-mod.parse-query-lines lines)
                              {:lines lines})
                   last-active (last-non-empty-trimmed (or (. parsed :lines) []))]
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

(fn M.prompt-has-active-query?
  [query-mod prompt-lines session]
  (let [parsed (query-mod.parse-query-lines (prompt-lines session))]
    (any-active-line? (or (. parsed :lines) []))))

(fn M.cancel-prompt-update!
  [session]
  (when (and session session.prompt-update-timer)
    (let [timer session.prompt-update-timer
          stopf (. timer :stop)
          closef (. timer :close)]
      (when stopf (pcall stopf timer))
      (when closef (pcall closef timer))
      (set session.prompt-update-timer nil)
      (set session.prompt-update-pending false))))

(fn M.begin-session-close!
  [session cancel-prompt-update!]
  "Cancel all queued prompt/preview/refresh async work for a session."
  (when session
    (set session.closing true)
    (set session.prompt-update-token (+ 1 (or session.prompt-update-token 0)))
    (set session.prompt-update-dirty false)
    (cancel-prompt-update! session)
    (set session.preview-update-token (+ 1 (or session.preview-update-token 0)))
    (when session.preview-update-timer
      (let [timer session.preview-update-timer
            stopf (. timer :stop)
            closef (. timer :close)]
        (when stopf (pcall stopf timer))
        (when closef (pcall closef timer))
        (set session.preview-update-timer nil)))
    (set session.preview-update-pending false)
    (set session.lazy-refresh-dirty false)
    (set session.lazy-refresh-pending false)
    (set session.syntax-refresh-dirty false)
    (set session.syntax-refresh-pending false)))

(fn M.schedule-prompt-update!
  [ctx session wait-ms]
  "Schedule trailing-edge prompt application and coalesce rapid edits."
  (let [{: active-by-prompt
         : apply-prompt-lines
         : prompt-update-delay-ms
         : now-ms
         : cancel-prompt-update!}
        ctx]
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
                        (= (. active-by-prompt session.prompt-buf) session)
                        (= token session.prompt-update-token)
                        session.prompt-update-dirty)
               (let [now (now-ms)
                     quiet-for (- now (or session.prompt-last-change-ms 0))
                     need-quiet (math.max 0 (prompt-update-delay-ms session))]
                 (if (< quiet-for need-quiet)
                     (M.schedule-prompt-update! ctx session (math.max 1 (- need-quiet quiet-for)))
                     (do
                       (set session.prompt-update-dirty false)
                       (set session.prompt-last-apply-ms now)
                       (apply-prompt-lines session))))))))))))

M
