(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})
(local source-mod (require :metabuffer.source))
(local lineno-mod (require :metabuffer.window.lineno))
(local statusline-mod (require :metabuffer.window.statusline))

(fn trim-or-pad-lines
  [lines target]
  (let [out []]
    (each [_ line (ipairs (or lines []))]
      (when (< (# out) target)
        (table.insert out (or line ""))))
    (while (< (# out) target)
      (table.insert out ""))
    out))

(fn leading-indent-width
  [line]
  (let [txt (or line "")
        ws (or (string.match txt "^(%s*)") "")]
    (vim.fn.strdisplaywidth ws)))

(fn preview-statusline-text-for-path
  [path]
  (statusline-mod.render-path path {:default-text "Preview"
                                    :file-group "MetaStatuslinePathFile"}))

(fn apply-ft-buffer-vars!
  [buf ft]
  (when (and buf (vim.api.nvim_buf_is_valid buf) (= ft "fennel"))
    (pcall vim.api.nvim_buf_set_var buf "fennel_lua_version" "5.1")
    (pcall vim.api.nvim_buf_set_var buf "fennel_use_luajit" (if _G.jit 1 0))))

(fn M.new
  [opts]
  "Create preview window manager for selected source refs."
  (let [{: selected-ref : read-file-lines-cached
         : is-active-session : debug-log : source-switch-debounce-ms
         : animation-mod : animate-enter? : preview-slide-ms} opts]

	  (fn target-preview-width
	    [session]
    (let [anchor-win (if (and session.meta
                              session.meta.win
                              (vim.api.nvim_win_is_valid session.meta.win.window))
                         session.meta.win.window
                         session.prompt-win)
          total-width (vim.api.nvim_win_get_width anchor-win)]
      ;; Derive from the stable main window width so prompt/preview siblings do
      ;; not create a recursive resize loop.
	      (math.max 36 (math.min 220 (math.floor (* total-width 0.58))))))

  (fn selected-preview-ref
    [session]
    (and session session.meta (selected-ref session.meta)))

  (fn refresh-preview-statusline!
    [session]
    (when (and session session.preview-win (vim.api.nvim_win_is_valid session.preview-win))
      (let [ref (selected-preview-ref session)
            path (and ref ref.path)
            text (preview-statusline-text-for-path path)]
        (set session.preview-statusline-text text)
        (pcall vim.api.nvim_set_option_value "statusline" text {:win session.preview-win}))))

  (fn ensure-preview-statusline-autocmds!
    [session]
    (when (and session
               session.preview-buf
               (vim.api.nvim_buf_is_valid session.preview-buf)
               (not session.preview-statusline-aug))
      (let [aug-name (.. "metabuffer.preview.statusline." (tostring session.preview-buf))
            aug (vim.api.nvim_create_augroup aug-name {:clear true})]
        (set session.preview-statusline-aug aug)
        (vim.api.nvim_create_autocmd ["BufEnter" "WinEnter" "FocusGained"]
          {:group aug
           :buffer session.preview-buf
           :callback (fn [_]
                       (vim.schedule
                         (fn []
                           (when (and (is-active-session session)
                                      session.preview-buf
                                      (vim.api.nvim_buf_is_valid session.preview-buf))
                             (refresh-preview-statusline! session)))))}))))

	  (fn mark-preview-buffer!
	    [buf]
    (when (and buf (vim.api.nvim_buf_is_valid buf))
      ;; Keep syntax/filetype, but hint heavy tooling to skip preview-only buffers.
      (pcall vim.api.nvim_buf_set_var buf "conjure_disable" true)
      (pcall vim.api.nvim_buf_set_var buf "lsp_disabled" 1)
      (pcall vim.api.nvim_buf_set_var buf "gitgutter_enabled" 0)
      (pcall vim.api.nvim_buf_set_var buf "gitsigns_disable" true)
      (pcall vim.api.nvim_buf_set_var buf "meta_preview" true)
      (pcall vim.diagnostic.enable false {:bufnr buf})))

	  (fn apply-preview-window-opts!
	    [session win]
	    (when (and win (vim.api.nvim_win_is_valid win))
      (pcall vim.api.nvim_set_option_value "number" false {:win win})
      (pcall vim.api.nvim_set_option_value "relativenumber" false {:win win})
      (pcall vim.api.nvim_set_option_value "wrap" false {:win win})
      (pcall vim.api.nvim_set_option_value "linebreak" false {:win win})
      (pcall vim.api.nvim_set_option_value "signcolumn" "no" {:win win})
      (pcall vim.api.nvim_set_option_value "foldcolumn" "0" {:win win})
      (pcall vim.api.nvim_set_option_value "statuscolumn" "" {:win win})
      (pcall vim.api.nvim_set_option_value "spell" false {:win win})
      (pcall vim.api.nvim_set_option_value "cursorline" true {:win win})
      ;; Match regular window palette in preview.
      (pcall vim.api.nvim_set_option_value "winblend" 0 {:win win})
	      (pcall vim.api.nvim_set_option_value "winhighlight"
	             "NormalFloat:Normal,Normal:Normal,NormalNC:Normal,CursorLine:CursorLine,SignColumn:SignColumn,FloatBorder:Normal,StatusLine:Normal,StatusLineNC:Normal"
	             {:win win})
        (when (and session (= (type session.preview-statusline-text) "string"))
          (pcall vim.api.nvim_set_option_value "statusline" session.preview-statusline-text {:win win}))))

  (fn ensure-preview-window!
    [session]
    (when-not (and session.preview-win (vim.api.nvim_win_is_valid session.preview-win))
      (let [buf (if (and session.preview-buf (vim.api.nvim_buf_is_valid session.preview-buf))
                    session.preview-buf
                    (vim.api.nvim_create_buf false true))
            width (target-preview-width session)
            win-id (vim.api.nvim_win_call
                     session.prompt-win
                     (fn []
                       (vim.cmd "rightbelow vsplit")
                       (vim.api.nvim_get_current_win)))]
        (set session.preview-buf buf)
        (set session.preview-win win-id)
        (set session.preview-layout nil)
        (set session.preview-last-path nil)
        (pcall vim.api.nvim_win_set_buf win-id buf)
        (pcall vim.api.nvim_win_set_width win-id width)
        (let [bo (. vim.bo buf)]
          ;; Keep scratch alive even when preview window temporarily shows source
          ;; buffers, and disable swapfile side effects.
          (set (. bo :bufhidden) "hide")
          (set (. bo :buftype) "nofile")
          (set (. bo :swapfile) false)
          (set (. bo :modifiable) false)
          (set (. bo :filetype) "text"))
        (let [wo (. vim.wo win-id)]
          (set (. wo :number) false)
          (set (. wo :relativenumber) false)
          (set (. wo :wrap) false)
          (set (. wo :linebreak) false)
          (set (. wo :cursorline) true)
          (set (. wo :signcolumn) "no"))
        (mark-preview-buffer! buf)
        (ensure-preview-statusline-autocmds! session)
        (apply-preview-window-opts! session session.preview-win)
        (when (and animation-mod
                   animate-enter?
                   (animate-enter? session)
                   (animation-mod.enabled? session :preview)
                   (not session.preview-animated?))
          (set session.preview-animated? true)
          (pcall vim.api.nvim_win_set_width win-id 24)
          (animation-mod.animate-win-width!
            session
            "preview-enter"
            win-id
            24
            width
            (animation-mod.duration-ms session :preview (or preview-slide-ms 180)))))))

  (fn close-preview-window!
    [session]
	    (when (and session.preview-win (vim.api.nvim_win_is_valid session.preview-win))
	      (pcall vim.api.nvim_win_close session.preview-win true))
      (when session.preview-statusline-aug
        (pcall vim.api.nvim_del_augroup_by_id session.preview-statusline-aug))
      (set session.preview-statusline-aug nil)
	    (set session.preview-win nil)
	    (set session.preview-buf nil))

  (fn ensure-preview-scratch-buf!
    [session]
    (when (or (not session.preview-buf) (not (vim.api.nvim_buf_is_valid session.preview-buf)))
      (set session.preview-buf (vim.api.nvim_create_buf false true))
      (let [bo (. vim.bo session.preview-buf)]
        (set (. bo :bufhidden) "hide")
        (set (. bo :buftype) "nofile")
        (set (. bo :swapfile) false)
        (set (. bo :modifiable) false)
        (set (. bo :filetype) "text"))
      (mark-preview-buffer! session.preview-buf)))

  (fn preview-context
    [session]
    (let [ref (selected-ref session.meta)
          p-height (if (and session.preview-win (vim.api.nvim_win_is_valid session.preview-win))
                       (vim.api.nvim_win_get_height session.preview-win)
                       (vim.api.nvim_win_get_height session.meta.win.window))
          width (target-preview-width session)
          preview-data (source-mod.preview-lines session ref p-height read-file-lines-cached)
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
          (pcall vim.api.nvim_win_set_width session.preview-win width)))))

  (fn render-preview-scratch!
    [session ctx]
    (when (~= (vim.api.nvim_win_get_buf session.preview-win) session.preview-buf)
      (pcall vim.api.nvim_win_set_buf session.preview-win session.preview-buf))
    (let [bo (. vim.bo session.preview-buf)]
      (set (. bo :modifiable) true))
    (let [start (or (. ctx :start-lnum) 1)
          stop (+ start (math.max 0 (- (# (. ctx :lines)) 1)))
          digit-width (math.max 2 (# (tostring (math.max 1 stop))))
          field-width (+ digit-width 1)
          focus-row (math.max 1 (or (. ctx :focus-row) 1))
          focus-line (or (. (. ctx :lines) focus-row) "")
          indent (leading-indent-width focus-line)
          base-target (math.max 0 (- (+ field-width indent) 8))
          ;; Never scroll away synthetic line numbers.
          target-leftcol (math.max 0 (math.min base-target (math.max 0 (- field-width 1))))
          rendered []
          ]
      (each [i line (ipairs (. ctx :lines))]
        (let [lnum (+ start (- i 1))
              lnum-cell (lineno-mod.lnum-cell lnum digit-width)]
          (table.insert rendered (.. lnum-cell (or line "")))))
      (vim.api.nvim_buf_set_lines session.preview-buf 0 -1 false rendered)
      (let [ns (or session.preview-hl-ns (vim.api.nvim_create_namespace "metabuffer.preview"))]
        (set session.preview-hl-ns ns)
        (vim.api.nvim_buf_clear_namespace session.preview-buf ns 0 -1)
        (each [row _ (ipairs rendered)]
          (pcall vim.api.nvim_buf_add_highlight
                 session.preview-buf
                 ns
                 "LineNr"
                 (- row 1)
                 0
                 field-width))
        (pcall vim.api.nvim_win_set_cursor session.preview-win [(. ctx :focus-row) 0])
        (pcall vim.api.nvim_win_call
               session.preview-win
               (fn [] (vim.fn.winrestview {:leftcol target-leftcol})))))
    (let [bo (. vim.bo session.preview-buf)
          ft (. ctx :ft)]
      (set (. bo :modifiable) false)
      (let [next-ft (if (and (= (type ft) "string") (~= ft ""))
                        ft
                        "text")]
        (apply-ft-buffer-vars! session.preview-buf next-ft)
        (pcall vim.api.nvim_set_option_value "syntax" "" {:buf session.preview-buf})
        (set (. bo :filetype) next-ft)
        (pcall vim.api.nvim_set_option_value "syntax" next-ft {:buf session.preview-buf}))))

	  (fn update-preview-window!
	    [session]
	    (ensure-preview-window! session)
	    (when (and session.preview-win (vim.api.nvim_win_is_valid session.preview-win))
	      (ensure-preview-scratch-buf! session)
	      (when (and session.preview-buf (vim.api.nvim_buf_is_valid session.preview-buf))
	        (let [ctx (preview-context session)]
          (debug-log (.. "preview idx=" (tostring session.meta.selected_index)
                         " path=" (tostring (and (. ctx :ref) (. (. ctx :ref) :path)))
                         " lnum=" (tostring (and (. ctx :ref) (. (. ctx :ref) :lnum)))))
	          (ensure-preview-width! session ctx)
	      (apply-preview-window-opts! session session.preview-win)
              (refresh-preview-statusline! session)
	      (render-preview-scratch! session ctx)
	      (set session.preview-last-path (and (. ctx :ref) (. (. ctx :ref) :path)))))))

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
     :refresh-statusline! refresh-preview-statusline!
	   :maybe-update-for-selection! maybe-update-preview-for-selection!
	   :cancel-update! cancel-preview-update!}))

M
