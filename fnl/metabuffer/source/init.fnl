(local text (require :metabuffer.source.text))
(local file (require :metabuffer.source.file))

(local M {})

(fn M.provider-for-ref
  [ref]
  (if (= (or (and ref ref.kind) "") "file-entry")
      file
      text))

(fn M.hit-prefix
  [ref]
  (let [provider (M.provider-for-ref ref)]
    ((. provider :hit-prefix) ref)))

(fn M.info-path
  [ref full-path?]
  (let [provider (M.provider-for-ref ref)]
    ((. provider :info-path) ref full-path?)))

(fn M.info-suffix
  [session ref mode read-file-lines-cached]
  (let [provider (M.provider-for-ref ref)]
    ((. provider :info-suffix) session ref mode read-file-lines-cached)))

(fn M.info-meta
  [session ref]
  (let [provider (M.provider-for-ref ref)
        f (. provider :info-meta)]
    (if (= (type f) "function")
        (f session ref)
        nil)))

(fn M.info-view
  [session ref ctx]
  (let [provider (M.provider-for-ref ref)
        f (. provider :info-view)
        mode (or (and ctx ctx.mode) "meta")
        read-file-lines-cached (and ctx ctx.read-file-lines-cached)]
    (if (= (type f) "function")
        (f session ref ctx)
        {:path (M.info-path ref false)
         :icon-path (M.info-path ref false)
         :show-icon true
         :highlight-dir true
         :highlight-file true
         :sign {:text "  " :hl "LineNr"}
         :suffix (M.info-suffix session ref mode read-file-lines-cached)
         :suffix-prefix "  "
         :suffix-highlights []})))

(fn M.preview-filetype
  [ref]
  (let [provider (M.provider-for-ref ref)]
    ((. provider :preview-filetype) ref)))

(fn M.preview-lines
  [session ref height read-file-lines-cached]
  (let [provider (M.provider-for-ref ref)]
    ((. provider :preview-lines) session ref height read-file-lines-cached)))

M
