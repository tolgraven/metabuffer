(import-macros {: when-let : when-not} :io.gitlab.andreyorst.cljlib.core)

(local M {})

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
  (when (and buf (vim.api.nvim_buf_is_valid buf))
    (pcall vim.api.nvim_set_option_value "modified" false {:buf buf})))

(fn remove-session!
  [deps session]
  (let [{: router
         : mods
         : windows
         : history}
        deps
        history-api (. history :api)
        sign-mod (. mods :sign)
        router-util-mod (. mods :router-util)
        info-window (. windows :info)
        preview-window (. windows :preview)
        context-window (. windows :context)
        active-by-source (. router :active-by-source)
        active-by-prompt (. router :active-by-prompt)
        instances (. router :instances)]
    (when session
      (set session.closing true)
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
        (pcall vim.api.nvim_win_del_var session.origin-win "airline_disable_statusline")))))

(fn apply-prompt-window-opts!
  [win]
  (when (and win (vim.api.nvim_win_is_valid win))
    (pcall vim.api.nvim_win_set_var win "airline_disable_statusline" 1)
    (let [wo (. vim.wo win)]
      (set (. wo :winfixwidth) true)
      (set (. wo :winfixheight) true)
      (set (. wo :number) false)
      (set (. wo :relativenumber) false)
      (set (. wo :signcolumn) "no")
      (set (. wo :foldcolumn) "0")
      (set (. wo :statusline) " ")
      (set (. wo :spell) false)
      (set (. wo :wrap) true)
      (set (. wo :linebreak) true))))

(fn hide-session-ui!
  [deps session]
  (let [{: router : mods : windows : history} deps
        router-util-mod (. mods :router-util)
        info-window (. windows :info)
        preview-window (. windows :preview)
        context-window (. windows :context)
        history-api (. history :api)
        active-by-source (. router :active-by-source)]
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
      (clear-buffer-modified! session.prompt-buf)
      (pcall vim.api.nvim_win_close session.prompt-win true))
    (set session.prompt-win nil)
    (when (and session.meta session.meta.buf session.meta.buf.buffer)
      (clear-buffer-modified! session.meta.buf.buffer))
    (info-window.close-window! session)
    (preview-window.close-window! session)
    (when (and context-window context-window.close-window!)
      (context-window.close-window! session))
    (history-api.close-history-browser! session)
    (when (and session.meta session.meta.buf session.meta.buf.buffer)
      (set (. active-by-source session.meta.buf.buffer) session))))

(fn restore-session-ui!
  [deps session opts]
  (let [{: mods : windows : refresh} deps
        meta-window-mod (. mods :meta-window)
        sync-prompt-buffer-name! (. refresh :sync-prompt-buffer-name!)
        router-util-mod (. mods :router-util)
        update-info-window (. refresh :info!)
        context-window (. windows :context)
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
        (when (and context-window context-window.update!)
          (pcall context-window.update! session))
        (when-not preserve-focus?
          (vim.api.nvim_set_current_win prompt-win)
          (if session.ui-last-insert-mode
              (vim.cmd "startinsert")
              (vim.cmd "stopinsert")))))))

(fn finish-accept
  [deps session]
  (let [{: router : mods : history : refresh} deps
        active-by-prompt (. router :active-by-prompt)
        router-prompt-mod (. mods :router-prompt)
        sign-mod (. mods :sign)
        router-util-mod (. mods :router-util)
        session-view (. mods :session-view)
        base-buffer (. mods :base-buffer)
        history-api (. history :api)
        apply-prompt-lines (. refresh :apply-prompt-lines!)
        wrapup (. refresh :wrapup)
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
              (when sign-mod
                (sign-mod.clear-change-signs! curr.buf.buffer))
              (session-view.wipe-temp-buffers curr)
              (remove-session! deps session)
              (wrapup curr)))))
    curr))

(fn finish-cancel
  [deps session]
  (let [{: mods : history : refresh} deps
        router-prompt-mod (. mods :router-prompt)
        router-util-mod (. mods :router-util)
        sign-mod (. mods :sign)
        session-view (. mods :session-view)
        base-buffer (. mods :base-buffer)
        history-api (. history :api)
        wrapup (. refresh :wrapup)
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
    (vim.cmd "silent! nohlsearch")
    (when (and (vim.api.nvim_win_is_valid session.origin-win)
               (vim.api.nvim_buf_is_valid session.origin-buf))
      (pcall vim.api.nvim_set_current_win session.origin-win)
      (pcall vim.api.nvim_win_set_buf session.origin-win session.origin-buf)
      (when session.source-view
        (vim.api.nvim_win_call
          session.origin-win
          (fn []
            (pcall vim.fn.winrestview session.source-view)))))
    (base-buffer.switch-buf curr.buf.model)
    (session-view.wipe-temp-buffers curr)
    (remove-session! deps session)
    (wrapup curr)
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
  (let [{: router : refresh} deps
        update-info-window (. refresh :info!)
        session (session-by-prompt (. router :active-by-prompt) prompt-buf)]
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

(fn inserted-row
  [prev-row next-row text rel-index]
  (let [base (or prev-row next-row {})
        out (vim.deepcopy base)
        prev-lnum (or (and prev-row (. prev-row :lnum)) (. base :lnum) 1)
        next-lnum (or (and next-row (. next-row :lnum)) (. base :lnum) (+ prev-lnum 1))
        lnum (if prev-row
                 (+ prev-lnum rel-index)
                 (math.max 1 (- next-lnum 1)))]
    (set (. out :lnum) (math.max 1 (or lnum 1)))
    (set (. out :text) (or text ""))
    (set (. out :line) (or text ""))
    out))

(fn projected-rows-from-edits
  [baseline-rows baseline-lines current-lines]
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
                (table.insert out (inserted-row prev-row next-row txt k))))))
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
        rows (projected-rows-from-edits baseline-rows baseline-lines current-lines)
        refs []
        content []
        idxs []]
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
       (> (. row :lnum) 0)
       (~= (. row :kind) "file-entry")))

(fn append-op!
  [ops path op]
  (let [per-file (or (. ops path) [])]
    (table.insert per-file op)
    (set (. ops path) per-file)))

(fn collect-file-ops
  [session]
  (let [meta session.meta
        buf meta.buf.buffer
        baseline-lines (or session.edit-baseline-lines (vim.api.nvim_buf_get_lines buf 0 -1 false))
        baseline-rows (or session.edit-baseline-rows [])
        current-lines (vim.api.nvim_buf_get_lines buf 0 -1 false)
        hunks (diff-hunks baseline-lines current-lines)
        ops {}]
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
                    (append-op! ops (. row :path) {:kind :replace :lnum (. row :lnum) :text text}))))
              (when (> a-count b-count)
                (for [i (+ common 1) a-count]
                  (let [row (. old-rows i)]
                    (when (valid-row? row)
                      (append-op! ops (. row :path) {:kind :delete :lnum (. row :lnum)})))))
              (when (> b-count a-count)
                (let [extra (slice-lines new-lines (+ common 1) (- b-count common))
                      anchor-row (. old-rows a-count)]
                  (when (and (valid-row? anchor-row) (> (# extra) 0))
                    (append-op! ops (. anchor-row :path)
                      {:kind :insert-after :lnum (. anchor-row :lnum) :lines extra}))))
              )
            (let [extra (slice-lines new-lines 1 b-count)
                  ;; For pure insertion hunks (a_count == 0), vim.diff's a_start
                  ;; points at the next old row. So insertion is between old
                  ;; rows [a_start-1] and [a_start].
                  prev-row (. baseline-rows (- a-start 1))
                  next-row (. baseline-rows a-start)]
              (when (> (# extra) 0)
                (if (valid-row? prev-row)
                    (append-op! ops (. prev-row :path)
                      {:kind :insert-after :lnum (. prev-row :lnum) :lines extra})
                    (when (valid-row? next-row)
                      (append-op! ops (. next-row :path)
                        {:kind :insert-before :lnum (. next-row :lnum) :lines extra}))))))))
    {:ops ops :current-lines current-lines}))

(fn apply-file-ops!
  [ops]
  (let [post-lines {}
        touched-paths {}]
    (var total 0)
    (var any-write false)
    (fn apply-op-to-loaded-buffer!
      [buf op delta]
      (if (= (. op :kind) :replace)
          (let [lnum (+ (. op :lnum) delta)
                line-count (vim.api.nvim_buf_line_count buf)]
            (if (and (>= lnum 1) (<= lnum line-count))
                (let [old (or (. (vim.api.nvim_buf_get_lines buf (- lnum 1) lnum false) 1) "")
                      new (or (. op :text) "")]
                  (if (~= old new)
                      (do
                        (vim.api.nvim_buf_set_lines buf (- lnum 1) lnum false [new])
                        [delta 1])
                      [delta 0]))
                [delta 0]))
          (= (. op :kind) :delete)
          (let [lnum (+ (. op :lnum) delta)
                line-count (vim.api.nvim_buf_line_count buf)]
            (if (and (>= lnum 1) (<= lnum line-count))
                (do
                  (vim.api.nvim_buf_set_lines buf (- lnum 1) lnum false [])
                  [(- delta 1) 1])
                [delta 0]))
          (= (. op :kind) :insert-before)
          (let [ins (or (. op :lines) [])
                lnum (+ (. op :lnum) delta)
                pos (math.max 1 (math.min (+ (vim.api.nvim_buf_line_count buf) 1) lnum))]
            (if (> (# ins) 0)
                (do
                  (vim.api.nvim_buf_set_lines buf (- pos 1) (- pos 1) false ins)
                  [(+ delta (# ins)) (# ins)])
                [delta 0]))
          (let [ins (or (. op :lines) [])
                lnum (+ (. op :lnum) delta)
                pos (math.max 0 (math.min (vim.api.nvim_buf_line_count buf) lnum))]
            (if (> (# ins) 0)
                (do
                  (vim.api.nvim_buf_set_lines buf pos pos false ins)
                  [(+ delta (# ins)) (# ins)])
                [delta 0]))))
    (fn apply-op-to-lines!
      [lines op delta]
      (if (= (. op :kind) :replace)
          (let [lnum (+ (. op :lnum) delta)]
            (if (and (>= lnum 1) (<= lnum (# lines))
                     (~= (. lines lnum) (. op :text)))
                (do
                  (set (. lines lnum) (. op :text))
                  [delta 1])
                [delta 0]))
          (= (. op :kind) :delete)
          (let [lnum (+ (. op :lnum) delta)]
            (if (and (>= lnum 1) (<= lnum (# lines)))
                (do
                  (table.remove lines lnum)
                  [(- delta 1) 1])
                [delta 0]))
          (= (. op :kind) :insert-before)
          (let [ins (or (. op :lines) [])
                lnum (+ (. op :lnum) delta)
                pos (math.max 1 (math.min (+ (# lines) 1) lnum))]
            (if (> (# ins) 0)
                (do
                  (for [i 1 (# ins)]
                    (table.insert lines (+ pos i -1) (. ins i)))
                  [(+ delta (# ins)) (# ins)])
                [delta 0]))
          (let [ins (or (. op :lines) [])
                lnum (+ (. op :lnum) delta)
                pos (math.max 0 (math.min (# lines) lnum))]
            (if (> (# ins) 0)
                (do
                  (for [i 1 (# ins)]
                    (table.insert lines (+ pos i) (. ins i)))
                  [(+ delta (# ins)) (# ins)])
                [delta 0]))))
    (each [path per-file (pairs (or ops {}))]
      (let [bufnr (vim.fn.bufnr path)]
        (if (and bufnr (> bufnr 0) (vim.api.nvim_buf_is_loaded bufnr))
            (let [bo (. vim.bo bufnr)
                  old-mod (. bo :modifiable)
                  old-ro (. bo :readonly)]
              ;; Apply changes directly to loaded file buffer so undo history in
              ;; that real buffer reflects propagated edits accurately.
              (set (. bo :modifiable) true)
              (set (. bo :readonly) false)
              (var delta 0)
              (var changed 0)
              (each [_ op (ipairs (or per-file []))]
                (let [[next-delta bump] (apply-op-to-loaded-buffer! bufnr op delta)]
                  (set delta next-delta)
                  (set changed (+ changed bump))))
              (set (. bo :modifiable) old-mod)
              (set (. bo :readonly) old-ro)
              (when (> changed 0)
                (let [[ok-write] [(pcall
                                   vim.api.nvim_buf_call
                                   bufnr
                                   (fn []
                                     (vim.cmd "silent keepalt noautocmd write")))]]
                  (if ok-write
                      (do
                        (set any-write true)
                        (set total (+ total changed))
                        (set (. touched-paths path) true)
                        (set (. post-lines path)
                             (vim.api.nvim_buf_get_lines bufnr 0 -1 false)))
                      (let [[ok-read lines0] [(pcall vim.api.nvim_buf_get_lines bufnr 0 -1 false)]]
                        (when (and ok-read (= (type lines0) "table"))
                          (let [[ok-fallback] [(pcall vim.fn.writefile lines0 path)]]
                            (when ok-fallback
                              (set any-write true)
                              (set total (+ total changed))
                              (set (. touched-paths path) true)
                              (set (. post-lines path) lines0)))))))))
            (let [[ok-read lines0] [(pcall vim.fn.readfile path)]]
              (when (and ok-read (= (type lines0) "table"))
                (let [lines (vim.deepcopy lines0)]
                  (var delta 0)
                  (var changed 0)
                  (each [_ op (ipairs (or per-file []))]
                    (let [[next-delta bump] (apply-op-to-lines! lines op delta)]
                      (set delta next-delta)
                      (set changed (+ changed bump))))
                  (when (> changed 0)
                    (let [[ok-write] [(pcall vim.fn.writefile lines path)]]
                      (when ok-write
                        (set any-write true)
                        (set total (+ total changed))
                        (set (. touched-paths path) true)
                        (set (. post-lines path) lines))))))))))
    {:wrote any-write :changed total :post-lines post-lines :paths touched-paths}))

(fn update-session-refs-after-ops!
  [session ops post-lines]
  (let [meta session.meta
        refs (or meta.buf.source-refs [])
        content (or meta.buf.content [])]
    (each [src-idx ref (ipairs refs)]
      (when (and ref (= (type ref.path) "string") (~= ref.path ""))
        (let [path ref.path
              per-file (. ops path)]
          (when per-file
            (let [lnum0 (if (and (= (type ref.lnum) "number") (> ref.lnum 0)) ref.lnum 1)]
              (var lnum lnum0)
              (each [_ op (ipairs per-file)]
                (if (= (. op :kind) :insert-before)
                    (when (>= lnum (. op :lnum))
                      (set lnum (+ lnum (# (or (. op :lines) [])))))
                    (= (. op :kind) :insert-after)
                    (when (> lnum (. op :lnum))
                      (set lnum (+ lnum (# (or (. op :lines) [])))))
                    (= (. op :kind) :delete)
                    (when (> lnum (. op :lnum))
                      (set lnum (- lnum 1)))
                    nil))
              (when (< lnum 1)
                (set lnum 1))
              (set (. ref :lnum) lnum)
              (let [lines (. post-lines path)
                    line (or (and lines
                                  (>= lnum 1)
                                  (<= lnum (# lines))
                                  (. lines lnum))
                             ref.line
                             "")]
                (set (. ref :line) line)
                (when src-idx
                  (set (. content src-idx) line))))))))
    (set meta.buf.content content)))

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
  (let [{: router : mods : refresh : windows} deps
        session (session-by-prompt (. router :active-by-prompt) prompt-buf)
        sign-mod (. mods :sign)
        update-info-window (. refresh :info!)
        preview-window (. windows :preview)
        context-window (. windows :context)]
    (when session
      (let [collected (collect-file-ops session)
            ops (. collected :ops)
            result (apply-file-ops! ops)
            buf session.meta.buf.buffer]
        (update-session-refs-after-ops! session ops (. result :post-lines))
        (invalidate-caches-for-paths! deps session (. result :paths))
        (when (> result.changed 0)
          (pcall session.meta.on-update 0))
        (pcall vim.api.nvim_set_option_value "modified" false {:buf buf})
        (pcall vim.api.nvim_buf_set_var buf "meta_manual_edit_active" false)
        (pcall session.meta.refresh_statusline)
        (pcall update-info-window session true)
        (pcall preview-window.maybe-update-for-selection! session)
        (when (and context-window context-window.update!)
          (pcall context-window.update! session))
        (when sign-mod
          (pcall sign-mod.capture-baseline! session)
          (pcall sign-mod.refresh-change-signs! session))
        (vim.notify
          (if (> result.changed 0)
              (.. "metabuffer: wrote " (tostring result.changed) " change(s)")
              "metabuffer: no changes")
          vim.log.levels.INFO)))))

(fn M.enter-edit-mode!
  [deps prompt-buf]
  (let [{: router : mods : history : refresh} deps
        session (session-by-prompt (. router :active-by-prompt) prompt-buf)
        router-util-mod (. mods :router-util)
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
      ;; Enter editing context in Normal mode; prompt starts in Insert mode.
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
               (or force (not session.results-edit-mode))
               session.meta
               session.meta.buf
               (= (vim.api.nvim_get_current_buf) session.meta.buf.buffer))
      (set session.meta.win.window (vim.api.nvim_get_current_win))
      (restore-session-ui!
        deps
        session
        {:preserve-focus (not force)}))))

M
