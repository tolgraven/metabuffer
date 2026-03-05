(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(fn M.prompt-height
  []
  (or (tonumber vim.g.meta_prompt_height)
      (tonumber (. vim.g "meta#prompt_height"))
      7))

(fn M.persist-prompt-height!
  [session]
  (when (and session session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
    (let [[ok h] [(pcall vim.api.nvim_win_get_height session.prompt-win)]]
      (when (and ok h (> h 0))
        (set vim.g.meta_prompt_height h)
        (set (. vim.g "meta#prompt_height") h)))))

(fn M.info-height
  [session]
  (if (and session session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
      (let [p-row-col (vim.api.nvim_win_get_position session.prompt-win)
            p-row (. p-row-col 1)]
        (math.max 7 (- p-row 2)))
      (math.max 7 (- vim.o.lines (+ (M.prompt-height) 4)))))

(fn M.prompt-lines
  [session]
  (if (and session (vim.api.nvim_buf_is_valid session.prompt-buf))
      (vim.api.nvim_buf_get_lines session.prompt-buf 0 -1 false)
      []))

(fn M.prompt-text
  [session]
  (table.concat (M.prompt-lines session) "\n"))

(fn M.mark-prompt-buffer!
  [buf]
  (when (and buf (vim.api.nvim_buf_is_valid buf))
    ;; Best-effort disables for common auto-pairs/completion helpers.
    (pcall vim.api.nvim_buf_set_var buf "autopairs_enabled" false)
    (pcall vim.api.nvim_buf_set_var buf "AutoPairsDisabled" 1)
    (pcall vim.api.nvim_buf_set_var buf "delimitMate_enabled" 0)
    (pcall vim.api.nvim_buf_set_var buf "pear_tree_disable" 1)
    (pcall vim.api.nvim_buf_set_var buf "endwise_disable" 1)
    (pcall vim.api.nvim_buf_set_var buf "cmp_enabled" false)
    (pcall vim.api.nvim_buf_set_var buf "meta_prompt" true)))

(fn M.set-prompt-text!
  [session text]
  (when (and session (vim.api.nvim_buf_is_valid session.prompt-buf))
    (set session.last-prompt-text (or text ""))
    (let [lines (if (= text "") [""] (vim.split text "\n" {:plain true}))
          row (# lines)
          col (# (. lines row))]
      (vim.api.nvim_buf_set_lines session.prompt-buf 0 -1 false lines)
      (pcall vim.api.nvim_win_set_cursor session.prompt-win [row col]))))

(fn M.current-buffer-path
  [buf]
  (and buf
       (vim.api.nvim_buf_is_valid buf)
       (let [[ok name] [(pcall vim.api.nvim_buf_get_name buf)]]
         (when (and ok (= (type name) "string") (~= name ""))
           name))))

(fn M.meta-buffer-name
  [session]
  (if session.project-mode
      "Metabuffer"
      (let [original-name (M.current-buffer-path session.source-buf)
            base-name (if (and (= (type original-name) "string") (~= original-name ""))
                          (vim.fn.fnamemodify original-name ":t")
                          "[No Name]")]
        (.. base-name " • Metabuffer"))))

(fn M.ensure-source-refs!
  [meta]
  (when (not meta.buf.source-refs)
    (set meta.buf.source-refs []))
  (when (< (# meta.buf.source-refs) (# meta.buf.content))
    (let [path (or (M.current-buffer-path meta.buf.model) "[Current Buffer]")
          model-buf (and meta.buf.model
                         (vim.api.nvim_buf_is_valid meta.buf.model)
                         meta.buf.model)]
      (for [i (+ (# meta.buf.source-refs) 1) (# meta.buf.content)]
        (table.insert meta.buf.source-refs {:path path :lnum i :buf model-buf :line (. meta.buf.content i)}))))
  meta.buf.source-refs)

(fn M.selected-ref
  [meta]
  (let [src-idx (. meta.buf.indices (+ meta.selected_index 1))
        refs (or meta.buf.source-refs [])]
    (and src-idx (. refs src-idx))))

(fn hidden-path?
  [path]
  (let [parts (vim.split path "/" {:plain true})]
    (var hidden false)
    (each [_ p (ipairs parts)]
      (when (and (~= p "") (vim.startswith p "."))
        (set hidden true)))
    hidden))

(fn dep-path?
  [settings path]
  (let [parts (vim.split path "/" {:plain true})]
    (var dep false)
    (each [_ p (ipairs parts)]
      (when (. settings.dep-dir-names p)
        (set dep true)))
    dep))

(fn M.allow-project-path?
  [settings rel include-hidden include-deps]
  (let [s (or rel "")]
    (if (or (= s "") (= s "."))
        false
        (if (or (vim.startswith s ".git/") (string.find s "/.git/" 1 true))
            false
            (if (and (not include-hidden) (hidden-path? s))
                false
                (if (and (not include-deps) (dep-path? settings s))
                    false
                    true))))))

(fn M.project-file-list
  [settings root include-hidden include-ignored include-deps]
  "Collect project file paths using rg (or glob fallback)."
  (let [rg-bin (or settings.project-rg-bin "rg")]
    (if (= 1 (vim.fn.executable rg-bin))
        (let [cmd [rg-bin]
              _ (each [_ arg (ipairs (or settings.project-rg-base-args []))]
                  (table.insert cmd arg))
              _ (when include-hidden
                  (table.insert cmd "--hidden"))
              _ (when include-ignored
                  (each [_ arg (ipairs (or settings.project-rg-include-ignored-args []))]
                    (table.insert cmd arg)))
              _ (when (not include-deps)
                  (each [_ glob (ipairs (or settings.project-rg-deps-exclude-globs []))]
                    (table.insert cmd "--glob")
                    (table.insert cmd glob)))
            rel (vim.fn.systemlist cmd)]
          (vim.tbl_map
            (fn [p] (vim.fn.fnamemodify (.. root "/" p) ":p"))
            (or rel [])))
        (vim.fn.globpath root (or settings.project-fallback-glob-pattern "**/*") true true))))

(fn ui-attached?
  []
  (> (# (vim.api.nvim_list_uis)) 0))

(fn M.lazy-streaming-allowed?
  [settings query-mod session]
  (and session
       session.project-mode
       (query-mod.truthy? settings.project-lazy-enabled)
       (or (not (query-mod.truthy? settings.project-lazy-disable-headless))
           (ui-attached?))))

(fn M.session-active?
  [active-by-prompt session]
  (and session
       session.prompt-buf
       (= (. active-by-prompt session.prompt-buf) session)))

(fn M.canonical-path
  [path]
  (when (and (= (type path) "string") (~= path ""))
    (vim.fn.fnamemodify path ":p")))

(fn M.path-under-root?
  [path root]
  (let [p (M.canonical-path path)
        r (M.canonical-path root)]
    (and p r (vim.startswith p r))))

(fn M.read-file-lines-cached
  [settings path]
  (if (or (not path) (= 0 (vim.fn.filereadable path)))
      nil
      (let [size (vim.fn.getfsize path)
            mtime (vim.fn.getftime path)
            cache (or settings.project-file-cache {})
            _ (set settings.project-file-cache cache)
            cached (. cache path)]
        (if (or (< size 0) (> size settings.project-max-file-bytes))
            nil
            (if (and (= (type cached) "table")
                     (= (. cached :size) size)
                     (= (. cached :mtime) mtime)
                     (= (type (. cached :lines)) "table"))
                (. cached :lines)
                (let [[ok lines] [(pcall vim.fn.readfile path)]]
                  (when (and ok (= (type lines) "table"))
                    (set (. cache path) {:size size :mtime mtime :lines lines})
                    lines)))))))

M
