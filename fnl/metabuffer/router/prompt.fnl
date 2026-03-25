(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local source-mod (require :metabuffer.source))
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

(fn option-prefix
  []
  (let [p (. vim.g "meta#prefix")]
    (if (and (= (type p) "string") (~= p ""))
        p
        "#")))

(fn incomplete-directive-token?
  [lines]
  (let [last-line (or (. (or lines []) (# (or lines []))) "")
        last-char (if (> (# last-line) 0)
                      (string.sub last-line (# last-line) (# last-line))
                      "")
        line-ends-with-space? (= last-char " ")
        trimmed-right (string.gsub last-line "%s+$" "")
        prefix (option-prefix)
        token (or (string.match trimmed-right "%S+$") "")
        prefix-len (# prefix)]
    (and (~= token "")
         (not line-ends-with-space?)
         (not (= (string.sub token 1 1) "\\"))
         (>= (# token) prefix-len)
         (= (string.sub token 1 prefix-len) prefix))))

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
        lines (prompt-lines session)
        parsed0 (if (or session.project-mode
                        (and session (query-mod.truthy? session.default-include-lgrep)))
                    (query-mod.parse-query-lines lines)
                    {:lines lines :lgrep-lines []})
        parsed (query-mod.apply-default-source
                 parsed0
                 (and session (query-mod.truthy? session.default-include-lgrep)))
        qlen (let [last-active (last-non-empty-trimmed (or (. parsed :lines) []))]
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
        extra (if (and session session.project-mode (not session.lazy-stream-done)) 2 0)
        source-extra-ms (source-mod.query-source-debounce-ms settings parsed)
        source-extra (if (> source-extra-ms 0)
                         (math.max 0 (- source-extra-ms
                                        (+ base short-extra scale extra)))
                         0)
        directive-extra (if (incomplete-directive-token? (prompt-lines session))
                            (math.max 0 (- (or settings.prompt-incomplete-directive-ms 1000)
                                           (+ base short-extra scale extra source-extra)))
                            0)]
    (+ base short-extra scale extra source-extra directive-extra)))

(fn M.prompt-has-active-query?
  [query-mod prompt-lines session]
  (let [parsed (query-mod.apply-default-source
                 (query-mod.parse-query-lines (prompt-lines session))
                 (and session (query-mod.truthy? session.default-include-lgrep)))]
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

(fn session-by-prompt
  [active-by-prompt prompt-buf]
  (. active-by-prompt prompt-buf))

(fn M.prompt-insert-at-cursor!
  [active-by-prompt prompt-buf text]
  (let [session (session-by-prompt active-by-prompt prompt-buf)]
    (when (and session
               session.prompt-buf
               session.prompt-win
               (vim.api.nvim_buf_is_valid session.prompt-buf)
               (vim.api.nvim_win_is_valid session.prompt-win)
               (= (type text) "string")
               (~= text ""))
      (let [[row col] (vim.api.nvim_win_get_cursor session.prompt-win)
            row0 (math.max 0 (- row 1))
            chunks (vim.split text "\n" {:plain true})
            last-line (. chunks (# chunks))
            next-row (+ row0 (# chunks))
            next-col (if (= (# chunks) 1)
                         (+ col (# last-line))
                         (# last-line))]
        (vim.api.nvim_buf_set_text session.prompt-buf row0 col row0 col chunks)
        (pcall vim.api.nvim_win_set_cursor session.prompt-win [next-row next-col])))))

(fn prompt-row-col
  [session]
  (if (and session
           session.prompt-win
           (vim.api.nvim_win_is_valid session.prompt-win))
      (let [[row col] (vim.api.nvim_win_get_cursor session.prompt-win)]
        {:row (math.max 1 row)
         :row0 (math.max 0 (- row 1))
         :col (math.max 0 col)})
      {:row 1 :row0 0 :col 0}))

(fn prompt-line-text
  [session row0]
  (let [lines (vim.api.nvim_buf_get_lines session.prompt-buf row0 (+ row0 1) false)]
    (or (. lines 1) "")))

(fn M.prompt-home!
  [active-by-prompt prompt-buf]
  (let [session (session-by-prompt active-by-prompt prompt-buf)]
    (when (and session
               session.prompt-win
               (vim.api.nvim_win_is_valid session.prompt-win))
      (let [{: row} (prompt-row-col session)]
        (pcall vim.api.nvim_win_set_cursor session.prompt-win [row 0])))))

(fn M.prompt-end!
  [active-by-prompt prompt-buf]
  (let [session (session-by-prompt active-by-prompt prompt-buf)]
    (when (and session
               session.prompt-buf
               session.prompt-win
               (vim.api.nvim_buf_is_valid session.prompt-buf)
               (vim.api.nvim_win_is_valid session.prompt-win))
      (let [{: row : row0} (prompt-row-col session)
            line (prompt-line-text session row0)]
        (pcall vim.api.nvim_win_set_cursor session.prompt-win [row (# line)])))))

(fn M.prompt-kill-backward!
  [active-by-prompt prompt-buf]
  (let [session (session-by-prompt active-by-prompt prompt-buf)]
    (when (and session
               session.prompt-buf
               session.prompt-win
               (vim.api.nvim_buf_is_valid session.prompt-buf)
               (vim.api.nvim_win_is_valid session.prompt-win))
      (let [{: row : row0 : col} (prompt-row-col session)]
        (when (> col 0)
          (let [line (prompt-line-text session row0)
                killed (string.sub line 1 col)]
            (set session.prompt-yank-register (or killed ""))
            (vim.api.nvim_buf_set_text session.prompt-buf row0 0 row0 col [""])
            (pcall vim.api.nvim_win_set_cursor session.prompt-win [row 0])))))))

(fn M.prompt-kill-forward!
  [active-by-prompt prompt-buf]
  (let [session (session-by-prompt active-by-prompt prompt-buf)]
    (when (and session
               session.prompt-buf
               session.prompt-win
               (vim.api.nvim_buf_is_valid session.prompt-buf)
               (vim.api.nvim_win_is_valid session.prompt-win))
      (let [{: row : row0 : col} (prompt-row-col session)
            line (prompt-line-text session row0)
            len (# line)]
        (when (< col len)
          (let [killed (string.sub line (+ col 1))]
            (set session.prompt-yank-register (or killed ""))
            (vim.api.nvim_buf_set_text session.prompt-buf row0 col row0 len [""])
            (pcall vim.api.nvim_win_set_cursor session.prompt-win [row col])))))))

(fn M.prompt-yank!
  [active-by-prompt prompt-buf]
  (let [session (session-by-prompt active-by-prompt prompt-buf)
        text (or (and session session.prompt-yank-register) "")]
    (when (~= text "")
      (M.prompt-insert-at-cursor! active-by-prompt prompt-buf text))))

(fn M.prompt-insert-text!
  [active-by-prompt prompt-buf text]
  (M.prompt-insert-at-cursor! active-by-prompt prompt-buf text))

(fn prompt-buffer-text
  [session]
  (if (and session
           session.prompt-buf
           (vim.api.nvim_buf_is_valid session.prompt-buf))
      (table.concat (vim.api.nvim_buf_get_lines session.prompt-buf 0 -1 false) "\n")
      ""))

(fn should-insert-history-fragment?
  [session fragment]
  (let [needle (or fragment "")
        hay (prompt-buffer-text session)]
    (and (~= needle "")
         (not (string.find hay needle 1 true)))))

(fn M.insert-last-prompt!
  [active-by-prompt history-api prompt-buf]
  (let [session (session-by-prompt active-by-prompt prompt-buf)
        entry (history-api.history-latest session)]
    (when (should-insert-history-fragment? session entry)
      (M.prompt-insert-at-cursor! active-by-prompt prompt-buf entry))
    (when (and session (~= entry ""))
      (set session.last-history-text entry))))

(fn M.insert-last-token!
  [active-by-prompt history-api prompt-buf]
  (let [session (session-by-prompt active-by-prompt prompt-buf)
        token (history-api.history-latest-token session)
        entry (history-api.history-latest session)]
    (when (should-insert-history-fragment? session token)
      (M.prompt-insert-at-cursor! active-by-prompt prompt-buf token))
    (when (and session (~= token ""))
      (set session.last-history-text entry))))

(fn M.insert-last-tail!
  [active-by-prompt history-api prompt-buf]
  (let [session (session-by-prompt active-by-prompt prompt-buf)
        tail (history-api.history-latest-tail session)
        entry (history-api.history-latest session)]
    (when (should-insert-history-fragment? session tail)
      (M.prompt-insert-at-cursor! active-by-prompt prompt-buf tail))
    (when (and session (~= tail ""))
      (set session.last-history-text entry))))

(fn find-token-span
  [line col]
  (var pos 1)
  (var before nil)
  (while (<= pos (# line))
    (let [[s e] [(string.find line "%S+" pos)]]
      (if (and s e)
          (let [s0 (- s 1)
                token (string.sub line s e)]
            (if (and (<= s0 col) (<= col e))
                (do
                  (set before {:s s :e e :token token})
                  (set pos (+ (# line) 1)))
                (do
                  (when (and (not before) (< col s0))
                    (set before {:s s :e e :token token})
                    (set pos (+ (# line) 1)))
                  (when (<= pos (# line))
                    (set pos (+ e 1))))))
          (set pos (+ (# line) 1)))))
  before)

(fn M.negate-current-token!
  [active-by-prompt prompt-buf]
  (let [session (session-by-prompt active-by-prompt prompt-buf)]
    (when (and session
               session.prompt-buf
               session.prompt-win
               (vim.api.nvim_buf_is_valid session.prompt-buf)
               (vim.api.nvim_win_is_valid session.prompt-win))
      (let [[row col] (vim.api.nvim_win_get_cursor session.prompt-win)
            row0 (math.max 0 (- row 1))
            line (or (. (vim.api.nvim_buf_get_lines session.prompt-buf row0 (+ row0 1) false) 1) "")]
        (when-let [span (find-token-span line col)]
          (let [s (. span :s)
                e (. span :e)
                token (. span :token)
                negated (and (> (# token) 1) (= (string.sub token 1 1) "!"))
                next-token (if negated (string.sub token 2) (.. "!" token))
                delta (- (# next-token) (# token))
                s0 (- s 1)]
            (vim.api.nvim_buf_set_text session.prompt-buf row0 s0 row0 e [next-token])
            (pcall vim.api.nvim_win_set_cursor
                   session.prompt-win
                   [row (math.max 0 (+ col (if (>= col s0) delta 0)))])))))))

M
