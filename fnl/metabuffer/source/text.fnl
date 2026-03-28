(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local path-hl (require :metabuffer.path_highlight))
(local util (require :metabuffer.util))
(local file-info (require :metabuffer.source.file_info))

(local M {})
(set M.provider-key "text")

(fn ref-path
  [session ref]
  (or (and ref ref.path)
      (and session session.source-buf
           (vim.api.nvim_buf_is_valid session.source-buf)
           (let [name (vim.api.nvim_buf_get_name session.source-buf)]
             (when (and (= (type name) "string") (~= name ""))
               name)))
      ""))

(fn icon-field
  [icon]
  (if (and (= (type icon) "string") (~= icon ""))
      (let [text (.. icon " ")]
        {:text text :width (vim.fn.strdisplaywidth text)})
      {:text "" :width 0}))

(fn split-source-path
  [path]
  (let [p (or path "")
        rel (if (~= p "") (vim.fn.fnamemodify p ":~:.") "[Current Buffer]")
        dir (vim.fn.fnamemodify rel ":h")
        file (vim.fn.fnamemodify rel ":t")
        dir-part (if (and dir (~= dir ".") (~= dir "")) (.. dir "/") "")]
    {:dir dir-part :file file :path rel}))

(fn ext-range
  [file file-start]
  (let [n (# (or file ""))
        dot (string.match (or file "") ".*()%.")]
    (if (and dot (> dot 1) (< dot n))
      {:start (+ file-start (- dot 1))
       :end (+ file-start n)}
      {:start 0 :end 0})))

(fn M.path-prefix
  [ref]
  (let [parts (split-source-path ref.path)
        icon-info (util.file-icon-info (or ref.path "") "Normal")
        iconf (icon-field (or (. icon-info :icon) ""))
        icon-prefix (. iconf :text)
        dir (or parts.dir "")
        file (or parts.file "")
        dir-start (# icon-prefix)
        file-start (+ dir-start (# dir))
        ex (ext-range file file-start)]
    {:text (.. icon-prefix dir file)
     :lnum-end 0
     :icon-start 0
     :icon-end (# icon-prefix)
     :icon-hl (or (. icon-info :icon-hl) "Normal")
     :dir-ranges (path-hl.ranges-for-dir dir dir-start)
     :file-start file-start
     :file-end (+ file-start (# file))
     :file-hl (or (. icon-info :file-hl) "Normal")
     :ext-start ex.start
     :ext-end ex.end
     :ext-hl (or (. icon-info :ext-hl) "Normal")
     :dir dir
     :file file
     :path (or parts.path "")}))

(fn M.hit-prefix
  [_ref]
  {:text ""
   :lnum-end 0
   :icon-start 0
   :icon-end 0
   :icon-hl "MetaSourceFile"
   :dir-ranges []
   :file-start 0
   :file-end 0
   :file-hl "MetaSourceFile"
   :ext-start 0
   :ext-end 0
   :ext-hl "MetaSourceFile"
   :dir ""
   :file ""
   :path ""})

(fn M.info-path
  [ref full-path?]
  (let [path0 (or (and ref ref.path) "")]
    (if (= path0 "")
        "[Current Buffer]"
        (if full-path?
            (vim.fn.fnamemodify path0 ":.")
            (vim.fn.fnamemodify path0 ":~:.")))))

(fn M.info-suffix
  [_session _ref _mode _read-file-lines-cached _read-file-view-cached]
  "")

(fn M.info-meta
  [_session _ref]
  nil)

(fn source-sign
  [_ref]
  (util.icon-sign {:category ""
                   :name ""
                   :fallback "󰈔"
                   :hl "MetaSourceFile"}))

(fn M.info-view
  [session ref ctx]
  (let [mode (or (and ctx ctx.mode) "meta")
        read-file-lines-cached (and ctx ctx.read-file-lines-cached)
        read-file-view-cached (and ctx ctx.read-file-view-cached)
        single-source? (clj.boolean (and ctx ctx.single-source?))
        sign (source-sign ref)]
    (if single-source?
        (let [path (ref-path session ref)]
          (if (and session.single-file-info-ready
                   ref
                   (~= path "")
                   ref.lnum
                   (= 1 (vim.fn.filereadable path)))
              (let [view (file-info.line-meta-info-view session path ref.lnum 1)]
                (set (. view :sign) sign)
                view)
              {:path ""
               :icon-path ""
               :show-icon false
               :highlight-dir false
               :highlight-file false
               :sign sign
               :suffix (M.info-suffix session ref mode read-file-lines-cached read-file-view-cached)
               :suffix-prefix ""
               :suffix-highlights []}))
        {:path (M.info-path ref false)
         :icon-path (M.info-path ref false)
         :show-icon true
         :highlight-dir true
         :highlight-file true
         :sign sign
         :suffix (M.info-suffix session ref mode read-file-lines-cached read-file-view-cached)
         :suffix-prefix "  "
         :suffix-highlights []})))

(fn M.preview-filetype
  [ref]
  (if (and ref ref.buf (vim.api.nvim_buf_is_valid ref.buf))
      (. (. vim.bo ref.buf) :filetype)
      (if (and ref ref.path)
          (let [[ok ft] [(pcall vim.filetype.match {:filename ref.path})]]
            (if (and ok (= (type ft) "string")) ft ""))
          "")))

(fn trim-or-pad-lines
  [lines target]
  (let [out []]
    (each [_ line (ipairs (or lines []))]
      (when (< (# out) target)
        (table.insert out (or line ""))))
    (while (< (# out) target)
      (table.insert out ""))
    out))

(fn M.preview-lines
  [session ref height read-file-lines-cached read-file-view-cached]
  (let [h (math.max 1 height)
        lnum (math.max 1 (or (and ref ref.preview-lnum) (and ref ref.lnum) 1))
        start (math.max 1 (- lnum 1))]
    (if (and ref ref.buf (vim.api.nvim_buf_is_valid ref.buf))
        (let [stop (+ start h -1)]
        {:start-lnum start
         :focus-lnum lnum
         :lines (trim-or-pad-lines
                 (vim.api.nvim_buf_get_lines ref.buf (- start 1) stop false)
                 h)})
        (if (and ref ref.path (= 1 (vim.fn.filereadable ref.path)))
            (let [view (or (and read-file-view-cached
                                (read-file-view-cached
                                  ref.path
                                  {:include-binary (and session session.effective-include-binary)
                                   :transforms (or (and session session.effective-transforms)
                                                   (and session session.transform-flags)
                                                   {})}))
                           {:lines (or (read-file-lines-cached
                                         ref.path
                                         {:include-binary (and session session.effective-include-binary)
                                          :hex-view (and session session.effective-include-hex)}) [])
                            :line-map []})
                  all (or (. view :lines) [])
                  line-map (or (. view :line-map) [])
                  start-idx0 nil]
              (var start-idx start-idx0)
              (each [idx mapped (ipairs line-map)]
                (when (and (not start-idx) (= mapped lnum))
                  (set start-idx idx)))
              (let [start-idx (or start-idx start)
                    stop (+ start-idx h -1)
                  slice []]
              (for [i start-idx stop]
                (table.insert slice (or (. all i) "")))
              {:start-lnum start
               :focus-lnum lnum
               :lines (trim-or-pad-lines slice h)}))
            {:start-lnum 1 :focus-lnum 1 :lines (trim-or-pad-lines [] h)}))))

(fn apply-op-to-loaded-buffer!
  [buf op delta]
  (if (= (. op :kind) :rewrite-bytes)
      (let [path (vim.api.nvim_buf_get_name buf)
            uv (or vim.uv vim.loop)
            bytes (or (. op :bytes) "")
            ok? (and uv uv.fs_open uv.fs_write uv.fs_close path)]
        (if ok?
            (let [[ok-open fd] [(pcall uv.fs_open path "w" 420)]]
              (when (and ok-open fd)
                (pcall uv.fs_write fd bytes 0)
                (pcall uv.fs_close fd))
              [delta 1])
            [delta 0]))
      (= (. op :kind) :replace)
      (let [lnum (+ (. op :lnum) delta)
            line-count (vim.api.nvim_buf_line_count buf)]
        (if (and (>= lnum 1) (<= lnum line-count))
            (let [old (or (. (vim.api.nvim_buf_get_lines buf (- lnum 1) lnum false) 1) "")
                  new (or (. op :text) "")]
              (if (~= old new)
                  (do
                    (vim.api.nvim_buf_set_lines buf (- lnum 1) lnum false [new])
                    [delta 1])
                  [delta 0]))
            [delta 0]))
      (= (. op :kind) :delete)
      (let [lnum (+ (. op :lnum) delta)
            line-count (vim.api.nvim_buf_line_count buf)]
        (if (and (>= lnum 1) (<= lnum line-count))
            (do
              (vim.api.nvim_buf_set_lines buf (- lnum 1) lnum false [])
              [(- delta 1) 1])
            [delta 0]))
      (= (. op :kind) :insert-before)
      (let [ins (or (. op :lines) [])
            lnum (+ (. op :lnum) delta)
            pos (math.max 1 (math.min (+ (vim.api.nvim_buf_line_count buf) 1) lnum))]
        (if (> (# ins) 0)
            (do
              (vim.api.nvim_buf_set_lines buf (- pos 1) (- pos 1) false ins)
              [(+ delta (# ins)) (# ins)])
            [delta 0]))
      (let [ins (or (. op :lines) [])
            lnum (+ (. op :lnum) delta)
            pos (math.max 0 (math.min (vim.api.nvim_buf_line_count buf) lnum))]
        (if (> (# ins) 0)
            (do
              (vim.api.nvim_buf_set_lines buf pos pos false ins)
              [(+ delta (# ins)) (# ins)])
            [delta 0]))))

(fn apply-op-to-lines!
  [lines op delta]
  (if (= (. op :kind) :rewrite-bytes)
      [delta 0]
      (= (. op :kind) :replace)
      (let [lnum (+ (. op :lnum) delta)]
        (if (and (>= lnum 1) (<= lnum (# lines))
                 (~= (. lines lnum) (. op :text)))
            (do
              (set (. lines lnum) (. op :text))
              [delta 1])
            [delta 0]))
      (= (. op :kind) :delete)
      (let [lnum (+ (. op :lnum) delta)]
        (if (and (>= lnum 1) (<= lnum (# lines)))
            (do
              (table.remove lines lnum)
              [(- delta 1) 1])
            [delta 0]))
      (= (. op :kind) :insert-before)
      (let [ins (or (. op :lines) [])
            lnum (+ (. op :lnum) delta)
            pos (math.max 1 (math.min (+ (# lines) 1) lnum))]
        (if (> (# ins) 0)
            (do
              (for [i 1 (# ins)]
                (table.insert lines (+ pos i -1) (. ins i)))
              [(+ delta (# ins)) (# ins)])
            [delta 0]))
      (let [ins (or (. op :lines) [])
            lnum (+ (. op :lnum) delta)
            pos (math.max 0 (math.min (# lines) lnum))]
        (if (> (# ins) 0)
            (do
              (for [i 1 (# ins)]
                (table.insert lines (+ pos i) (. ins i)))
              [(+ delta (# ins)) (# ins)])
            [delta 0]))))

(fn M.apply-write-ops!
  [ops]
  (let [post-lines {}
        touched-paths {}]
    (var total 0)
    (var any-write false)
    (each [path per-file (pairs (or ops {}))]
      (let [bufnr (vim.fn.bufnr path)]
        (if (and bufnr (> bufnr 0) (vim.api.nvim_buf_is_loaded bufnr))
            (let [bo (. vim.bo bufnr)
                  old-mod (. bo :modifiable)
                  old-ro (. bo :readonly)]
              (set (. bo :modifiable) true)
              (set (. bo :readonly) false)
              (var delta 0)
              (var changed 0)
              (each [_ op (ipairs (or per-file []))]
                (let [[next-delta bump] (apply-op-to-loaded-buffer! bufnr op delta)]
                  (set delta next-delta)
                  (set changed (+ changed bump))))
              (set (. bo :modifiable) old-mod)
              (set (. bo :readonly) old-ro)
              (when (> changed 0)
                (let [[ok-write] [(pcall vim.api.nvim_buf_call bufnr (fn [] (vim.cmd "silent keepalt noautocmd write")))]]
                  (if ok-write
                      (do
                        (set any-write true)
                        (set total (+ total changed))
                        (set (. touched-paths path) true)
                        (set (. post-lines path) (vim.api.nvim_buf_get_lines bufnr 0 -1 false)))
                      (let [[ok-read lines0] [(pcall vim.api.nvim_buf_get_lines bufnr 0 -1 false)]]
                        (when (and ok-read (= (type lines0) "table"))
                          (let [[ok-fallback] [(pcall vim.fn.writefile lines0 path)]]
                            (when ok-fallback
                              (set any-write true)
                              (set total (+ total changed))
                              (set (. touched-paths path) true)
                              (set (. post-lines path) lines0)))))))))
            (let [[ok-read lines0] [(pcall vim.fn.readfile path)]]
              (when (or (and ok-read (= (type lines0) "table"))
                        (and (> (# (or per-file [])) 0)
                             (= (. (. per-file 1) :kind) :rewrite-bytes)))
                (let [lines (vim.deepcopy lines0)]
                  (var delta 0)
                  (var changed 0)
                  (each [_ op (ipairs (or per-file []))]
                    (if (= (. op :kind) :rewrite-bytes)
                        (let [uv (or vim.uv vim.loop)
                              bytes (or (. op :bytes) "")]
                          (when (and uv uv.fs_open uv.fs_write uv.fs_close)
                            (let [[ok-open fd] [(pcall uv.fs_open path "w" 420)]]
                              (when (and ok-open fd)
                                (pcall uv.fs_write fd bytes 0)
                                (pcall uv.fs_close fd)
                                (set changed (+ changed 1))))))
                        (let [[next-delta bump] (apply-op-to-lines! lines op delta)]
                          (set delta next-delta)
                          (set changed (+ changed bump)))))
                  (when (> changed 0)
                    (if (and (> (# (or per-file [])) 0)
                             (= (. (. per-file 1) :kind) :rewrite-bytes))
                        (do
                          (set any-write true)
                          (set total (+ total changed))
                          (set (. touched-paths path) true)
                          (set (. post-lines path) (vim.fn.readfile path)))
                        (let [[ok-write] [(pcall vim.fn.writefile lines path)]]
                          (when ok-write
                            (set any-write true)
                            (set total (+ total changed))
                            (set (. touched-paths path) true)
                            (set (. post-lines path) lines)))))))))))
    {:wrote any-write :changed total :post-lines post-lines :paths touched-paths :renames {}}))

M
