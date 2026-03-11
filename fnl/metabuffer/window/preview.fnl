(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})
(local lineno-mod (require :metabuffer.window.lineno))
(local source-mod (require :metabuffer.source))

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

(fn M.new
  [opts]
  "Create preview window manager for selected source refs."
  (let [{: floating-window-mod : selected-ref : read-file-lines-cached
         : is-active-session : debug-log : source-switch-debounce-ms} opts]

  (fn preview-window-config
    [session width height]
    (let [p-row-col (vim.api.nvim_win_get_position session.prompt-win)
          p-row (. p-row-col 1)
          p-col (. p-row-col 2)
          p-width (vim.api.nvim_win_get_width session.prompt-win)]
      (if session.window-local-layout
          {:relative "win"
           :win session.prompt-win
           :anchor "NW"
           :row 0
           :col p-width
           :width width
           :height height}
          {:relative "editor"
           :anchor "NE"
           :row p-row
           :col (+ p-col p-width)
           :width width
           :height height})))

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
    [win]
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
             "NormalFloat:Normal,Normal:Normal,NormalNC:Normal,CursorLine:CursorLine,SignColumn:SignColumn,FloatBorder:Normal"
             {:win win})))

  (fn ensure-preview-window!
    [session]
    (when-not (and session.preview-win (vim.api.nvim_win_is_valid session.preview-win))
      (let [buf (vim.api.nvim_create_buf false true)
            p-width (vim.api.nvim_win_get_width session.prompt-win)
            p-height (vim.api.nvim_win_get_height session.prompt-win)
            width (math.max 36 (math.min 128 (math.floor (* p-width 0.58))))
            cfg (preview-window-config session width p-height)
            win (floating-window-mod.new vim buf cfg)]
        (set session.preview-buf buf)
        (set session.preview-win win.window)
        (set session.preview-layout nil)
        (set session.preview-last-path nil)
        (let [bo (. vim.bo buf)]
          ;; Keep scratch alive even when preview window temporarily shows source
          ;; buffers, and disable swapfile side effects.
          (set (. bo :bufhidden) "hide")
          (set (. bo :buftype) "nofile")
          (set (. bo :swapfile) false)
          (set (. bo :modifiable) false)
          (set (. bo :filetype) "text"))
        (let [wo (. vim.wo win.window)]
          (set (. wo :number) false)
          (set (. wo :relativenumber) false)
          (set (. wo :wrap) false)
          (set (. wo :linebreak) false)
          (set (. wo :cursorline) true)
          (set (. wo :signcolumn) "no"))
        (mark-preview-buffer! buf))
      (apply-preview-window-opts! session.preview-win)))

  (fn close-preview-window!
    [session]
    (when (and session.preview-win (vim.api.nvim_win_is_valid session.preview-win))
      (pcall vim.api.nvim_win_close session.preview-win true))
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
          p-width (vim.api.nvim_win_get_width session.prompt-win)
          p-height (vim.api.nvim_win_get_height session.prompt-win)
          width (math.max 36 (math.min 128 (math.floor (* p-width 0.58))))
          cfg (preview-window-config session width p-height)
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
       :p-row (. cfg :row)
       :p-height p-height
       :width width
       :col (. cfg :col)
       :cfg cfg
       :ft ft
       :lines lines
       :start-lnum start-lnum
       :focus-row focus-row}))

  (fn maybe-update-preview-layout!
    [session ctx]
    (let [row (. ctx :p-row)
          col (. ctx :col)
          width (. ctx :width)
          height (. ctx :p-height)]
      (when (or (not session.preview-layout)
                (~= (. session.preview-layout :row) row)
                (~= (. session.preview-layout :col) col)
                (~= (. session.preview-layout :width) width)
                (~= (. session.preview-layout :height) height))
        (set session.preview-layout {:row row :col col :width width :height height})
        (pcall vim.api.nvim_win_set_config session.preview-win (. ctx :cfg)))))

  (fn render-preview-scratch!
    [session ctx]
    (when (~= (vim.api.nvim_win_get_buf session.preview-win) session.preview-buf)
      (pcall vim.api.nvim_win_set_buf session.preview-win session.preview-buf))
    (let [bo (. vim.bo session.preview-buf)]
      (set (. bo :modifiable) true))
    (let [start (or (. ctx :start-lnum) 1)
          stop (+ start (math.max 0 (- (# (. ctx :lines)) 1)))
          digit-width (lineno-mod.digit-width-from-max-value stop)
          field-width (+ digit-width 1)
          focus-row (math.max 1 (or (. ctx :focus-row) 1))
          focus-line (or (. (. ctx :lines) focus-row) "")
          indent (leading-indent-width focus-line)
          target-leftcol (math.max 0 (+ field-width (math.max 0 (- indent 2))))
          rendered []
          highlights []]
      (each [i line (ipairs (. ctx :lines))]
        (let [lnum-cell (lineno-mod.lnum-cell (+ start i -1) digit-width)
              text (.. lnum-cell (or line ""))]
          (table.insert rendered text)
          (table.insert highlights [(- i 1) "LineNr" 0 (# lnum-cell)])))
      (vim.api.nvim_buf_set_lines session.preview-buf 0 -1 false rendered)
      (pcall vim.api.nvim_set_option_value "numberwidth" field-width {:win session.preview-win})
      (let [ns (or session.preview-hl-ns (vim.api.nvim_create_namespace "metabuffer.preview"))]
        (set session.preview-hl-ns ns)
        (vim.api.nvim_buf_clear_namespace session.preview-buf ns 0 -1)
        (each [_ h (ipairs highlights)]
          (vim.api.nvim_buf_add_highlight session.preview-buf ns (. h 2) (. h 1) (. h 3) (. h 4)))
        (pcall vim.api.nvim_win_set_cursor session.preview-win [(. ctx :focus-row) 0])
        (pcall vim.fn.winrestview {:leftcol target-leftcol})))
    (let [bo (. vim.bo session.preview-buf)
          ft (. ctx :ft)]
      (set (. bo :modifiable) false)
      (let [next-ft (if (and (= (type ft) "string") (~= ft ""))
                        ft
                        "text")]
        (when (~= (. bo :filetype) next-ft)
          (set (. bo :filetype) next-ft)))))

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
          (maybe-update-preview-layout! session ctx)
          (apply-preview-window-opts! session.preview-win)
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
   :maybe-update-for-selection! maybe-update-preview-for-selection!
   :cancel-update! cancel-preview-update!}))

M
