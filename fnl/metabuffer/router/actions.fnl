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
      (when session.prompt-buf
        (set (. active-by-prompt session.prompt-buf) nil)))))

(fn clear-hit-highlight!
  [curr]
  (let [matcher (curr.matcher)]
    (when matcher
      (pcall matcher.remove-highlight matcher))))

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
          ;; Keep the Meta session alive so jumplist <C-o> can return to the
          ;; exact results/prompt/info state after opening a project hit.
          (pcall vim.cmd "stopinsert")
          (pcall curr.refresh_statusline)
          (pcall deps.update-info-window session false))
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

M
