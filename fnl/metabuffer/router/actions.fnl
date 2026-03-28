(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)

(local M {})
(local util (require :metabuffer.util))
(local source-mod (require :metabuffer.source))
(local transform-mod (require :metabuffer.transform))
(local events (require :metabuffer.events))

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

(fn silent-win-set-buf!
  [win buf]
  "Attach buffer to window without surfacing the old viewport first."
  (when (and win buf
             (vim.api.nvim_win_is_valid win)
             (vim.api.nvim_buf_is_valid buf))
    (or (pcall vim.api.nvim_win_call
               win
               (fn []
                 (vim.cmd (.. "silent keepalt noautocmd buffer " buf))))
        (pcall vim.api.nvim_win_set_buf win buf))))

(fn clear-buffer-modified!
  [buf]
  (when (and buf (vim.api.nvim_buf_is_valid buf))
    (pcall vim.api.nvim_set_option_value "modified" false {:buf buf})))

(fn destroy-window-wrapper!
  [wrapper]
  (when (and wrapper
             wrapper.window
             (vim.api.nvim_win_is_valid wrapper.window)
             wrapper.destroy)
    (pcall wrapper.destroy)))

(fn restore-window-wrapper-opts!
  [wrapper]
  (when (and wrapper
             wrapper.window
             (vim.api.nvim_win_is_valid wrapper.window)
             wrapper.restore-opts)
    (pcall wrapper.restore-opts)))

(fn apply-window-wrapper-opts!
  [wrapper opts]
  (when (and wrapper
             wrapper.window
             (vim.api.nvim_win_is_valid wrapper.window)
             wrapper.apply-opts)
    (pcall wrapper.apply-opts opts)))

(fn restore-main-window-opts!
  [session]
  "Restore the original local options for Meta-managed windows."
  (let [main-win (and session session.meta session.meta.win)
        status-win (and session session.meta session.meta.status-win)]
    (destroy-window-wrapper! main-win)
    (when (and status-win
               (~= status-win main-win))
      (destroy-window-wrapper! status-win))))

(fn suspend-main-window-opts!
  [session]
  "Temporarily restore origin window-local options while keeping wrappers reusable."
  (let [main-win (and session session.meta session.meta.win)
        status-win (and session session.meta session.meta.status-win)]
    (restore-window-wrapper-opts! main-win)
    (when (and status-win
               (~= status-win main-win))
      (restore-window-wrapper-opts! status-win))
    (each [_ win (ipairs [(and main-win main-win.window)
                          (and status-win status-win.window)])]
      (when (and win (vim.api.nvim_win_is_valid win))
        (events.send :on-win-teardown! {:win win :role :main})))))

(fn resume-main-window-opts!
  [deps session]
  "Reapply Meta window-local options after a hidden session becomes visible again."
  (let [meta-window-mod (. (. deps :mods) :meta-window)
        opts (or (and meta-window-mod (. meta-window-mod :default-opts)) {})
        main-win (and session session.meta session.meta.win)
        status-win (and session session.meta session.meta.status-win)]
    (apply-window-wrapper-opts! main-win opts)
    (when (and status-win
               (~= status-win main-win))
      (apply-window-wrapper-opts! status-win opts))
    (each [_ win (ipairs [(and main-win main-win.window)
                          (and status-win status-win.window)])]
      (when (and win (vim.api.nvim_win_is_valid win))
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
  (when (and session session.startup-cursor-hidden?)
    (let [value (or session.startup-saved-guicursor vim.o.guicursor)]
      (set session.startup-cursor-hidden? false)
      (set session.startup-saved-guicursor nil)
      (pcall vim.api.nvim_set_option_value "guicursor" value {:scope "global"}))))

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
      (history-api.push-history-entry!
        session
        (or session.last-prompt-text
            (if (and session.prompt-buf (vim.api.nvim_buf_is_valid session.prompt-buf))
                (router-util-mod.prompt-text session)
                "")))
      (router-util-mod.persist-prompt-height! session)
      (router-util-mod.persist-results-wrap! session)
      (when session.augroup
        (pcall vim.api.nvim_del_augroup_by_id session.augroup))
      (when (and session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
        (pcall vim.api.nvim_win_close session.prompt-win true))
      (when (and session.prompt-buf (vim.api.nvim_buf_is_valid session.prompt-buf))
        (clear-buffer-modified! session.prompt-buf)
        (pcall vim.api.nvim_buf_delete session.prompt-buf {:force true}))
      (when (and session.meta session.meta.buf session.meta.buf.buffer)
        (clear-buffer-modified! session.meta.buf.buffer))
      (info-window.close-window! session)
      (preview-window.close-window! session)
      (when (and context-window context-window.close-window!)
        (context-window.close-window! session))
      (history-api.close-history-browser! session)
      (when (and sign-mod session.meta session.meta.buf session.meta.buf.buffer)
        (sign-mod.clear-change-signs! session.meta.buf.buffer))
      (clear-map-entry! active-by-source session.source-buf session)
      (when (and session.meta session.meta.buf session.meta.buf.buffer)
        (clear-map-entry! active-by-source session.meta.buf.buffer session))
      (clear-map-entry! active-by-prompt session.prompt-buf session)
      (when session.instance-id
        (clear-map-entry! instances session.instance-id session))
      (when (and session.origin-win (vim.api.nvim_win_is_valid session.origin-win))
        (events.send :on-win-teardown! {:win session.origin-win :role :origin})))))

(local prompt-window-opts {
  :winfixwidth true
  :winfixheight true
  :number false
  :relativenumber false
  :signcolumn "no"
  :foldcolumn "0"
  :statusline " "
  :spell false
  :wrap true
  :linebreak true
})

(fn apply-prompt-window-opts!
  [win]
  (when (and win (vim.api.nvim_win_is_valid win))
    (events.send :on-win-create! {:win win :role :prompt})
    (each [name value (pairs prompt-window-opts)]
      (pcall vim.api.nvim_set_option_value name value {:win win}))))

(fn wipe-replaced-split-buffer!
  [old-buf]
  "Delete the temporary unnamed split buffer created by :new before reattaching prompt."
  (when (and old-buf (vim.api.nvim_buf_is_valid old-buf))
    (util.delete-transient-unnamed-buffer! old-buf)))

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

(fn hide-session-ui!
  [deps session]
  (let [{: router : mods : windows : history} deps
        router-util-mod (. mods :router-util)
        animation-mod (. mods :animation)
        info-window (. windows :info)
        preview-window (. windows :preview)
        context-window (. windows :context)
        history-api (. history :api)
        active-by-source (. router :active-by-source)]
    (set session.ui-hidden true)
    (set session._last-prompt-statusline nil)
    (when (and animation-mod animation-mod.cancel-session!)
      (animation-mod.cancel-session! session))
    (restore-startup-cursor! session)
    (set session.ui-last-insert-mode (vim.startswith (. (vim.api.nvim_get_mode) :mode) "i"))
    (when (and session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
      (let [[ok cur] [(pcall vim.api.nvim_win_get_cursor session.prompt-win)]]
        (when (and ok (= (type cur) "table"))
          (set session.hidden-prompt-cursor [(or (. cur 1) 1) (or (. cur 2) 0)])))
      (router-util-mod.persist-prompt-height! session)
      (router-util-mod.persist-results-wrap! session)
      (set session.hidden-prompt-height (vim.api.nvim_win_get_height session.prompt-win))
      (when (and session.prompt-buf (vim.api.nvim_buf_is_valid session.prompt-buf))
        (let [bo (. vim.bo session.prompt-buf)]
          (set (. bo :bufhidden) "hide")))
      (clear-buffer-modified! session.prompt-buf)
      (pcall vim.api.nvim_win_close session.prompt-win true))
    (set session.prompt-win nil)
    (when (and session.meta session.meta.buf session.meta.buf.buffer)
      (clear-buffer-modified! session.meta.buf.buffer))
    (suspend-main-window-opts! session)
    (info-window.close-window! session)
    (preview-window.close-window! session)
    (when (and context-window context-window.close-window!)
      (context-window.close-window! session))
    (history-api.close-history-browser! session)
    (when (and session.meta session.meta.buf session.meta.buf.buffer)
      (set (. active-by-source session.meta.buf.buffer) session))))

(fn restore-session-ui!
  [deps session opts]
  (let [{: mods : refresh} deps
        sync-prompt-buffer-name! (. refresh :sync-prompt-buffer-name!)
        router-util-mod (. mods :router-util)
        session-view-mod (. mods :session-view)
        preserve-focus? (and opts (. opts :preserve-focus))
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
                             (vim.api.nvim_get_current_win)))
            old-buf (and prompt-win
                         (vim.api.nvim_win_is_valid prompt-win)
                         (vim.api.nvim_win_get_buf prompt-win))]
        (set session.prompt-win prompt-win)
        (util.mark-transient-unnamed-buffer! old-buf)
        (pcall vim.api.nvim_win_set_height prompt-win height)
        (pcall vim.api.nvim_win_set_buf prompt-win session.prompt-buf)
        (wipe-replaced-split-buffer! old-buf)
        (let [bo (. vim.bo session.prompt-buf)]
          (set (. bo :buftype) "nofile")
          (set (. bo :bufhidden) "hide")
          (set (. bo :swapfile) false)
          (set (. bo :modifiable) true)
          (set (. bo :filetype) "metabufferprompt"))
        (apply-prompt-window-opts! prompt-win)
        (sync-prompt-buffer-name! session)
        (set session._last-prompt-statusline nil)
        (set curr.status-win curr.win)
        (set session.ui-hidden false)
        (resume-main-window-opts! deps session)
        (when (and curr curr.buf curr.buf.buffer (vim.api.nvim_buf_is_valid curr.buf.buffer))
          (let [bo (. vim.bo curr.buf.buffer)]
            (set curr.buf.keep-modifiable true)
            (set (. bo :buftype) "acwrite")
            (set (. bo :modifiable) true)
            (set (. bo :readonly) false)
            (set (. bo :bufhidden) "hide"))
          (pcall curr.buf.render))
        (events.send :on-restore-ui!
          {:session session
           :restore-view? (and session-view-mod session.source-view)})
        (let [cursor (or session.hidden-prompt-cursor [1 0])
              row (math.max 1 (or (. cursor 1) 1))
              col (math.max 0 (or (. cursor 2) 0))
              line-count (math.max 1 (vim.api.nvim_buf_line_count session.prompt-buf))
              row* (math.min row line-count)
              line (or (. (vim.api.nvim_buf_get_lines session.prompt-buf (- row* 1) row* false) 1) "")
              col* (math.min col (# line))]
          (pcall vim.api.nvim_win_set_cursor prompt-win [row* col*]))
        (events.send :on-restore-ui!
          {:session session
           :refresh-lines true})
        (when-not preserve-focus?
          (vim.api.nvim_set_current_win prompt-win)
          (if session.ui-last-insert-mode
              (vim.cmd "startinsert")
              (vim.cmd "stopinsert")))))))

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
                  rel (vim.fn.fnamemodify path ":~:.")
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
            (silent-win-set-buf! target-win target-buf)
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
  (let [{: router : history : mods : windows} deps
        active-by-source (. router :active-by-source)
        history-api (. history :api)
        router-util-mod (. mods :router-util)
        info-window (. windows :info)
        preview-window (. windows :preview)
        instances (. router :instances)
        active-by-prompt (. router :active-by-prompt)
        session (. active-by-source results-buf)]
    (when (and session (not session._results_wiped))
      (set session._results_wiped true)
      (set session.closing true)
      (restore-main-window-opts! session)
      (history-api.push-history-entry!
        session
        (or session.last-prompt-text
            (if (and session.prompt-buf (vim.api.nvim_buf_is_valid session.prompt-buf))
                (router-util-mod.prompt-text session)
                "")))
      (router-util-mod.persist-prompt-height! session)
      (when (and session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
        (pcall vim.api.nvim_win_close session.prompt-win true))
      (when (and session.prompt-buf (vim.api.nvim_buf_is_valid session.prompt-buf))
        (pcall vim.api.nvim_buf_delete session.prompt-buf {:force true}))
      (info-window.close-window! session)
      (preview-window.close-window! session)
      (history-api.close-history-browser! session)
      (clear-map-entry! active-by-source session.source-buf session)
      (clear-map-entry! active-by-source results-buf session)
      (clear-map-entry! active-by-prompt session.prompt-buf session)
      (when session.instance-id
        (clear-map-entry! instances session.instance-id session)))))

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
  (let [{: router} deps
        active-by-source (. router :active-by-source)
        buf session.meta.buf.buffer]
    (set (. active-by-source buf) session)))

(fn diff-hunks
  [old-lines new-lines]
  (let [old-text (table.concat (or old-lines []) "\n")
        new-text (table.concat (or new-lines []) "\n")
        [ok out] [(pcall vim.diff old-text new-text {:result_type "indices" :algorithm "histogram"})]]
    (if (and ok (= (type out) "table")) out [])))

(fn hunk-indices
  [h]
  [(or (. h 1) 1) (or (. h 2) 0) (or (. h 3) 1) (or (. h 4) 0)])

(fn slice-lines
  [lines start count]
  (let [out []]
    (for [i start (+ start count -1)]
      (when (and (>= i 1) (<= i (# lines)))
        (table.insert out (. lines i))))
    out))

(fn clone-row-with-text
  [row text]
  (let [r (vim.deepcopy (or row {}))]
    (set (. r :text) (or text ""))
    (set (. r :line) (or text ""))
    r))

(fn consecutive-same-source?
  [prev-row next-row]
  (and prev-row
       next-row
       (= (type (. prev-row :path)) "string")
       (= (type (. next-row :path)) "string")
       (~= (. prev-row :path) "")
       (~= (. next-row :path) "")
       (= (type (. prev-row :lnum)) "number")
       (= (type (. next-row :lnum)) "number")
       (= (. prev-row :path) (. next-row :path))
       (= (+ (. prev-row :lnum) 1) (. next-row :lnum))))

(fn inserted-row
  [session prev-row next-row text rel-index]
  (let [base (or prev-row next-row {})
        out (vim.deepcopy base)
        prev-lnum (or (and prev-row (. prev-row :lnum)) (. base :lnum) 1)
        next-lnum (or (and next-row (. next-row :lnum)) (. base :lnum) (+ prev-lnum 1))
        pending (or session.pending-structural-edit {})
        pending-side (. pending :side)
        pending-path (. pending :path)
        pending-lnum (. pending :lnum)
        lnum (if (consecutive-same-source? prev-row next-row)
                 (+ prev-lnum rel-index)
                 (if (and (= pending-side "after")
                          prev-row
                          (= pending-path (. prev-row :path))
                          (= pending-lnum (. prev-row :lnum)))
                     (+ pending-lnum rel-index)
                     (if (and (= pending-side "before")
                              next-row
                              (= pending-path (. next-row :path))
                              (= pending-lnum (. next-row :lnum)))
                         (+ pending-lnum rel-index -1)
                         (if prev-row
                             (+ prev-lnum rel-index)
                             (math.max 1 (- next-lnum 1))))))]
    (set (. out :lnum) (math.max 1 (or lnum 1)))
    (set (. out :text) (or text ""))
    (set (. out :line) (or text ""))
    (if (consecutive-same-source? prev-row next-row)
        (do
          (set (. out :insert-path) (. prev-row :path))
          (set (. out :insert-lnum) (. prev-row :lnum))
          (set (. out :insert-side) "after"))
        (do
          (when (and (= pending-side "after")
                     prev-row
                     (= (type (. prev-row :path)) "string")
                     (~= (. prev-row :path) "")
                     (= (type (. prev-row :lnum)) "number")
                     (= pending-path (. prev-row :path))
                     (= pending-lnum (. prev-row :lnum)))
            (set (. out :insert-path) (. prev-row :path))
            (set (. out :insert-lnum) (. prev-row :lnum))
            (set (. out :insert-side) "after"))
          (when (and (= pending-side "before")
                     next-row
                     (= (type (. next-row :path)) "string")
                     (~= (. next-row :path) "")
                     (= (type (. next-row :lnum)) "number")
                     (= pending-path (. next-row :path))
                     (= pending-lnum (. next-row :lnum)))
            (set (. out :insert-path) (. next-row :path))
            (set (. out :insert-lnum) (. next-row :lnum))
            (set (. out :insert-side) "before"))))
    out))

(fn projected-rows-from-edits
  [session baseline-rows baseline-lines current-lines]
  (let [hunks (diff-hunks baseline-lines current-lines)
        out []
        idx {:old 1 :new 1}]
    (each [_ h (ipairs hunks)]
      (let [[a-start a-count b-start b-count] (hunk-indices h)
            common (math.min a-count b-count)]
        ;; unchanged rows before hunk
        (while (< (. idx :old) a-start)
          (let [txt (or (. current-lines (. idx :new)) "")]
            (table.insert out (clone-row-with-text (. baseline-rows (. idx :old)) txt))
            (set (. idx :old) (+ (. idx :old) 1))
            (set (. idx :new) (+ (. idx :new) 1))))
        ;; replacements
        (for [k 1 common]
          (let [txt (or (. current-lines (+ b-start k -1)) "")]
            (table.insert out (clone-row-with-text (. baseline-rows (+ a-start k -1)) txt))))
        ;; insertions
        (when (> b-count a-count)
          (let [extra (- b-count common)
                prev-row (if (> (+ a-start common -1) 0)
                             (. baseline-rows (+ a-start common -1))
                             nil)
                next-row (. baseline-rows (+ a-start common))]
            (for [k 1 extra]
              (let [txt (or (. current-lines (+ b-start common k -1)) "")]
                (table.insert out (inserted-row session prev-row next-row txt k))))))
        ;; deletions are omitted from output
        (set (. idx :old) (+ a-start a-count))
        (set (. idx :new) (+ b-start b-count))))
    ;; unchanged tail
    (while (<= (. idx :old) (# baseline-rows))
      (let [txt (or (. current-lines (. idx :new)) "")]
        (table.insert out (clone-row-with-text (. baseline-rows (. idx :old)) txt))
        (set (. idx :old) (+ (. idx :old) 1))
        (set (. idx :new) (+ (. idx :new) 1))))
    out))

(fn apply-live-edits-to-meta!
  [session current-lines]
  (let [meta session.meta
        baseline-lines (or session.edit-baseline-lines [])
        baseline-rows (or session.edit-baseline-rows [])
        rows (projected-rows-from-edits session baseline-rows baseline-lines current-lines)
        refs []
        content []
        idxs []]
    (set session.live-edit-rows rows)
    (for [i 1 (# rows)]
      (let [row (or (. rows i) {})]
        (set (. refs i) {:kind (or (. row :kind) "")
                         :path (or (. row :path) "")
                         :lnum (or (. row :lnum) 1)
                         :open-lnum (or (. row :open-lnum) (. row :lnum) 1)
                         :line (or (. row :text) (. row :line) "")})
        (set (. content i) (or (. row :text) (. row :line) ""))
        (set (. idxs i) i)))
    (set meta.buf.source-refs refs)
    (set meta.buf.content content)
    (set meta.buf.indices idxs)
    (let [max (math.max 1 (# idxs))]
      (set meta.selected_index
           (math.max 0 (math.min (or meta.selected_index 0) (- max 1)))))))

(fn valid-row?
  [row]
  (and row
       (= (type (. row :path)) "string")
       (~= (. row :path) "")
       (= (type (. row :lnum)) "number")
       (> (. row :lnum) 0)))

(fn special-projected-row?
  [row]
  (and row
       (. row :source-group-id)
       (or (> (# (or (. row :transform-chain) [])) 0)
           (= (or (. row :source-group-kind) "") "file"))))

(fn append-op!
  [ops path op]
  (let [per-file (or (. ops path) [])]
    (table.insert per-file op)
    (set (. ops path) per-file)))

(fn append-group-op!
  [ops row current-rows processed]
  (let [group-id (. row :source-group-id)
        path (. row :path)
        key (.. path "|" (tostring group-id))
        group-lines []]
    (if (. (or processed {}) key)
        nil
        (do
          (set (. processed key) true)
          (each [_ r (ipairs (or current-rows []))]
            (when (and (= (. r :path) path)
                       (= (. r :source-group-id) group-id))
              (table.insert group-lines (or (. r :text) (. r :line) ""))))
          (let [reversed (transform-mod.reverse-group row group-lines {:path path :lnum (. row :lnum)})]
            (if (. reversed :error)
                {:error (. reversed :error)}
                (do
                  (if (= (. reversed :kind) :rewrite-bytes)
                      (append-op! ops path {:kind :rewrite-bytes
                                            :bytes (. reversed :bytes)
                                            :ref-kind (or (. row :kind) "")})
                      (append-op! ops path {:kind :replace
                                            :lnum (. row :lnum)
                                            :text (. reversed :text)
                                            :old-text (or (. row :source-text) "")
                                            :ref-kind (or (. row :kind) "")}))
                  nil)))))))

(fn structural-op-from-current-rows
  [current-rows start count]
  (let [rows (slice-lines current-rows start count)
        first-row (. rows 1)]
    (if (and first-row
             (. first-row :insert-path)
             (. first-row :insert-lnum)
             (. first-row :insert-side))
        (let [path (. first-row :insert-path)
              lnum (. first-row :insert-lnum)
              side (. first-row :insert-side)
              ref-kind (or (. first-row :kind) "")
              lines []
              state {:consistent? true}]
          (each [_ row (ipairs rows)]
            (when (or (~= (. row :insert-path) path)
                      (~= (. row :insert-lnum) lnum)
                      (~= (. row :insert-side) side))
              (set (. state :consistent?) false))
            (table.insert lines (or (. row :text) (. row :line) "")))
          (when (. state :consistent?)
            {:path path :lnum lnum :side side :lines lines :ref-kind ref-kind}))
        nil)))

(fn pending-structural-op
  [session start count current-lines fallback-kind]
  (let [pending (or session.pending-structural-edit {})
        path (. pending :path)
        lnum (. pending :lnum)
        side (. pending :side)
        ref-kind (or (. pending :kind) fallback-kind "")]
    (when (and (= (type path) "string")
               (~= path "")
               (= (type lnum) "number")
               (> lnum 0)
               (or (= side "before") (= side "after"))
               (> count 0)
               (~= ref-kind "file-entry"))
      {:path path
       :lnum lnum
       :side side
       :lines (slice-lines current-lines start count)
       :ref-kind ref-kind})))

(fn collect-file-ops
  [session]
  (let [meta session.meta
        buf meta.buf.buffer
        baseline-lines (or session.edit-baseline-lines (vim.api.nvim_buf_get_lines buf 0 -1 false))
        baseline-rows (or session.edit-baseline-rows [])
        current-lines (vim.api.nvim_buf_get_lines buf 0 -1 false)
        current-rows (projected-rows-from-edits session baseline-rows baseline-lines current-lines)
        hunks (diff-hunks baseline-lines current-lines)
        ops {}
        state {:unsafe-structural? false
               :processed-special-groups {}}]
    (set session.live-edit-rows current-rows)
    (each [_ h (ipairs hunks)]
      (let [[a-start a-count b-start b-count] (hunk-indices h)
            common (math.min a-count b-count)
            old-rows (slice-lines baseline-rows a-start a-count)
            new-lines (slice-lines current-lines b-start b-count)]
        (if (> a-count 0)
            (do
              (for [i 1 common]
                (let [row (. old-rows i)
                      text (or (. new-lines i) "")]
                  (when (and (valid-row? row) (~= (or (. row :text) "") text))
                    (if (special-projected-row? row)
                        (let [err (append-group-op! ops row current-rows (. state :processed-special-groups))]
                          (when err
                            (set (. state :unsafe-structural?) true)))
                        (append-op! ops (. row :path) {:kind :replace
                                                       :lnum (. row :lnum)
                                                       :text text
                                                       :old-text (or (. row :text) "")
                                                       :ref-kind (or (. row :kind) "")})))))
              (when (> a-count b-count)
                (for [i (+ common 1) a-count]
                  (let [row (. old-rows i)]
                    (if (and (valid-row? row) (not (special-projected-row? row)))
                        (append-op! ops (. row :path) {:kind :delete :lnum (. row :lnum) :ref-kind (or (. row :kind) "")})
                        (set (. state :unsafe-structural?) true)))))
              (when (> b-count a-count)
                (let [insert-op (or (structural-op-from-current-rows current-rows (+ b-start common) (- b-count common))
                                    (pending-structural-op session (+ b-start common) (- b-count common) current-lines
                                      (or (and (. old-rows common) (. (. old-rows common) :kind))
                                          (and (. old-rows (+ common 1)) (. (. old-rows (+ common 1)) :kind))
                                          "")))]
                  (if insert-op
                      (append-op! ops (. insert-op :path)
                        {:kind (if (= (. insert-op :side) "before") :insert-before :insert-after)
                         :lnum (. insert-op :lnum)
                         :lines (. insert-op :lines)
                         :ref-kind (or (. insert-op :ref-kind) "")})
                      (set (. state :unsafe-structural?) true)))))
            (when (> b-count 0)
              (let [insert-op (or (structural-op-from-current-rows current-rows b-start b-count)
                                  (pending-structural-op session b-start b-count current-lines ""))]
                (if insert-op
                    (append-op! ops (. insert-op :path)
                      {:kind (if (= (. insert-op :side) "before") :insert-before :insert-after)
                       :lnum (. insert-op :lnum)
                       :lines (. insert-op :lines)
                       :ref-kind (or (. insert-op :ref-kind) "")})
                    (set (. state :unsafe-structural?) true)))))))
    {:ops ops
     :current-lines current-lines
     :current-rows current-rows
     :unsafe-structural? (. state :unsafe-structural?)}))

(fn grouped-path-ops->flat-ops
  [ops]
  (let [out []]
    (each [path per-file (pairs (or ops {}))]
      (each [_ op (ipairs (or per-file []))]
        (let [item (vim.deepcopy (or op {}))]
          (set (. item :path) path)
          (table.insert out item))))
    out))

(fn apply-file-ops!
  [ops]
  (source-mod.apply-write-ops! (grouped-path-ops->flat-ops ops)))

(fn update-row-after-ops
  [row ops post-lines renames]
  (let [ref (vim.deepcopy (or row {}))
        path0 (or (. ref :path) "")
        path (or (. (or renames {}) path0) path0)
        lnum0 (if (and (= (type (. ref :lnum)) "number") (> (. ref :lnum) 0)) (. ref :lnum) 1)
        generated-path (. ref :insert-path)
        generated-lnum (. ref :insert-lnum)
        generated-side (. ref :insert-side)]
    (set (. ref :path) path)
    (var lnum lnum0)
    (each [_ op (ipairs (or (. ops path) []))]
      (let [same-generated? (and (= generated-path path)
                                 (= generated-lnum (. op :lnum))
                                 (or (and (= generated-side "before") (= (. op :kind) :insert-before))
                                     (and (= generated-side "after") (= (. op :kind) :insert-after))))]
        (when-not same-generated?
          (if (= (. op :kind) :insert-before)
              (when (>= lnum (. op :lnum))
                (set lnum (+ lnum (# (or (. op :lines) [])))))
              (= (. op :kind) :insert-after)
              (when (> lnum (. op :lnum))
                (set lnum (+ lnum (# (or (. op :lines) [])))))
              (= (. op :kind) :delete)
              (when (> lnum (. op :lnum))
                (set lnum (- lnum 1)))
              nil))))
    (when (< lnum 1)
      (set lnum 1))
    (set (. ref :lnum) lnum)
    (let [lines (. post-lines path)
          line (or (and lines
                        (>= lnum 1)
                        (<= lnum (# lines))
                        (. lines lnum))
                   (. ref :text)
                   (. ref :line)
                   "")]
      (set (. ref :line) line)
      (set (. ref :text) line))
    ref))

(fn update-session-refs-after-ops!
  [session current-rows ops post-lines renames]
  (let [meta session.meta
        refs []
        content []
        idxs []]
    (each [_ row (ipairs (or current-rows []))]
      (let [ref (update-row-after-ops row ops post-lines renames)
            idx (+ (# refs) 1)]
        (when (= (or (. ref :kind) "") "file-entry")
          (let [rel (vim.fn.fnamemodify (or (. ref :path) "") ":.")]
            (set (. ref :line) (if (and (= (type rel) "string") (~= rel "")) rel (or (. ref :path) "")))
            (set (. ref :text) (. ref :line))))
        (table.insert refs {:kind (or (. ref :kind) "")
                            :path (or (. ref :path) "")
                            :lnum (or (. ref :lnum) 1)
                            :open-lnum (or (. ref :open-lnum) (. ref :lnum) 1)
                            :source-lnum (. ref :source-lnum)
                            :source-text (. ref :source-text)
                            :source-group-id (. ref :source-group-id)
                            :source-group-kind (. ref :source-group-kind)
                            :transform-chain (vim.deepcopy (or (. ref :transform-chain) []))
                            :line (or (. ref :line) "")})
        (table.insert content (or (. ref :line) ""))
        (table.insert idxs idx)))
    (set meta.buf.source-refs refs)
    (set meta.buf.content content)
    (set meta.buf.indices idxs)))

(fn invalidate-caches-for-paths!
  [deps session updates]
  (let [{: router} deps
        project-file-cache (and router router.project-file-cache)
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
  (let [{: router : mods} deps
        session (session-by-prompt (. router :active-by-prompt) prompt-buf)
        sign-mod (. mods :sign)]
    (when session
      (let [collected (collect-file-ops session)
            ops (. collected :ops)
            buf session.meta.buf.buffer]
        (if (. collected :unsafe-structural?)
            (do
              (vim.notify
                "metabuffer: only in-place line replacements are writable from results; open the real file for insert/delete edits"
                vim.log.levels.ERROR)
              (events.send :on-query-update!
                {:session session
                 :query (or session.prompt-last-applied-text "")
                 :refresh-lines false
                 :refresh-signs? true}))
            (let [result (apply-file-ops! ops)]
              (set session.pending-structural-edit nil)
              (update-session-refs-after-ops! session (. collected :current-rows) ops (. result :post-lines) (. result :renames))
              (invalidate-caches-for-paths! deps session (. result :paths))
              (when (> result.changed 0)
                (pcall session.meta.on-update 0))
              (pcall vim.api.nvim_set_option_value "modified" false {:buf buf})
              (pcall vim.api.nvim_buf_set_var buf "meta_manual_edit_active" false)
              (events.send :on-query-update!
                {:session session
                 :query (or session.prompt-last-applied-text "")
                 :refresh-lines true
                 :capture-sign-baseline? (not (not sign-mod))
                 :refresh-signs? (not (not sign-mod))})
              (vim.notify
                (if (> result.changed 0)
                    (.. "metabuffer: wrote " (tostring result.changed) " change(s)")
                    "metabuffer: no changes")
                vim.log.levels.INFO)))))))

(fn M.enter-edit-mode!
  [deps prompt-buf]
  (let [{: router : mods : history : refresh} deps
        session (session-by-prompt (. router :active-by-prompt) prompt-buf)
        router-util-mod (. mods :router-util)
        sign-mod (. mods :sign)
        history-api (. history :api)
        apply-prompt-lines (. refresh :apply-prompt-lines!)]
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
      (when sign-mod
        (pcall sign-mod.capture-baseline! session))
      ;; Enter editing context in Normal mode; prompt starts in Insert mode.
      (pcall vim.cmd "stopinsert"))))

(fn M.hide-visible-ui!
  [deps prompt-buf]
  (let [{: router} deps
        session (session-by-prompt (. router :active-by-prompt) prompt-buf)]
    (when (and session
               (not session.ui-hidden)
               (not session.closing))
      (set session.results-edit-mode false)
      (hide-session-ui! deps session)
      (pcall vim.cmd "stopinsert"))))

(fn M.sync-live-edits!
  [deps prompt-buf]
  (let [{: router} deps
        session (session-by-prompt (. router :active-by-prompt) prompt-buf)]
    (when (and session session.meta session.meta.buf)
      (let [buf session.meta.buf.buffer
            manual? (let [[ok v] [(pcall vim.api.nvim_buf_get_var buf "meta_manual_edit_active")]]
                      (and ok v))]
        (when (and manual? (vim.api.nvim_buf_is_valid buf))
          (let [current-lines (vim.api.nvim_buf_get_lines buf 0 -1 false)]
            (apply-live-edits-to-meta! session current-lines)))))))

(fn M.maybe-restore-ui!
  [deps prompt-buf force]
  (let [{: router} deps
        session (session-by-prompt (. router :active-by-prompt) prompt-buf)]
    (when (and session
               session.ui-hidden
               session.meta
               session.meta.buf)
      (let [current-buf (vim.api.nvim_get_current_buf)
            results-buf session.meta.buf.buffer]
        (when (or force
                  (= current-buf results-buf))
          (set session.meta.win.window (vim.api.nvim_get_current_win))
          (restore-session-ui!
            deps
            session
            {:preserve-focus (not force)}))))))

M
