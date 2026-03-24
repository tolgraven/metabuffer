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

(fn M.provider-for-op
  [op]
  (if (= (or (and op op.ref-kind) "") "file-entry")
      file
      text))

(fn M.apply-write-ops!
  [ops]
  (let [grouped {}]
    (each [_ op (ipairs (or ops []))]
      (let [provider (M.provider-for-op op)
            key (or (. provider :provider-key) "text")
            bucket (or (. grouped key) {:provider provider :ops {}})
            bucket-ops (. bucket :ops)
            path (or (. op :path) "")
            per-path (or (. bucket-ops path) [])]
        (table.insert per-path op)
        (set (. bucket-ops path) per-path)
        (set (. grouped key) bucket)))
    (let [result {:wrote false :changed 0 :post-lines {} :paths {} :renames {}}
          post-lines (. result :post-lines)
          paths (. result :paths)
          renames (. result :renames)]
      (each [_ bucket (pairs grouped)]
        (let [provider (. bucket :provider)
              f (. provider :apply-write-ops!)
              part (if (= (type f) "function")
                       (f (. bucket :ops))
                       {:wrote false :changed 0 :post-lines {} :paths {} :renames {}})]
          (when (. part :wrote)
            (set (. result :wrote) true))
          (set (. result :changed) (+ (. result :changed) (or (. part :changed) 0)))
          (each [path lines (pairs (or (. part :post-lines) {}))]
            (set (. post-lines path) lines))
          (each [path v (pairs (or (. part :paths) {}))]
            (set (. paths path) v))
          (each [old-path new-path (pairs (or (. part :renames) {}))]
            (set (. renames old-path) new-path))))
      result)))

M
