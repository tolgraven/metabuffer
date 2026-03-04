(local meta_mod (require :metabuffer.meta))
(local prompt_window_mod (require :metabuffer.window.prompt))
(local meta_window_mod (require :metabuffer.window.metawindow))
(local floating_window_mod (require :metabuffer.window.floating))
(local base_buffer (require :metabuffer.buffer.base))
(local state (require :metabuffer.core.state))
(local debug (require :metabuffer.debug))

(local M {})
(set M.instances {})
(set M.active-by-source {})
(set M.active-by-prompt {})
(var update-info-window nil)
(set M.history-max 100)
(set M.project-max-file-bytes (or vim.g.meta_project_max_file_bytes (* 1024 1024)))
(set M.project-max-total-lines (or vim.g.meta_project_max_total_lines 200000))
(set M.default-include-hidden (or vim.g.meta_project_include_hidden false))
(set M.default-include-ignored (or vim.g.meta_project_include_ignored false))
(set M.default-include-deps (or vim.g.meta_project_include_deps false))
(set M.info-max-lines (or vim.g.meta_info_max_lines 10000))
(set M.info-min-width (or vim.g.meta_info_width 28))
(set M.info-max-width (or vim.g.meta_info_max_width 52))

(fn debug-log [msg]
  (debug.log "router" msg))

(fn prompt-height []
  (or (tonumber vim.g.meta_prompt_height)
      (tonumber (. vim.g "meta#prompt_height"))
      7))

(fn persist-prompt-height! [session]
  (when (and session session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
    (let [[ok h] [(pcall vim.api.nvim_win_get_height session.prompt-win)]]
      (when (and ok h (> h 0))
        (set vim.g.meta_prompt_height h)
        (set (. vim.g "meta#prompt_height") h)))))

(fn info-height [session]
  (if (and session session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
      (let [p-row-col (vim.api.nvim_win_get_position session.prompt-win)
            p-row (. p-row-col 1)]
        (math.max 7 (- p-row 2)))
      (math.max 7 (- vim.o.lines (+ (prompt-height) 4)))))

(fn lnum-width-from-max-len [max-len]
  (+ (math.max 2 (or max-len 1)) 1))

(fn lnum-width-from-max-value [max-value]
  (lnum-width-from-max-len (# (tostring (math.max 1 (or max-value 1))))))

(fn lnum-cell [lnum width]
  (.. (string.rep " " (math.max 0 (- width (+ (# lnum) 1))))
      lnum
      " "))

(fn mark-preview-buffer! [buf]
  (when (and buf (vim.api.nvim_buf_is_valid buf))
    ;; Keep syntax/filetype, but hint heavy tooling to skip preview-only buffers.
    (pcall vim.api.nvim_buf_set_var buf "conjure_disable" true)
    (pcall vim.api.nvim_buf_set_var buf "lsp_disabled" 1)
    (pcall vim.api.nvim_buf_set_var buf "gitgutter_enabled" 0)
    (pcall vim.api.nvim_buf_set_var buf "gitsigns_disable" true)
    (pcall vim.api.nvim_buf_set_var buf "meta_preview" true)
    (pcall vim.diagnostic.enable false {:bufnr buf})))

(fn apply-preview-window-opts! [win]
  (when (and win (vim.api.nvim_win_is_valid win))
    (pcall vim.api.nvim_set_option_value "number" false {:win win})
    (pcall vim.api.nvim_set_option_value "relativenumber" false {:win win})
    (pcall vim.api.nvim_set_option_value "signcolumn" "no" {:win win})
    (pcall vim.api.nvim_set_option_value "foldcolumn" "0" {:win win})
    (pcall vim.api.nvim_set_option_value "statuscolumn"
           "%#LineNr#%=%{v:virtnum>0?'':printf('%*d ',get(b:,'meta_preview_lnum_width',3)-1,get(b:,'meta_preview_start_lnum',1)+v:lnum-1)}"
           {:win win})
    (pcall vim.api.nvim_set_option_value "spell" false {:win win})
    (pcall vim.api.nvim_set_option_value "cursorline" true {:win win})
    ;; Match regular window palette in preview.
    (pcall vim.api.nvim_set_option_value "winblend" 0 {:win win})
    (pcall vim.api.nvim_set_option_value "winhighlight"
           "NormalFloat:Normal,Normal:Normal,NormalNC:Normal,CursorLine:CursorLine,SignColumn:SignColumn,FloatBorder:Normal"
           {:win win})
    (pcall vim.api.nvim_set_option_value "statusline" " Preview " {:win win})))

(set M.dep-dir-names
  {"node_modules" true
   ".venv" true
   "venv" true
   "vendor" true
   "dist" true
   "build" true
   "target" true
   "__pycache__" true
   ".mypy_cache" true
   ".pytest_cache" true
   ".tox" true
   ".next" true
   ".nuxt" true
   ".yarn" true
   ".pnpm-store" true})

(fn truthy? [v]
  (or (= v true) (= v 1) (= v "1") (= v "true")))

(fn option-prefix []
  (let [p (. vim.g "meta#prefix")]
    (if (and (= (type p) "string") (~= p ""))
        p
        "#")))

(fn parse-option-token [tok]
  (let [prefix (option-prefix)
        hidden-on (or (= tok "#hidden") (= tok "+hidden") (= tok (.. prefix "hidden")))
        hidden-off (or (= tok "#nohidden") (= tok "-hidden") (= tok (.. prefix "nohidden")))
        ignored-on (or (= tok "#ignored") (= tok "+ignored") (= tok (.. prefix "ignored")))
        ignored-off (or (= tok "#noignored") (= tok "-ignored") (= tok (.. prefix "noignored")))
        deps-on (or (= tok "#deps") (= tok "+deps") (= tok (.. prefix "deps")))
        deps-off (or (= tok "#nodeps") (= tok "-deps") (= tok (.. prefix "nodeps")))]
    (if hidden-on
        [:hidden true]
        (if hidden-off
            [:hidden false]
            (if ignored-on
        [:ignored true]
        (if ignored-off
            [:ignored false]
            (if deps-on
                [:deps true]
                (if deps-off
                    [:deps false]
                    nil))))))))

(fn parse-query-lines [lines]
  (var include-hidden nil)
  (var include-ignored nil)
  (var include-deps nil)
  (local cleaned [])
  (each [_ line (ipairs (or lines []))]
    (local trimmed (vim.trim (or line "")))
    (if (= trimmed "")
        (table.insert cleaned "")
        (let [parts (vim.split trimmed "%s+")
              keep []]
          (each [_ tok (ipairs (or parts []))]
            (let [parsed (parse-option-token tok)]
              (if parsed
                  (let [k (. parsed 1)
                        v (. parsed 2)]
                    (if (= k :hidden)
                        (set include-hidden v)
                        (if (= k :ignored)
                            (set include-ignored v)
                            (when (= k :deps)
                              (set include-deps v)))))
                  (table.insert keep tok))))
          (table.insert cleaned (table.concat keep " ")))))
  {:lines cleaned :include-hidden include-hidden :include-ignored include-ignored :include-deps include-deps})

(fn parse-query-text [query]
  (if (not (and (= (type query) "string") (~= query "")))
      {:query query :include-hidden nil :include-ignored nil :include-deps nil}
      (let [lines (vim.split query "\n" {:plain true})
            parsed (parse-query-lines lines)]
        {:query (table.concat (. parsed :lines) "\n")
         :include-hidden (. parsed :include-hidden)
         :include-ignored (. parsed :include-ignored)
         :include-deps (. parsed :include-deps)})))

(fn history-list []
  (if (= (type vim.g.metabuffer_prompt_history) "table")
      vim.g.metabuffer_prompt_history
      (do
        (set vim.g.metabuffer_prompt_history [])
        vim.g.metabuffer_prompt_history)))

(fn push-history! [text]
  (when (and (= (type text) "string") (~= (vim.trim text) ""))
    ;; vim.g table values are copied on read; write back after mutation.
    (local h (vim.deepcopy (history-list)))
    (if (or (= (# h) 0) (~= (. h (# h)) text))
        (table.insert h text))
    (while (> (# h) M.history-max)
      (table.remove h 1))
    (set vim.g.metabuffer_prompt_history h)))

(fn prompt-lines [session]
  (if (and session (vim.api.nvim_buf_is_valid session.prompt-buf))
      (vim.api.nvim_buf_get_lines session.prompt-buf 0 -1 false)
      []))

(fn prompt-text [session]
  (table.concat (prompt-lines session) "\n"))

(fn mark-prompt-buffer! [buf]
  (when (and buf (vim.api.nvim_buf_is_valid buf))
    ;; Best-effort disables for common auto-pairs/completion helpers.
    (pcall vim.api.nvim_buf_set_var buf "autopairs_enabled" false)
    (pcall vim.api.nvim_buf_set_var buf "AutoPairsDisabled" 1)
    (pcall vim.api.nvim_buf_set_var buf "delimitMate_enabled" 0)
    (pcall vim.api.nvim_buf_set_var buf "pear_tree_disable" 1)
    (pcall vim.api.nvim_buf_set_var buf "endwise_disable" 1)
    (pcall vim.api.nvim_buf_set_var buf "cmp_enabled" false)
    (pcall vim.api.nvim_buf_set_var buf "meta_prompt" true)))

(fn set-prompt-text! [session text]
  (when (and session (vim.api.nvim_buf_is_valid session.prompt-buf))
    (set session.last-prompt-text (or text ""))
    (local lines (if (= text "") [""] (vim.split text "\n" {:plain true})))
    (vim.api.nvim_buf_set_lines session.prompt-buf 0 -1 false lines)
    (let [row (# lines)
          col (# (. lines row))]
      (pcall vim.api.nvim_win_set_cursor session.prompt-win [row col]))))

(fn history-entry [session idx]
  (let [h (history-list)
        n (# h)]
    (if (and (> idx 0) (<= idx n))
        (. h (+ (- n idx) 1))
        nil)))

(fn current-buffer-path [buf]
  (if (and buf (vim.api.nvim_buf_is_valid buf))
      (let [[ok name] [(pcall vim.api.nvim_buf_get_name buf)]]
        (if (and ok (= (type name) "string") (~= name ""))
            name
            nil))
      nil))

(fn meta-buffer-name [session]
  (if session.project-mode
      "Metabuffer"
      (let [original-name (current-buffer-path session.source-buf)
            base-name (if (and (= (type original-name) "string") (~= original-name ""))
                          (vim.fn.fnamemodify original-name ":t")
                          "[No Name]")]
        (.. base-name " • Metabuffer"))))

(fn ensure-source-refs! [meta]
  (when (not meta.buf.source-refs)
    (set meta.buf.source-refs []))
  (when (< (# meta.buf.source-refs) (# meta.buf.content))
    (let [path (or (current-buffer-path meta.buf.model) "[Current Buffer]")
          model-buf (if (and meta.buf.model (vim.api.nvim_buf_is_valid meta.buf.model))
                        meta.buf.model
                        nil)]
      (for [i (+ (# meta.buf.source-refs) 1) (# meta.buf.content)]
        (table.insert meta.buf.source-refs {:path path :lnum i :buf model-buf :line (. meta.buf.content i)}))))
  meta.buf.source-refs)

(fn selected-ref [meta]
  (let [src-idx (. meta.buf.indices (+ meta.selected_index 1))
        refs (or meta.buf.source-refs [])]
    (and src-idx (. refs src-idx))))

(fn trim-or-pad-lines [lines target]
  (let [out []]
    (each [_ line (ipairs (or lines []))]
      (when (< (# out) target)
        (table.insert out (or line ""))))
    (while (< (# out) target)
      (table.insert out ""))
    out))

(fn context-lines-for-ref [session ref height]
  (let [h (math.max 1 height)
        lnum (math.max 1 (or (and ref ref.lnum) 1))
        start (math.max 1 (- lnum 1))
        stop (+ start h -1)]
    (if (and ref ref.buf (vim.api.nvim_buf_is_valid ref.buf))
        (let [lines (vim.api.nvim_buf_get_lines ref.buf (- start 1) stop false)]
          (trim-or-pad-lines lines h))
        (if (and ref ref.path (= 1 (vim.fn.filereadable ref.path)))
            (let [cache (or session.preview-file-cache {})
                  _ (set session.preview-file-cache cache)
                  all0 (. cache ref.path)
                  all (if (= (type all0) "table")
                          all0
                          (let [[ok lines] [(pcall vim.fn.readfile ref.path)]]
                            (if (and ok (= (type lines) "table"))
                                (do
                                  (set (. cache ref.path) lines)
                                  lines)
                                [])))]
              (if (= (type all) "table")
                  (let [slice []]
                    (for [i start stop]
                      (table.insert slice (or (. all i) "")))
                    (trim-or-pad-lines slice h))
                  (trim-or-pad-lines [] h)))
            (trim-or-pad-lines [] h)))))

(fn filetype-for-ref [ref]
  (if (and ref ref.buf (vim.api.nvim_buf_is_valid ref.buf))
      (. (. vim.bo ref.buf) :filetype)
      (if (and ref ref.path)
          (let [[ok ft] [(pcall vim.filetype.match {:filename ref.path})]]
            (if (and ok (= (type ft) "string")) ft ""))
          "")))

(fn ensure-ref-buffer! [session ref]
  (if (and ref ref.buf (vim.api.nvim_buf_is_valid ref.buf))
      ref.buf
      (if (and ref ref.path (= 1 (vim.fn.filereadable ref.path)))
          (let [cache (or session.preview-path-bufs {})
                _ (set session.preview-path-bufs cache)
                cached (. cache ref.path)]
            (if (and cached (vim.api.nvim_buf_is_valid cached))
                cached
                (let [[ok lines] [(pcall vim.fn.readfile ref.path)]]
                  (if (and ok (= (type lines) "table"))
                        (let [buf (vim.api.nvim_create_buf false true)
                              ft (filetype-for-ref ref)]
                        (mark-preview-buffer! buf)
                        (pcall vim.api.nvim_buf_set_name buf ref.path)
                        (let [bo (. vim.bo buf)]
                          (set (. bo :buftype) "nofile")
                          (set (. bo :bufhidden) "hide")
                          (set (. bo :swapfile) false)
                          (set (. bo :modifiable) true))
                        (vim.api.nvim_buf_set_lines buf 0 -1 false lines)
                        (let [bo (. vim.bo buf)]
                          (set (. bo :modifiable) false)
                          (set (. bo :filetype)
                               (if (and (= (type ft) "string") (~= ft ""))
                                   ft
                                   "text")))
                        (set (. cache ref.path) buf)
                        buf)
                      nil))))
          nil)))

(fn hidden-path? [path]
  (let [parts (vim.split path "/" {:plain true})]
    (var hidden false)
    (each [_ p (ipairs parts)]
      (when (and (~= p "") (vim.startswith p "."))
        (set hidden true)))
    hidden))

(fn dep-path? [path]
  (let [parts (vim.split path "/" {:plain true})]
    (var dep false)
    (each [_ p (ipairs parts)]
      (when (. M.dep-dir-names p)
        (set dep true)))
    dep))

(fn allow-project-path? [rel include-hidden include-deps]
  (let [s (or rel "")]
    (if (or (= s "") (= s "."))
        false
        (if (or (vim.startswith s ".git/") (string.find s "/.git/" 1 true))
            false
            (if (and (not include-hidden) (hidden-path? s))
                false
                (if (and (not include-deps) (dep-path? s))
                    false
                    true))))))

(fn project-file-list [root include-hidden include-ignored include-deps]
  (if (= 1 (vim.fn.executable "rg"))
      (let [cmd ["rg" "--files" "--glob" "!.git"]
            _ (when include-hidden
                (table.insert cmd "--hidden"))
            _ (when include-ignored
                (table.insert cmd "--no-ignore")
                (table.insert cmd "--no-ignore-vcs")
                (table.insert cmd "--no-ignore-parent"))
            _ (when (not include-deps)
                (table.insert cmd "--glob")
                (table.insert cmd "!node_modules/**")
                (table.insert cmd "--glob")
                (table.insert cmd "!vendor/**")
                (table.insert cmd "--glob")
                (table.insert cmd "!.venv/**")
                (table.insert cmd "--glob")
                (table.insert cmd "!venv/**")
                (table.insert cmd "--glob")
                (table.insert cmd "!dist/**")
                (table.insert cmd "--glob")
                (table.insert cmd "!build/**")
                (table.insert cmd "--glob")
                (table.insert cmd "!target/**"))
            rel (vim.fn.systemlist cmd)]
        (vim.tbl_map
          (fn [p] (vim.fn.fnamemodify (.. root "/" p) ":p"))
          (or rel [])))
      (vim.fn.globpath root "**/*" true true)))

(fn collect-project-sources [session include-hidden include-ignored include-deps]
  (let [meta session.meta
        root (vim.fn.getcwd)
        current-path (current-buffer-path session.source-buf)
        file-cache (or session.preview-file-cache {})
        _ (set session.preview-file-cache file-cache)
        content []
        refs []]
    (var total-lines 0)
    (local push-line! (fn [path lnum line]
                     (table.insert content line)
                     (table.insert refs {:path path :lnum lnum :line line})
                     (set total-lines (+ total-lines 1))))
    ;; Include current buffer first.
    (each [i line (ipairs (or session.single-content []))]
      (push-line! (or current-path "[Current Buffer]") i line))
    (when (and current-path (= (type session.single-content) "table"))
      (set (. file-cache current-path) (vim.deepcopy session.single-content)))
    (each [_ path (ipairs (project-file-list root include-hidden include-ignored include-deps))]
      (let [rel (vim.fn.fnamemodify path ":.")]
        (when (and (< total-lines M.project-max-total-lines)
                   (allow-project-path? rel include-hidden include-deps)
                   (or (not current-path) (~= (vim.fn.fnamemodify path ":p") (vim.fn.fnamemodify current-path ":p")))
                   (= 1 (vim.fn.filereadable path)))
        (let [size (vim.fn.getfsize path)]
          (when (and (>= size 0) (<= size M.project-max-file-bytes))
            (let [[ok lines] [(pcall vim.fn.readfile path)]]
              (when (and ok (= (type lines) "table"))
                (set (. file-cache path) lines)
                (each [lnum line (ipairs lines)]
                  (when (< total-lines M.project-max-total-lines)
                    (push-line! path lnum line))))))))))
    {:content content :refs refs}))

(fn apply-source-set! [session]
  (local meta session.meta)
  (if session.project-mode
      (let [pool (collect-project-sources session session.effective-include-hidden session.effective-include-ignored session.effective-include-deps)]
        (set meta.buf.content pool.content)
        (set meta.buf.source-refs pool.refs))
      (do
        (set meta.buf.content (vim.deepcopy session.single-content))
        (set meta.buf.source-refs (vim.deepcopy session.single-refs))))
  ;; Keep main results buffer as pure content lines; source context is shown
  ;; in the right floating info window.
  (set meta.buf.show-source-prefix false)
  (set meta.buf.show-source-separators session.project-mode)
  (set meta.buf.all-indices [])
  (for [i 1 (# meta.buf.content)]
    (table.insert meta.buf.all-indices i))
  (set meta.buf.indices (vim.deepcopy meta.buf.all-indices))
  (set meta.selected_index (math.max 0 (math.min meta.selected_index (math.max 0 (- (# meta.buf.indices) 1)))))
  (set meta._prev_text ""))

(fn ensure-info-window! [session]
  (when (not (and session.info-win (vim.api.nvim_win_is_valid session.info-win)))
    (let [buf (vim.api.nvim_create_buf false true)
          width M.info-min-width
          height (info-height session)
          col vim.o.columns
          row 1
          win (floating_window_mod.new vim buf {:width width :height height :col col :row row})]
      (set session.info-buf buf)
      (set session.info-win win.window)
      (let [bo (. vim.bo buf)]
        (set (. bo :buftype) "nofile")
        (set (. bo :bufhidden) "wipe")
        (set (. bo :swapfile) false)
        (set (. bo :modifiable) false)
        (set (. bo :filetype) "metabuffer")))))

(fn ensure-preview-window! [session]
  (when (not (and session.preview-win (vim.api.nvim_win_is_valid session.preview-win)))
    (let [buf (vim.api.nvim_create_buf false true)
          p-row-col (vim.api.nvim_win_get_position session.prompt-win)
          p-row (. p-row-col 1)
          p-col (. p-row-col 2)
          p-width (vim.api.nvim_win_get_width session.prompt-win)
          p-height (vim.api.nvim_win_get_height session.prompt-win)
          width (math.max 36 (math.min 128 (math.floor (* p-width 0.58))))
          col (+ p-col p-width)
          row p-row
          win (floating_window_mod.new vim buf {:width width :height p-height :col col :row row})]
      (set session.preview-buf buf)
      (set session.preview-win win.window)
      (let [bo (. vim.bo buf)
            wo (. vim.wo win.window)]
        (set (. bo :buftype) "nofile")
        ;; Keep scratch alive even when preview window temporarily shows source
        ;; buffers, otherwise it gets wiped and future fallback updates stop.
        (set (. bo :bufhidden) "hide")
        (set (. bo :swapfile) false)
        (set (. bo :modifiable) false)
        (set (. bo :filetype) "text")
        (set (. wo :number) true)
        (set (. wo :relativenumber) false)
        (set (. wo :signcolumn) "no")
        (set (. wo :foldcolumn) "0")
        (set (. wo :cursorline) true)
        (set (. wo :statusline) " Preview ")
        (mark-preview-buffer! buf))
      (apply-preview-window-opts! win.window))))

(fn close-preview-window! [session]
  (when (and session.preview-win (vim.api.nvim_win_is_valid session.preview-win))
    (pcall vim.api.nvim_win_close session.preview-win true))
  (set session.preview-win nil)
  (set session.preview-buf nil))

(fn ensure-preview-scratch-buf! [session]
  (when (or (not session.preview-buf) (not (vim.api.nvim_buf_is_valid session.preview-buf)))
    (set session.preview-buf (vim.api.nvim_create_buf false true))
    (let [bo (. vim.bo session.preview-buf)]
      (set (. bo :buftype) "nofile")
      (set (. bo :bufhidden) "hide")
      (set (. bo :swapfile) false)
      (set (. bo :modifiable) false)
      (set (. bo :filetype) "text"))
    (mark-preview-buffer! session.preview-buf)))

(fn preview-context [session]
  (let [ref (selected-ref session.meta)
        p-row-col (vim.api.nvim_win_get_position session.prompt-win)
        p-row (. p-row-col 1)
        p-col (. p-row-col 2)
        p-width (vim.api.nvim_win_get_width session.prompt-win)
        p-height (vim.api.nvim_win_get_height session.prompt-win)
        width (math.max 36 (math.min 128 (math.floor (* p-width 0.58))))
        col (+ p-col p-width)
        cfg {:relative "editor"
             :anchor "NE"
             :row p-row
             :col col
             :width width
             :height p-height}
        ft (filetype-for-ref ref)
        lines (context-lines-for-ref session ref p-height)
        start-lnum (if ref (math.max 1 (- (or ref.lnum 1) 1)) 1)
        focus-row (if ref (math.max 1 (math.min 2 p-height)) 1)]
    {:ref ref
     :p-row p-row
     :p-height p-height
     :width width
     :col col
     :cfg cfg
     :ft ft
     :lines lines
     :start-lnum start-lnum
     :focus-row focus-row}))

(fn maybe-update-preview-layout! [session ctx]
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

(fn render-preview-scratch! [session ctx]
  (when (~= (vim.api.nvim_win_get_buf session.preview-win) session.preview-buf)
    (pcall vim.api.nvim_win_set_buf session.preview-win session.preview-buf))
  (let [bo (. vim.bo session.preview-buf)]
    (set (. bo :modifiable) true))
  (vim.api.nvim_buf_set_lines session.preview-buf 0 -1 false (. ctx :lines))
  (let [b (. vim.b session.preview-buf)
        start (or (. ctx :start-lnum) 1)
        stop (+ start (math.max 0 (- (# (. ctx :lines)) 1)))
        width (lnum-width-from-max-value stop)]
    (set (. b :meta_preview_start_lnum) start)
    (set (. b :meta_preview_lnum_width) width)
    (pcall vim.api.nvim_set_option_value "numberwidth" width {:win session.preview-win}))
  (let [bo (. vim.bo session.preview-buf)
        ft (. ctx :ft)]
    (set (. bo :modifiable) false)
    (let [next-ft (if (and (= (type ft) "string") (~= ft ""))
                      ft
                      "text")]
      (when (~= (. bo :filetype) next-ft)
        (set (. bo :filetype) next-ft))))
  (pcall vim.api.nvim_win_set_cursor session.preview-win [(. ctx :focus-row) 0]))

(fn update-preview-window! [session]
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
        (render-preview-scratch! session ctx)))))

(fn schedule-preview-update! [session]
  (when (and session (not session.preview-update-pending))
    (set session.preview-update-pending true)
    (vim.defer_fn
      (fn []
        (set session.preview-update-pending false)
        (when (and session
                   session.prompt-buf
                   (= (. M.active-by-prompt session.prompt-buf) session))
          (pcall update-preview-window! session)))
      16)))

(fn fit-info-width! [session lines]
  (when (and session.info-win (vim.api.nvim_win_is_valid session.info-win))
    (let [widths (vim.tbl_map (fn [line] (# line)) (or lines []))
          unpack-fn (or table.unpack unpack)
          max-len (if (and (> (# widths) 0) unpack-fn) (math.max (unpack-fn widths)) 0)
          needed max-len
          max-available (math.max M.info-min-width (math.floor (* vim.o.columns 0.34)))
          upper (math.min M.info-max-width max-available)
          target (math.max M.info-min-width (math.min needed upper))
          height (info-height session)
          cfg {:relative "editor"
               :anchor "NE"
               :row 1
               :col vim.o.columns
               :width target
               :height height}]
      (pcall vim.api.nvim_win_set_config session.info-win cfg))))

(fn info-max-width-now []
  (let [max-available (math.max M.info-min-width (math.floor (* vim.o.columns 0.34)))]
    (math.min M.info-max-width max-available)))

(fn ext-from-path [path]
  (let [file (vim.fn.fnamemodify (or path "") ":t")
        dot (string.match file ".*()%.")]
    (if (and dot (> dot 0) (< dot (# file)))
        (string.sub file (+ dot 1))
        "")))

(fn devicon-for-path [path fallback-hl]
  (let [file (vim.fn.fnamemodify (or path "") ":t")
        ext (ext-from-path path)
        [ok-web web] [(pcall require :nvim-web-devicons)]]
    (if (and ok-web web)
        (let [[ok-i icon icon-hl] [(pcall web.get_icon file ext {:default true})]
              file-hl fallback-hl]
          {:icon (if (and ok-i (= (type icon) "string") (~= icon "")) icon "")
           :icon-hl (if (and ok-i (= (type icon-hl) "string") (~= icon-hl "")) icon-hl fallback-hl)
           :file-hl file-hl})
        (if (= 1 (vim.fn.exists "*WebDevIconsGetFileTypeSymbol"))
            (let [icon (vim.fn.WebDevIconsGetFileTypeSymbol file)]
              {:icon (if (and (= (type icon) "string") (~= icon "")) icon "")
               :icon-hl fallback-hl
               :file-hl fallback-hl})
            {:icon "" :icon-hl fallback-hl :file-hl fallback-hl}))))

(fn icon-field [icon]
  (if (and (= (type icon) "string") (~= icon ""))
      (let [text (.. icon " ")]
        {:text text :width (vim.fn.strdisplaywidth text)})
      {:text "" :width 0}))

(fn compact-dir [dir]
  (if (or (= dir "") (= dir "."))
      ""
      (let [parts (vim.split dir "/" {:plain true})
            out []]
        (each [_ p (ipairs (or parts []))]
          (when (~= p "")
            (table.insert out (string.sub p 1 1))))
        (if (= (# out) 0)
            ""
            (.. (table.concat out "/") "/")))))

(fn compact-dir-keep-last [dir]
  (if (or (= dir "") (= dir "."))
      ""
      (let [parts0 (vim.split dir "/" {:plain true})
            parts []]
        (each [_ p (ipairs (or parts0 []))]
          (when (~= p "")
            (table.insert parts p)))
        (let [n (# parts)]
          (if (= n 0)
              ""
              (if (= n 1)
                  (.. (. parts 1) "/")
                  (let [out []]
                    (for [i 1 (- n 1)]
                      (table.insert out (string.sub (. parts i) 1 1)))
                    (table.insert out (. parts n))
                    (.. (table.concat out "/") "/"))))))))

(fn fit-path-into-width [path path-width]
  (let [dir0 (vim.fn.fnamemodify path ":h")
        dir (if (or (= dir0 ".") (= dir0 "")) "" (.. dir0 "/"))
        file (vim.fn.fnamemodify path ":t")
        budget (math.max 1 path-width)
        full (.. dir file)]
    (if (<= (# full) budget)
        [dir file]
        (let [kdir (compact-dir-keep-last dir0)
              keep-last (.. kdir file)]
          (if (<= (# keep-last) budget)
              [kdir file]
              (let [cdir (compact-dir dir0)
                    compact (.. cdir file)]
                (if (<= (# compact) budget)
                    [cdir file]
                    (if (> (# file) budget)
                        ["" (if (> budget 3)
                                (.. "..." (string.sub file (+ (- (# file) budget) 4)))
                                (string.sub file (+ (- (# file) budget) 1)))]
                        (let [dir-budget (math.max 0 (- budget (# file)))
                              short-dir (if (<= (# cdir) dir-budget)
                                            cdir
                                            (if (> dir-budget 3)
                                                (.. "..." (string.sub cdir (+ (- (# cdir) dir-budget) 4)))
                                                (string.sub cdir (+ (- (# cdir) dir-budget) 1))))]
                          [short-dir file])))))))))

(fn info-range [selected-index total cap]
  (if (or (<= total 0) (<= cap 0))
      [1 0]
      (if (<= total cap)
          [1 total]
          (let [sel (math.max 1 (math.min total (+ selected-index 1)))
                half (math.floor (/ cap 2))
                start (math.max 1 (math.min (- sel half) (+ (- total cap) 1)))
                stop (math.min total (+ start cap -1))]
            [start stop]))))

(fn build-info-lines [meta refs idxs target-width start-index stop-index]
  (let [line-hl "LineNr"
        dir-hl (if (= 1 (vim.fn.hlexists "NERDTreeDir"))
                   "NERDTreeDir"
                   (if (= 1 (vim.fn.hlexists "NetrwDir")) "NetrwDir" "Directory"))
        file-hl (if (= 1 (vim.fn.hlexists "NERDTreeFile"))
                    "NERDTreeFile"
                    (if (= 1 (vim.fn.hlexists "NetrwPlain"))
                        "NetrwPlain"
                        (if (= 1 (vim.fn.hlexists "NvimTreeFileName"))
                            "NvimTreeFileName"
                            "Normal")))
        lnum-width (let [limit (math.min (# idxs) M.info-max-lines)
                         max-lnum-len (if (> limit 0)
                                          (let [lens []]
                                            (for [i 1 limit]
                                              (let [src-idx (. idxs i)
                                                    ref (. refs src-idx)
                                                    lnum (tostring (or (and ref ref.lnum) src-idx))]
                                                (table.insert lens (# lnum))))
                                            (let [unpack-fn (or table.unpack unpack)]
                                              (if (and unpack-fn (> (# lens) 0))
                                                  (math.max (unpack-fn lens))
                                                  1)))
                                          1)]
                     (lnum-width-from-max-len max-lnum-len))
        path-width (math.max 1 (- target-width lnum-width))
        lines []
        highlights []]
    (if (= (# idxs) 0)
        (table.insert lines "No hits")
        (do
          (for [i start-index stop-index]
            (let [src-idx (. idxs i)
                  ref (. refs src-idx)
                  lnum (tostring (or (and ref ref.lnum) src-idx))
                  lnum-cell (lnum-cell lnum lnum-width)
                  path (vim.fn.fnamemodify (or (and ref ref.path) "[Current Buffer]") ":~:.")
                  icon-info (devicon-for-path path file-hl)
                  icon (or (. icon-info :icon) "")
                  iconf (icon-field icon)
                  icon-prefix (. iconf :text)
                  icon-hl (or (. icon-info :icon-hl) file-hl)
                  icon-width (. iconf :width)
                  [dir file0] (fit-path-into-width path (math.max 1 (- path-width icon-width)))
                  file (.. icon-prefix file0)
                  this-file-hl (or (. icon-info :file-hl) file-hl)
                  row (# lines)
                  line (.. lnum-cell icon-prefix dir file0)
                  num-start 0
                  num-end (+ num-start (# lnum-cell))
                  icon-start num-end
                  icon-end (+ icon-start (# icon-prefix))
                  dir-start icon-end
                  file-start (+ dir-start (# dir))]
              (table.insert lines line)
              (table.insert highlights [row line-hl num-start num-end])
              (when (> (# icon-prefix) 0)
                (table.insert highlights [row icon-hl icon-start icon-end]))
              (when (> (# dir) 0)
                (table.insert highlights [row dir-hl dir-start (+ dir-start (# dir))]))
              (table.insert highlights [row this-file-hl file-start (+ file-start (# file0))])))))
    {:lines lines :highlights highlights}))

(fn close-info-window! [session]
  (when (and session.info-win (vim.api.nvim_win_is_valid session.info-win))
    (pcall vim.api.nvim_win_close session.info-win true))
  (set session.info-win nil)
  (set session.info-buf nil))

(fn render-info-lines! [session meta]
  (let [refs (or meta.buf.source-refs [])
        idxs (or meta.buf.indices [])
        total (# idxs)
        [start-index stop-index] (info-range meta.selected_index total M.info-max-lines)
        _ (set session.info-start-index start-index)
        _ (set session.info-stop-index stop-index)
        built (build-info-lines meta refs idxs (info-max-width-now) start-index stop-index)
        raw-lines (. built :lines)
        lines (if (= (type raw-lines) "table")
                  (vim.tbl_map tostring raw-lines)
                  [(tostring raw-lines)])
        highlights (or (. built :highlights) [])
        ns (vim.api.nvim_create_namespace "MetaInfoWindow")]
    (debug-log (.. "info render hits=" (tostring (# idxs))
                   " lines=" (tostring (# lines))))
    (let [bo (. vim.bo session.info-buf)]
      (set (. bo :modifiable) true))
    (fit-info-width! session lines)
    (let [[ok-set err-set] [(pcall vim.api.nvim_buf_set_lines session.info-buf 0 -1 false lines)]]
      (when (not ok-set)
        (debug-log (.. "info set_lines failed: " (tostring err-set)))))
    (vim.api.nvim_buf_clear_namespace session.info-buf ns 0 -1)
    (each [_ h (ipairs highlights)]
      (vim.api.nvim_buf_add_highlight session.info-buf ns (. h 2) (. h 1) (. h 3) (. h 4)))
    (let [bo (. vim.bo session.info-buf)]
      (set (. bo :modifiable) false))))

(fn sync-info-cursor! [session meta]
  (when (vim.api.nvim_win_is_valid session.info-win)
    (let [idxs (or meta.buf.indices [])
          info-lines (vim.api.nvim_buf_line_count session.info-buf)
          start-index (or session.info-start-index 1)
          stop-index (or session.info-stop-index (math.min (# idxs) M.info-max-lines))
          hits-shown (if (>= stop-index start-index) (+ (- stop-index start-index) 1) 0)
          hits-total (# idxs)
          status (.. " Hits " hits-shown "/" hits-total " ")
          selected1 (+ meta.selected_index 1)
          row (if (> info-lines 0)
                  (math.max 1 (math.min (+ (- selected1 start-index) 1) info-lines))
                  1)]
      (pcall vim.api.nvim_win_set_option session.info-win "statusline" status)
      (when (> info-lines 0)
        (let [[ok-cur err-cur] [(pcall vim.api.nvim_win_set_cursor session.info-win [row 0])]]
          (when (not ok-cur)
            (debug-log (.. "info set_cursor failed: " (tostring err-cur)))))))))

(fn update-info-window-regular! [session]
  (close-info-window! session)
  (update-preview-window! session))

(fn update-info-window-project! [session refresh-lines]
  (ensure-info-window! session)
  (debug-log (.. "info enter refresh=" (tostring refresh-lines)
                 " selected=" (tostring session.meta.selected_index)
                 " info-win=" (tostring session.info-win)
                 " info-buf=" (tostring session.info-buf)))
  (when (and session.info-buf (vim.api.nvim_buf_is_valid session.info-buf))
    (let [meta session.meta]
      (let [selected1 (+ meta.selected_index 1)
            start-index (or session.info-start-index 1)
            stop-index (or session.info-stop-index 0)
            out-of-range (or (< selected1 start-index) (> selected1 stop-index))]
      (when (or refresh-lines out-of-range)
        (let [idxs (or meta.buf.indices [])
              sig (.. (tostring idxs)
                      "|"
                      (tostring (# idxs))
                      "|"
                      (tostring (info-max-width-now))
                      "|"
                      (tostring (info-height session))
                      "|"
                      (tostring vim.o.columns))]
          ;; Selection can move outside the currently rendered slice while
          ;; indices/layout stay identical. In that case we must rerender to
          ;; recentre the info window range.
          (when (or out-of-range (~= session.info-render-sig sig))
            (set session.info-render-sig sig)
            (render-info-lines! session meta)))))
      (sync-info-cursor! session meta)))
  (update-preview-window! session))

(set update-info-window
  (fn [session refresh-lines]
    (let [refresh-lines (if (= refresh-lines nil) true refresh-lines)]
      (if session.project-mode
          (update-info-window-project! session refresh-lines)
          (update-info-window-regular! session)))))

(fn wipe-temp-buffers [meta]
  (when meta
    (let [main-buf meta.buf.buffer
          model-buf meta.buf.model
          index-buf (and meta.buf.indexbuf meta.buf.indexbuf.buffer)]
      (when (and index-buf (not (= index-buf model-buf)) (vim.api.nvim_buf_is_valid index-buf))
        (pcall vim.api.nvim_buf_delete index-buf {:force true}))
      (when (and main-buf (not (= main-buf model-buf)) (vim.api.nvim_buf_is_valid main-buf))
        (pcall vim.api.nvim_buf_delete main-buf {:force true})))))

(fn setup-state [query mode source-view]
  (if (and (= mode "resume") vim.b._meta_context)
      (let [ctx (vim.deepcopy vim.b._meta_context)]
        (when (and query (~= query ""))
          (set ctx.text query)
          (set ctx.caret-locus (# query)))
        (when source-view
          (set ctx.source-view source-view))
        ctx)
      (let [ctx (state.default-condition (or query ""))]
        (when source-view
          (set ctx.source-view source-view))
        ctx)))

(fn restore-meta-view! [meta source-view]
  (when (and meta (vim.api.nvim_win_is_valid meta.win.window))
    (let [line-count (vim.api.nvim_buf_line_count meta.buf.buffer)
          line (math.max 1 (math.min (meta.selected_line) line-count))
          src-view (or source-view {})
          src-lnum (or (. src-view :lnum) line)
          src-topline (or (. src-view :topline) src-lnum)
          offset (math.max 0 (- src-lnum src-topline))
          topline (math.max 1 (math.min (- line offset) line-count))]
      (vim.api.nvim_win_call meta.win.window
        (fn []
          (local view (vim.fn.winsaveview))
          (set (. view :lnum) line)
          (set (. view :topline) topline)
          (when (~= (. src-view :leftcol) nil)
            (set (. view :leftcol) (. src-view :leftcol)))
          (when (~= (. src-view :col) nil)
            (set (. view :col) (. src-view :col)))
          (vim.fn.winrestview view))))))

(fn M._store_vars [meta]
  (set vim.b._meta_context (meta.store))
  (set vim.b._meta_indexes meta.buf.indices)
  (set vim.b._meta_updates meta.updates)
  (set vim.b._meta_source_bufnr meta.buf.model)
  meta)

(fn M._wrapup [meta]
  (vim.cmd "redraw|redrawstatus")
  (M._store_vars meta))

(fn remove-session [session]
  (when session
    (push-history! (or session.last-prompt-text
                       (if (and session.prompt-buf (vim.api.nvim_buf_is_valid session.prompt-buf))
                           (prompt-text session)
                           "")))
    (persist-prompt-height! session)
    (when session.augroup
      (pcall vim.api.nvim_del_augroup_by_id session.augroup))
    (when (and session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
      (pcall vim.api.nvim_win_close session.prompt-win true))
    (when (and session.prompt-buf (vim.api.nvim_buf_is_valid session.prompt-buf))
      (pcall vim.api.nvim_buf_delete session.prompt-buf {:force true}))
    (close-info-window! session)
    (close-preview-window! session)
    (when session.source-buf
      (set (. M.active-by-source session.source-buf) nil))
    (when session.prompt-buf
      (set (. M.active-by-prompt session.prompt-buf) nil))))

(fn apply-prompt-lines [session]
  (when (and session (vim.api.nvim_buf_is_valid session.prompt-buf))
    (let [lines (vim.api.nvim_buf_get_lines session.prompt-buf 0 -1 false)]
      (set session.last-prompt-text (table.concat lines "\n"))
      (let [parsed (if session.project-mode
                       (parse-query-lines lines)
                       {:lines lines :include-ignored nil :include-deps nil})
            next-ignored (if (= (. parsed :include-ignored) nil)
                             session.include-ignored
                             (. parsed :include-ignored))
            next-deps (if (= (. parsed :include-deps) nil)
                          session.include-deps
                          (. parsed :include-deps))
            next-hidden (if (= (. parsed :include-hidden) nil)
                            session.include-hidden
                            (. parsed :include-hidden))
            changed (or (~= next-hidden session.effective-include-hidden)
                        (~= next-ignored session.effective-include-ignored)
                        (~= next-deps session.effective-include-deps))]
        (set session.effective-include-hidden next-hidden)
        (set session.effective-include-ignored next-ignored)
        (set session.effective-include-deps next-deps)
        (set session.meta.debug_out
          (if session.project-mode
              (.. " ["
                  (if session.effective-include-hidden "+hidden" "-hidden")
                  " "
                  (if session.effective-include-ignored "+ignored" "-ignored")
                  " "
                  (if session.effective-include-deps "+deps" "-deps")
                  "]")
              ""))
        (when (and session.project-mode changed)
          (apply-source-set! session))
        (session.meta.set-query-lines (. parsed :lines)))
      (let [[ok err] [(pcall session.meta.on-update 0)]]
        (if ok
            (do
              (session.meta.refresh_statusline)
              (update-info-window session))
            (when (string.find (tostring err) "E565")
              ;; Textlock race: retry right after current input cycle.
              (vim.defer_fn (fn []
                              (when (and session.meta
                                         (vim.api.nvim_buf_is_valid session.meta.buf.buffer))
                                (pcall session.meta.on-update 0)
                                (pcall session.meta.refresh_statusline)
                                (pcall update-info-window session)))
                            1)))))))

(fn M.on-prompt-changed [prompt-buf]
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      ;; Buffer change callbacks run under textlock; schedule updates so
      ;; rendering and window mutations are allowed.
      (vim.schedule (fn []
                      (apply-prompt-lines session))))))

(fn finish-accept [session]
  (local curr session.meta)
  (set session.last-prompt-text (prompt-text session))
  (push-history! session.last-prompt-text)
  (apply-prompt-lines session)
  (pcall vim.cmd "stopinsert")
  (let [matcher (curr.matcher)]
    (when matcher
      (pcall matcher.remove-highlight matcher)))
  (pcall vim.cmd (.. "sign unplace * buffer=" curr.buf.buffer))
  (when (and (vim.api.nvim_win_is_valid session.origin-win)
             (vim.api.nvim_buf_is_valid session.origin-buf))
    (pcall vim.api.nvim_set_current_win session.origin-win)
    (pcall vim.api.nvim_win_set_buf session.origin-win session.origin-buf))
  (if session.project-mode
      (let [ref (selected-ref curr)]
        (when (and ref ref.path)
          (vim.cmd (.. "edit " (vim.fn.fnameescape ref.path)))
          (vim.api.nvim_win_set_cursor 0 [(math.max 1 (or ref.lnum 1)) 0])))
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
  (wipe-temp-buffers curr)
  (remove-session session)
  (M._wrapup curr)
  curr)

(fn finish-cancel [session]
  (local curr session.meta)
  (set session.last-prompt-text (prompt-text session))
  (push-history! session.last-prompt-text)
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
  (wipe-temp-buffers curr)
  (remove-session session)
  (M._wrapup curr)
  curr)

(fn M.finish [kind prompt-buf]
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (if (= kind "accept")
          (finish-accept session)
          (finish-cancel session)))))

(fn M.move-selection [prompt-buf delta]
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

(fn sync-selected-from-main-cursor! [session]
  (let [meta session.meta
        max (# meta.buf.indices)]
    (if (<= max 0)
        (set meta.selected_index 0)
        (when (vim.api.nvim_win_is_valid meta.win.window)
          (let [c (vim.api.nvim_win_get_cursor meta.win.window)
                row (. c 1)
                clamped (math.max 1 (math.min row max))]
            (when (~= row clamped)
              (pcall vim.api.nvim_win_set_cursor meta.win.window [clamped (. c 2)]))
            (set meta.selected_index (- clamped 1)))))))

(fn M.scroll-main [prompt-buf action]
  (let [session (. M.active-by-prompt prompt-buf)]
    (when (and session (vim.api.nvim_win_is_valid session.meta.win.window))
      (let [runner (fn []
                     (vim.api.nvim_win_call session.meta.win.window
                       (fn []
                         (let [line-count (vim.api.nvim_buf_line_count session.meta.buf.buffer)
                               win-height (math.max 1 (vim.api.nvim_win_get_height session.meta.win.window))
                               half-step (math.max 1 (math.floor (/ win-height 2)))
                               page-step (math.max 1 (- win-height 2))
                               step (if (or (= action "half-down") (= action "half-up")) half-step page-step)
                               dir (if (or (= action "half-down") (= action "page-down")) 1 -1)
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
                     (sync-selected-from-main-cursor! session)
                     (pcall session.meta.refresh_statusline)
                     (pcall update-info-window session false))
            mode (. (vim.api.nvim_get_mode) :mode)]
        (if (and (= (type mode) "string") (vim.startswith mode "i"))
            (vim.schedule runner)
            (runner))))))

(fn maybe-sync-from-main! [session force-refresh]
  (when (and session
             (vim.api.nvim_win_is_valid session.meta.win.window)
             (vim.api.nvim_buf_is_valid session.prompt-buf)
             (= (. M.active-by-prompt session.prompt-buf) session))
    (let [before session.meta.selected_index]
      (sync-selected-from-main-cursor! session)
      (when (or force-refresh (~= before session.meta.selected_index))
        (pcall session.meta.refresh_statusline)
        (pcall update-info-window session false)))))

(fn schedule-scroll-sync! [session]
  (when (and session (not session.scroll-sync-pending))
    (set session.scroll-sync-pending true)
    (vim.defer_fn
      (fn []
        (set session.scroll-sync-pending false)
        (maybe-sync-from-main! session true))
      20)))

(fn M.history-or-move [prompt-buf delta]
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (let [txt (prompt-text session)
            can-history (or (= txt "")
                            (= txt session.initial-prompt-text)
                            (= txt session.last-history-text))]
        (if can-history
            (let [h (history-list)
                  n (# h)]
              (when (> n 0)
                (set session.history-index (math.max 0 (math.min (+ session.history-index delta) n)))
                (if (= session.history-index 0)
                    (do
                      (set session.last-history-text "")
                      (set-prompt-text! session session.initial-prompt-text))
                    (let [entry (history-entry session session.history-index)]
                      (when entry
                        (set session.last-history-text entry)
                        (set-prompt-text! session entry))))))
            (M.move-selection prompt-buf delta))))))

(fn M.toggle-scan-option [prompt-buf which]
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (if (= which "ignored")
          (set session.include-ignored (not session.include-ignored))
          (if (= which "deps")
              (set session.include-deps (not session.include-deps))
              (when (= which "hidden")
                (set session.include-hidden (not session.include-hidden)))))
      (set session.effective-include-hidden session.include-hidden)
      (set session.effective-include-ignored session.include-ignored)
      (set session.effective-include-deps session.include-deps)
      (when session.project-mode
        (apply-source-set! session))
      (apply-prompt-lines session))))

(fn M.toggle-project-mode [prompt-buf]
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (set session.project-mode (not session.project-mode))
      (set session.meta.project-mode session.project-mode)
      (session.meta.buf.set-name (meta-buffer-name session))
      (apply-source-set! session)
      (apply-prompt-lines session))))

(fn register-prompt-hooks [session]
  (fn disable-cmp []
    (mark-prompt-buffer! session.prompt-buf)
    (let [[ok cmp] [(pcall require :cmp)]]
      (when ok
        (pcall cmp.setup.buffer {:enabled false})
        (pcall cmp.abort))))
  (fn switch-mode [which]
    (let [meta session.meta]
      (meta.switch_mode which)
      (pcall meta.refresh_statusline)))
  (fn apply-keymaps []
    (local opts {:buffer session.prompt-buf :silent true :noremap true :nowait true})
    (fn map! [m lhs rhs]
      (vim.keymap.set m lhs rhs opts))
    (fn map-rules! [rules]
      (each [_ r (ipairs rules)]
        (map! (. r 1) (. r 2) (. r 3))))
    (map-rules!
      [ [["n" "i"] "<CR>" (fn [] (M.finish "accept" session.prompt-buf))]
        ;; In insert mode, <Esc> should only leave insert mode.
        ;; Cancel/close only from normal mode.
        ["n" "<Esc>" (fn [] (M.finish "cancel" session.prompt-buf))]
        ["n" "<C-p>" (fn [] (M.move-selection session.prompt-buf -1))]
        ["n" "<C-n>" (fn [] (M.move-selection session.prompt-buf 1))]
        ["i" "<C-p>" (fn [] (M.move-selection session.prompt-buf -1))]
        ["i" "<C-n>" (fn [] (M.move-selection session.prompt-buf 1))]
        ["n" "<C-k>" (fn [] (M.move-selection session.prompt-buf -1))]
        ["n" "<C-j>" (fn [] (M.move-selection session.prompt-buf 1))]
        ["i" "<C-k>" (fn [] (M.move-selection session.prompt-buf -1))]
        ["i" "<C-j>" (fn [] (M.move-selection session.prompt-buf 1))]
        ["i" "<Up>" (fn [] (M.history-or-move session.prompt-buf 1))]
        ["i" "<Down>" (fn [] (M.history-or-move session.prompt-buf -1))]
        ["n" "<Up>" (fn [] (M.history-or-move session.prompt-buf 1))]
        ["n" "<Down>" (fn [] (M.history-or-move session.prompt-buf -1))]
        ;; Statusline keys: C^ (matcher), C_ (case), Cs (syntax)
        [["n" "i"] "<C-^>" (fn [] (switch-mode "matcher"))]
        [["n" "i"] "<C-6>" (fn [] (switch-mode "matcher"))]
        [["n" "i"] "<C-_>" (fn [] (switch-mode "case"))]
        [["n" "i"] "<C-/>" (fn [] (switch-mode "case"))]
        [["n" "i"] "<C-?>" (fn [] (switch-mode "case"))]
        [["n" "i"] "<C-->" (fn [] (switch-mode "case"))]
        [["n" "i"] "<C-o>" (fn [] (switch-mode "case"))]
        [["n" "i"] "<C-s>" (fn [] (switch-mode "syntax"))]
        ["n" "<C-g>" (fn [] (M.toggle-scan-option session.prompt-buf "ignored"))]
        ["n" "<C-l>" (fn [] (M.toggle-scan-option session.prompt-buf "deps"))]
        [["n" "i"] "<C-d>" (fn [] (M.scroll-main session.prompt-buf "half-down"))]
        [["n" "i"] "<C-u>" (fn [] (M.scroll-main session.prompt-buf "half-up"))]
        [["n" "i"] "<C-f>" (fn [] (M.scroll-main session.prompt-buf "page-down"))]
        [["n" "i"] "<C-b>" (fn [] (M.scroll-main session.prompt-buf "page-up"))]
        ;; keep project toggle available without conflicting with scroll/page keys
        [["n" "i"] "<C-t>" (fn [] (M.toggle-project-mode session.prompt-buf))] ]))
  (local aug (vim.api.nvim_create_augroup (.. "MetaPrompt" session.prompt-buf) {:clear true}))
  (set session.augroup aug)
  ;; Low-level buffer attach catches edits reliably across Insert/Normal modes
  ;; and user configs where TextChangedI autocmds may not fire as expected.
  (vim.api.nvim_buf_attach session.prompt-buf false
    {:on_lines (fn [_ _ _ _ _ _ _ _]
                 (M.on-prompt-changed session.prompt-buf))
     :on_detach (fn []
                  (when session.prompt-buf
                    (set (. M.active-by-prompt session.prompt-buf) nil)))})
  ;; Keep autocmd hooks as a fallback.
  (vim.api.nvim_create_autocmd ["TextChanged" "TextChangedI"]
    {:group aug
     :buffer session.prompt-buf
     :callback (fn [_]
                 (M.on-prompt-changed session.prompt-buf))})
  ;; Re-assert prompt maps when entering insert mode; this wins over late
  ;; plugin mappings (for example completion plugins).
  (vim.api.nvim_create_autocmd "InsertEnter"
    {:group aug
     :buffer session.prompt-buf
     :callback (fn [_]
                 (vim.schedule
                   (fn []
                     (disable-cmp)
                     (apply-keymaps))))})
  ;; Some statusline plugins or focus transitions (for example tmux pane
  ;; switches) can overwrite local statusline state. Re-apply ours when the
  ;; prompt window regains focus.
  (vim.api.nvim_create_autocmd ["BufEnter" "WinEnter" "FocusGained"]
    {:group aug
     :buffer session.prompt-buf
     :callback (fn [_]
                 (vim.schedule
                   (fn []
                     (when (and session.meta
                                (vim.api.nvim_buf_is_valid session.prompt-buf))
                       (pcall session.meta.refresh_statusline)))))})
  ;; Refresh mode segment when switching Insert/Normal/Replace in the prompt.
  (vim.api.nvim_create_autocmd ["ModeChanged" "InsertEnter" "InsertLeave"]
    {:group aug
     :buffer session.prompt-buf
     :callback (fn [_]
                 (vim.schedule
                   (fn []
                     (when (and session.meta
                                (vim.api.nvim_buf_is_valid session.prompt-buf))
                       (pcall session.meta.refresh_statusline)))))})
  ;; Recompute floating info rendering/width when editor windows resize.
  (vim.api.nvim_create_autocmd ["VimResized" "WinResized"]
    {:group aug
     :callback (fn [_]
                 (vim.schedule
                   (fn []
                     (when (and session.meta
                                (vim.api.nvim_buf_is_valid session.prompt-buf))
                       (pcall update-info-window session)))))})
  ;; Keep selection/status/info synced when user scrolls or moves in the
  ;; main meta window with regular motions/mouse while prompt is open.
  (vim.api.nvim_create_autocmd ["CursorMoved" "CursorMovedI"]
    {:group aug
     :buffer session.meta.buf.buffer
     :callback (fn [_]
                 (vim.schedule
                   (fn []
                     (maybe-sync-from-main! session))))})
  (vim.api.nvim_create_autocmd "WinScrolled"
    {:group aug
     :callback (fn [_]
                 (schedule-scroll-sync! session))})
  (disable-cmp)
  (mark-prompt-buffer! session.prompt-buf)
  (apply-keymaps)
  )

(fn M.start [query mode _meta project-mode]
  (let [parsed-query (parse-query-text query)
        query0 (. parsed-query :query)
        start-hidden (if (= (. parsed-query :include-hidden) nil)
                         (truthy? M.default-include-hidden)
                         (. parsed-query :include-hidden))
        start-ignored (if (= (. parsed-query :include-ignored) nil)
                          (truthy? M.default-include-ignored)
                          (. parsed-query :include-ignored))
        start-deps (if (= (. parsed-query :include-deps) nil)
                       (truthy? M.default-include-deps)
                       (. parsed-query :include-deps))
        query query0]
  (local source-buf (vim.api.nvim_get_current_buf))
  (when (. M.active-by-source source-buf)
    (remove-session (. M.active-by-source source-buf)))
  (let [origin-win (vim.api.nvim_get_current_win)
        origin-buf source-buf
        source-view (vim.fn.winsaveview)
        _ (set (. source-view :_meta_win_height) (vim.api.nvim_win_get_height origin-win))
        condition (setup-state query mode source-view)
        curr (meta_mod.new vim condition)]
    (set curr.project-mode (or project-mode false))
    (base_buffer.switch-buf curr.buf.buffer)
    (ensure-source-refs! curr)
    (curr.on-init)
    (let [initial-lines (if (and query (~= query ""))
                            (vim.split query "\n" {:plain true})
                            [""])
          prompt-win (prompt_window_mod.new vim {:height (prompt-height)})
          prompt-buf prompt-win.buffer
          session {:source-buf source-buf
                   :origin-win origin-win
                   :origin-buf origin-buf
                   :prompt-win prompt-win.window
                   :prompt-buf prompt-buf
                   :initial-prompt-text (table.concat initial-lines "\n")
                   :last-prompt-text (table.concat initial-lines "\n")
                   :last-history-text ""
                   :history-index 0
                   :project-mode (or project-mode false)
                   :include-hidden start-hidden
                   :include-ignored start-ignored
                   :include-deps start-deps
                   :effective-include-hidden start-hidden
                   :effective-include-ignored start-ignored
                   :effective-include-deps start-deps
                   :single-content (vim.deepcopy curr.buf.content)
                   :single-refs (vim.deepcopy (or curr.buf.source-refs []))
                   :meta curr}]
      (apply-source-set! session)
      (set curr.status-win (meta_window_mod.new vim prompt-win.window))
      ;; Statusline info should live in prompt window, not result split.
      (curr.win.set-statusline "")
      (vim.api.nvim_buf_set_lines prompt-buf 0 -1 false initial-lines)
      (mark-prompt-buffer! prompt-buf)
      (register-prompt-hooks session)
      (set (. M.active-by-source source-buf) session)
      (set (. M.active-by-prompt prompt-buf) session)
      (apply-prompt-lines session)
      ;; Opening prompt split resizes the meta window, which can shift scroll.
      ;; Re-apply source-relative view after layout settles.
      (restore-meta-view! curr source-view)
      (vim.api.nvim_set_current_win prompt-win.window)
      (vim.cmd "startinsert")
      (set (. M.instances source-buf) curr)
      curr))))

(fn M.sync [meta query]
  (if (not meta)
      (do (vim.notify "No Meta instance" vim.log.levels.WARN) nil)
      (do
        (meta.set-query-lines (if (and query (~= query "")) [query] []))
        (meta.on-update 0)
        (M._store_vars meta)
        meta)))

(fn M.push [meta]
  (if (not meta)
      (vim.notify "No Meta instance" vim.log.levels.WARN)
      (let [lines (vim.api.nvim_buf_get_lines meta.buf.buffer 0 -1 false)]
        (meta.buf.push-visible-lines lines))))

(fn M.entry_start [query _bang]
  (M.start query "start" nil _bang))

(fn M.entry_resume [query]
  (M.start query "resume" nil))

(fn M.entry_sync [query]
  (local key (vim.api.nvim_get_current_buf))
  (M.sync (. M.instances key) query))

(fn M.entry_push []
  (local key (vim.api.nvim_get_current_buf))
  (M.push (. M.instances key)))

(fn M.entry_cursor_word [resume]
  (local w (vim.fn.expand "<cword>"))
  (if resume
      (M.entry_resume w)
      (M.entry_start w false)))

M
