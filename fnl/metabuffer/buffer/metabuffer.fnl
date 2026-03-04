(local base (require :metabuffer.buffer.base))
(local ui (require :metabuffer.buffer.ui))

(local M {})

(set M.default-opts {:buflisted false :bufhidden "hide" :buftype "nofile"})

(fn split-source-path [path]
  (let [p (or path "")
        rel (if (~= p "") (vim.fn.fnamemodify p ":~:.") "[Current Buffer]")
        dir (vim.fn.fnamemodify rel ":h")
        file (vim.fn.fnamemodify rel ":t")
        dir-part (if (and dir (~= dir ".") (~= dir "")) (.. dir "/") "")]
    {:dir dir-part :file file}))

(fn source-prefix [ref]
  (let [lnum (or ref.lnum 0)
        parts (split-source-path ref.path)
        lnum-str (string.format "%6d" lnum)
        dir (or parts.dir "")
        file (or parts.file "")]
    {:text (.. lnum-str "  " dir file "  ")
     :lnum-end (# lnum-str)
     :dir-start (+ (# lnum-str) 2)
     :dir-end (+ (+ (# lnum-str) 2) (# dir))
     :file-start (+ (+ (# lnum-str) 2) (# dir))
     :file-end (+ (+ (+ (# lnum-str) 2) (# dir)) (# file))}))

(fn M.new [nvim model]
  (local self (base.new nvim {:model model :name "meta" :default-opts M.default-opts}))
  (set self.syntax-type "buffer")
  (set self.indexbuf (ui.new nvim self "indexes"))
  (set self.show-source-prefix false)
  (set self.show-source-separators false)
  (set self.source-hl-ns (vim.api.nvim_create_namespace "metabuffer_source"))
  (set self.source-sep-ns (vim.api.nvim_create_namespace "metabuffer_source_separator"))

  (fn self.model-valid? []
    (and self.model (vim.api.nvim_buf_is_valid self.model)))

  (fn self.syntax []
    (if (and (= self.syntax-type "buffer") (self.model-valid?))
        (. (. vim.bo self.model) :syntax)
        "metabuffer"))

  (fn self.apply-syntax [syntax-type]
    (when syntax-type
      (set self.syntax-type syntax-type))
    (let [bo (. vim.bo self.buffer)]
      (if (= self.syntax-type "buffer")
          (if (self.model-valid?)
              (let [ft (. (. vim.bo self.model) :filetype)
                    syn (. (. vim.bo self.model) :syntax)]
                (when (and ft (~= ft ""))
                  (set (. bo :filetype) ft))
                (if (and syn (~= syn ""))
                    (set (. bo :syntax) syn)
                    (set (. bo :syntax) "")))
              (do
                (set (. bo :filetype) "metabuffer")
                (set (. bo :syntax) "metabuffer")))
          (do
            (set (. bo :filetype) "metabuffer")
            (set (. bo :syntax) "metabuffer")))))

  (fn self.update []
    (self.render))

  (fn self.render []
    (local view (vim.fn.winsaveview))
    (let [bo (. vim.bo self.buffer)]
      (set (. bo :modifiable) true))
    (local out [])
    (local ranges [])
    (each [_ idx (ipairs self.indices)]
      (let [line (. self.content idx)]
        (if (and self.show-source-prefix self.source-refs (. self.source-refs idx))
            (let [ref (. self.source-refs idx)
                  pfx (source-prefix ref)
                  row (+ (# out) 1)]
              (table.insert out (.. pfx.text line))
              (table.insert ranges {:row row
                                    :lnum-end pfx.lnum-end
                                    :dir-start pfx.dir-start
                                    :dir-end pfx.dir-end
                                    :file-start pfx.file-start
                                    :file-end pfx.file-end}))
            (table.insert out line))))
    (vim.api.nvim_buf_set_lines self.buffer 0 -1 false out)
    (vim.api.nvim_buf_clear_namespace self.buffer self.source-hl-ns 0 -1)
    (vim.api.nvim_buf_clear_namespace self.buffer self.source-sep-ns 0 -1)
    (when self.show-source-prefix
      (each [_ r (ipairs ranges)]
        (let [row0 (- r.row 1)]
          (vim.api.nvim_buf_add_highlight self.buffer self.source-hl-ns "MetaSourceLineNr" row0 0 r.lnum-end)
          (when (> (- r.dir-end r.dir-start) 0)
            (vim.api.nvim_buf_add_highlight self.buffer self.source-hl-ns "MetaSourceDir" row0 r.dir-start r.dir-end))
          (when (> (- r.file-end r.file-start) 0)
            (vim.api.nvim_buf_add_highlight self.buffer self.source-hl-ns "MetaSourceFile" row0 r.file-start r.file-end)))))
    (when (and self.show-source-separators self.source-refs)
      (let [n (# self.indices)]
        (for [i 1 (- n 1)]
          (let [cur-idx (. self.indices i)
                next-idx (. self.indices (+ i 1))
                cur-ref (and cur-idx (. self.source-refs cur-idx))
                next-ref (and next-idx (. self.source-refs next-idx))
                cur-path (and cur-ref cur-ref.path)
                next-path (and next-ref next-ref.path)]
            (when (~= (or cur-path "") (or next-path ""))
              (vim.api.nvim_buf_set_extmark
                self.buffer
                self.source-sep-ns
                (- i 1)
                0
                {:end_row i
                 :end_col 0
                 :hl_group "MetaSourceBoundary"
                 :hl_eol true
                 :priority 120}))))))
    (let [bo (. vim.bo self.buffer)]
      (set (. bo :modifiable) false))
    (vim.fn.winrestview view)
    (self.indexbuf.update))

  (fn self.push-visible-lines [visible]
    (when (self.model-valid?)
      (local n (math.min (# visible) (# self.indices)))
      (for [i 1 n]
        (let [src (. self.indices i)
              old (vim.api.nvim_buf_get_lines self.model (- src 1) src false)
              old-line (. old 1)
              new-line (. visible i)]
          (when (~= old-line new-line)
            (vim.api.nvim_buf_set_lines self.model (- src 1) src false [new-line])
            (set (. self.content src) new-line))))))

  self)

M
