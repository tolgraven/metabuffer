(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local base (require :metabuffer.buffer.base))
(local ui (require :metabuffer.buffer.ui))
(local query-mod (require :metabuffer.query))
(local source-mod (require :metabuffer.source))

(local M {})

(set M.default-opts {:buflisted false :bufhidden "hide" :buftype "nofile"})

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

(fn apply-ft-buffer-vars!
  [buf ft]
  (when (and buf
             (vim.api.nvim_buf_is_valid buf)
             (= ft "fennel"))
    (pcall vim.api.nvim_buf_set_var buf "fennel_lua_version" "5.1")
    (pcall vim.api.nvim_buf_set_var buf "fennel_use_luajit" (if jit 1 0))))

(fn stop-buffer-treesitter!
  [buf]
  (when (and buf (vim.api.nvim_buf_is_valid buf) vim.treesitter)
    (pcall vim.treesitter.stop buf)))

(fn start-buffer-treesitter!
  [buf ft]
  (when (and buf
             (vim.api.nvim_buf_is_valid buf)
             vim.treesitter
             (= (type ft) "string")
             (~= ft "")
             (~= ft "metabuffer")
             (~= ft "text"))
    (pcall vim.treesitter.start buf ft)))

(fn normalize-render-line
  [line]
  (let [txt (tostring (or line ""))]
    (let [s1 (string.gsub txt "\r\n" " ")
          s2 (string.gsub s1 "\n" " ")
          s3 (string.gsub s2 "\r" " ")]
      s3)))

(fn set-bvar!
  [buf name value]
  (when (and buf (vim.api.nvim_buf_is_valid buf))
    (pcall vim.api.nvim_buf_set_var buf name value)))

(fn bvar
  [buf name default]
  (let [[ok v] [(pcall vim.api.nvim_buf_get_var buf name)]]
    (if ok v default)))

(fn session_has_pending_work
  [self]
  (let [session self.session]
    (and session
         (or session.prompt-update-pending
             session.prompt-update-dirty
             session.project-bootstrap-pending
             (and session.project-mode (not session.project-bootstrapped))))))

(fn any-non-empty-line?
  [lines]
  (let [active false]
    (var out active)
    (each [_ line (ipairs (or lines []))]
      (when (and (not out) (~= (vim.trim (or line "")) ""))
        (set out true)))
    out))

(fn session_has_active_filter
  [self]
  (let [session self.session
        parsed (and session session.last-parsed-query)]
    (and session
         parsed
         (or (query-mod.query-lines-has-active? (or (. parsed :lines) []))
             (any-non-empty-line? (or (. parsed :file-lines) []))))))

(fn should_defer_empty_frame
  [self frame]
  (and (= (# (or frame.lines [])) 0)
       (> (# (or self.last-rendered-lines [])) 0)
       (not (session_has_active_filter self))
       (session_has_pending_work self)))

(fn save_window_views
  [self]
  (let [views {}]
    (each [_ win (ipairs (vim.fn.win_findbuf self.buffer))]
      (when (vim.api.nvim_win_is_valid win)
        (set (. views win)
             (vim.api.nvim_win_call win (fn [] (vim.fn.winsaveview))))))
    views))

(fn restore_window_views
  [views]
  (each [win view (pairs views)]
    (when (vim.api.nvim_win_is_valid win)
      (vim.api.nvim_win_call win
        (fn []
          (pcall vim.fn.winrestview view))))))

(fn rendered_line
  [self idx]
  (let [line (. self.content idx)]
    (if (and self.show-source-prefix self.source-refs (. self.source-refs idx))
        (let [ref (. self.source-refs idx)
              pfx (source-prefix ref)]
          {:text (if (= (or pfx.text "") "")
                     (normalize-render-line line)
                     (if (= (or line "") "")
                         (normalize-render-line pfx.text)
                         (normalize-render-line (.. pfx.text "  " line))))
           :range {:lnum-end pfx.lnum-end
                   :icon-start pfx.icon-start
                   :icon-end pfx.icon-end
                   :icon-hl pfx.icon-hl
                   :dir-ranges (or pfx.dir-ranges [])
                   :file-start pfx.file-start
                   :file-end pfx.file-end
                   :file-hl pfx.file-hl
                   :ext-start pfx.ext-start
                   :ext-end pfx.ext-end
                   :ext-hl pfx.ext-hl}})
        {:text (normalize-render-line line)})))

(fn normalize_frame_lines
  [lines]
  (let [out (vim.deepcopy (or lines []))]
    (for [i 1 (# out)]
      (let [line0 (. out i)
            line1 (tostring (or line0 ""))
            line2 (string.gsub line1 "[\r\n\v\f]" "")]
        (set (. out i) line2)))
    out))

(fn build_render_frame
  [self]
  (let [lines []
        ranges []]
    (each [_ idx (ipairs self.indices)]
      (let [entry (rendered_line self idx)
            row (+ (# lines) 1)]
        (table.insert lines entry.text)
        (when entry.range
          (table.insert ranges (vim.tbl_extend "force" entry.range {:row row})))))
    {:lines (normalize_frame_lines lines)
     :ranges ranges}))

(fn set_render_buffer_lines
  [self lines]
  (let [bo (. vim.bo self.buffer)]
    (set (. bo :modifiable) true))
  (set-bvar! self.buffer "meta_internal_render" true)
  (let [manual-edit-active? (bvar self.buffer "meta_manual_edit_active" false)
        undo-levels (if manual-edit-active?
                        nil
                        (vim.api.nvim_get_option_value "undolevels" {:buf self.buffer}))]
    (when undo-levels
      (pcall vim.api.nvim_set_option_value "undolevels" -1 {:buf self.buffer}))
    (vim.api.nvim_buf_set_lines self.buffer 0 -1 false (or lines []))
    (when-not manual-edit-active?
      (pcall vim.api.nvim_set_option_value "modified" false {:buf self.buffer}))
    (when undo-levels
      (pcall vim.api.nvim_set_option_value "undolevels" undo-levels {:buf self.buffer}))))

(fn clear_render_namespaces
  [self]
  (vim.api.nvim_buf_clear_namespace self.buffer self.source-hl-ns 0 -1)
  (vim.api.nvim_buf_clear_namespace self.buffer self.source-sep-ns 0 -1)
  (vim.api.nvim_buf_clear_namespace self.buffer self.source-alt-ns 0 -1))

(fn apply_frame_highlights
  [self ranges]
  (when self.show-source-prefix
    (each [_ r (ipairs (or ranges []))]
      (let [row0 (- r.row 1)]
        (when (> (or r.lnum-end 0) 0)
          (vim.api.nvim_buf_add_highlight
            self.buffer
            self.source-hl-ns
            "MetaSourceLineNr"
            row0
            0
            r.lnum-end))
        (when (> (- r.icon-end r.icon-start) 0)
          (vim.api.nvim_buf_add_highlight
            self.buffer
            self.source-hl-ns
            (or r.icon-hl "MetaSourceFile")
            row0
            r.icon-start
            r.icon-end))
        (each [_ dr (ipairs (or r.dir-ranges []))]
          (vim.api.nvim_buf_add_highlight
            self.buffer
            self.source-hl-ns
            dr.hl
            row0
            dr.start
            dr.end))
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
             :priority 230}))))))

(fn apply_frame_separators
  [self]
  (when self.source-refs
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
          (when (and self.show-source-alt-bg alt)
            (vim.api.nvim_buf_set_extmark
              self.buffer
              self.source-alt-ns
              (- i 1)
              0
              {:line_hl_group "MetaSourceAltBg"
               :priority 90}))))
      (when self.show-source-separators
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
                 :priority 120}))))))))

(fn finalize_render
  [self views]
  (self.apply-source-syntax-regions)
  (let [bo (. vim.bo self.buffer)]
    (set (. bo :modifiable) (if self.keep-modifiable true false)))
  (set-bvar! self.buffer "meta_internal_render" false)
  (restore_window_views views)
  (self.indexbuf.update))

(fn stage_render_frame
  [self frame]
  (set self.pending-render-frame (vim.deepcopy frame))
  false)

(fn commit_render_frame
  [self frame]
  (set_render_buffer_lines self frame.lines)
  (set self.last-rendered-lines (vim.deepcopy frame.lines))
  (set self.pending-render-frame nil)
  (clear_render_namespaces self)
  (apply_frame_highlights self frame.ranges)
  true)

(fn attach-basic-buffer-methods!
  [self]
  (fn self.prepare-visible-edit!
    []
    (let [bo (. vim.bo self.buffer)]
      (set self.keep-modifiable true)
      (set (. bo :buftype) "acwrite")
      (set (. bo :bufhidden) "hide")
      (set (. bo :modifiable) true)
      (set (. bo :readonly) false))
    (base.clear-modified! self.buffer))
  (fn self.clear-modified!
    []
    (base.clear-modified! self.buffer))
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
              "text")))))

(fn attach-source-syntax-core-methods!
  [self]
  (fn self.clear-source-syntax
    []
    (set self.source-syntax-fill-token (+ 1 (or self.source-syntax-fill-token 0)))
    (set self.source-syntax-fill-pending false)
    (stop-buffer-treesitter! self.buffer)
    (when (and self.source-syntax-groups (> (# self.source-syntax-groups) 0))
      (vim.api.nvim_buf_call self.buffer
        (fn []
          (each [_ g (ipairs self.source-syntax-groups)]
            (vim.cmd (.. "silent! syntax clear " g))))))
    (set self.source-syntax-groups [])
    (set self.source-syntax-included {})
    (set self.source-syntax-base-reset? false)
    (set self.source-syntax-next-group-id 0))
  (fn self.add-source-syntax-range
    [syntax-start syntax-stop]
    (when (and self.source-refs
               (> (# self.indices) 0)
               (<= syntax-start syntax-stop))
      (let [included self.source-syntax-included
            groups self.source-syntax-groups]
        (vim.api.nvim_buf_call self.buffer
          (fn []
            (fn add-block
              [start stop ft]
              (when (and ft (~= ft "") (<= start stop))
                (let [synfiles (syntax-files-for-ft ft)
                      has-syntax (> (# synfiles) 0)]
                  (when has-syntax
                    (when-not self.source-syntax-base-reset?
                      (vim.cmd "silent! syntax clear")
                      (pcall vim.api.nvim_buf_del_var self.buffer "current_syntax")
                      (set self.source-syntax-base-reset? true))
                    (let [cluster (.. "MetaSrcFt_" (sanitize-syntax-id ft))]
                      (when-not (. included cluster)
                        (apply-ft-buffer-vars! self.buffer ft)
                        (each [_ synfile (ipairs synfiles)]
                          (pcall vim.api.nvim_buf_del_var self.buffer "current_syntax")
                          (vim.cmd (.. "silent! syntax include @" cluster " " (vim.fn.fnameescape synfile))))
                        (set (. included cluster) true))
                      (set self.source-syntax-next-group-id (+ self.source-syntax-next-group-id 1))
                      (let [group (string.format "MetaSrcBlock_%d" self.source-syntax-next-group-id)]
                        (vim.cmd
                          (string.format
                            "silent! syntax match %s /\\%%>%dl\\%%<%dl.*/ contains=@%s transparent"
                            group
                            (- start 1)
                            (+ stop 1)
                            cluster))
                        (table.insert groups group)))))))
            (var start syntax-start)
            (var prev-ft nil)
            (var prev-src-idx nil)
            (for [i syntax-start syntax-stop]
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
              (add-block start syntax-stop prev-ft))))))))

(fn attach-source-syntax-fill-methods!
  [self]
  (fn self.run-source-syntax-fill-step
    [total-lines]
    (let [session self.session
          chunk (math.max 1 (or (and session session.project-source-syntax-chunk-lines) 240))
          token self.source-syntax-fill-token]
      (when (and self.source-syntax-fill-pending
                 (vim.api.nvim_buf_is_valid self.buffer)
                 (= token self.source-syntax-fill-token))
        (var budget chunk)
        (when (and (<= self.source-syntax-next-after total-lines) (> budget 0))
          (let [stop (math.min total-lines (+ self.source-syntax-next-after budget -1))]
            (self.add-source-syntax-range self.source-syntax-next-after stop)
            (set budget (- budget (+ (- stop self.source-syntax-next-after) 1)))
            (set self.source-syntax-next-after (+ stop 1))))
        (when (and (>= self.source-syntax-next-before 1) (> budget 0))
          (let [start (math.max 1 (+ self.source-syntax-next-before (- budget) 1))]
            (self.add-source-syntax-range start self.source-syntax-next-before)
            (set self.source-syntax-next-before (- start 1))))
        (if (or (<= self.source-syntax-next-after total-lines)
                (>= self.source-syntax-next-before 1))
            (vim.defer_fn
              (fn []
                (self.run-source-syntax-fill-step total-lines))
              17)
            (do
              (set self.source-syntax-fill-pending false)
              (vim.api.nvim_buf_call self.buffer
                (fn []
                  (vim.cmd "silent! syntax sync fromstart"))))))))
  (fn self.schedule-source-syntax-fill
    [syntax-start syntax-stop total-lines]
    (set self.source-syntax-fill-token (+ 1 (or self.source-syntax-fill-token 0)))
    (set self.source-syntax-fill-pending true)
    (set self.source-syntax-next-after (+ syntax-stop 1))
    (set self.source-syntax-next-before (- syntax-start 1))
    (vim.defer_fn
      (fn []
        (self.run-source-syntax-fill-step total-lines))
      17)))

(fn attach-source-syntax-apply-methods!
  [self]
  (fn self.apply-source-syntax-regions
    []
    (if (not (and self.show-source-separators
                  (= self.syntax-type "buffer")
                  self.source-refs
                  (> (# self.indices) 0)))
        (self.clear-source-syntax)
        (let [n (# self.indices)
              session self.session
              chunk (math.max 1 (or (and session session.project-source-syntax-chunk-lines) 240))]
          (var visible-start 1)
          (var visible-stop n)
          (let [wins (vim.fn.win_findbuf self.buffer)]
            (var win nil)
            (each [_ candidate (ipairs wins)]
              (when (and (not win) (vim.api.nvim_win_is_valid candidate))
                (set win candidate)))
            (when win
              (let [view (vim.api.nvim_win_call win (fn [] (vim.fn.winsaveview)))
                    height (math.max 1 (vim.api.nvim_win_get_height win))]
                (set visible-start (math.max 1 (math.min (or (. view :topline) 1) n)))
                (set visible-stop (math.max visible-start
                                            (math.min (+ visible-start height -1) n))))))
          (let [incremental-fill? (and session
                                       session.project-mode
                                       (not self.visible-source-syntax-only)
                                       (> n chunk))
                syntax-start (if (or self.visible-source-syntax-only incremental-fill?)
                                 visible-start
                                 1)
                syntax-stop (if (or self.visible-source-syntax-only incremental-fill?)
                                visible-stop
                                n)]
            (self.clear-source-syntax)
            (self.add-source-syntax-range syntax-start syntax-stop)
            (when (not (or self.visible-source-syntax-only incremental-fill?))
              (vim.api.nvim_buf_call self.buffer
                (fn []
                  (vim.cmd "silent! syntax sync fromstart"))))
            (when incremental-fill?
              (self.schedule-source-syntax-fill syntax-start syntax-stop n))))))
  (fn self.syntax
    []
    (if (and (= self.syntax-type "buffer") (self.model-valid?))
        (. (. vim.bo self.model) :syntax)
        "metabuffer")))

(fn attach-render-methods!
  [self]
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
                  (apply-ft-buffer-vars! self.buffer ft)
                  (set (. bo :filetype) ft))
                (if (and syn (~= syn ""))
                    (set (. bo :syntax) syn)
                    (set (. bo :syntax) ""))
                (start-buffer-treesitter! self.buffer ft))
              (do
                (stop-buffer-treesitter! self.buffer)
                (set (. bo :filetype) "metabuffer")
                (set (. bo :syntax) "metabuffer")))
          (do
            (stop-buffer-treesitter! self.buffer)
            (set (. bo :filetype) "metabuffer")
            (set (. bo :syntax) "metabuffer")))))
  (fn self.update
    []
    (self.render))
  (fn self.render
    []
    (let [views (save_window_views self)
          frame (build_render_frame self)
          committed? (if (should_defer_empty_frame self frame)
                         (stage_render_frame self frame)
                         (commit_render_frame self frame))]
      (when committed?
        (apply_frame_separators self)
        (finalize_render self views))))
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
              (set (. self.content src) new-line))))))))

(fn initialize-metabuffer-state!
  [self nvim]
  (set self.syntax-type "buffer")
  (set self.indexbuf (ui.new nvim self "indexes"))
  (set self.show-source-prefix false)
  (set self.show-source-separators false)
  (set self.show-source-alt-bg true)
  (set self.visible-source-syntax-only false)
  (set self.source-hl-ns (vim.api.nvim_create_namespace "metabuffer_source"))
  (set self.source-sep-ns (vim.api.nvim_create_namespace "metabuffer_source_separator"))
  (set self.source-alt-ns (vim.api.nvim_create_namespace "metabuffer_source_alt"))
  (set self.source-syntax-groups [])
  (set self.source-syntax-included {})
  (set self.source-syntax-base-reset? false)
  (set self.source-syntax-next-group-id 0)
  (set self.source-syntax-fill-token 0)
  (set self.source-syntax-fill-pending false)
  (set self.keep-modifiable false)
  (set self.last-rendered-lines [])
  (set self.pending-render-frame nil))

(fn M.new
  [nvim model]
  "Public API: M.new."
  (let [self (base.new nvim {:model model :name "meta" :default-opts M.default-opts})]
    (initialize-metabuffer-state! self nvim)
    (attach-basic-buffer-methods! self)
    (attach-source-syntax-core-methods! self)
    (attach-source-syntax-fill-methods! self)
    (attach-source-syntax-apply-methods! self)
    (attach-render-methods! self)
    self))

M
