(import-macros {: if-let} :io.gitlab.andreyorst.cljlib.core)
(local text (require :metabuffer.source.text))
(local file-info (require :metabuffer.source.file_info))
(local util (require :metabuffer.util))

(local M {})
(set M.provider-key "file-entry")
(set M.query-directive-specs
     [{:kind "toggle"
       :long "file"
       :token-key :include-files
       :arg "{token}"
       :doc "Switch to file-entry source filtering."
       :await-when-true true
       :await {:kind "file"}}])

(fn M.parse-bare-token
  [state tok unquote-token]
  "Handle bare file-source shortcut tokens. Expected output: updated state or nil."
  (let [t (or tok "")]
    (if (= t "./")
        (let [next (vim.deepcopy state)]
          (set (. next :include-files) true)
          (set (. next :file-await-token) true)
          (set (. next :await-directive) {:kind "file"})
          next)
        (if-let [matched (string.match t "^%./(.+)$")]
          (let [next (vim.deepcopy state)]
            (set (. next :include-files) true)
            (table.insert (. next :file-lines) (unquote-token matched))
            (set (. next :file-await-token) false)
            next)
          nil))))

(fn M.hit-prefix
  [ref]
  (text.path-prefix ref))

(fn M.info-path
  [ref full-path?]
  (text.info-path ref full-path?))

(fn M.info-suffix
  [session ref mode read-file-lines-cached read-file-view-cached]
  (let [path (and ref ref.path)]
        (if (not (and path (= 1 (vim.fn.filereadable path))))
            ""
        (if (= (or mode "meta") "meta")
            (. (file-info.file-meta-data session path) :text)
            (file-info.file-first-line session read-file-lines-cached read-file-view-cached path)))))

(fn M.info-meta
  [session ref]
  (let [path (and ref ref.path)]
    (if (and path (= 1 (vim.fn.filereadable path))
             (= (or (and ref ref.kind) "") "file-entry"))
        (file-info.file-meta-data session path)
        nil)))

(fn source-sign
  [_ref]
  (util.icon-sign {:category "directory"
                   :name "."
                   :fallback "󰉋"
                   :hl "MiniIconsAzure"}))

(fn M.info-view
  [session ref ctx]
  (let [mode (or (and ctx ctx.mode) "meta")
        path-width (or (and ctx ctx.path-width) 1)
        read-file-lines-cached (and ctx ctx.read-file-lines-cached)
        suffix0 (M.info-suffix session ref mode read-file-lines-cached nil)
        sign (source-sign ref)]
    (if (= mode "meta")
        (let [view (file-info.meta-info-view session (or (and ref ref.path) "") path-width)]
          (set (. view :sign) sign)
          view)
        {:path ""
         :icon-path (or (and ref ref.path) "")
         :show-icon false
         :highlight-dir false
         :highlight-file false
         :sign sign
         :suffix suffix0
         :suffix-prefix ""
         :suffix-highlights []})))

(fn M.preview-filetype
  [ref]
  (let [path (and ref ref.path)]
    (if (and (= (type path) "string") (~= path ""))
        (let [[ok ft] [(pcall vim.filetype.match {:filename path})]]
          (if (and ok (= (type ft) "string") (~= ft ""))
              ft
              "text"))
        "text")))

(fn M.preview-lines
  [session ref height read-file-lines-cached read-file-view-cached]
  ;; File-provider preview always starts from line 1 unless explicit preview-lnum is set.
  (let [r (vim.deepcopy (or ref {}))]
    ;; File entries should always preview file contents from path, never another buffer.
    (set r.buf nil)
    (if (not r.preview-lnum)
        (set r.preview-lnum 1))
    (text.preview-lines session r height read-file-lines-cached read-file-view-cached)))

(fn normalize-target-path
  [old-path text]
  (let [trimmed (vim.trim (or text ""))]
    (if (or (= trimmed "") (= trimmed old-path))
        old-path
        (let [cwd (vim.fn.getcwd)
              candidate (vim.fn.fnamemodify trimmed ":p")]
          (if (vim.startswith candidate cwd)
              candidate
              (vim.fn.fnamemodify (.. cwd "/" trimmed) ":p"))))))

(fn M.apply-write-ops!
  [ops]
  (let [renames {}
        touched-paths {}]
    (var total 0)
    (var any-write false)
    (each [path per-file (pairs (or ops {}))]
      (when (and (= (# (or per-file [])) 1)
                 (= (or (and (. per-file 1) (. (. per-file 1) :kind)) "") :replace))
        (let [op (. per-file 1)
              target (normalize-target-path path (. op :text))]
          (when (~= target path)
            (when (= (vim.fn.mkdir (vim.fn.fnamemodify target ":h") "p") 1) true)
            (let [[ok] [(pcall vim.loop.fs_rename path target)]]
              (when ok
                (set any-write true)
                (set total (+ total 1))
                (set (. touched-paths path) true)
                (set (. renames path) target)))))))
    {:wrote any-write :changed total :post-lines {} :paths touched-paths :renames renames}))

M
