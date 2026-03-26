(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local M {})
(local source-mod (require :metabuffer.source))
(local statusline-mod (require :metabuffer.window.statusline))
(local util (require :metabuffer.util))
(local base-window-mod (require :metabuffer.window.base))
(local router-util-mod (require :metabuffer.router.util))
(local events (require :metabuffer.events))
(local metabuffer-winhighlight (. base-window-mod :metabuffer-winhighlight))

(fn preview-winhighlight
  []
  (.. (metabuffer-winhighlight)
      ",StatusLine:MetaPreviewStatusline,StatusLineNC:MetaPreviewStatusline"))

(fn trim-or-pad-lines
  [lines target]
  (let [out []]
    (each [_ line (ipairs (or lines []))]
      (when (< (# out) target)
        (table.insert out (or line ""))))
    (while (< (# out) target)
      (table.insert out ""))
    out))

(fn preview-statusline-text-for-path
  [path]
  (statusline-mod.render-path path {:default-text "Preview"
                                    :base-group "MetaPreviewStatusline"
                                    :left-pad "   "
                                    :seg-prefix "MetaPreviewStatuslinePathSeg"
                                    :sep-group "MetaPreviewStatuslinePathSep"
                                    :file-group "MetaPreviewStatuslinePathFile"}))

(fn apply-ft-buffer-vars!
  [buf ft]
  (when (and buf (vim.api.nvim_buf_is_valid buf) (= ft "fennel"))
    (pcall vim.api.nvim_buf_set_var buf "fennel_lua_version" "5.1")
    (pcall vim.api.nvim_buf_set_var buf "fennel_use_luajit" (if _G.jit 1 0))))

(fn set-window-options!
  [win opts]
  (each [name value (pairs (or opts {}))]
    (pcall vim.api.nvim_set_option_value name value {:win win})))

(fn set-buffer-options!
  [buf opts]
  (each [name value (pairs (or opts {}))]
    (set (. vim.bo buf name) value)))

(fn delete-window-match!
  [win id]
  (when (and id win (vim.api.nvim_win_is_valid win))
    (or (pcall vim.fn.matchdelete id win)
        (pcall vim.api.nvim_win_call win (fn [] (vim.fn.matchdelete id))))))

(fn with-file-messages-suppressed
  [f]
  "Run preview buffer attachment without file-read hit-enter messages."
  (let [prev vim.o.shortmess
        next (if (string.find prev "F" 1 true) prev (.. prev "F"))]
    (set vim.o.shortmess next)
    (let [[ok result] [(pcall f)]]
      (set vim.o.shortmess prev)
      (if ok
          result
          (error result)))))

(fn wipe-replaced-split-buffer!
  [old-buf]
  "Delete the temporary [No Name] split buffer created by :vsplit before reattaching preview."
  (when (and old-buf (vim.api.nvim_buf_is_valid old-buf))
    (util.delete-transient-unnamed-buffer! old-buf)))

(fn M.new
  [opts]
  "Create preview window manager for selected source refs."
  (local selected-ref (. opts :selected-ref))
  (local read-file-lines-cached (. opts :read-file-lines-cached))
  (local read-file-view-cached (. opts :read-file-view-cached))
  (local floating-window-mod (. opts :floating-window-mod))
  (local is-active-session (. opts :is-active-session))
  (local debug-log (. opts :debug-log))
  (local source-switch-debounce-ms (. opts :source-switch-debounce-ms))

  (local target-preview-width
    (fn [session]
      (let [anchor-win (if (and session.meta
                                session.meta.win
                                (vim.api.nvim_win_is_valid session.meta.win.window))
                           session.meta.win.window
                           session.prompt-win)
            total-width (vim.api.nvim_win_get_width anchor-win)]
        ;; Derive from the stable main window width so prompt/preview siblings do
        ;; not create a recursive resize loop.
        (math.max 36 (math.min 220 (math.floor (* total-width 0.58)))))))

  (local selected-preview-ref
    (fn [session]
      (and session session.meta (selected-ref session.meta))))

  (local preview-float-config
    (fn [session width height]
      (let [host-win (if (and session.meta
                              session.meta.win
                              (vim.api.nvim_win_is_valid session.meta.win.window))
                         session.meta.win.window
                         session.prompt-win)]
        {:relative "win"
         :win host-win
         :anchor "SE"
         :row 0
         :col (vim.api.nvim_win_get_width host-win)
         :width width
         :height (math.max 1 (or height 1))})))

  (local refresh-preview-statusline!
    (fn [session]
      (when (and session session.preview-win (vim.api.nvim_win_is_valid session.preview-win))
        (let [ref (selected-preview-ref session)
              path (and ref ref.path)
              text (preview-statusline-text-for-path path)]
          (set session.preview-statusline-text text)
          (pcall vim.api.nvim_set_option_value "statusline" text {:win session.preview-win})))))

  (local ensure-preview-statusline-autocmds!
    (fn [session]
      (when (and session
                 session.preview-buf
                 (vim.api.nvim_buf_is_valid session.preview-buf)
                 (or (not session.preview-statusline-aug)
                     (~= session.preview-statusline-buf session.preview-buf)))
        (when session.preview-statusline-aug
          (pcall vim.api.nvim_del_augroup_by_id session.preview-statusline-aug))
        (let [aug-name (.. "metabuffer.preview.statusline." (tostring session.preview-buf))
              aug (vim.api.nvim_create_augroup aug-name {:clear true})]
          (set session.preview-statusline-aug aug)
          (set session.preview-statusline-buf session.preview-buf)
          (vim.api.nvim_create_autocmd
            ["BufEnter" "WinEnter" "FocusGained"]
            {:group aug
             :buffer session.preview-buf
             :callback (fn [_]
                         (vim.schedule
                           (fn []
                             (when (and (is-active-session session)
                                        session.preview-buf
                                        (vim.api.nvim_buf_is_valid session.preview-buf))
                               (refresh-preview-statusline! session)))))})))))

  (local mark-preview-buffer!
    (fn [buf]
      (when (and buf (vim.api.nvim_buf_is_valid buf))
        (events.send :on-buf-create! {:buf buf :role :preview}))))

  (local file-backed-preview-ref?
    (fn [ref]
      (and ref
           (or (and ref.buf (vim.api.nvim_buf_is_valid ref.buf))
               (and ref.path (= 1 (vim.fn.filereadable ref.path)))))))

  (local real-preview-buffer
    (fn [ref]
      (if (and ref ref.buf (vim.api.nvim_buf_is_valid ref.buf))
          ref.buf
          (let [path (and ref ref.path)]
            (when (and (= (type path) "string") (~= path "") (= 1 (vim.fn.filereadable path)))
              (let [buf (vim.fn.bufadd path)]
                (with-file-messages-suppressed
                  (fn []
                    (pcall vim.fn.bufload buf)))
                (if (vim.api.nvim_buf_is_valid buf) buf nil)))))))

  (local apply-preview-window-opts!
    (fn [session win]
      (when (and win (vim.api.nvim_win_is_valid win))
        (when-not (. (or session.preview-compat-initialized-wins {}) win)
          (when (not session.preview-compat-initialized-wins)
            (set session.preview-compat-initialized-wins {}))
          (tset session.preview-compat-initialized-wins win true)
          (events.send :on-win-create! {:win win :role :preview}))
        (let [real-buffer? (clj.boolean session.preview-real-buffer?)
              persisted-wrap (router-util-mod.results-wrap-enabled?)
              wrap? (if (~= persisted-wrap nil) (clj.boolean persisted-wrap) false)
              win-opts {:number real-buffer?
                        :relativenumber false
                        :wrap wrap?
                        :linebreak wrap?
                        :winfixwidth true
                        :signcolumn (if real-buffer? "auto" "no")
                        :foldcolumn "0"
                        :statuscolumn ""
                        :spell false
                        :cursorline true
                        ;; Match regular window palette in preview.
                        :winblend 0
                        :winhighlight (preview-winhighlight)
                        :statusline (if session.preview-float?
                                        ""
                                        (or session.preview-statusline-text ""))}]
          (set-window-options! win win-opts)))))

  (local clear-preview-focus-highlight!
    (fn [session]
      (when session.preview-focus-match-id
        (delete-window-match! session.preview-win session.preview-focus-match-id)
        (set session.preview-focus-match-id nil))))

  (local apply-preview-focus-highlight!
    (fn [session lnum]
      (clear-preview-focus-highlight! session)
      (when (and session.preview-win
                 (vim.api.nvim_win_is_valid session.preview-win)
                 lnum
                 (>= lnum 1))
        (let [pat (.. "\\%" (tostring lnum) "l.*")
              [ok id] [(pcall vim.fn.matchadd "MetaWindowCursorLine" pat 18 -1 {:window session.preview-win})]]
          (when ok
            (set session.preview-focus-match-id id))))))

  (var close-preview-window! nil)

  (fn ensure-preview-window!
    [session]
    (when-not (and session.preview-win (vim.api.nvim_win_is_valid session.preview-win))
      (let [buf (if (and session.preview-scratch-buf (vim.api.nvim_buf_is_valid session.preview-scratch-buf))
                    session.preview-scratch-buf
                    (vim.api.nvim_create_buf false true))
            width (target-preview-width session)
            float-start? (clj.boolean session.prompt-animating?)
            height (if float-start? 1 (math.max 1 (vim.api.nvim_win_get_height session.prompt-win)))
            win-id (if float-start?
                       (. (floating-window-mod.new vim buf (preview-float-config session width height)) :window)
                       (vim.api.nvim_win_call
                         session.prompt-win
                         (fn []
                           (vim.cmd "rightbelow vsplit")
                           (vim.api.nvim_get_current_win))))]
        (set session.preview-scratch-buf buf)
        (set session.preview-buf buf)
        (set session.preview-win win-id)
        (set session.preview-float? float-start?)
        (set session.preview-real-buffer? false)
        (set session.preview-layout nil)
        (set session.preview-last-path nil)
        (let [old-buf (and (not float-start?)
                           win-id
                           (vim.api.nvim_win_is_valid win-id)
                           (vim.api.nvim_win_get_buf win-id))]
          (when old-buf
            (util.mark-transient-unnamed-buffer! old-buf))
        (util.set-buffer-name! buf "[Metabuffer Preview]")
        (pcall vim.api.nvim_win_set_buf win-id buf)
          (wipe-replaced-split-buffer! old-buf))
        (when-not float-start?
          (pcall vim.api.nvim_win_set_width win-id width))
        ;; Keep scratch alive even when preview window temporarily shows source
        ;; buffers, and disable swapfile side effects.
        (set-buffer-options!
          buf
          {:bufhidden "hide"
           :buftype "nofile"
           :swapfile false
           :modifiable false
           :filetype ""})
        (mark-preview-buffer! buf)
        (ensure-preview-statusline-autocmds! session)
        (apply-preview-window-opts! session session.preview-win)
        (set session.preview-animated? true))))

  (fn ensure-preview-split-window!
    [session]
    (when session.preview-float?
      (close-preview-window! session)
      (ensure-preview-window! session))
    (when (and session.preview-win (vim.api.nvim_win_is_valid session.preview-win))
      (set session.preview-float? false)))

  (set close-preview-window!
    (fn [session]
      (let [buf session.preview-buf
            scratch-buf session.preview-scratch-buf]
	      (when (and session.preview-win (vim.api.nvim_win_is_valid session.preview-win))
	        (pcall vim.api.nvim_win_close session.preview-win true))
      (when session.preview-statusline-aug
        (pcall vim.api.nvim_del_augroup_by_id session.preview-statusline-aug))
      (set session.preview-statusline-aug nil)
      (set session.preview-statusline-buf nil)
      (clear-preview-focus-highlight! session)
        (when (and scratch-buf
                   (vim.api.nvim_buf_is_valid scratch-buf)
                   (= true (pcall vim.api.nvim_buf_get_var scratch-buf "meta_preview")))
          (pcall vim.api.nvim_buf_delete scratch-buf {:force true}))
        (when (and buf
                   (vim.api.nvim_buf_is_valid buf)
                   (= true (pcall vim.api.nvim_buf_get_var buf "meta_preview")))
          (pcall vim.api.nvim_buf_delete buf {:force true}))
	      (set session.preview-win nil)
      (set session.preview-float? false)
      (set session.preview-real-buffer? false)
      (set session.preview-scratch-buf nil)
	      (set session.preview-buf nil)
        (set session.preview-compat-initialized-wins nil))))

  (fn ensure-preview-scratch-buf!
    [session]
    (when (or (not session.preview-scratch-buf) (not (vim.api.nvim_buf_is_valid session.preview-scratch-buf)))
      (set session.preview-scratch-buf (vim.api.nvim_create_buf false true))
      (util.set-buffer-name! session.preview-scratch-buf "[Metabuffer Preview]")
      (set-buffer-options!
        session.preview-scratch-buf
        {:bufhidden "hide"
         :buftype "nofile"
         :swapfile false
         :modifiable false
         :filetype ""})
      (mark-preview-buffer! session.preview-scratch-buf)))

  (fn preview-context
    [session]
    (let [ref (selected-ref session.meta)
          p-height (if (and session.preview-win (vim.api.nvim_win_is_valid session.preview-win))
                       (vim.api.nvim_win_get_height session.preview-win)
                       (vim.api.nvim_win_get_height session.meta.win.window))
          width (target-preview-width session)
          preview-data (source-mod.preview-lines session ref p-height read-file-lines-cached read-file-view-cached)
          ft (source-mod.preview-filetype ref)
          lines (or preview-data.lines (trim-or-pad-lines [] p-height))
          src-lnum (math.max 1 (or preview-data.focus-lnum (and ref (or ref.preview-lnum ref.lnum)) 1))
          start-lnum (math.max 1 (or preview-data.start-lnum (if ref (- src-lnum 1) 1)))
          focus-row (if ref
                        (let [row (+ (- src-lnum start-lnum) 1)]
                          (math.max 1 (math.min row p-height)))
                        1)]
      {:ref ref
       :p-height p-height
       :width width
       :ft ft
       :lines lines
       :start-lnum start-lnum
       :focus-row focus-row}))

  (fn ensure-preview-width!
    [session ctx]
    (let [width (. ctx :width)]
      (when (and session.preview-win (vim.api.nvim_win_is_valid session.preview-win))
        (when (~= width (or session.preview-width 0))
          (set session.preview-width width)
          (if session.preview-float?
              (let [height (math.max 1 (vim.api.nvim_win_get_height session.preview-win))]
                (pcall vim.api.nvim_win_set_config
                       session.preview-win
                       (preview-float-config session width height)))
              (pcall vim.api.nvim_win_set_width session.preview-win width))))))

  (fn render-preview-scratch!
    [session ctx]
    (ensure-preview-scratch-buf! session)
    (set session.preview-real-buffer? false)
    (set session.preview-buf session.preview-scratch-buf)
    (when (~= (vim.api.nvim_win_get_buf session.preview-win) session.preview-buf)
      (pcall vim.api.nvim_win_set_buf session.preview-win session.preview-buf))
    (let [bo (. vim.bo session.preview-buf)]
      (set (. bo :modifiable) true))
    (let [rendered []]
      (each [_ line (ipairs (. ctx :lines))]
        (table.insert rendered (or line "")))
      (vim.api.nvim_buf_set_lines session.preview-buf 0 -1 false rendered)
      (pcall vim.api.nvim_win_set_cursor session.preview-win [(. ctx :focus-row) 0])
      (apply-preview-focus-highlight! session (. ctx :focus-row)))
    (let [bo (. vim.bo session.preview-buf)
          ft (. ctx :ft)]
      (set (. bo :modifiable) false)
      (let [next-ft (if (and (= (type ft) "string") (~= ft "")) ft "")]
        (when (~= next-ft "")
          (apply-ft-buffer-vars! session.preview-buf next-ft))
        (pcall vim.api.nvim_set_option_value "syntax" "" {:buf session.preview-buf})
        (set (. bo :filetype) next-ft)
        (when (~= next-ft "")
          (pcall vim.api.nvim_set_option_value "syntax" next-ft {:buf session.preview-buf})))))

  (fn render-preview-source!
    [session ctx]
    (let [ref (. ctx :ref)
          buf (real-preview-buffer ref)]
      (when (and buf (vim.api.nvim_buf_is_valid buf))
        (set session.preview-real-buffer? true)
        (set session.preview-buf buf)
        (when (~= (vim.api.nvim_win_get_buf session.preview-win) buf)
          (with-file-messages-suppressed
            (fn []
              (pcall vim.api.nvim_win_set_buf session.preview-win buf))))
        (let [bo (. vim.bo buf)]
          (set (. bo :bufhidden) "hide"))
        (let [lnum (math.max 1 (or (and ref (or ref.preview-lnum ref.lnum)) 1))
              topline (math.max 1 (- lnum 2))]
          (pcall vim.api.nvim_win_call
                 session.preview-win
                 (fn []
                   (pcall vim.fn.winrestview
                          {:lnum lnum
                           :topline topline
                           :col 0
                           :leftcol 0})))
          (apply-preview-focus-highlight! session lnum)))))

  (fn render-preview-placeholder!
    [session]
    (ensure-preview-scratch-buf! session)
    (set session.preview-real-buffer? false)
    (set session.preview-buf session.preview-scratch-buf)
    (when (and session.preview-buf (vim.api.nvim_buf_is_valid session.preview-buf))
      (when (~= (vim.api.nvim_win_get_buf session.preview-win) session.preview-buf)
        (pcall vim.api.nvim_win_set_buf session.preview-win session.preview-buf))
      (let [bo (. vim.bo session.preview-buf)]
        (set (. bo :modifiable) true)
        (vim.api.nvim_buf_set_lines session.preview-buf 0 -1 false [""])
        (set (. bo :modifiable) false)
        (pcall vim.api.nvim_set_option_value "syntax" "" {:buf session.preview-buf})
        (set (. bo :filetype) "")))
    (clear-preview-focus-highlight! session)
    (set session.preview-last-path nil))

  (fn update-preview-window!
    [session]
    (ensure-preview-window! session)
    (when (and session.preview-win (vim.api.nvim_win_is_valid session.preview-win))
      (if session.prompt-animating?
          (do
            (apply-preview-window-opts! session session.preview-win)
            (render-preview-placeholder! session))
          (do
            (ensure-preview-split-window! session)
            (let [ctx (preview-context session)]
              (debug-log (.. "preview idx=" (tostring session.meta.selected_index)
                             " path=" (tostring (and (. ctx :ref) (. (. ctx :ref) :path)))
                             " lnum=" (tostring (and (. ctx :ref) (. (. ctx :ref) :lnum)))))
              (ensure-preview-width! session ctx)
              (if (file-backed-preview-ref? (. ctx :ref))
                  (render-preview-source! session ctx)
                  (render-preview-scratch! session ctx))
              (ensure-preview-statusline-autocmds! session)
              (apply-preview-window-opts! session session.preview-win)
              (refresh-preview-statusline! session)
              (set session.preview-last-path (and (. ctx :ref) (. (. ctx :ref) :path))))))))

  (fn selected-preview-path
    [session]
    (let [ref (and session session.meta (selected-ref session.meta))]
      (or (and ref ref.path) "")))

  (fn cancel-preview-update!
    [session]
    (when session
      (set session.preview-update-token (+ 1 (or session.preview-update-token 0)))
      (when session.preview-update-timer
        (let [timer session.preview-update-timer
              stopf (. timer :stop)
              closef (. timer :close)]
          (when stopf (pcall stopf timer))
          (when closef (pcall closef timer))
          (set session.preview-update-timer nil)))
      (set session.preview-update-pending false)))

  (fn schedule-preview-update!
    [session wait-ms]
    (when session
      (cancel-preview-update! session)
      (set session.preview-update-pending true)
      (set session.preview-update-token (+ 1 (or session.preview-update-token 0)))
      (let [token session.preview-update-token
            target-path (selected-preview-path session)
            timer (vim.loop.new_timer)]
        (set session.preview-update-timer timer)
        ((. timer :start)
         timer
         (math.max 0 (or wait-ms 0))
         0
         (vim.schedule_wrap
           (fn []
             (when (and session.preview-update-timer
                        (= session.preview-update-timer timer))
               (let [stopf (. timer :stop)
                     closef (. timer :close)]
                 (when stopf (pcall stopf timer))
                 (when closef (pcall closef timer))
                 (set session.preview-update-timer nil)
                 (set session.preview-update-pending false)))
             (when (and session
                        (= token session.preview-update-token)
                        (is-active-session session)
                        (= target-path (selected-preview-path session)))
               (pcall update-preview-window! session))))))))

  (fn maybe-update-preview-for-selection!
    [session]
    (let [target-path (selected-preview-path session)
          shown-path (or session.preview-last-path "")]
      (if (and (~= shown-path "")
               (~= target-path shown-path))
          (schedule-preview-update! session source-switch-debounce-ms)
          (do
            (cancel-preview-update! session)
            (update-preview-window! session)))))

	  {:close-window! close-preview-window!
     :ensure-window! ensure-preview-window!
     :update! update-preview-window!
     :refresh-statusline! refresh-preview-statusline!
     :maybe-update-for-selection! maybe-update-preview-for-selection!
     :cancel-update! cancel-preview-update!})

M
