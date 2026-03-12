(import-macros {: when-let : when-not} :io.gitlab.andreyorst.cljlib.core)

(local M {})

(fn session-by-prompt
  [active-by-prompt prompt-buf]
  (. active-by-prompt prompt-buf))

(fn remove-session!
  [deps session]
  (let [history-api (. deps :history-api)
        router-util-mod (. deps :router-util-mod)
        info-window (. deps :info-window)
        preview-window (. deps :preview-window)
        active-by-source (. deps :active-by-source)
        active-by-prompt (. deps :active-by-prompt)]
    (when session
      (history-api.push-history-entry!
        session
        (or session.last-prompt-text
            (if (and session.prompt-buf (vim.api.nvim_buf_is_valid session.prompt-buf))
                (router-util-mod.prompt-text session)
                "")))
      (router-util-mod.persist-prompt-height! session)
      (when session.augroup
        (pcall vim.api.nvim_del_augroup_by_id session.augroup))
      (when (and session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
        (pcall vim.api.nvim_win_close session.prompt-win true))
      (when (and session.prompt-buf (vim.api.nvim_buf_is_valid session.prompt-buf))
        (pcall vim.api.nvim_buf_delete session.prompt-buf {:force true}))
      (info-window.close-window! session)
      (preview-window.close-window! session)
      (history-api.close-history-browser! session)
      (when session.source-buf
        (set (. active-by-source session.source-buf) nil))
      (when (and session.meta session.meta.buf session.meta.buf.buffer)
        (set (. active-by-source session.meta.buf.buffer) nil))
      (when session.prompt-buf
        (set (. active-by-prompt session.prompt-buf) nil)))))

(fn clear-hit-highlight!
  [curr]
  (let [matcher (curr.matcher)]
    (when matcher
      (pcall matcher.remove-highlight matcher))))

(fn apply-prompt-window-opts!
  [win]
  (when (and win (vim.api.nvim_win_is_valid win))
    (let [wo (. vim.wo win)]
      (set (. wo :winfixheight) true)
      (set (. wo :number) false)
      (set (. wo :relativenumber) false)
      (set (. wo :signcolumn) "no")
      (set (. wo :foldcolumn) "0")
      (set (. wo :spell) false)
      (set (. wo :wrap) true)
      (set (. wo :linebreak) false))))

(fn hide-session-ui!
  [deps session]
  (let [router-util-mod (. deps :router-util-mod)
        info-window (. deps :info-window)
        preview-window (. deps :preview-window)
        history-api (. deps :history-api)
        active-by-source (. deps :active-by-source)]
    (set session.ui-hidden true)
    (set session.ui-last-insert-mode (vim.startswith (. (vim.api.nvim_get_mode) :mode) "i"))
    (when (and session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
      (let [[ok cur] [(pcall vim.api.nvim_win_get_cursor session.prompt-win)]]
        (when (and ok (= (type cur) "table"))
          (set session.hidden-prompt-cursor [(or (. cur 1) 1) (or (. cur 2) 0)])))
      (router-util-mod.persist-prompt-height! session)
      (set session.hidden-prompt-height (vim.api.nvim_win_get_height session.prompt-win))
      (when (and session.prompt-buf (vim.api.nvim_buf_is_valid session.prompt-buf))
        (let [bo (. vim.bo session.prompt-buf)]
          (set (. bo :bufhidden) "hide")))
      (pcall vim.api.nvim_win_close session.prompt-win true))
    (set session.prompt-win nil)
    (info-window.close-window! session)
    (preview-window.close-window! session)
    (history-api.close-history-browser! session)
    (when (and session.meta session.meta.buf session.meta.buf.buffer)
      (set (. active-by-source session.meta.buf.buffer) session))))

(fn restore-session-ui!
  [deps session]
  (let [prompt-window-mod (. deps :prompt-window-mod)
        meta-window-mod (. deps :meta-window-mod)
        sync-prompt-buffer-name! (. deps :sync-prompt-buffer-name!)
        router-util-mod (. deps :router-util-mod)
        update-info-window (. deps :update-info-window)
        curr session.meta]
    (when (and session.ui-hidden
               session.prompt-buf
               (vim.api.nvim_buf_is_valid session.prompt-buf)
               curr
               curr.win
               (vim.api.nvim_win_is_valid curr.win.window))
      (let [height (or session.hidden-prompt-height (router-util-mod.prompt-height))
            local-layout? (if (= session.window-local-layout nil) true session.window-local-layout)
            prompt-win (if (and local-layout? (vim.api.nvim_win_is_valid curr.win.window))
                           (vim.api.nvim_win_call
                             curr.win.window
                             (fn []
                               (vim.cmd (.. "belowright " (tostring height) "new"))
                               (vim.api.nvim_get_current_win)))
                           (do
                             (vim.cmd (.. "botright " (tostring height) "new"))
                             (vim.api.nvim_get_current_win)))]
        (set session.prompt-win prompt-win)
        (pcall vim.api.nvim_win_set_height prompt-win height)
        (pcall vim.api.nvim_win_set_buf prompt-win session.prompt-buf)
        (let [bo (. vim.bo session.prompt-buf)]
          (set (. bo :buftype) "nofile")
          (set (. bo :bufhidden) "hide")
          (set (. bo :swapfile) false)
          (set (. bo :modifiable) true)
          (set (. bo :filetype) "metabufferprompt"))
        (apply-prompt-window-opts! prompt-win)
        (sync-prompt-buffer-name! session)
        (set curr.status-win (meta-window-mod.new vim prompt-win))
        (set session.ui-hidden false)
        (when (and curr curr.buf curr.buf.buffer (vim.api.nvim_buf_is_valid curr.buf.buffer))
          (let [bo (. vim.bo curr.buf.buffer)]
            (set curr.buf.keep-modifiable true)
            (set (. bo :buftype) "acwrite")
            (set (. bo :modifiable) true)
            (set (. bo :readonly) false)
            (set (. bo :bufhidden) "hide"))
          (pcall curr.buf.render))
        (vim.cmd "silent! nohlsearch")
        (let [cursor (or session.hidden-prompt-cursor [1 0])
              row (math.max 1 (or (. cursor 1) 1))
              col (math.max 0 (or (. cursor 2) 0))
              line-count (math.max 1 (vim.api.nvim_buf_line_count session.prompt-buf))
              row* (math.min row line-count)
              line (or (. (vim.api.nvim_buf_get_lines session.prompt-buf (- row* 1) row* false) 1) "")
              col* (math.min col (# line))]
          (pcall vim.api.nvim_win_set_cursor prompt-win [row* col*]))
        (pcall curr.refresh_statusline)
        (pcall update-info-window session true)
        (vim.api.nvim_set_current_win prompt-win)
        (if session.ui-last-insert-mode
            (vim.cmd "startinsert")
            (vim.cmd "stopinsert"))))))

(fn finish-accept
  [deps session]
  (let [active-by-prompt (. deps :active-by-prompt)
        router-prompt-mod (. deps :router-prompt-mod)
        router-util-mod (. deps :router-util-mod)
        session-view (. deps :session-view)
        base-buffer (. deps :base-buffer)
        history-api (. deps :history-api)
        apply-prompt-lines (. deps :apply-prompt-lines)
        wrapup (. deps :wrapup)
        curr session.meta]
    (set session.last-prompt-text (router-util-mod.prompt-text session))
    (history-api.push-history-entry! session session.last-prompt-text)
    (apply-prompt-lines session)
    (if session.project-mode
        (let [_ (when (vim.api.nvim_win_is_valid curr.win.window)
                  (pcall vim.api.nvim_set_current_win curr.win.window))
              ref (router-util-mod.selected-ref curr)]
          (when (and ref ref.path)
            (let [path (or ref.path "")
                  rel (vim.fn.fnamemodify path ":.")
                  target (if (and (= (type rel) "string") (~= rel ""))
                             rel
                             path)]
              (vim.cmd (.. "edit " (vim.fn.fnameescape target))))
            (vim.api.nvim_win_set_cursor 0 [(math.max 1 (or ref.open-lnum ref.lnum 1)) 0])))
        (do
          (when (and (vim.api.nvim_win_is_valid session.origin-win)
                     (vim.api.nvim_buf_is_valid session.origin-buf))
            (pcall vim.api.nvim_set_current_win session.origin-win)
            (pcall vim.api.nvim_win_set_buf session.origin-win session.origin-buf))
          (base-buffer.switch-buf curr.buf.model)
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
    (if session.project-mode
        (do
          ;; Accept should exit visible Meta UI, but keep resumable state so
          ;; returning to the results buffer restores prompt/info/selection.
          (pcall vim.cmd "stopinsert")
          (clear-hit-highlight! curr)
          (set session.results-edit-mode false)
          (hide-session-ui! deps session))
        (vim.schedule
          (fn []
            (when (= (. active-by-prompt session.prompt-buf) session)
              (router-prompt-mod.begin-session-close!
                session
                router-prompt-mod.cancel-prompt-update!)
              (pcall vim.cmd "stopinsert")
              (clear-hit-highlight! curr)
              (pcall vim.cmd (.. "sign unplace * buffer=" curr.buf.buffer))
              (session-view.wipe-temp-buffers curr)
              (remove-session! deps session)
              (wrapup curr)))))
    curr))

(fn finish-cancel
  [deps session]
  (let [router-prompt-mod (. deps :router-prompt-mod)
        router-util-mod (. deps :router-util-mod)
        session-view (. deps :session-view)
        base-buffer (. deps :base-buffer)
        history-api (. deps :history-api)
        wrapup (. deps :wrapup)
        curr session.meta]
    (router-prompt-mod.begin-session-close!
      session
      router-prompt-mod.cancel-prompt-update!)
    (set session.last-prompt-text (router-util-mod.prompt-text session))
    (history-api.push-history-entry! session session.last-prompt-text)
    (pcall vim.cmd "stopinsert")
    (clear-hit-highlight! curr)
    (pcall vim.cmd (.. "sign unplace * buffer=" curr.buf.buffer))
    (vim.cmd "silent! nohlsearch")
    (when (and (vim.api.nvim_win_is_valid session.origin-win)
               (vim.api.nvim_buf_is_valid session.origin-buf))
      (pcall vim.api.nvim_set_current_win session.origin-win)
      (pcall vim.api.nvim_win_set_buf session.origin-win session.origin-buf))
    (base-buffer.switch-buf curr.buf.model)
    (session-view.wipe-temp-buffers curr)
    (remove-session! deps session)
    (wrapup curr)
    curr))

(fn M.finish!
  [deps kind prompt-buf]
  (let [session (session-by-prompt (. deps :active-by-prompt) prompt-buf)]
    (when session
      (if (= kind "accept")
          (finish-accept deps session)
          (finish-cancel deps session)))))

(fn M.accept!
  [deps prompt-buf]
  (let [history-api (. deps :history-api)
        session (session-by-prompt (. deps :active-by-prompt) prompt-buf)]
    (if (and session session.history-browser-active)
        (history-api.apply-history-browser-selection! session)
        (M.finish! deps "accept" prompt-buf))))

(fn M.cancel!
  [deps prompt-buf]
  (let [history-api (. deps :history-api)
        session (session-by-prompt (. deps :active-by-prompt) prompt-buf)]
    (if (and session session.history-browser-active)
        (history-api.close-history-browser! session)
        (M.finish! deps "cancel" prompt-buf))))

(fn M.accept-main!
  [deps prompt-buf]
  (M.accept! deps prompt-buf))

(fn M.open-history-searchback!
  [deps prompt-buf]
  (let [active-by-prompt (. deps :active-by-prompt)
        history-store (. deps :history-store)
        history-api (. deps :history-api)
        session (session-by-prompt active-by-prompt prompt-buf)]
    (when session
      (when-not session.history-cache
        (set session.history-cache (vim.deepcopy (history-store.list))))
      (history-api.open-history-browser! session "history"))))

(fn M.merge-history-cache!
  [deps prompt-buf]
  (let [history-api (. deps :history-api)
        session (session-by-prompt (. deps :active-by-prompt) prompt-buf)]
    (when session
      (history-api.merge-history-into-session! session)
      (history-api.refresh-history-browser! session))))

(fn append-current-symbol!
  [deps prompt-buf f]
  (let [active-by-prompt (. deps :active-by-prompt)
        router-util-mod (. deps :router-util-mod)
        session (session-by-prompt active-by-prompt prompt-buf)]
    (when session
      (let [word (vim.api.nvim_win_call
                   session.meta.win.window
                   (fn [] (vim.fn.expand "<cword>")))
            token (f word)]
        (when (~= token "")
          (let [current (router-util-mod.prompt-text session)
                sep (if (or (= current "")
                            (vim.endswith current " ")
                            (vim.endswith current "\n"))
                        ""
                        " ")
                next (.. current sep token)]
            (router-util-mod.set-prompt-text! session next)))))))

(fn M.exclude-symbol-under-cursor!
  [deps prompt-buf]
  (append-current-symbol!
    deps
    prompt-buf
    (fn [word]
      (if (and (= (type word) "string") (~= (vim.trim word) ""))
          (.. "!" word)
          ""))))

(fn M.insert-symbol-under-cursor!
  [deps prompt-buf]
  (append-current-symbol!
    deps
    prompt-buf
    (fn [word]
      (if (and (= (type word) "string") (~= (vim.trim word) ""))
          word
          ""))))

(fn M.toggle-scan-option!
  [deps prompt-buf which]
  (let [project-source (. deps :project-source)
        apply-prompt-lines (. deps :apply-prompt-lines)
        session (session-by-prompt (. deps :active-by-prompt) prompt-buf)]
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

(fn M.toggle-project-mode!
  [deps prompt-buf]
  (let [router-util-mod (. deps :router-util-mod)
        sync-prompt-buffer-name! (. deps :sync-prompt-buffer-name!)
        project-source (. deps :project-source)
        apply-prompt-lines (. deps :apply-prompt-lines)
        session (session-by-prompt (. deps :active-by-prompt) prompt-buf)]
    (when session
      (set session.project-mode (not session.project-mode))
      (set session.meta.project-mode session.project-mode)
      (session.meta.buf.set-name (router-util-mod.meta-buffer-name session))
      (sync-prompt-buffer-name! session)
      (project-source.apply-source-set! session)
      (apply-prompt-lines session))))

(fn M.toggle-info-file-entry-view!
  [deps prompt-buf]
  (let [update-info-window (. deps :update-info-window)
        session (session-by-prompt (. deps :active-by-prompt) prompt-buf)]
    (when session
      (set session.info-file-entry-view
           (if (= (or session.info-file-entry-view "meta") "content")
               "meta"
               "content"))
      (set session.info-render-sig nil)
      (pcall update-info-window session true))))

(fn M.remove-session!
  [deps session]
  (remove-session! deps session))

(fn set-results-edit-buffer!
  [session]
  (let [buf session.meta.buf.buffer
        bo (. vim.bo buf)]
    (set (. bo :buftype) "acwrite")
    (set (. bo :bufhidden) "hide")
    (set (. bo :modifiable) true)
    (set (. bo :readonly) false)
    (pcall vim.api.nvim_set_option_value "modified" false {:buf buf})))

(fn ensure-session-for-results-buf!
  [deps session]
  (let [active-by-source (. deps :active-by-source)
        buf session.meta.buf.buffer]
    (set (. active-by-source buf) session)))

(fn path-updates-from-visible
  [session]
  (let [meta session.meta
        visible (vim.api.nvim_buf_get_lines meta.buf.buffer 0 -1 false)
        idxs (or meta.buf.indices [])
        refs (or meta.buf.source-refs [])
        content meta.buf.content
        updates {}]
    (for [i 1 (math.min (# visible) (# idxs))]
      (let [src-idx (. idxs i)
            ref (. refs src-idx)
            kind (or (and ref ref.kind) "")
            path (and ref ref.path)
            lnum (and ref ref.lnum)
            old (or (. content src-idx) "")
            new (or (. visible i) "")]
        (when (and ref
                   (~= kind "file-entry")
                   (= (type path) "string")
                   (~= path "")
                   (= (type lnum) "number")
                   (> lnum 0)
                   (~= old new))
          (let [per-file (or (. updates path) {})]
            (set (. per-file lnum) {:new new :src-idx src-idx})
            (set (. updates path) per-file)))))
    updates))

(fn apply-path-updates!
  [session updates]
  (let [meta session.meta
        any-written false
        writes 0]
    (var wrote any-written)
    (var changed writes)
    (each [path per-file (pairs updates)]
      (let [[ok-read lines] [(pcall vim.fn.readfile path)]]
        (when (and ok-read (= (type lines) "table"))
          (var local-change false)
          (each [lnum payload (pairs per-file)]
            (when (and (>= lnum 1) (<= lnum (# lines)))
              (let [next-line (. payload :new)
                    src-idx (. payload :src-idx)]
                (when (~= (. lines lnum) next-line)
                  (set (. lines lnum) next-line)
                  (set (. meta.buf.content src-idx) next-line)
                  (when (and meta.buf.source-refs (. meta.buf.source-refs src-idx))
                    (let [src-ref (. meta.buf.source-refs src-idx)]
                      (set (. src-ref :line) next-line)))
                  (set local-change true)
                  (set changed (+ changed 1))))))
          (when local-change
            (let [[ok-write] [(pcall vim.fn.writefile lines path)]]
              (when ok-write
                (set wrote true)
                (let [bufnr (vim.fn.bufnr path)]
                  (when (and bufnr (> bufnr 0) (vim.api.nvim_buf_is_loaded bufnr))
                    (each [lnum payload (pairs per-file)]
                      (when (and (>= lnum 1) (<= lnum (# lines)))
                        (pcall vim.api.nvim_buf_set_lines bufnr (- lnum 1) lnum false [(. payload :new)])))))))))))
    {:wrote wrote :changed changed}))

(fn invalidate-caches-for-paths!
  [deps session updates]
  (let [settings (. deps :settings)
        project-file-cache (and settings settings.project-file-cache)
        preview-file-cache (or session.preview-file-cache {})
        info-file-head-cache (or session.info-file-head-cache {})
        info-file-meta-cache (or session.info-file-meta-cache {})]
    (set session.preview-file-cache preview-file-cache)
    (set session.info-file-head-cache info-file-head-cache)
    (set session.info-file-meta-cache info-file-meta-cache)
    (each [path _ (pairs (or updates {}))]
      (when project-file-cache
        (set (. project-file-cache path) nil))
      (set (. preview-file-cache path) nil)
      (set (. info-file-head-cache path) nil)
      (set (. info-file-meta-cache path) nil))))

(fn M.write-results!
  [deps prompt-buf]
  (let [session (session-by-prompt (. deps :active-by-prompt) prompt-buf)
        update-info-window (. deps :update-info-window)
        preview-window (. deps :preview-window)]
    (when session
      (let [updates (path-updates-from-visible session)
            result (apply-path-updates! session updates)
            buf session.meta.buf.buffer]
        (invalidate-caches-for-paths! deps session updates)
        (when (> result.changed 0)
          (pcall session.meta.on-update 0))
        (pcall vim.api.nvim_set_option_value "modified" false {:buf buf})
        (pcall session.meta.refresh_statusline)
        (pcall update-info-window session true)
        (pcall preview-window.maybe-update-for-selection! session)
        (vim.notify
          (if (> result.changed 0)
              (.. "metabuffer: wrote " (tostring result.changed) " change(s)")
              "metabuffer: no changes")
          vim.log.levels.INFO)))))

(fn M.enter-edit-mode!
  [deps prompt-buf]
  (let [session (session-by-prompt (. deps :active-by-prompt) prompt-buf)
        router-util-mod (. deps :router-util-mod)
        history-api (. deps :history-api)
        apply-prompt-lines (. deps :apply-prompt-lines)]
    (when session
      (set session.last-prompt-text (router-util-mod.prompt-text session))
      (history-api.push-history-entry! session session.last-prompt-text)
      (apply-prompt-lines session)
      (set session.results-edit-mode true)
      (hide-session-ui! deps session)
      (ensure-session-for-results-buf! deps session)
      (set-results-edit-buffer! session)
      (when (and session.meta session.meta.win (vim.api.nvim_win_is_valid session.meta.win.window))
        (pcall vim.api.nvim_set_current_win session.meta.win.window)
        (pcall vim.api.nvim_win_set_buf session.meta.win.window session.meta.buf.buffer))
      ;; Enter editing context in Normal mode; prompt starts in Insert mode.
      (pcall vim.cmd "stopinsert"))))

(fn M.maybe-restore-ui!
  [deps prompt-buf force]
  (let [session (session-by-prompt (. deps :active-by-prompt) prompt-buf)]
    (when (and session
               session.ui-hidden
               (or force (not session.results-edit-mode))
               session.meta
               session.meta.buf
               (= (vim.api.nvim_get_current_buf) session.meta.buf.buffer))
      (set session.meta.win.window (vim.api.nvim_get_current_win))
      (restore-session-ui! deps session))))

M
