(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local meta_mod (require :metabuffer.meta))
(local prompt_window_mod (require :metabuffer.window.prompt))
(local meta_window_mod (require :metabuffer.window.metawindow))
(local floating_window_mod (require :metabuffer.window.floating))
(local preview_window_mod (require :metabuffer.window.preview))
(local info_window_mod (require :metabuffer.window.info))
(local history_browser_window_mod (require :metabuffer.window.history_browser))
(local project_source_mod (require :metabuffer.project.source))
(local base_buffer (require :metabuffer.buffer.base))
(local session_view (require :metabuffer.session.view))
(local debug (require :metabuffer.debug))
(local config (require :metabuffer.config))
(local query_mod (require :metabuffer.query))
(local history_store (require :metabuffer.history_store))
(local prompt_hooks_mod (require :metabuffer.prompt.hooks))
(local router_util_mod (require :metabuffer.router.util))
(local router_prompt_mod (require :metabuffer.router.prompt))
(local router_query_flow_mod (require :metabuffer.router.query_flow))

(local M {})

(fn sync-prompt-buffer-name!
  [session]
  (when (and session
             session.prompt-buf
             (vim.api.nvim_buf_is_valid session.prompt-buf)
             session.meta
             session.meta.buf
             (= (type session.meta.buf.name) "string")
             (~= session.meta.buf.name ""))
    (pcall
      vim.api.nvim_buf_set_name
      session.prompt-buf
      (.. session.meta.buf.name " [Prompt]"))))

(set M.instances {})
(set M.active-by-source {})
(set M.active-by-prompt {})
(var update-info-window nil)
(var apply-prompt-lines nil)
(var preview-window nil)
(var info-window nil)
(var history-browser-window nil)
(var query-flow-deps nil)
(fn M.configure
  [opts]
  "Public API: M.configure."
  (config.apply-router-defaults M vim opts))

(M.configure nil)
(local push-history! (fn [text]
                       (history_store.push! text M.history-max)))

(fn debug-log
  [msg]
  (debug.log "router" msg))

(local prompt-scheduler-ctx
  {:active-by-prompt M.active-by-prompt
   :apply-prompt-lines (fn [session]
                         (apply-prompt-lines session))
   :prompt-update-delay-ms (fn [session]
                             (router_prompt_mod.prompt-update-delay-ms
                               M
                               query_mod
                               router_util_mod.prompt-lines
                               session))
   :now-ms router_prompt_mod.now-ms
   :cancel-prompt-update! router_prompt_mod.cancel-prompt-update!})

(set preview-window
  (preview_window_mod.new
    {:floating-window-mod floating_window_mod
     :selected-ref router_util_mod.selected-ref
     :read-file-lines-cached (fn [path]
                               (router_util_mod.read-file-lines-cached M path))
     :is-active-session (fn [session]
                          (and session
                               session.prompt-buf
                               (= (. M.active-by-prompt session.prompt-buf) session)))
     :debug-log debug-log
     :source-switch-debounce-ms M.preview-source-switch-debounce-ms}))

(set info-window
  (let [candidate
        (info_window_mod.new
          {:floating-window-mod floating_window_mod
           :info-min-width M.info-min-width
           :info-max-width M.info-max-width
           :info-max-lines M.info-max-lines
           :info-height router_util_mod.info-height
           :debug-log debug-log
           :read-file-lines-cached (fn [path]
                                     (router_util_mod.read-file-lines-cached M path))
           :update-preview (fn [session]
                             (preview-window.maybe-update-for-selection! session))})]
    (if (= (type candidate) "function")
        {:update! candidate
         :close-window! (fn [_] nil)}
        candidate)))

(set history-browser-window
  (history_browser_window_mod.new
    {:floating-window-mod floating_window_mod}))

(set update-info-window
  (fn [session refresh-lines]
    (when (and info-window info-window.update!)
      (info-window.update! session refresh-lines))))

(local project-source
  (project_source_mod.new
    {:settings M
     :truthy? query_mod.truthy?
     :selected-ref router_util_mod.selected-ref
     :canonical-path router_util_mod.canonical-path
     :current-buffer-path router_util_mod.current-buffer-path
     :path-under-root? router_util_mod.path-under-root?
     :allow-project-path? (fn [rel include-hidden include-deps]
                            (router_util_mod.allow-project-path? M rel include-hidden include-deps))
     :project-file-list (fn [root include-hidden include-ignored include-deps]
                          (router_util_mod.project-file-list M root include-hidden include-ignored include-deps))
     :read-file-lines-cached (fn [path]
                               (router_util_mod.read-file-lines-cached M path))
     :session-active? (fn [session]
                        (router_util_mod.session-active? M.active-by-prompt session))
     :lazy-streaming-allowed? (fn [session]
                                (router_util_mod.lazy-streaming-allowed? M query_mod session))
     :on-prompt-changed (fn [prompt-buf force]
                          (M.on-prompt-changed prompt-buf force))
     :prompt-has-active-query? (fn [session]
                                 (router_prompt_mod.prompt-has-active-query?
                                   query_mod
                                   router_util_mod.prompt-lines
                                   session))
     :now-ms router_prompt_mod.now-ms
     :prompt-update-delay-ms (fn [session]
                               (router_prompt_mod.prompt-update-delay-ms
                                 M
                                 query_mod
                                 router_util_mod.prompt-lines
                                 session))
     :schedule-prompt-update! (fn [session wait-ms]
                                (router_prompt_mod.schedule-prompt-update!
                                  prompt-scheduler-ctx
                                  session
                                  wait-ms))
     :restore-meta-view! session_view.restore-meta-view!
     :update-info-window update-info-window}))

(fn merge-history-into-session!
  [session]
  (let [local0 (or session.history-cache [])
        merged (vim.deepcopy local0)
        incoming (history_store.list)
        seen {}]
    (each [_ item (ipairs merged)]
      (when (= (type item) "string")
        (set (. seen item) true)))
    (each [_ item (ipairs incoming)]
      (when (and (= (type item) "string")
                 (~= (vim.trim item) "")
                 (not (. seen item)))
        (table.insert merged item)
        (set (. seen item) true)))
    (while (> (# merged) M.history-max)
      (table.remove merged 1))
    (set session.history-cache merged)))

(fn save-current-prompt-tag!
  [session tag prompt]
  (when (and (= (type tag) "string")
             (~= (vim.trim tag) "")
             (= (type prompt) "string")
             (~= (vim.trim prompt) ""))
    (history_store.save-tag! tag prompt)))

(fn restore-saved-prompt-tag!
  [session tag]
  (when (and session
             (= (type tag) "string")
             (~= (vim.trim tag) ""))
    (when-let [saved (history_store.saved-entry tag)]
      (router_util_mod.set-prompt-text! session saved)
      true)))

(fn history-browser-filter
  [session]
  (vim.trim (or (router_util_mod.prompt-text session) "")))

(fn history-browser-items
  [session]
  (let [mode (or session.history-browser-mode "history")
        filter0 (string.lower (history-browser-filter session))
        out []]
    (if (= mode "saved")
        (each [_ item (ipairs (history_store.saved-items))]
          (let [tag (or (. item :tag) "")
                prompt (or (. item :prompt) "")
                hay (string.lower (.. tag " " prompt))]
            (when (or (= filter0 "")
                      (not (not (string.find hay filter0 1 true))))
              (table.insert out {:label (.. "##" tag "  " prompt)
                                 :prompt prompt
                                 :tag tag}))))
        (let [h (or session.history-cache (history_store.list))]
          (for [i (# h) 1 -1]
            (let [entry (or (. h i) "")
                  hay (string.lower entry)]
              (when (or (= filter0 "")
                        (not (not (string.find hay filter0 1 true))))
                (table.insert out {:label entry :prompt entry}))))))
    out))

(fn refresh-history-browser!
  [session]
  (when (and session history-browser-window session.history-browser-active)
    (set session.history-browser-filter (history-browser-filter session))
    (history-browser-window.refresh! session (history-browser-items session))))

(fn close-history-browser!
  [session]
  (when history-browser-window
    (history-browser-window.close! session)))

(fn open-history-browser!
  [session mode]
  (when history-browser-window
    (history-browser-window.open! session (or mode "history"))
    (refresh-history-browser! session)))

(fn apply-history-browser-selection!
  [session]
  (when (and history-browser-window session.history-browser-active)
    (when-let [selected (history-browser-window.selected! session)]
      (when-let [prompt (. selected :prompt)]
        (router_util_mod.set-prompt-text! session prompt)))
    (close-history-browser! session)))

(set query-flow-deps
  {:active-by-prompt M.active-by-prompt
   :query-mod query_mod
   :project-source project-source
   :update-info-window update-info-window
   :settings M
   :prompt-scheduler-ctx prompt-scheduler-ctx
   :merge-history-into-session! merge-history-into-session!
   :save-current-prompt-tag! save-current-prompt-tag!
   :restore-saved-prompt-tag! restore-saved-prompt-tag!
   :open-saved-browser! (fn [session]
                          (open-history-browser! session "saved"))
   :apply-prompt-lines (fn [session]
                         (apply-prompt-lines session))})

(fn M._store_vars
  [meta]
  "Public API: M._store_vars."
  (set vim.b._meta_context (meta.store))
  (set vim.b._meta_indexes meta.buf.indices)
  (set vim.b._meta_updates meta.updates)
  (set vim.b._meta_source_bufnr meta.buf.model)
  meta)

(fn M._wrapup
  [meta]
  "Public API: M._wrapup."
  (vim.cmd "redraw|redrawstatus")
  (M._store_vars meta))

(fn project-setting-token
  [name enabled]
  (.. "#" (if enabled "+" "-") name))

(fn history-entry-query
  [entry]
  (let [parsed (query_mod.parse-query-text (or entry ""))]
    (or (. parsed :query) "")))

(fn history-entry-token
  [entry]
  (let [parts (vim.split (history-entry-query entry) "%s+" {:trimempty true})]
    (if (> (# parts) 0)
        (. parts (# parts))
        "")))

(fn history-entry-tail
  [entry]
  (let [parts (vim.split (history-entry-query entry) "%s+" {:trimempty true})]
    (if (> (# parts) 1)
        (table.concat (vim.list_slice parts 2) " ")
        "")))

(fn history-entry-with-settings
  [session prompt]
  (let [query-text (or prompt "")
        prefix (if (and session session.project-mode)
                   (table.concat
                     [(project-setting-token "hidden" session.effective-include-hidden)
                      (project-setting-token "ignored" session.effective-include-ignored)
                      (project-setting-token "deps" session.effective-include-deps)
                      (project-setting-token "file" session.effective-include-files)
                      (project-setting-token "prefilter" session.prefilter-mode)
                      (project-setting-token "lazy" session.lazy-mode)]
                     " ")
                   "")]
    (if (= prefix "")
        query-text
        (if (= query-text "")
            prefix
            (.. prefix " " query-text)))))

(fn push-history-entry!
  [session text]
  (push-history! (history-entry-with-settings session text)))

(fn remove-session
  [session]
  (when session
    (push-history-entry!
      session
      (or session.last-prompt-text
          (if (and session.prompt-buf (vim.api.nvim_buf_is_valid session.prompt-buf))
              (router_util_mod.prompt-text session)
              "")))
    (router_util_mod.persist-prompt-height! session)
    (when session.augroup
      (pcall vim.api.nvim_del_augroup_by_id session.augroup))
    (when (and session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
      (pcall vim.api.nvim_win_close session.prompt-win true))
    (when (and session.prompt-buf (vim.api.nvim_buf_is_valid session.prompt-buf))
      (pcall vim.api.nvim_buf_delete session.prompt-buf {:force true}))
    (info-window.close-window! session)
    (preview-window.close-window! session)
    (close-history-browser! session)
    (when session.source-buf
      (set (. M.active-by-source session.source-buf) nil))
    (when session.prompt-buf
      (set (. M.active-by-prompt session.prompt-buf) nil))))

(set apply-prompt-lines
  (fn [session]
    (router_query_flow_mod.apply-prompt-lines! query-flow-deps session)))

(fn M.on-prompt-changed
  [prompt-buf force event-tick]
  "Entry point for prompt edits; keeps typing fast by deferring matcher work."
  (router_query_flow_mod.on-prompt-changed!
    query-flow-deps
    prompt-buf
    force
    event-tick)
  (let [session (. M.active-by-prompt prompt-buf)]
    (when (and session session.history-browser-active)
      (refresh-history-browser! session))))

(fn M.accept
  [prompt-buf]
  "Accept prompt or apply selected history-browser item."
  (let [session (. M.active-by-prompt prompt-buf)]
    (if (and session session.history-browser-active)
        (apply-history-browser-selection! session)
        (M.finish "accept" prompt-buf))))

(fn M.cancel
  [prompt-buf]
  "Close history-browser first, otherwise cancel Meta prompt."
  (let [session (. M.active-by-prompt prompt-buf)]
    (if (and session session.history-browser-active)
        (close-history-browser! session)
        (M.finish "cancel" prompt-buf))))

(fn finish-accept
  [session]
  (let [curr session.meta]
    (set session.last-prompt-text (router_util_mod.prompt-text session))
    (push-history-entry! session session.last-prompt-text)
    (apply-prompt-lines session)
    (when (and (vim.api.nvim_win_is_valid session.origin-win)
               (vim.api.nvim_buf_is_valid session.origin-buf))
      (pcall vim.api.nvim_set_current_win session.origin-win)
      (pcall vim.api.nvim_win_set_buf session.origin-win session.origin-buf))
    (if session.project-mode
        (let [ref (router_util_mod.selected-ref curr)]
          (when (and ref ref.path)
            (vim.cmd (.. "edit " (vim.fn.fnameescape ref.path)))
            (vim.api.nvim_win_set_cursor 0 [(math.max 1 (or ref.open-lnum ref.lnum 1)) 0])))
        (do
          (base_buffer.switch-buf curr.buf.model)
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
    (vim.schedule
      (fn []
        (when (= (. M.active-by-prompt session.prompt-buf) session)
          (router_prompt_mod.begin-session-close!
            session
            router_prompt_mod.cancel-prompt-update!)
          (pcall vim.cmd "stopinsert")
          (let [matcher (curr.matcher)]
            (when matcher
              (pcall matcher.remove-highlight matcher)))
          (pcall vim.cmd (.. "sign unplace * buffer=" curr.buf.buffer))
          (session_view.wipe-temp-buffers curr)
          (remove-session session)
          (M._wrapup curr))))
    curr))

(fn finish-cancel
  [session]
  (let [curr session.meta]
    (router_prompt_mod.begin-session-close!
      session
      router_prompt_mod.cancel-prompt-update!)
    (set session.last-prompt-text (router_util_mod.prompt-text session))
    (push-history-entry! session session.last-prompt-text)
    (pcall vim.cmd "stopinsert")
    (let [matcher (curr.matcher)]
      (when matcher
        (pcall matcher.remove-highlight matcher)))
    (pcall vim.cmd (.. "sign unplace * buffer=" curr.buf.buffer))
    (vim.cmd "silent! nohlsearch")
    (when (and (vim.api.nvim_win_is_valid session.origin-win)
               (vim.api.nvim_buf_is_valid session.origin-buf))
      (pcall vim.api.nvim_set_current_win session.origin-win)
      (pcall vim.api.nvim_win_set_buf session.origin-win session.origin-buf))
    (base_buffer.switch-buf curr.buf.model)
    (session_view.wipe-temp-buffers curr)
    (remove-session session)
    (M._wrapup curr)
    curr))

(fn M.finish
  [kind prompt-buf]
  "Public API: M.finish."
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (if (= kind "accept")
          (finish-accept session)
          (finish-cancel session)))))

(fn M.move-selection
  [prompt-buf delta]
  "Public API: M.move-selection."
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (let [runner (fn []
                     (let [meta session.meta
                           max (# meta.buf.indices)]
                       (when (> max 0)
                         (set meta.selected_index (math.max 0 (math.min (+ meta.selected_index delta) (- max 1))))
                         (let [row (+ meta.selected_index 1)]
                           (when (vim.api.nvim_win_is_valid meta.win.window)
                             (pcall vim.api.nvim_win_set_cursor meta.win.window [row 0])))
                         (pcall meta.refresh_statusline)
                         (pcall update-info-window session false))))
            mode (. (vim.api.nvim_get_mode) :mode)]
        (if (and (= (type mode) "string") (vim.startswith mode "i"))
            (vim.schedule runner)
            (runner))))))

(fn can-refresh-source-syntax?
  [session]
  (let [buf (and session session.meta session.meta.buf)]
    (and session
         session.project-mode
         buf
         buf.show-source-separators
         (= buf.syntax-type "buffer"))))

(fn schedule-source-syntax-refresh!
  [session]
  (when (can-refresh-source-syntax? session)
    (set session.syntax-refresh-dirty true)
    (when-not session.syntax-refresh-pending
      (set session.syntax-refresh-pending true)
      (vim.defer_fn
        (fn []
          (set session.syntax-refresh-pending false)
          (when (and session
                     session.prompt-buf
                     (= (. M.active-by-prompt session.prompt-buf) session))
            (when session.syntax-refresh-dirty
              (set session.syntax-refresh-dirty false)
              (pcall session.meta.buf.apply-source-syntax-regions))
            ;; If additional scroll events arrived while refreshing, ensure we
            ;; run one trailing update.
            (when session.syntax-refresh-dirty
              (schedule-source-syntax-refresh! session))))
        (or M.source-syntax-refresh-debounce-ms 80)))))

(fn M.scroll-main
  [prompt-buf action]
  "Public API: M.scroll-main."
  (let [session (. M.active-by-prompt prompt-buf)]
    (when (and session (vim.api.nvim_win_is_valid session.meta.win.window))
      (let [runner (fn []
                     (vim.api.nvim_win_call session.meta.win.window
                       (fn []
                         (let [line-count (vim.api.nvim_buf_line_count session.meta.buf.buffer)
                               win-height (math.max 1 (vim.api.nvim_win_get_height session.meta.win.window))
                               half-step (math.max 1 (math.floor (/ win-height 2)))
                               page-step (math.max 1 (- win-height 2))
                               step (if (or (= action "line-down") (= action "line-up"))
                                        1
                                        (or (= action "half-down") (= action "half-up"))
                                        half-step
                                        page-step)
                               dir (if (or (= action "line-down") (= action "half-down") (= action "page-down")) 1 -1)
                               max-top (math.max 1 (+ (- line-count win-height) 1))
                               view (vim.fn.winsaveview)
                               old-top (. view :topline)
                               old-lnum (. view :lnum)
                               old-col (or (. view :col) 0)
                               row-off (math.max 0 (- old-lnum old-top))
                               new-top (math.max 1 (math.min (+ old-top (* dir step)) max-top))
                               new-lnum (math.max 1 (math.min (+ new-top row-off) line-count))]
                           (set (. view :topline) new-top)
                           (set (. view :lnum) new-lnum)
                           (set (. view :col) old-col)
                           (vim.fn.winrestview view))))
                     (session_view.sync-selected-from-main-cursor! session)
                     (pcall session.meta.refresh_statusline)
                     (pcall update-info-window session false))
            mode (. (vim.api.nvim_get_mode) :mode)]
        (if (and (= (type mode) "string") (vim.startswith mode "i"))
            (vim.schedule runner)
            (runner))))))

(fn maybe-sync-from-main!
  [session force-refresh]
  (session_view.maybe-sync-from-main!
    session
    force-refresh
    {:active-by-prompt M.active-by-prompt
     :schedule-source-syntax-refresh! schedule-source-syntax-refresh!
     :update-info-window update-info-window}))

(fn schedule-scroll-sync!
  [session]
  (session_view.schedule-scroll-sync!
    session
    {:scroll-sync-debounce-ms M.scroll-sync-debounce-ms
     :maybe-sync-from-main! maybe-sync-from-main!}))

(fn M.history-or-move
  [prompt-buf delta]
  "Public API: M.history-or-move."
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (if session.history-browser-active
          (history-browser-window.move! session delta)
          (let [txt (router_util_mod.prompt-text session)
                can-history (or (= txt "")
                                (= txt session.initial-prompt-text)
                                (= txt session.last-history-text)
                                (= txt (history-entry-query session.last-history-text)))]
            (if can-history
                (let [h (or session.history-cache (history_store.list))
                      n (# h)]
                  (when (> n 0)
                    (set session.history-index (math.max 0 (math.min (+ session.history-index delta) n)))
                    (if (= session.history-index 0)
                        (do
                          (set session.last-history-text "")
                          (router_util_mod.set-prompt-text! session session.initial-prompt-text))
                        (let [entry (. h (+ (- n session.history-index) 1))]
                          (when entry
                            (set session.last-history-text entry)
                            (router_util_mod.set-prompt-text! session entry))))))
                (M.move-selection prompt-buf delta)))))))

(fn history-latest
  [session]
  (let [h (or (and session session.history-cache) (history_store.list))
        n (# h)]
    (if (> n 0) (. h n) "")))

(fn history-latest-token
  [session]
  (history-entry-token (history-latest session)))

(fn history-latest-tail
  [session]
  (history-entry-tail (history-latest session)))

(fn M.last-prompt-entry
  [prompt-buf]
  "Return most recent prompt history entry."
  (history-latest (. M.active-by-prompt prompt-buf)))

(fn M.last-prompt-token
  [prompt-buf]
  "Return final token of most recent prompt history entry."
  (history-latest-token (. M.active-by-prompt prompt-buf)))

(fn M.last-prompt-tail
  [prompt-buf]
  "Return latest prompt entry except its first token."
  (history-latest-tail (. M.active-by-prompt prompt-buf)))

(fn M.saved-prompt-entry
  [tag]
  "Return saved prompt text by tag."
  (history_store.saved-entry tag))

(fn prompt-insert-at-cursor!
  [session text]
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
      (pcall vim.api.nvim_win_set_cursor session.prompt-win [next-row next-col]))))

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

(fn M.prompt-home
  [prompt-buf]
  "Move prompt cursor to start of current line."
  (let [session (. M.active-by-prompt prompt-buf)]
    (when (and session
               session.prompt-win
               (vim.api.nvim_win_is_valid session.prompt-win))
      (let [{: row} (prompt-row-col session)]
        (pcall vim.api.nvim_win_set_cursor session.prompt-win [row 0])))))

(fn M.prompt-end
  [prompt-buf]
  "Move prompt cursor to end of current line."
  (let [session (. M.active-by-prompt prompt-buf)]
    (when (and session
               session.prompt-buf
               session.prompt-win
               (vim.api.nvim_buf_is_valid session.prompt-buf)
               (vim.api.nvim_win_is_valid session.prompt-win))
      (let [{: row : row0} (prompt-row-col session)
            line (prompt-line-text session row0)]
        (pcall vim.api.nvim_win_set_cursor session.prompt-win [row (# line)])))))

(fn M.prompt-kill-backward
  [prompt-buf]
  "Kill from line start to cursor and store in prompt yank register."
  (let [session (. M.active-by-prompt prompt-buf)]
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

(fn M.prompt-kill-forward
  [prompt-buf]
  "Kill from cursor to end of current line and store in prompt yank register."
  (let [session (. M.active-by-prompt prompt-buf)]
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

(fn M.prompt-yank
  [prompt-buf]
  "Insert prompt yank register content at cursor."
  (let [session (. M.active-by-prompt prompt-buf)
        text (or (and session session.prompt-yank-register) "")]
    (when (~= text "")
      (prompt-insert-at-cursor! session text))))

(fn M.prompt-insert-text
  [prompt-buf text]
  "Insert arbitrary text at prompt cursor."
  (let [session (. M.active-by-prompt prompt-buf)]
    (prompt-insert-at-cursor! session text)))

(fn M.insert-last-prompt
  [prompt-buf]
  "Insert most recent prompt history entry at cursor."
  (let [session (. M.active-by-prompt prompt-buf)
        entry (history-latest session)]
    (prompt-insert-at-cursor! session entry)
    (when (and session (~= entry ""))
      (set session.last-history-text entry))))

(fn M.insert-last-token
  [prompt-buf]
  "Insert last token from most recent prompt history entry at cursor."
  (let [session (. M.active-by-prompt prompt-buf)
        token (history-latest-token session)
        entry (history-latest session)]
    (prompt-insert-at-cursor! session token)
    (when (and session (~= token ""))
      (set session.last-history-text entry))))

(fn M.insert-last-tail
  [prompt-buf]
  "Insert most recent prompt entry except first token."
  (let [session (. M.active-by-prompt prompt-buf)
        tail (history-latest-tail session)
        entry (history-latest session)]
    (prompt-insert-at-cursor! session tail)
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

(fn M.negate-current-token
  [prompt-buf]
  "Toggle ! prefix on token under cursor in prompt insert mode."
  (let [session (. M.active-by-prompt prompt-buf)]
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
            (pcall vim.api.nvim_win_set_cursor session.prompt-win
                   [row (math.max 0 (+ col (if (>= col s0) delta 0)))])))))))

(fn M.open-history-searchback
  [prompt-buf]
  "Open floating searchback browser from prompt (<C-r>)."
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (when-not session.history-cache
        (set session.history-cache (vim.deepcopy (history_store.list))))
      (open-history-browser! session "history"))))

(fn M.merge-history-cache
  [prompt-buf]
  "Merge persisted prompt history into this session's private history cache."
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (merge-history-into-session! session)
      (refresh-history-browser! session))))

(fn M.exclude-symbol-under-cursor
  [prompt-buf]
  "Append !<cword> into prompt query."
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (let [word (vim.api.nvim_win_call
                   session.meta.win.window
                   (fn [] (vim.fn.expand "<cword>")))
            token (if (and (= (type word) "string") (~= (vim.trim word) ""))
                      (.. "!" word)
                      "")]
        (when (~= token "")
          (let [current (router_util_mod.prompt-text session)
                sep (if (or (= current "")
                            (vim.endswith current " ")
                            (vim.endswith current "\n"))
                        ""
                        " ")
                next (.. current sep token)]
            (router_util_mod.set-prompt-text! session next)))))))

(fn M.insert-symbol-under-cursor
  [prompt-buf]
  "Append <cword> from main results window into prompt query."
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (let [word (vim.api.nvim_win_call
                   session.meta.win.window
                   (fn [] (vim.fn.expand "<cword>")))
            token (if (and (= (type word) "string") (~= (vim.trim word) ""))
                      word
                      "")]
        (when (~= token "")
          (let [current (router_util_mod.prompt-text session)
                sep (if (or (= current "")
                            (vim.endswith current " ")
                            (vim.endswith current "\n"))
                        ""
                        " ")
                next (.. current sep token)]
            (router_util_mod.set-prompt-text! session next)))))))

(fn M.accept-main
  [prompt-buf]
  "Accept current selection from the main results window."
  (M.accept prompt-buf))

(fn M.toggle-scan-option
  [prompt-buf which]
  "Toggle include-hidden/include-ignored/include-deps scan flags."
  (let [session (. M.active-by-prompt prompt-buf)]
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

(fn M.toggle-project-mode
  [prompt-buf]
  "Public API: M.toggle-project-mode."
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (set session.project-mode (not session.project-mode))
      (set session.meta.project-mode session.project-mode)
      (session.meta.buf.set-name (router_util_mod.meta-buffer-name session))
      (sync-prompt-buffer-name! session)
      (project-source.apply-source-set! session)
      (apply-prompt-lines session))))

(fn M.toggle-info-file-entry-view
  [prompt-buf]
  "Cycle info-window file-entry rendering mode."
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (set session.info-file-entry-view
           (if (= (or session.info-file-entry-view "meta") "content")
               "meta"
               "content"))
      (set session.info-render-sig nil)
      (pcall update-info-window session true))))

(fn register-prompt-hooks
  [session]
  (let [hooks
        (prompt_hooks_mod.new
          {:mark-prompt-buffer! router_util_mod.mark-prompt-buffer!
           :default-prompt-keymaps M.prompt-keymaps
           :default-main-keymaps M.main-keymaps
           :active-by-prompt M.active-by-prompt
           :on-prompt-changed M.on-prompt-changed
           :update-info-window update-info-window
           :maybe-sync-from-main! maybe-sync-from-main!
           :schedule-scroll-sync! schedule-scroll-sync!})]
    (hooks.register! M session)))

(fn M.start
  [query mode _meta project-mode]
  "Create a Meta session and wire prompt/result/project orchestration."
  (pcall vim.cmd "silent! nohlsearch")
  (let [start-query (or query "")
        latest-history (history-latest nil)
        expanded-query (if (= start-query "!!")
                           latest-history
                           (= start-query "!$")
                           (history-entry-token latest-history)
                           (= start-query "!^!")
                           (history-entry-tail latest-history)
                           start-query)
        parsed-query (query_mod.parse-query-text expanded-query)
        query0 (. parsed-query :query)
        start-hidden (if-some [v (. parsed-query :include-hidden)]
                             v
                             (query_mod.truthy? M.default-include-hidden))
        start-ignored (if-some [v (. parsed-query :include-ignored)]
                              v
                              (query_mod.truthy? M.default-include-ignored))
        start-deps (if-some [v (. parsed-query :include-deps)]
                           v
                           (query_mod.truthy? M.default-include-deps))
        start-files (if-some [v (. parsed-query :include-files)]
                            v
                            (query_mod.truthy? M.default-include-files))
        start-prefilter (if-some [v (. parsed-query :prefilter)]
                                v
                                (query_mod.truthy? M.project-lazy-prefilter-enabled))
        start-lazy (if-some [v (. parsed-query :lazy)]
                           v
                           (query_mod.truthy? M.project-lazy-enabled))
        query query0]
  (let [source-buf (vim.api.nvim_get_current_buf)]
    (when (. M.active-by-source source-buf)
      (remove-session (. M.active-by-source source-buf)))
    (let [origin-win (vim.api.nvim_get_current_win)
          origin-buf source-buf
          source-view (vim.fn.winsaveview)
          _ (set (. source-view :_meta_win_height) (vim.api.nvim_win_get_height origin-win))
          condition (session_view.setup-state query mode source-view)
          curr (meta_mod.new vim condition)]
    (set curr.project-mode (or project-mode false))
    (base_buffer.switch-buf curr.buf.buffer)
    (router_util_mod.ensure-source-refs! curr)
    (let [initial-lines (if (and query (~= query ""))
                            (vim.split query "\n" {:plain true})
                            [""])
          prompt-win (prompt_window_mod.new
                       vim
                       {:height (router_util_mod.prompt-height)
                        :window-local-layout M.window-local-layout
                        :origin-win origin-win})
          prompt-buf prompt-win.buffer
          session {:source-buf source-buf
                   :origin-win origin-win
                   :origin-buf origin-buf
                   :source-view source-view
                   :initial-source-line (math.max 1 (or (. source-view :lnum) (+ (or condition.selected-index 0) 1)))
                   :prompt-win prompt-win.window
                   :prompt-buf prompt-buf
                   :window-local-layout M.window-local-layout
                   :prompt-keymaps M.prompt-keymaps
                   :main-keymaps M.main-keymaps
                   :prompt-fallback-keymaps M.prompt-fallback-keymaps
                   :info-file-entry-view (or M.info-file-entry-view "meta")
                   :initial-prompt-text (table.concat initial-lines "\n")
                   :last-prompt-text (table.concat initial-lines "\n")
                   :last-history-text ""
                   :history-index 0
                   :history-cache (vim.deepcopy (history_store.list))
                   :prompt-update-pending false
                   :prompt-update-dirty false
                   :prompt-change-seq 0
                   :prompt-last-apply-ms 0
                   :prompt-last-event-text (table.concat initial-lines "\n")
                   :initial-query-active (query_mod.query-lines-has-active? (. parsed-query :lines))
                   :startup-initializing true
                   :project-mode (or project-mode false)
                   :include-hidden start-hidden
                   :include-ignored start-ignored
                   :include-deps start-deps
                   :include-files start-files
                   :effective-include-hidden start-hidden
                   :effective-include-ignored start-ignored
                   :effective-include-deps start-deps
                   :effective-include-files start-files
                   :project-bootstrap-pending false
                   :project-bootstrap-token 0
                   :project-bootstrap-delay-ms (if (query_mod.query-lines-has-active? (. parsed-query :lines))
                                                   M.project-bootstrap-delay-ms
                                                   M.project-bootstrap-idle-delay-ms)
                   :project-bootstrapped (not (or project-mode false))
                   :prefilter-mode start-prefilter
                   :lazy-mode start-lazy
                   :last-parsed-query {:lines (if (and query (~= query ""))
                                                  (vim.split query "\n" {:plain true})
                                                  [""])
                                       :include-hidden start-hidden
                                       :include-ignored start-ignored
                                       :include-deps start-deps
                                       :include-files start-files
                                       :file-lines (or (. parsed-query :file-lines) [])
                                       :prefilter start-prefilter
                                       :lazy start-lazy}
                   :file-query-lines (or (. parsed-query :file-lines) [])
                   :single-content (vim.deepcopy curr.buf.content)
                   :single-refs (vim.deepcopy (or curr.buf.source-refs []))
                   :meta curr}]
      (let [initial-query-active session.initial-query-active]
        (if session.project-mode
            (project-source.apply-minimal-source-set! session)
            (project-source.apply-source-set! session))
        (set curr.status-win (meta_window_mod.new vim prompt-win.window))
        ;; Statusline info should live in prompt window, not result split.
        (curr.win.set-statusline "")
        ;; Initialize/render after prompt split exists so we avoid an extra
        ;; post-split view correction pass that can visually "flash" scroll.
        (curr.on-init)
        (sync-prompt-buffer-name! session)
        ;; Ensure initial selection/view is anchored before attaching prompt
        ;; hooks that may sync from main-window cursor events.
        (when session.project-mode
          (session_view.restore-meta-view! curr session.source-view))
        (vim.api.nvim_buf_set_lines prompt-buf 0 -1 false initial-lines)
        (router_util_mod.mark-prompt-buffer! prompt-buf)
        (register-prompt-hooks session)
        (set (. M.active-by-source source-buf) session)
        (set (. M.active-by-prompt prompt-buf) session)
        (when-not (and session.project-mode (not initial-query-active))
          (apply-prompt-lines session))
        (vim.api.nvim_set_current_win prompt-win.window)
        (let [row (math.max 1 (# initial-lines))
              line (or (. initial-lines row) "")
              col (# line)]
          (pcall vim.api.nvim_win_set_cursor prompt-win.window [row col]))
        (vim.cmd "startinsert")
        (vim.schedule
          (fn []
            (set session.startup-initializing false)
            (when (and session.project-mode (not session.project-bootstrapped))
              ;; Start project lazy/eager expansion as soon as UI is ready,
              ;; independent of prompt input.
              (project-source.schedule-project-bootstrap! session 0))))
        (when (and session.project-mode (not initial-query-active))
          ;; Keep startup critical path lean; refresh auxiliary UI right after.
          (vim.schedule
            (fn []
              (when (= (. M.active-by-prompt session.prompt-buf) session)
                (pcall curr.refresh_statusline)
                (pcall update-info-window session)))))
        (set (. M.instances source-buf) curr)
        curr))))))

(fn M.sync
  [meta query]
  "Public API: M.sync."
  (when-not meta
    (vim.notify "No Meta instance" vim.log.levels.WARN))
  (when meta
    (meta.set-query-lines (if (and query (~= query "")) [query] []))
    (meta.on-update 0)
    (M._store_vars meta)
    meta))

(fn M.push
  [meta]
  "Public API: M.push."
  (when-not meta
    (vim.notify "No Meta instance" vim.log.levels.WARN))
  (when meta
    (let [lines (vim.api.nvim_buf_get_lines meta.buf.buffer 0 -1 false)]
      (meta.buf.push-visible-lines lines))))

(fn M.entry_start
  [query _bang]
  "Public API: M.entry_start."
  (M.start query "start" nil _bang))

(fn M.entry_resume
  [query]
  "Public API: M.entry_resume."
  (M.start query "resume" nil))

(fn M.entry_sync
  [query]
  "Public API: M.entry_sync."
  (let [key (vim.api.nvim_get_current_buf)]
    (M.sync (. M.instances key) query)))

(fn M.entry_push
  []
  "Public API: M.entry_push."
  (let [key (vim.api.nvim_get_current_buf)]
    (M.push (. M.instances key))))

(fn M.entry_cursor_word
  [resume]
  "Public API: M.entry_cursor_word."
  (let [w (vim.fn.expand "<cword>")]
    (if resume
        (M.entry_resume w)
        (M.entry_start w false))))

M
