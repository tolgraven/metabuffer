(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)

(local M {})
(local base-buffer-mod (require :metabuffer.buffer.base))
(local events (require :metabuffer.events))
(local util (require :metabuffer.util))
(local actions-edit-mod (require :metabuffer.router.actions_edit))
(var edit-actions nil)

(fn session-by-prompt
  [active-by-prompt prompt-buf]
  (. active-by-prompt prompt-buf))

(fn clear-map-entry!
  [tbl key expected]
  (when (and tbl key (= (. tbl key) expected))
    (set (. tbl key) nil)))

(fn clear-hit-highlight!
  [curr]
  (let [matcher (curr.matcher)]
    (when matcher
      (pcall matcher.remove-highlight matcher))))

(fn clear-buffer-modified!
  [buf]
  (base-buffer-mod.clear-modified! buf))

(fn clear-managed-buffer-modified!
  [buf-wrapper]
  (when (and buf-wrapper buf-wrapper.clear-modified!)
    (pcall buf-wrapper.clear-modified! buf-wrapper)))

(fn with-valid-window-wrapper!
  [wrapper]
  (when (and wrapper
             wrapper.window
             (vim.api.nvim_win_is_valid wrapper.window))
    wrapper))

(fn destroy-window-wrapper!
  [wrapper]
  (when-let [target (with-valid-window-wrapper! wrapper)]
    (when target.destroy
      (pcall target.destroy))))

(fn restore-window-wrapper-opts!
  [wrapper]
  (when-let [target (with-valid-window-wrapper! wrapper)]
    (when target.restore-opts
      (pcall target.restore-opts))))

(fn apply-window-wrapper-opts!
  [wrapper opts]
  (when-let [target (with-valid-window-wrapper! wrapper)]
    (when target.apply-opts
      (pcall target.apply-opts opts))))

(fn session-main-wrappers
  [session]
  (let [main-win (and session session.meta session.meta.win)
        status-win (and session session.meta session.meta.status-win)]
    (if (= status-win main-win)
        [main-win]
        [main-win status-win])))

(fn each-session-main-wrapper!
  [session f]
  (each [_ wrapper (ipairs (session-main-wrappers session))]
    (when wrapper
      (f wrapper))))

(fn each-session-main-window!
  [session f]
  (each-session-main-wrapper! session
    (fn [wrapper]
      (let [win wrapper.window]
        (when (and win (vim.api.nvim_win_is_valid win))
          (f win))))))

(fn restore-main-window-opts!
  [session]
  "Restore the original local options for Meta-managed windows."
  (each-session-main-wrapper! session destroy-window-wrapper!))

(fn suspend-main-window-opts!
  [session]
  "Temporarily restore origin window-local options while keeping wrappers reusable."
  (each-session-main-wrapper! session restore-window-wrapper-opts!)
  (each-session-main-window! session
    (fn [win]
      (events.send :on-win-teardown! {:win win :role :main}))))

(fn resume-main-window-opts!
  [deps session]
  "Reapply Meta window-local options after a hidden session becomes visible again."
  (let [meta-window-mod (. (. deps :mods) :meta-window)
        opts (or (and meta-window-mod (. meta-window-mod :default-opts)) {})]
    (each-session-main-wrapper! session
      (fn [wrapper]
        (apply-window-wrapper-opts! wrapper opts)))
    (each-session-main-window! session
      (fn [win]
        (events.send :on-win-create! {:win win :role :main})))))

(fn restore-managed-buffer-effects!
  [session]
  (when session
    (each [_ [buf role] (ipairs [[(and session.meta session.meta.buf session.meta.buf.buffer) :meta]
                                 [session.prompt-buf :prompt]
                                 [session.info-buf :info]
                                 [session.preview-buf :preview]
                                 [session.history-browser-buf :history-browser]])]
      (events.send :on-buf-teardown! {:buf buf :role role}))
    (each [_ buf (pairs (or session.ts-expand-bufs {}))]
      (events.send :on-buf-teardown! {:buf buf :role :context}))))

(fn restore-startup-cursor!
  [session]
  (util.restore-global-cursor! session :startup-cursor-hidden? :startup-saved-guicursor))

(fn session-prompt-text
  [router-util-mod session]
  (or session.last-prompt-text
      (if (and session.prompt-buf
               (vim.api.nvim_buf_is_valid session.prompt-buf))
          (router-util-mod.prompt-text session)
          "")))

(fn persist-session-ui-state!
  [history-api router-util-mod session]
  (history-api.push-history-entry!
    session
    (session-prompt-text router-util-mod session))
  (router-util-mod.persist-prompt-height! session)
  (router-util-mod.persist-results-wrap! session))

(fn close-session-prompt!
  [session]
  (when (and session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
    (pcall vim.api.nvim_win_close session.prompt-win true))
  (when (and session.prompt-buf (vim.api.nvim_buf_is_valid session.prompt-buf))
    (clear-buffer-modified! session.prompt-buf)
    (pcall vim.api.nvim_buf_delete session.prompt-buf {:force true})))

(fn close-session-side-windows!
  [history-api info-window preview-window context-window session]
  (info-window.close-window! session)
  (preview-window.close-window! session)
  (when (and context-window context-window.close-window!)
    (context-window.close-window! session))
  (history-api.close-history-browser! session))

(fn clear-session-registry-entries!
  [active-by-source active-by-prompt instances session]
  (clear-map-entry! active-by-source session.source-buf session)
  (when (and session.meta session.meta.buf session.meta.buf.buffer)
    (clear-map-entry! active-by-source session.meta.buf.buffer session))
  (clear-map-entry! active-by-prompt session.prompt-buf session)
  (when session.instance-id
    (clear-map-entry! instances session.instance-id session)))

(fn remove-session!
  [deps session]
  (let [{: router
         : mods
         : windows
         : history}
        deps
        history-api (. history :api)
        sign-mod (. mods :sign)
        animation-mod (. mods :animation)
        router-util-mod (. mods :router-util)
        info-window (. windows :info)
        preview-window (. windows :preview)
        context-window (. windows :context)
        active-by-source (. router :active-by-source)
        active-by-prompt (. router :active-by-prompt)
        instances (. router :instances)]
    (when session
      (set session.closing true)
      (events.send :on-session-stop! {:session session})
      (when (and animation-mod animation-mod.unmark-mini-session!)
        (animation-mod.unmark-mini-session! session))
      (when (and animation-mod animation-mod.cancel-session!)
        (animation-mod.cancel-session! session))
      (restore-startup-cursor! session)
      (restore-managed-buffer-effects! session)
      (restore-main-window-opts! session)
      (persist-session-ui-state! history-api router-util-mod session)
      (when session.augroup
        (pcall vim.api.nvim_del_augroup_by_id session.augroup))
      (close-session-prompt! session)
      (when (and session.meta session.meta.buf session.meta.buf.buffer)
        (clear-buffer-modified! session.meta.buf.buffer))
      (close-session-side-windows! history-api info-window preview-window context-window session)
      (when (and sign-mod session.meta session.meta.buf session.meta.buf.buffer)
        (sign-mod.clear-change-signs! session.meta.buf.buffer))
      (clear-session-registry-entries! active-by-source active-by-prompt instances session)
      (when (and session.origin-win (vim.api.nvim_win_is_valid session.origin-win))
        (events.send :on-win-teardown! {:win session.origin-win :role :origin})))))

(fn handoff-host-window!
  [win buf]
  "Re-fire host window enter autocmds after silent Meta teardown staging."
  (when (and win buf
             (vim.api.nvim_win_is_valid win)
             (vim.api.nvim_buf_is_valid buf))
    (pcall vim.api.nvim_win_call
           win
           (fn []
             (pcall vim.api.nvim_exec_autocmds "BufWinEnter" {:buffer buf :modeline false})
             (pcall vim.api.nvim_exec_autocmds "BufEnter" {:buffer buf :modeline false})
             (pcall vim.api.nvim_exec_autocmds "WinEnter" {:modeline false})
             (pcall vim.cmd "redraw!")))))

(fn close-session-windows!
  [deps session]
  (let [info-window (. (. deps :windows) :info)
        preview-window (. (. deps :windows) :preview)
        context-window (. (. deps :windows) :context)
        history-api (. (. deps :history) :api)]
    (info-window.close-window! session)
    (preview-window.close-window! session)
    (when (and context-window context-window.close-window!)
      (context-window.close-window! session))
    (history-api.close-history-browser! session)))

(fn restore-prompt-window!
  [deps session]
  (let [mods (. deps :mods)
        prompt-window-mod (. mods :prompt-window)
        router-util-mod (. mods :router-util)
        height (or session.hidden-prompt-height (router-util-mod.prompt-height))
        prompt-window (prompt-window-mod.restore-hidden!
                        vim
                        session.prompt-buf
                        {:origin-win (and session.meta session.meta.win session.meta.win.window)
                         :window-local-layout session.window-local-layout
                         :height height})]
    (set session.prompt-window prompt-window)
    (set session.prompt-win prompt-window.window)
    prompt-window))

(fn restore-results-buffer!
  [session]
  (let [curr session.meta]
    (when (and curr curr.buf curr.buf.prepare-visible-edit!)
      (pcall curr.buf.prepare-visible-edit! curr.buf))
    (when curr
      (pcall curr.buf.render))))

(fn capture-hidden-ui-state!
  [prompt-window-mod router-util-mod session]
  (prompt-window-mod.capture-hidden-state!
    session
    {:persist-state! (fn []
                       (router-util-mod.persist-prompt-height! session)
                       (router-util-mod.persist-results-wrap! session))
     :close-directive-help! (fn []
                              (when (and session.directive-help-win
                                         (vim.api.nvim_win_is_valid session.directive-help-win))
                                (pcall vim.api.nvim_win_close session.directive-help-win true))
                              (set session.directive-help-win nil))}))

(fn finish-session-ui-restore!
  [deps session preserve-focus?]
  (let [{: mods : refresh} deps
        sync-prompt-buffer-name! (. refresh :sync-prompt-buffer-name!)
        session-view-mod (. mods :session-view)
        prompt-window-mod (. mods :prompt-window)
        curr session.meta
        _prompt-window (restore-prompt-window! deps session)]
    (sync-prompt-buffer-name! session)
    (set session._last-prompt-statusline nil)
    (set curr.status-win curr.win)
    (set session.ui-hidden false)
    (resume-main-window-opts! deps session)
    (restore-results-buffer! session)
    (events.send :on-restore-ui!
      {:session session
       :restore-view? (and session-view-mod session.source-view)
       :refresh-lines true})
    (prompt-window-mod.restore-focus! session preserve-focus?)))

(fn hide-session-ui!
  [deps session]
  (let [{: router : mods} deps
        animation-mod (. mods :animation)
        prompt-window-mod (. mods :prompt-window)
        router-util-mod (. mods :router-util)
        active-by-source (. router :active-by-source)]
    (set session.ui-hidden true)
    (set session._last-prompt-statusline nil)
    (when (and animation-mod animation-mod.cancel-session!)
      (animation-mod.cancel-session! session))
    (restore-startup-cursor! session)
    (set session.ui-last-insert-mode (vim.startswith (. (vim.api.nvim_get_mode) :mode) "i"))
    (capture-hidden-ui-state! prompt-window-mod router-util-mod session)
    (prompt-window-mod.close! session)
    (clear-managed-buffer-modified! (and session.meta session.meta.buf))
    (suspend-main-window-opts! session)
    (close-session-windows! deps session)
    (when (and session.meta session.meta.buf session.meta.buf.buffer)
      (set (. active-by-source session.meta.buf.buffer) session))))

(fn restore-session-ui!
  [deps session opts]
  (let [preserve-focus? (and opts (. opts :preserve-focus))
        curr session.meta]
    (when (and (not session.restoring-ui?)
               session.ui-hidden
               session.prompt-buf
               (vim.api.nvim_buf_is_valid session.prompt-buf)
               curr
               curr.win
               (vim.api.nvim_win_is_valid curr.win.window))
      (set session.restoring-ui? true)
      (let [[ok err]
            [(xpcall
               (fn []
                 (finish-session-ui-restore! deps session preserve-focus?))
               debug.traceback)]]
        (set session.restoring-ui? false)
        (when-not ok
          (error err))))))

(fn finish-accept
  [deps session]
  (let [{: mods : history : refresh} deps
        router-util-mod (. mods :router-util)
        base-buffer (. mods :base-buffer)
        history-api (. history :api)
        apply-prompt-lines (. refresh :apply-prompt-lines!)
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
            (vim.api.nvim_win_set_cursor 0 [(math.max 1 (or ref.open-lnum ref.lnum 1)) 0])
            (vim.cmd "normal! ^")))
        (let [row (curr.selected_line)
              vq (curr.vim_query)
              target-buf curr.buf.model
              target-win session.origin-win]
          (when (and target-win
                     (vim.api.nvim_win_is_valid target-win)
                     target-buf
                     (vim.api.nvim_buf_is_valid target-buf))
            (router-util-mod.silent-win-set-buf! target-win target-buf)
            (vim.api.nvim_win_call
              target-win
              (fn []
                (pcall vim.api.nvim_win_set_cursor target-win [row 0])
                (if (~= vq "")
                    (let [pos (vim.fn.searchpos vq "cnW" row)
                          hit-row (. pos 1)
                          hit-col (. pos 2)]
                      (when (and (= hit-row row) (> hit-col 0))
                        (pcall vim.api.nvim_win_set_cursor target-win [row hit-col])))
                    (pcall vim.cmd "normal! ^"))))
            (pcall vim.api.nvim_set_current_win target-win)
            (base-buffer.switch-buf target-buf))))
    (vim.cmd "normal! zv")
    (let [vq (curr.vim_query)]
      (when (~= vq "")
        (vim.fn.setreg "/" vq)))
    (events.send :on-accept! {:session session})
    ;; Accept should exit visible Meta UI, but keep resumable state so
    ;; returning to the results buffer restores prompt/info/selection.
     (pcall vim.cmd "stopinsert")
     (clear-hit-highlight! curr)
     (set session.results-edit-mode false)
     (hide-session-ui! deps session)
     (handoff-host-window! (vim.api.nvim_get_current_win) (vim.api.nvim_get_current_buf))
     curr))

(fn finish-cancel
  [deps session]
  (let [{: mods : history} deps
        router-prompt-mod (. mods :router-prompt)
        router-util-mod (. mods :router-util)
        sign-mod (. mods :sign)
        history-api (. history :api)
        curr session.meta]
    (router-prompt-mod.begin-session-close!
      session
      router-prompt-mod.cancel-prompt-update!)
    (set session.last-prompt-text (router-util-mod.prompt-text session))
    (history-api.push-history-entry! session session.last-prompt-text)
    (pcall vim.cmd "stopinsert")
    (clear-hit-highlight! curr)
    (when sign-mod
      (sign-mod.clear-change-signs! curr.buf.buffer))
    (events.send :on-cancel! {:session session})
    (when (and (vim.api.nvim_win_is_valid session.origin-win)
               (vim.api.nvim_buf_is_valid session.origin-buf))
      (pcall vim.api.nvim_set_current_win session.origin-win)
      (pcall vim.api.nvim_win_set_buf session.origin-win session.origin-buf)
      (when session.source-view
        (vim.api.nvim_win_call
          session.origin-win
          (fn []
            (pcall vim.fn.winrestview session.source-view)))))
    (set session.results-edit-mode false)
    (hide-session-ui! deps session)
    (handoff-host-window! session.origin-win session.origin-buf)
    ;; Closing prompt/info windows reshuffles layout and can stomp the
    ;; winrestview above; reapply once Neovim has settled.
    (when session.source-view
      (let [view session.source-view
            win session.origin-win]
        (vim.schedule
          (fn []
            (when (vim.api.nvim_win_is_valid win)
              (vim.api.nvim_win_call
                win
                (fn []
                  (pcall vim.fn.winrestview view))))))))
    curr))

(fn M.finish!
  [deps kind prompt-buf]
  (let [{: router} deps
        session (session-by-prompt (. router :active-by-prompt) prompt-buf)]
    (when session
      (if (= kind "accept")
          (finish-accept deps session)
          (finish-cancel deps session)))))

(fn M.accept!
  [deps prompt-buf]
  (let [{: router : history} deps
        history-api (. history :api)
        session (session-by-prompt (. router :active-by-prompt) prompt-buf)]
    (if (and session session.history-browser-active)
        (history-api.apply-history-browser-selection! session)
        (M.finish! deps "accept" prompt-buf))))

(fn M.cancel!
  [deps prompt-buf]
  (let [{: router : history} deps
        history-api (. history :api)
        session (session-by-prompt (. router :active-by-prompt) prompt-buf)]
    (if (and session session.history-browser-active)
        (history-api.close-history-browser! session)
        (M.finish! deps "cancel" prompt-buf))))

(fn M.accept-main!
  [deps prompt-buf]
  (M.accept! deps prompt-buf))

(fn M.open-history-searchback!
  [deps prompt-buf]
  (let [{: router : history} deps
        active-by-prompt (. router :active-by-prompt)
        history-store (. history :store)
        history-api (. history :api)
        session (session-by-prompt active-by-prompt prompt-buf)]
    (when session
      (when-not session.history-cache
        (set session.history-cache (vim.deepcopy (history-store.list))))
      (history-api.open-history-browser! session "history"))))

(fn M.merge-history-cache!
  [deps prompt-buf]
  (let [{: router : history} deps
        history-api (. history :api)
        session (session-by-prompt (. router :active-by-prompt) prompt-buf)]
    (when session
      (history-api.merge-history-into-session! session)
      (history-api.refresh-history-browser! session))))

(fn append-current-symbol!
  [deps prompt-buf f opts]
  (let [{: router : mods} deps
        active-by-prompt (. router :active-by-prompt)
        router-util-mod (. mods :router-util)
        on-newline? (and opts (. opts :newline))
        session (session-by-prompt active-by-prompt prompt-buf)]
    (when session
      (let [word (vim.api.nvim_win_call
                   session.meta.win.window
                   (fn [] (vim.fn.expand "<cword>")))
            token (f word)]
        (when (~= token "")
          (let [current (router-util-mod.prompt-text session)
                sep (if on-newline?
                        (if (or (= current "") (vim.endswith current "\n")) "" "\n")
                        (if (or (= current "")
                                (vim.endswith current " ")
                                (vim.endswith current "\n"))
                            ""
                            " "))
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

(fn M.insert-symbol-under-cursor-newline!
  [deps prompt-buf]
  (append-current-symbol!
    deps
    prompt-buf
    (fn [word]
      (if (and (= (type word) "string") (~= (vim.trim word) ""))
          word
          ""))
    {:newline true}))

(fn M.toggle-prompt-results-focus!
  [deps prompt-buf]
  (let [{: router} deps
        session (session-by-prompt (. router :active-by-prompt) prompt-buf)]
    (when session
      (let [meta-win (and session.meta session.meta.win session.meta.win.window)
            prompt-win session.prompt-win
            cur-win (vim.api.nvim_get_current_win)]
        (if (and session.ui-hidden
                 session.meta
                 session.meta.buf
                 (= (vim.api.nvim_get_current_buf) session.meta.buf.buffer))
            (do
              (restore-session-ui! deps session {:preserve-focus false})
              (when (and session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
                (pcall vim.api.nvim_set_current_win session.prompt-win)
                (pcall vim.cmd "startinsert")))
            (if (and prompt-win (vim.api.nvim_win_is_valid prompt-win) (= cur-win prompt-win))
                (do
                  (when (and meta-win (vim.api.nvim_win_is_valid meta-win))
                    (pcall vim.api.nvim_set_current_win meta-win))
                  (pcall vim.cmd "stopinsert"))
                (when (and prompt-win (vim.api.nvim_win_is_valid prompt-win))
                  (pcall vim.api.nvim_set_current_win prompt-win)
                  (pcall vim.cmd "startinsert"))))))))

(fn M.toggle-scan-option!
  [deps prompt-buf which]
  (let [{: router : project : refresh} deps
        project-source (. project :source)
        apply-prompt-lines (. refresh :apply-prompt-lines!)
        session (session-by-prompt (. router :active-by-prompt) prompt-buf)]
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
  (let [{: router : mods : refresh : project} deps
        router-util-mod (. mods :router-util)
        sync-prompt-buffer-name! (. refresh :sync-prompt-buffer-name!)
        project-source (. project :source)
        apply-prompt-lines (. refresh :apply-prompt-lines!)
        session (session-by-prompt (. router :active-by-prompt) prompt-buf)]
    (when session
      (set session.project-mode (not session.project-mode))
      (set session.meta.project-mode session.project-mode)
      (session.meta.buf.set-name (router-util-mod.meta-buffer-name session))
      (sync-prompt-buffer-name! session)
      (project-source.apply-source-set! session)
      (apply-prompt-lines session))))

(fn M.toggle-info-file-entry-view!
  [deps prompt-buf]
  (let [{: router} deps
        session (session-by-prompt (. router :active-by-prompt) prompt-buf)]
    (when session
      (set session.info-file-entry-view
           (if (= (or session.info-file-entry-view "meta") "content")
               "meta"
               "content"))
      (set session.info-render-sig nil)
      (events.send :on-query-update!
        {:session session
         :query (or session.prompt-last-applied-text "")
         :refresh-lines true}))))

(fn M.refresh-files!
  [deps prompt-buf]
  (let [{: router : mods : refresh : project} deps
        router-util-mod (. mods :router-util)
        project-source (. project :source)
        apply-prompt-lines (. refresh :apply-prompt-lines!)
        session (session-by-prompt (. router :active-by-prompt) prompt-buf)]
    (when session
      (router-util-mod.clear-file-caches! router session)
      (when session.project-mode
        (project-source.apply-source-set! session))
      (apply-prompt-lines session)
      (events.send :on-query-update!
        {:session session
         :query (or session.prompt-last-applied-text "")
         :refresh-lines true})
      (vim.notify "metabuffer: refreshed cached file views" vim.log.levels.INFO))))

(fn M.remove-session!
  [deps session]
  (remove-session! deps session))

(fn M.on-results-buffer-wipe!
  [deps results-buf]
  ((. edit-actions :on-results-buffer-wipe!) deps results-buf))

(set edit-actions
     (actions-edit-mod.new
       {:session-by-prompt session-by-prompt
        :clear-map-entry! clear-map-entry!
        :restore-main-window-opts! restore-main-window-opts!
        :hide-session-ui! hide-session-ui!
        :restore-session-ui! restore-session-ui!}))

(fn M.write-results!
  [deps prompt-buf]
  ((. edit-actions :write-results!) deps prompt-buf))

(fn M.enter-edit-mode!
  [deps prompt-buf]
  ((. edit-actions :enter-edit-mode!) deps prompt-buf))

(fn M.hide-visible-ui!
  [deps prompt-buf]
  ((. edit-actions :hide-visible-ui!) deps prompt-buf))

(fn M.sync-live-edits!
  [deps prompt-buf]
  ((. edit-actions :sync-live-edits!) deps prompt-buf))

(fn M.maybe-restore-ui!
  [deps prompt-buf force]
  ((. edit-actions :maybe-restore-ui!) deps prompt-buf force))

M
