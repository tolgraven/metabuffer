(local path-hl (require :metabuffer.path_highlight))
(local util (require :metabuffer.util))

(local M {})

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
        icon-info (util.devicon-info (or ref.path "") "Normal")
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
  [_session _ref _mode _read-file-lines-cached]
  "")

(fn M.info-meta
  [_session _ref]
  nil)

(fn M.info-view
  [session ref ctx]
  (let [mode (or (and ctx ctx.mode) "meta")
        read-file-lines-cached (and ctx ctx.read-file-lines-cached)]
    {:path (M.info-path ref false)
     :icon-path (M.info-path ref false)
     :show-icon true
     :highlight-dir true
     :highlight-file true
     :sign {:text "  " :hl "LineNr"}
     :suffix (M.info-suffix session ref mode read-file-lines-cached)
     :suffix-prefix "  "
     :suffix-highlights []}))

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
  [session ref height read-file-lines-cached]
  (let [h (math.max 1 height)
        lnum (math.max 1 (or (and ref ref.preview-lnum) (and ref ref.lnum) 1))
        start (math.max 1 (- lnum 1))
        stop (+ start h -1)]
    (if (and ref ref.buf (vim.api.nvim_buf_is_valid ref.buf))
        {:start-lnum start
         :focus-lnum lnum
         :lines (trim-or-pad-lines
                 (vim.api.nvim_buf_get_lines ref.buf (- start 1) stop false)
                 h)}
        (if (and ref ref.path (= 1 (vim.fn.filereadable ref.path)))
            (let [cache (or session.preview-file-cache {})
                  _ (set session.preview-file-cache cache)
                  all0 (. cache ref.path)
                  all (if (= (type all0) "table")
                          all0
                          (let [lines (read-file-lines-cached
                                        ref.path
                                        {:include-binary (and session session.effective-include-binary)
                                         :hex-view (and session session.effective-include-hex)})]
                            (if (= (type lines) "table")
                                (do
                                  (set (. cache ref.path) lines)
                                  lines)
                                [])))
                  slice []]
              (for [i start stop]
                (table.insert slice (or (. all i) "")))
              {:start-lnum start
               :focus-lnum lnum
               :lines (trim-or-pad-lines slice h)})
            {:start-lnum 1 :focus-lnum 1 :lines (trim-or-pad-lines [] h)}))))

M
