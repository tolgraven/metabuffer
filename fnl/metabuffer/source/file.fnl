(local text (require :metabuffer.source.text))
(local file-info (require :metabuffer.source.file_info))

(local M {})

(fn M.hit-prefix
  [ref]
  (text.path-prefix ref))

(fn M.info-path
  [ref full-path?]
  (text.info-path ref full-path?))

(fn M.info-suffix
  [session ref mode read-file-lines-cached]
  (let [path (and ref ref.path)]
        (if (not (and path (= 1 (vim.fn.filereadable path))))
            ""
        (if (= (or mode "meta") "meta")
            (. (file-info.file-meta-data session path) :text)
            (file-info.file-first-line session read-file-lines-cached path)))))

(fn M.info-meta
  [session ref]
  (let [path (and ref ref.path)]
    (if (and path (= 1 (vim.fn.filereadable path))
             (= (or (and ref ref.kind) "") "file-entry"))
        (file-info.file-meta-data session path)
        nil)))

(fn M.info-view
  [session ref ctx]
  (let [mode (or (and ctx ctx.mode) "meta")
        path-width (or (and ctx ctx.path-width) 1)
        read-file-lines-cached (and ctx ctx.read-file-lines-cached)
        suffix0 (M.info-suffix session ref mode read-file-lines-cached)]
    (if (= mode "meta")
        (file-info.meta-info-view session (or (and ref ref.path) "") path-width)
        {:path ""
         :icon-path (or (and ref ref.path) "")
         :show-icon false
         :highlight-dir false
         :highlight-file false
         :sign (file-info.file-status-sign
                (or (and (M.info-meta session ref) (. (M.info-meta session ref) :status)) ""))
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
  [session ref height read-file-lines-cached]
  ;; File-provider preview always starts from line 1 unless explicit preview-lnum is set.
  (let [r (vim.deepcopy (or ref {}))]
    ;; File entries should always preview file contents from path, never another buffer.
    (set r.buf nil)
    (if (not r.preview-lnum)
        (set r.preview-lnum 1))
    (text.preview-lines session r height read-file-lines-cached)))

M
