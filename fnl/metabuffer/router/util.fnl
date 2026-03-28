(import-macros {: when-let
                 : if-let
                 : when-some
                 : if-some
                 : when-not
                 : cond}
  :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local transform-mod (require :metabuffer.transform))
(local config-mod (require :metabuffer.config))
(local M {})

(local prompt-height-state-file
  (.. (vim.fn.stdpath "state") "/metabuffer_prompt_height"))

(local results-wrap-state-file
  (.. (vim.fn.stdpath "state") "/metabuffer_results_wrap"))

(fn read-prompt-height-state
  []
  (let [[ok fh] [(pcall io.open prompt-height-state-file "r")]]
    (if (and ok fh)
        (let [line (fh:read "*l")
              _ (fh:close)
              n (tonumber (or line ""))]
          (if (and n (> n 0)) n nil))
        nil)))

(fn write-prompt-height-state!
  [h]
  (when (and h (> h 0))
    (let [[ok fh] [(pcall io.open prompt-height-state-file "w")]]
      (when (and ok fh)
        (fh:write (tostring h))
        (fh:close)))))

(fn read-results-wrap-state
  []
  (let [[ok fh] [(pcall io.open results-wrap-state-file "r")]]
    (if (and ok fh)
        (let [line (vim.trim (or (fh:read "*l") ""))
              _ (fh:close)]
          (if (or (= line "1") (= line "true"))
              true
              (= line "0")
              false
              nil))
        nil)))

(fn write-results-wrap-state!
  [enabled]
  (when (~= enabled nil)
    (let [[ok fh] [(pcall io.open results-wrap-state-file "w")]]
      (when (and ok fh)
        (fh:write (if enabled "1" "0"))
        (fh:close)))))

(fn M.silent-win-set-buf!
  [win buf]
  "Attach buffer to a window without surfacing file/info messages."
  (when (and win buf
             (vim.api.nvim_win_is_valid win)
             (vim.api.nvim_buf_is_valid buf))
    (or (pcall vim.api.nvim_win_call
               win
               (fn []
                 (vim.cmd (.. "silent keepalt noautocmd buffer " buf))))
        (pcall vim.api.nvim_win_set_buf win buf))))

(fn M.prompt-height
  []
  (or (tonumber vim.g.meta_prompt_height)
      (tonumber (. vim.g "meta#prompt_height"))
      (read-prompt-height-state)
      7))

(fn M.persist-prompt-height!
  [session]
  (when (and session session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
    (let [[ok h] [(pcall vim.api.nvim_win_get_height session.prompt-win)]]
      (when (and ok h (> h 0))
        (set vim.g.meta_prompt_height h)
        (set (. vim.g "meta#prompt_height") h)
        (write-prompt-height-state! h)))))

(fn M.results-wrap-enabled?
  []
  (let [v (read-results-wrap-state)]
    (if (= v nil) nil v)))

(fn M.persist-results-wrap!
  [session]
  (when (and session
             session.meta
             session.meta.win
             session.meta.win.window
             (vim.api.nvim_win_is_valid session.meta.win.window))
    (let [[ok wrap?] [(pcall vim.api.nvim_get_option_value "wrap" {:win session.meta.win.window})]]
      (when ok
        (write-results-wrap-state! (clj.boolean wrap?))))))

(fn M.info-height
  [session]
  (cond
    (and session
         (or session.startup-initializing session.prompt-animating? session.animate-enter?)
         session.source-view)
    (let [host-height (or (. session.source-view :_meta_win_height)
                          (and session.origin-win
                               (vim.api.nvim_win_is_valid session.origin-win)
                               (vim.api.nvim_win_get_height session.origin-win))
                          (and session.meta
                               session.meta.win
                               (vim.api.nvim_win_is_valid session.meta.win.window)
                               (vim.api.nvim_win_get_height session.meta.win.window))
                          0)
          prompt-height (math.max 1 (or session.prompt-target-height (M.prompt-height)))]
      (math.max 7 (- host-height prompt-height)))
    (and session
         session.meta
         session.meta.win
         (vim.api.nvim_win_is_valid session.meta.win.window))
    (math.max 7 (vim.api.nvim_win_get_height session.meta.win.window))
    (and session session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
    (let [p-row-col (vim.api.nvim_win_get_position session.prompt-win)
          p-row (. p-row-col 1)]
      (math.max 7 (- p-row 2)))
    true
    (math.max 7 (- vim.o.lines (+ (M.prompt-height) 4)))))

(fn M.prompt-lines
  [session]
  (if (and session
           (= (type session.prompt-buf) "number")
           (vim.api.nvim_buf_is_valid session.prompt-buf))
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
      (pcall vim.api.nvim_win_set_cursor session.prompt-win [row col])
      (when (and session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
        (pcall vim.api.nvim_set_option_value "wrap" true {:win session.prompt-win})
        (pcall vim.api.nvim_set_option_value "linebreak" true {:win session.prompt-win})))))

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
  (when-not meta.buf.source-refs
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

(fn M.clear-file-caches!
  [router session]
  "Drop shared and per-session file/view caches so the next refresh rebuilds
   from disk. Expected output: nil."
  (when router
    (set router.project-file-cache {}))
  (when session
    (set session.preview-file-cache {})
    (set session.info-file-head-cache {})
    (set session.info-file-meta-cache {})
    (set session.ts-expand-bufs {})
    (set session.info-line-meta-range-key nil)
    (set session.info-render-sig nil)
    (when (and session.meta (= (type (. session.meta :_filter-cache)) "table"))
      (set (. session.meta :_filter-cache) {})
      (set (. session.meta :_filter-cache-line-count) (# (or (. session.meta.buf :content) []))))))

(fn hidden-path?
  [path]
  (let [parts (vim.split path "/" {:plain true})]
    (let [step (fn step
                 [idx]
                 (if (> idx (# parts))
                   false
                   (let [p (. parts idx)]
                     (or (and (~= p "")
                              (= (string.sub p 1 1) "."))
                         (step (+ idx 1))))))]
      (step 1))))

(fn dep-path?
  [settings path]
  (let [parts (vim.split path "/" {:plain true})]
    (let [step (fn step
                 [idx]
                 (if (> idx (# parts))
                   false
                   (or (. settings.dep-dir-names (. parts idx))
                       (step (+ idx 1)))))]
      (step 1))))

(fn M.allow-project-path?
  [settings rel include-hidden include-deps]
  (let [s (or rel "")]
    (cond
      (or (= s "") (= s ".")) false
      (or (vim.startswith s ".git/")
          (string.find s "/.git/" 1 true)) false
      (and (not include-hidden) (hidden-path? s)) false
      (and (not include-deps) (dep-path? settings s)) false
      :else true)))

(fn M.project-file-list
  [settings root include-hidden include-ignored include-deps]
  "Collect project file paths using rg (or glob fallback).
  Checks vim.g.__meta_project_file_list_cache first for pre-seeded
  test fixtures, keyed by root|hidden|ignored|deps."
  (let [cache (and vim.g.__meta_project_file_list_cache
                   (. vim.g.__meta_project_file_list_cache
                      (.. root "|"
                          (if include-hidden "1" "0") "|"
                          (if include-ignored "1" "0") "|"
                          (if include-deps "1" "0"))))]
    (if cache
        cache
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
                    _ (when-not include-deps
                        (each [_ glob (ipairs (or settings.project-rg-deps-exclude-globs []))]
                          (table.insert cmd "--glob")
                          (table.insert cmd glob)))
                  rel (vim.fn.systemlist cmd)]
                (vim.tbl_map
                  (fn [p] (vim.fn.fnamemodify (.. root "/" p) ":p"))
                  (or rel [])))
              (vim.fn.globpath root (or settings.project-fallback-glob-pattern "**/*") true true))))))

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

(fn contains-nul-byte?
  [s]
  (let [[ok match?] [(pcall string.find s "\0" 1 true)]]
    (and ok (clj.boolean (~= match? nil)))))

(fn suspicious-binary-head?
  [s]
  (let [[ok-n n] [(pcall string.len s)]]
    (if (or (not ok-n) (not (= (type n) "number")))
      false
        (if (= n 0)
            false
            (let [bad0 0]
              (var bad bad0)
              (for [i 1 n]
                (let [[ok-b b] [(pcall string.byte s i)]]
                  (when (and ok-b
                             b
                             (or (< b 9)
                                 (= b 11)
                                 (= b 12)
                                 (and (> b 13) (< b 32))
                                 (= b 127)))
                    (set bad (+ bad 1)))))
              (> (/ bad n) 0.1))))))

(fn binary-head?
  [head]
  (and (= (type head) "string")
       (or (contains-nul-byte? head)
           (suspicious-binary-head? head))))

(fn settings-project-max-file-bytes
  [settings]
  (let [fallback (. (. config-mod :defaults) :options)
        fallback-max (or (and fallback (. fallback :project_max_file_bytes))
                         1048576)]
    (or (and settings (. settings :project-max-file-bytes))
        (and settings (. settings :project_max_file_bytes))
        fallback-max)))

(fn read-file-head-bytes
  [path n]
  "Read up to N raw bytes from PATH. Returns string or nil."
  (let [uv (or vim.uv vim.loop)]
    (when (and uv uv.fs_open uv.fs_read uv.fs_close path)
      (let [[ok-open fd] [(pcall uv.fs_open path "r" 438)]]
        (when (and ok-open fd)
          (let [[ok-read chunk] [(pcall uv.fs_read fd (or n 256) 0)]]
            (pcall uv.fs_close fd)
            (when (and ok-read (= (type chunk) "string"))
              chunk)))))))

(fn read-file-bytes
  [path]
  "Read all raw bytes from PATH. Returns string or nil."
  (let [uv (or vim.uv vim.loop)]
    (when (and uv uv.fs_open uv.fs_read uv.fs_close path)
      (let [[ok-open fd] [(pcall uv.fs_open path "r" 438)]]
        (when (and ok-open fd)
          (let [[ok-stat stat] [(pcall uv.fs_fstat fd)]
                size (if (and ok-stat (= (type stat) "table"))
                         (. stat :size)
                         nil)
                [ok-read chunk] [(pcall uv.fs_read fd (or size 0) 0)]]
            (pcall uv.fs_close fd)
            (when (and ok-read (= (type chunk) "string"))
              chunk)))))))

(fn bytes->lines
  [s]
  "Split raw text bytes into lines without going through vim.fn.readfile."
  (if (not (= (type s) "string"))
      []
      (let [norm (string.gsub s "\r\n" "\n")
            lines (vim.split norm "\n" {:plain true})]
        (if (and (> (# lines) 0) (= (. lines (# lines)) ""))
            (table.remove lines)
            nil)
        lines)))

(fn M.binary-file?
  [settings path]
  (if (or (not path) (= 0 (vim.fn.filereadable path)))
      false
      (let [size (vim.fn.getfsize path)
            mtime (vim.fn.getftime path)
            max-bytes (settings-project-max-file-bytes settings)
            cache (or settings.project-file-cache {})
            _ (set settings.project-file-cache cache)
            cached (. cache path)]
        (if (or (< size 0) (> size max-bytes))
            false
            (if (and (= (type cached) "table")
                     (= (. cached :size) size)
                     (= (. cached :mtime) mtime)
                     (~= (. cached :binary) nil))
                (clj.boolean (. cached :binary))
                (let [head (read-file-head-bytes path 256)
                      bin? (binary-head? head)
                      prev-lines (and (= (type cached) "table") (. cached :lines))]
                  (set (. cache path)
                       {:size size
                        :mtime mtime
                        :binary (clj.boolean bin?)
                        :lines (if (= (type prev-lines) "table") prev-lines nil)})
                  (clj.boolean bin?)))))))

(fn M.read-file-view-cached
  [settings path opts]
  (fn binary-header-line
    [size]
    (let [kb (math.max 1 (math.floor (/ (math.max 0 (or size 0)) 1024)))]
      (.. "binary " (tostring kb) " KB")))
  (fn binary-default-lines
    [size]
    [(binary-header-line size)])
  (let [include-binary (and opts (. opts :include-binary))
        transforms0 (or (and opts opts.transforms) {})
        transforms (if (and opts
                            (. opts :hex-view)
                            (= (. transforms0 :hex) nil))
                       (vim.tbl_extend "force" transforms0 {:hex true})
                       transforms0)
        wrap-width (and opts (. opts :wrap-width))
        linebreak? (if (= (and opts (. opts :linebreak)) nil) true (clj.boolean (. opts :linebreak)))
        transform-sig (.. (transform-mod.signature transforms)
                          "|w:" (tostring (or wrap-width 0))
                          "|lb:" (if linebreak? "1" "0"))]
    (if (or (not path) (= 0 (vim.fn.filereadable path)))
        nil
        (let [size (vim.fn.getfsize path)
              mtime (vim.fn.getftime path)
              max-bytes (settings-project-max-file-bytes settings)
              cache (or settings.project-file-cache {})
              _ (set settings.project-file-cache cache)
              cached (. cache path)]
          (if (or (< size 0) (> size max-bytes))
              nil
              (if (and (= (type cached) "table")
                       (= (. cached :size) size)
                       (= (. cached :mtime) mtime))
                  (if (. cached :binary)
                      (if include-binary
                          (let [views (or (. cached :views) {})
                                found (. views transform-sig)]
                            (if (= (type found) "table")
                                found
                                (let [raw-lines (or (. cached :raw-lines)
                                                    (binary-default-lines size))
                                      ctx {:binary true
                                           :size size
                                           :head (. cached :head)
                                           :transforms transforms}
                                      view (transform-mod.apply-view path raw-lines ctx)]
                                  (set (. views transform-sig) view)
                                  (set (. cached :views) views)
                                  view)))
                          nil)
                       (let [views (or (. cached :views) {})
                             found (. views transform-sig)]
                         (if (= (type found) "table")
                             found
                             ;; binary-file? may have created a cache entry without :lines;
                             ;; read the file now if :lines is missing.
                             (let [raw-lines (or (. cached :lines)
                                                 (let [text (read-file-bytes path)
                                                       ls (bytes->lines text)]
                                                   (when (= (type ls) "table")
                                                     (set (. cached :lines) ls))
                                                   (or ls [])))
                                   ctx {:binary false
                                        :size size
                                        :head (or (. cached :head) (read-file-head-bytes path 4096))
                                        :transforms transforms}
                                   view (transform-mod.apply-view path raw-lines ctx)]
                               (set (. views transform-sig) view)
                               (set (. cached :views) views)
                               view))))
                  (let [head (read-file-head-bytes path 4096)]
                    (if (binary-head? head)
                        (let [entry {:size size :mtime mtime :binary true :head head}]
                          (if include-binary
                              (let [raw-lines (binary-default-lines size)
                                    ctx {:binary true
                                         :size size
                                         :head head
                                         :transforms transforms}
                                    view (transform-mod.apply-view path raw-lines ctx)
                                    views {}]
                                (set (. entry :raw-lines) (if (= (type raw-lines) "table") raw-lines []))
                                (set (. views transform-sig) view)
                                (set (. entry :views) views)
                                (set (. cache path) entry)
                                view)
                              (do
                                (set (. cache path) entry)
                                nil)))
                        (let [text (read-file-bytes path)
                              lines (bytes->lines text)]
                          (when (= (type lines) "table")
                            (let [entry {:size size
                                         :mtime mtime
                                         :binary false
                                         :head head
                                         :lines lines
                                         :views {}}
                                  view (transform-mod.apply-view path lines {:binary false
                                                                             :size size
                                                                             :head head
                                                                             :transforms transforms})
                                  views {}]
                              (set (. views transform-sig) view)
                              (set (. entry :views) views)
                              (set (. cache path) entry)
                              view)))))))))))

(fn M.read-file-lines-cached
  [settings path opts]
  (let [view (M.read-file-view-cached settings path opts)]
    (and view (. view :lines))))

M
