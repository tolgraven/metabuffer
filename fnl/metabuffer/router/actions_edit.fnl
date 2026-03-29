(import-macros {: when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})
(local debug-mod (require :metabuffer.debug))
(local actions-writeback-mod (require :metabuffer.router.actions_writeback))

(fn M.new
  [opts]
  "Build results-edit and writeback action helpers."
  (let [{: session-by-prompt : clear-map-entry! : restore-main-window-opts!
         : hide-session-ui! : restore-session-ui!} (or opts {})]
    (fn ensure-session-for-results-buf!
      [deps session]
      (let [{: router} deps
            active-by-source (. router :active-by-source)
            buf session.meta.buf.buffer]
        (set (. active-by-source buf) session)))
    (let [writeback (actions-writeback-mod.new {})
          apply-live-edits-to-meta! (. writeback :apply-live-edits-to-meta!)
          write-results-core! (. writeback :write-results!)]

    (fn write-results!
      [deps prompt-buf]
      (let [{: router : mods} deps
            session (session-by-prompt (. router :active-by-prompt) prompt-buf)
            sign-mod (. mods :sign)]
        (when session
          (write-results-core! deps session sign-mod))))

    (fn enter-edit-mode!
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
          (when (and session.meta session.meta.buf session.meta.buf.prepare-visible-edit!)
            (pcall session.meta.buf.prepare-visible-edit! session.meta.buf))
          (when (and session.meta session.meta.win (vim.api.nvim_win_is_valid session.meta.win.window))
            (pcall vim.api.nvim_set_current_win session.meta.win.window)
            (pcall vim.api.nvim_win_set_buf session.meta.win.window session.meta.buf.buffer))
          (when sign-mod
            (pcall sign-mod.capture-baseline! session))
          (pcall vim.cmd "stopinsert"))))

    (fn hide-visible-ui!
      [deps prompt-buf]
      (let [{: router} deps
            session (session-by-prompt (. router :active-by-prompt) prompt-buf)]
        (when (and session
                   (not session.ui-hidden)
                   (not session.closing))
          (set session.results-edit-mode false)
          (hide-session-ui! deps session)
          (pcall vim.cmd "stopinsert"))))

    (fn sync-live-edits!
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

    (fn maybe-restore-ui!
      [deps prompt-buf force]
      (let [{: router} deps
            session (session-by-prompt (. router :active-by-prompt) prompt-buf)]
        (when (and session
                   session.ui-hidden
                   (not session.restoring-ui?)
                   session.meta
                   session.meta.buf)
          (let [current-buf (vim.api.nvim_get_current_buf)
                results-buf session.meta.buf.buffer]
            (when (or force
                      (= current-buf results-buf))
              (debug-mod.log :router-actions
                         (.. "maybe-restore-ui"
                              " force=" (tostring (not (not force)))
                              " current=" (tostring current-buf)
                              " results=" (tostring results-buf)
                              " hidden=" (tostring (not (not session.ui-hidden)))
                              " restoring=" (tostring (not (not session.restoring-ui?)))
                              " bootstrapped=" (tostring (not (not session.project-bootstrapped)))
                              " stream-done=" (tostring (not (not session.lazy-stream-done)))))
              (set session.meta.win.window (vim.api.nvim_get_current_win))
              (restore-session-ui!
                deps
                session
                {:preserve-focus (not force)}))))))

    (fn on-results-buffer-wipe!
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

    {:write-results! write-results!
     :enter-edit-mode! enter-edit-mode!
     :hide-visible-ui! hide-visible-ui!
     :sync-live-edits! sync-live-edits!
     :maybe-restore-ui! maybe-restore-ui!
     :on-results-buffer-wipe! on-results-buffer-wipe!})))

M
