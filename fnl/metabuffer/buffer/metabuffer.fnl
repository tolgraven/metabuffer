(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local base (require :metabuffer.buffer.base))
(local ui (require :metabuffer.buffer.ui))
(local source-mod (require :metabuffer.source))

(local M {})

(set M.default-opts {:buflisted false :bufhidden "hide" :buftype "nofile"})

(fn ext-from-path
  [path]
  (let [file (vim.fn.fnamemodify (or path "") ":t")
        dot (string.match file ".*()%.")]
    (if (and dot (> dot 0) (< dot (# file)))
        (string.sub file (+ dot 1))
        "")))

(fn devicon-for-path
  [path fallback-hl]
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
    {:dir dir-part :file file}))

(fn source-prefix
  [ref]
  (source-mod.hit-prefix ref))

(fn sanitize-syntax-id
  [s]
  (let [base (or s "text")
        cleaned (string.gsub base "[^%w_]" "_")]
    (if (= cleaned "") "text" cleaned)))

(fn syntax-files-for-ft
  [ft]
  (let [files []
        base (vim.api.nvim_get_runtime_file (.. "syntax/" ft ".vim") true)
        after (vim.api.nvim_get_runtime_file (.. "after/syntax/" ft ".vim") true)]
    (each [_ f (ipairs base)]
      (table.insert files f))
    (each [_ f (ipairs after)]
      (table.insert files f))
    files))

(fn normalize-render-line
  [line]
  (let [txt (tostring (or line ""))]
    (let [s1 (string.gsub txt "\r\n" " ")
          s2 (string.gsub s1 "\n" " ")
          s3 (string.gsub s2 "\r" " ")]
      s3)))

(fn M.new
  [nvim model]
  "Public API: M.new."
  (let [self (base.new nvim {:model model :name "meta" :default-opts M.default-opts})]
    (set self.syntax-type "buffer")
    (set self.indexbuf (ui.new nvim self "indexes"))
    (set self.show-source-prefix false)
    (set self.show-source-separators false)
    (set self.source-hl-ns (vim.api.nvim_create_namespace "metabuffer_source"))
    (set self.source-sep-ns (vim.api.nvim_create_namespace "metabuffer_source_separator"))
    (set self.source-alt-ns (vim.api.nvim_create_namespace "metabuffer_source_alt"))
    (set self.source-syntax-groups [])
    (set self.keep-modifiable false)

  (fn self.model-valid?
  []
    (and self.model (vim.api.nvim_buf_is_valid self.model)))

  (fn self.ref-filetype
  [ref]
    (let [kind (and ref ref.kind)
          path (and ref ref.path)
          ft (when (and (= (type path) "string") (~= path ""))
               (or (vim.filetype.match {:filename (vim.fn.fnamemodify path ":t")})
                   (vim.filetype.match {:filename path})))]
      (if (= kind "file-entry")
          "text"
          (if (and (= (type ft) "string") (~= ft ""))
          ft
          "text"))))

  (fn self.clear-source-syntax
  []
    (when (and self.source-syntax-groups (> (# self.source-syntax-groups) 0))
      (vim.api.nvim_buf_call self.buffer
        (fn []
          (each [_ g (ipairs self.source-syntax-groups)]
            (vim.cmd (.. "silent! syntax clear " g))))))
    (set self.source-syntax-groups []))

  (fn self.apply-source-syntax-regions
  []
    (if (not (and self.show-source-separators
                  (= self.syntax-type "buffer")
                  self.source-refs
                  (> (# self.indices) 0)))
        (self.clear-source-syntax)
        (let [n (# self.indices)
              included {}
              groups []]
          (self.clear-source-syntax)
          (vim.api.nvim_buf_call self.buffer
            (fn []
              ;; Reset inherited/base syntax only when we know we can apply at
              ;; least one source syntax cluster; this keeps source-file
              ;; highlighting accurate while avoiding stale cross-file syntax.
              (vim.cmd "silent! syntax clear")
              (pcall vim.api.nvim_buf_del_var self.buffer "current_syntax")
              (fn add-block
  [start stop ft]
                (when (and ft (~= ft "") (<= start stop))
                  (let [cluster (.. "MetaSrcFt_" (sanitize-syntax-id ft))
                          group (string.format "MetaSrcBlock_%d_%d" start stop)
                          synfiles (syntax-files-for-ft ft)
                          has-syntax (> (# synfiles) 0)]
                    (when has-syntax
                      (when-not (. included cluster)
                        ;; Most syntax files early-return when b:current_syntax
                        ;; is set; clear it before each include so mixed
                        ;; filetype blocks can all load.
                        (each [_ synfile (ipairs synfiles)]
                          (pcall vim.api.nvim_buf_del_var self.buffer "current_syntax")
                          (vim.cmd (.. "silent! syntax include @" cluster " " (vim.fn.fnameescape synfile))))
                        (set (. included cluster) true))
                      (vim.cmd
                        (string.format
                          "silent! syntax match %s /\\%%>%dl\\%%<%dl.*/ contains=@%s transparent"
                          group
                          (- start 1)
                          (+ stop 1)
                          cluster))
                      (table.insert groups group)))))
              (var start 1)
              (var prev-ft nil)
              (var prev-src-idx nil)
              (for [i 1 n]
                (let [idx (. self.indices i)
                      ref (and idx (. self.source-refs idx))
                      ft (self.ref-filetype ref)]
                  (when-not prev-ft
                    (set prev-ft ft))
                  (when (or (~= ft prev-ft)
                            (and prev-src-idx (~= idx (+ prev-src-idx 1))))
                    (add-block start (- i 1) prev-ft)
                    (set start i)
                    (set prev-ft ft))
                  (set prev-src-idx idx)))
              (when prev-ft
                (add-block start n prev-ft))
              ;; Re-sync so contained syntax in mixed blocks updates reliably.
              (vim.cmd "silent! syntax sync fromstart")))
          (set self.source-syntax-groups groups))))

  (fn self.syntax
  []
    (if (and (= self.syntax-type "buffer") (self.model-valid?))
        (. (. vim.bo self.model) :syntax)
        "metabuffer"))

  (fn self.apply-syntax
  [syntax-type]
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

  (fn self.update
  []
    (self.render))

  (fn self.render
  []
    (let [win-views {}
          out []
          ranges []]
      (each [_ win (ipairs (vim.fn.win_findbuf self.buffer))]
        (when (vim.api.nvim_win_is_valid win)
          (set (. win-views win)
               (vim.api.nvim_win_call win (fn [] (vim.fn.winsaveview))))))
      (let [bo (. vim.bo self.buffer)]
        (set (. bo :modifiable) true))
      (each [_ idx (ipairs self.indices)]
        (let [line (. self.content idx)]
          (if (and self.show-source-prefix self.source-refs (. self.source-refs idx))
              (let [ref (. self.source-refs idx)
                    pfx (source-prefix ref)
                    row (+ (# out) 1)]
                (table.insert out (if (= (or pfx.text "") "")
                                      (normalize-render-line line)
                                      (if (= (or line "") "")
                                        (normalize-render-line pfx.text)
                                        (normalize-render-line (.. pfx.text "  " line)))))
                (table.insert ranges {:row row
                                      :lnum-end pfx.lnum-end
                                      :icon-start pfx.icon-start
                                      :icon-end pfx.icon-end
                                      :icon-hl pfx.icon-hl
                                      :dir-ranges (or pfx.dir-ranges [])
                                      :file-start pfx.file-start
                                      :file-end pfx.file-end
                                      :file-hl pfx.file-hl
                                      :ext-start pfx.ext-start
                                      :ext-end pfx.ext-end
                                      :ext-hl pfx.ext-hl}))
              (table.insert out (normalize-render-line line)))))
      (for [i 1 (# out)]
        (let [line0 (. out i)
              line1 (tostring (or line0 ""))
              line2 (string.gsub line1 "[\r\n\v\f]" "")]
          (set (. out i) line2)))
      (vim.api.nvim_buf_set_lines self.buffer 0 -1 false out)
      (vim.api.nvim_buf_clear_namespace self.buffer self.source-hl-ns 0 -1)
      (vim.api.nvim_buf_clear_namespace self.buffer self.source-sep-ns 0 -1)
      (vim.api.nvim_buf_clear_namespace self.buffer self.source-alt-ns 0 -1)
      (when self.show-source-prefix
        (each [_ r (ipairs ranges)]
          (let [row0 (- r.row 1)]
            (when (> (or r.lnum-end 0) 0)
              (vim.api.nvim_buf_add_highlight self.buffer self.source-hl-ns "MetaSourceLineNr" row0 0 r.lnum-end))
            (when (> (- r.icon-end r.icon-start) 0)
              (vim.api.nvim_buf_add_highlight self.buffer self.source-hl-ns (or r.icon-hl "MetaSourceFile") row0 r.icon-start r.icon-end))
            (each [_ dr (ipairs (or r.dir-ranges []))]
              (vim.api.nvim_buf_add_highlight self.buffer self.source-hl-ns dr.hl row0 dr.start dr.end))
            (when (> (- r.file-end r.file-start) 0)
              (vim.api.nvim_buf_set_extmark
                self.buffer
                self.source-hl-ns
                row0
                r.file-start
                {:end_row row0
                 :end_col r.file-end
                 :hl_group (or r.file-hl "Normal")
                 :hl_mode "combine"
                 :priority 220}))
            (when (> (- (or r.ext-end 0) (or r.ext-start 0)) 0)
              (vim.api.nvim_buf_set_extmark
                self.buffer
                self.source-hl-ns
                row0
                r.ext-start
                {:end_row row0
                 :end_col r.ext-end
                 :hl_group (or r.ext-hl r.file-hl "Normal")
                 :hl_mode "combine"
                 :priority 230})))))
      (when (and self.show-source-separators self.source-refs)
        (let [n (# self.indices)]
          (var alt false)
          (var prev-path nil)
          (for [i 1 n]
            (let [idx (. self.indices i)
                  ref (and idx (. self.source-refs idx))
                  path (or (and ref ref.path) "")]
              (when (= prev-path nil)
                (set prev-path path))
              (when (~= path prev-path)
                (set alt (not alt))
                (set prev-path path))
              (when alt
                (vim.api.nvim_buf_set_extmark
                  self.buffer
                  self.source-alt-ns
                  (- i 1)
                  0
                  {:end_row i
                   :end_col 0
                   :hl_group "MetaSourceAltBg"
                   :hl_eol true
                   :hl_mode "combine"
                   ;; Keep this below syntax priority so syntax colors remain.
                   :priority 1}))))
          (for [i 1 (- n 1)]
            (let [cur-idx (. self.indices i)
                  next-idx (. self.indices (+ i 1))
                  cur-ref (and cur-idx (. self.source-refs cur-idx))
                  next-ref (and next-idx (. self.source-refs next-idx))
                  cur-path (and cur-ref cur-ref.path)
                  next-path (and next-ref next-ref.path)]
              (when (and (~= (or cur-path "") (or next-path ""))
                         (~= (and cur-ref cur-ref.kind) "file-entry")
                         (~= (and next-ref next-ref.kind) "file-entry"))
                (vim.api.nvim_buf_set_extmark
                  self.buffer
                  self.source-sep-ns
                  (- i 1)
                  0
                  {:end_row i
                   :end_col 0
                   :hl_group "MetaSourceBoundary"
                   :hl_eol true
                   :hl_mode "combine"
                   :priority 120}))))))
      (self.apply-source-syntax-regions)
      (let [bo (. vim.bo self.buffer)]
        (set (. bo :modifiable) (if self.keep-modifiable true false)))
      (each [win view (pairs win-views)]
        (when (vim.api.nvim_win_is_valid win)
          (vim.api.nvim_win_call win
            (fn []
              (pcall vim.fn.winrestview view)))))
      (self.indexbuf.update)))

  (fn self.push-visible-lines
  [visible]
    (when (self.model-valid?)
      (let [n (math.min (# visible) (# self.indices))]
        (for [i 1 n]
          (let [src (. self.indices i)
                old (vim.api.nvim_buf_get_lines self.model (- src 1) src false)
                old-line (. old 1)
                new-line (. visible i)]
            (when (~= old-line new-line)
              (vim.api.nvim_buf_set_lines self.model (- src 1) src false [new-line])
              (set (. self.content src) new-line)))))))

    self))

M
