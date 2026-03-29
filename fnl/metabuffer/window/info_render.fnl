(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local M {})
(local lineno-mod (require :metabuffer.window.lineno))
(local source-mod (require :metabuffer.source))
(local path-hl (require :metabuffer.path_highlight))
(local util (require :metabuffer.util))
(local file-info (require :metabuffer.source.file_info))
(local helper-mod (require :metabuffer.window.info_helpers))

(local info-content-ns (vim.api.nvim_create_namespace "MetaInfoWindow"))
(local info-selection-ns (vim.api.nvim_create_namespace "MetaInfoSelection"))
(local str (. helper-mod :str))
(local join-str (. helper-mod :join-str))
(local info-placeholder-line (. helper-mod :info-placeholder-line))
(local indices-slice-sig (. helper-mod :indices-slice-sig))
(local ref-path (. helper-mod :ref-path))
(local refs-slice-sig (. helper-mod :refs-slice-sig))
(local fit-path-into-width (. helper-mod :fit-path-into-width))
(local info-range (. helper-mod :info-range))
(local numeric-max (. helper-mod :numeric-max))
(local info-winbar-active? (. helper-mod :info-winbar-active?))

(fn M.new
  [opts]
  "Build info window render/update helpers."
  (let [info-min-width (. opts :info-min-width)
        info-max-width (. opts :info-max-width)
        info-max-lines (. opts :info-max-lines)
        info-height (. opts :info-height)
        debug-log (. opts :debug-log)
        read-file-lines-cached (. opts :read-file-lines-cached)
        read-file-view-cached (. opts :read-file-view-cached)
        resize-info-window! (. opts :resize-info-window!)
        refresh-info-statusline! (. opts :refresh-info-statusline!)
        valid-info-win? (. opts :valid-info-win?)
        session-host-win (. opts :session-host-win)
        ext-start-in-file (. opts :ext-start-in-file)
        icon-field (. opts :icon-field)
        project-loading-pending? (. opts :project-loading-pending?)]
    (fn apply-info-highlights!
      [session ns highlights]
      (each [_ h (ipairs (or highlights []))]
        (vim.api.nvim_buf_add_highlight session.info-buf ns (. h 2) (. h 1) (. h 3) (. h 4))))

    (fn sync-info-selection!
      [session meta]
      (when (and (valid-info-win? session)
                 session.info-buf
                 (vim.api.nvim_buf_is_valid session.info-buf))
        (let [info-lines (vim.api.nvim_buf_line_count session.info-buf)
              selected1 (+ meta.selected_index 1)
              row0 (if (and (> info-lines 0)
                            (> selected1 0))
                       (math.max 0 (math.min (- selected1 1) (- info-lines 1)))
                       nil)]
          (vim.api.nvim_buf_clear_namespace session.info-buf info-selection-ns 0 -1)
          (when (and row0 (>= row0 0) (< row0 info-lines))
            (vim.api.nvim_buf_add_highlight session.info-buf info-selection-ns "Visual" row0 0 -1)))))

    (fn build-info-row
      [session ref src-idx target-width lnum-digit-width lightweight?]
      (let [line-hl "LineNr"
            signcol-display-width 2
            file-hl (if (= 1 (vim.fn.hlexists "NERDTreeFile"))
                        "NERDTreeFile"
                        (if (= 1 (vim.fn.hlexists "NetrwPlain"))
                            "NetrwPlain"
                            (if (= 1 (vim.fn.hlexists "NvimTreeFileName"))
                                "NvimTreeFileName"
                                "Normal")))
            lnum (tostring (or (and ref ref.lnum) src-idx))
            lnum-cell0 (lineno-mod.lnum-cell lnum lnum-digit-width)
            base-path (vim.fn.fnamemodify (or (and ref ref.path) "[Current Buffer]") ":~:.")
            path-width (math.max 1 (- target-width (+ lnum-digit-width 1) signcol-display-width))
            info-view (if lightweight?
                          {:path base-path
                           :show-icon false
                           :highlight-dir false
                           :highlight-file false
                           :suffix ""
                           :suffix-highlights []
                           :sign {:text "  " :hl "LineNr"}}
                          (source-mod.info-view
                            session
                            ref
                            {:mode (or session.info-file-entry-view "meta")
                             :path-width path-width
                             :single-source? (and (not session.project-mode)
                                                  (not session.active-source-key))
                             :read-file-lines-cached read-file-lines-cached
                             :read-file-view-cached read-file-view-cached}))
            sign (or (. info-view :sign) {:text "  " :hl "LineNr"})
            sign-raw (or (. sign :text) "")
            sign-pad (math.max 0 (- signcol-display-width (vim.fn.strdisplaywidth sign-raw)))
            sign-prefix (.. sign-raw (string.rep " " sign-pad))
            sign-hl (or (. sign :hl) "LineNr")
            sign-highlights (or (. sign :highlights) [])
            sign-width (# sign-prefix)
            sign-glyph-start1 (or (string.find sign-prefix "%S") 0)
            sign-glyph (vim.trim sign-prefix)
            sign-glyph-start (if (> sign-glyph-start1 0) (- sign-glyph-start1 1) -1)
            sign-glyph-end (if (and (> sign-glyph-start1 0) (> (# sign-glyph) 0))
                               (+ sign-glyph-start (# sign-glyph))
                               -1)
            path (or (. info-view :path) base-path)
            icon-path (or (. info-view :icon-path) path)
            show-icon? (if (= (. info-view :show-icon) nil) true (. info-view :show-icon))
            highlight-dir? (if (= (. info-view :highlight-dir) nil) true (. info-view :highlight-dir))
            highlight-file? (if (= (. info-view :highlight-file) nil) true (. info-view :highlight-file))
            suffix0 (or (. info-view :suffix) "")
            suffix-prefix (if (> (# suffix0) 0) (or (. info-view :suffix-prefix) "  ") "")
            suffix-hls (or (. info-view :suffix-highlights) [])
            icon-info (if show-icon?
                          (util.file-icon-info icon-path file-hl)
                          {:icon "" :icon-hl file-hl :file-hl file-hl :ext-hl file-hl})
            icon (or (. icon-info :icon) "")
            iconf (icon-field icon)
            icon-prefix (if show-icon? (. iconf :text) "")
            ext0 (util.ext-from-path icon-path)
            ext-bucket-hl (if (= ext0 "")
                              nil
                              (path-hl.group-for-segment ext0))
            ext-hl (or ext-bucket-hl (. icon-info :ext-hl) (. icon-info :icon-hl) file-hl)
            icon-hl (or ext-bucket-hl (. icon-info :icon-hl) file-hl)
            [dir file0 dir-original] (fit-path-into-width path (math.max 1 (- path-width (if show-icon? (. iconf :width) 0))))
            this-file-hl (or (. icon-info :file-hl) file-hl)
            line (.. sign-prefix lnum-cell0 icon-prefix dir file0 suffix-prefix suffix0)
            sign-start 0
            sign-end (+ sign-start sign-width)
            num-start sign-end
            num-end (+ num-start (# lnum-cell0))
            icon-start num-end
            icon-end (+ icon-start (# icon-prefix))
            dir-start icon-end
            file-start (+ dir-start (# dir))
            suffix-start (+ file-start (# file0) (# suffix-prefix))
            highlights []]
        (when (> sign-width 0)
          (table.insert highlights ["SignColumn" sign-start sign-end]))
        (if (> (# sign-highlights) 0)
            (each [_ part (ipairs sign-highlights)]
              (let [s (+ sign-start (or (. part :start) 0))
                    e (+ sign-start (or (. part :end) 0))]
                (when (> e s)
                  (table.insert highlights [(or (. part :hl) sign-hl) s e]))))
            (when (and (> sign-glyph-end sign-glyph-start) (> sign-width 0))
              (table.insert highlights [sign-hl (+ sign-start sign-glyph-start) (+ sign-start sign-glyph-end)])))
        (table.insert highlights [line-hl num-start num-end])
        (when (> (# icon-prefix) 0)
          (table.insert highlights [icon-hl icon-start icon-end]))
        (when (and highlight-dir? (> (# dir) 0))
          (each [_ dr (ipairs (path-hl.ranges-for-dir dir dir-start dir-original))]
            (table.insert highlights [dr.hl dr.start dr.end])))
        (when (and highlight-file? (> (# file0) 0))
          (table.insert highlights [this-file-hl file-start (+ file-start (# file0))]))
        (when (and highlight-file? (> (# file0) 0))
          (let [dot (ext-start-in-file file0)]
            (when (> dot 0)
              (table.insert highlights [ext-hl (+ file-start (- dot 1)) (+ file-start (# file0))]))))
        (when (> (# suffix0) 0)
          (table.insert highlights ["Comment" suffix-start (+ suffix-start (# suffix0))]))
        (each [_ sh (ipairs suffix-hls)]
          (let [s (+ suffix-start (or sh.start 0))
                e (+ suffix-start (or sh.end 0))]
            (when (> e s)
              (table.insert highlights [(or sh.hl "Comment") s e]))))
        {:line line :highlights highlights}))

    (fn schedule-info-highlight-fill!
      [session refs target-width lnum-digit-width deferred-rows]
      (let [pending (or deferred-rows [])
            batch-size (math.max 4 (math.min 24 (math.max 1 (info-height session))))]
        (if (= (# pending) 0)
            (do
              (set session.info-highlight-fill-pending? false)
              (refresh-info-statusline! session))
            (let [token (+ 1 (or session.info-highlight-fill-token 0))]
              (set session.info-highlight-fill-token token)
              (set session.info-highlight-fill-pending? true)
              (refresh-info-statusline! session)
              (var next-index 1)
              (fn run-batch
                []
                (when (and session
                           session.info-highlight-fill-pending?
                           (= token session.info-highlight-fill-token)
                           session.info-buf
                           (vim.api.nvim_buf_is_valid session.info-buf))
                  (let [bo (. vim.bo session.info-buf)]
                    (set (. bo :modifiable) true))
                  (let [stop (math.min (# pending) (+ next-index batch-size -1))]
                    (for [i next-index stop]
                      (let [spec (. pending i)
                            row0 (. spec 1)
                            src-idx (. spec 2)
                            ref (. refs src-idx)
                            built (build-info-row session ref src-idx target-width lnum-digit-width false)
                            line (str (. built :line))
                            highlights (or (. built :highlights) [])]
                        (vim.api.nvim_buf_set_lines session.info-buf row0 (+ row0 1) false [line])
                        (vim.api.nvim_buf_clear_namespace session.info-buf info-content-ns row0 (+ row0 1))
                        (each [_ h (ipairs highlights)]
                          (vim.api.nvim_buf_add_highlight session.info-buf info-content-ns (. h 1) row0 (. h 2) (. h 3)))))
                    (if (< stop (# pending))
                        (do
                          (set next-index (+ stop 1))
                          (vim.defer_fn run-batch 17))
                        (do
                          (set session.info-highlight-fill-pending? false)
                          (refresh-info-statusline! session))))
                  (let [bo (. vim.bo session.info-buf)]
                    (set (. bo :modifiable) false))))
              (vim.defer_fn run-batch 17)))))

    (fn set-info-topline!
      [session top]
      (when (valid-info-win? session)
        (vim.api.nvim_win_call
          session.info-win
          (fn []
            (let [line-count (math.max 1 (vim.api.nvim_buf_line_count session.info-buf))
                  top* (math.max 1 (math.min top line-count))
                  selected1 (math.max top* (math.min (+ session.meta.selected_index 1) line-count))
                  view (vim.fn.winsaveview)]
              (set (. view :topline) top*)
              (set (. view :lnum) selected1)
              (set (. view :col) 0)
              (set (. view :leftcol) 0)
              (pcall vim.fn.winrestview view))))))

    (fn ensure-regular-info-buffer-shape!
      [session render-stop]
      (when (and session.info-buf
                 (vim.api.nvim_buf_is_valid session.info-buf))
        (let [needed (math.max 1 (or render-stop 0))
              current (vim.api.nvim_buf_line_count session.info-buf)]
          (when (~= current needed)
            (let [bo (. vim.bo session.info-buf)]
              (set (. bo :modifiable) true))
            (if (< current needed)
                (vim.api.nvim_buf_set_lines
                  session.info-buf
                  current
                  current
                  false
                  (vim.tbl_map (fn [_] (info-placeholder-line session)) (vim.fn.range (+ current 1) needed)))
                (vim.api.nvim_buf_set_lines session.info-buf needed -1 false []))
            (let [bo (. vim.bo session.info-buf)]
              (set (. bo :modifiable) false))))))

    (fn fit-info-width!
      [session lines]
      (when (valid-info-win? session)
        (let [widths (vim.tbl_map (fn [line] (vim.fn.strdisplaywidth (or line ""))) (or lines []))
              max-len (numeric-max widths 0)
              host-win (session-host-win session)
              host-width (if (and session.window-local-layout
                                  host-win
                                  (vim.api.nvim_win_is_valid host-win))
                             (vim.api.nvim_win_get_width host-win)
                             vim.o.columns)
              max-available (math.max info-min-width (math.floor (* host-width 0.34)))
              upper (math.min info-max-width max-available)
              fit-target (math.max info-min-width (math.min max-len upper))
              frozen-width (and (not session.project-mode) session.info-fixed-width)
              target (or frozen-width fit-target)
              height (info-height session)]
          (when (and (not session.project-mode)
                     (not frozen-width))
            (set session.info-fixed-width (math.max info-min-width fit-target)))
          (resize-info-window! session target height))))

    (fn info-max-width-now
      [session]
      (let [host-win (session-host-win session)
            host-width (if (and session
                                session.window-local-layout
                                host-win
                                (vim.api.nvim_win_is_valid host-win))
                           (vim.api.nvim_win_get_width host-win)
                           vim.o.columns)
            max-available (math.max info-min-width (math.floor (* host-width 0.34)))]
        (math.min info-max-width max-available)))

    (fn info-visible-range
      [session meta total cap]
      (if (or (<= total 0) (<= cap 0))
          [1 0]
          (if (and session
                   meta
                   meta.win
                   (vim.api.nvim_win_is_valid meta.win.window))
              (let [view (vim.api.nvim_win_call meta.win.window (fn [] (vim.fn.winsaveview)))
                    top0 (math.max 1 (math.min total (or (. view :topline) 1)))
                    overlay-offset (if (info-winbar-active? session project-loading-pending?) 1 0)
                    top (math.max 1 (math.min total (+ top0 overlay-offset)))
                    height0 (math.max 1 (vim.api.nvim_win_get_height meta.win.window))
                    height (math.max 1 (- height0 overlay-offset))
                    stop0 (math.min total (+ top height -1))
                    shown (math.max 1 (+ (- stop0 top) 1))]
                (if (<= shown cap)
                    [top stop0]
                    [top (+ top cap -1)]))
              (info-range meta.selected_index total cap))))

    (fn build-info-lines
      [session refs idxs target-width start-index stop-index visible-start visible-stop]
      (let [lnum-digit-width (let [vis-lo (math.max 1 (or visible-start start-index))
                                   vis-hi (math.min (# idxs) (or visible-stop stop-index))
                                   max-lnum-len (if (> vis-hi 0)
                                                    (let [lens []]
                                                      (for [i vis-lo vis-hi]
                                                        (let [src-idx (. idxs i)
                                                              ref (. refs src-idx)
                                                              lnum (tostring (or (and ref ref.lnum) src-idx))]
                                                          (table.insert lens (# lnum))))
                                                      (numeric-max lens 1))
                                                    1)]
                               (lineno-mod.digit-width-from-max-len max-lnum-len))
            lines []
            highlights []
            deferred-rows []]
        (if (= (# idxs) 0)
            (table.insert lines "No matches")
            (for [i start-index stop-index]
              (let [src-idx (. idxs i)
                    ref (. refs src-idx)
                    row0 (- i 1)
                    built (build-info-row session ref src-idx target-width lnum-digit-width false)]
                (table.insert lines (. built :line))
                (each [_ h (ipairs (or (. built :highlights) []))]
                  (table.insert highlights [row0 (. h 1) (. h 2) (. h 3)])))))
        {:lines lines :highlights highlights :deferred-rows deferred-rows :lnum-digit-width lnum-digit-width}))

    (fn render-info-lines!
      [session meta render-start render-stop visible-start visible-stop]
      (let [refs (or meta.buf.source-refs [])
            idxs (or meta.buf.indices [])
            _ (set session.info-start-index visible-start)
            _ (set session.info-stop-index visible-stop)
            _ (set session.info-render-start render-start)
            _ (set session.info-render-stop render-stop)
            built (build-info-lines session refs idxs (info-max-width-now session) render-start render-stop visible-start visible-stop)
            raw-lines (. built :lines)
            lines (if (= (type raw-lines) "table")
                      (vim.tbl_map str raw-lines)
                      [(str raw-lines)])
            highlights (or (. built :highlights) [])
            deferred-rows (or (. built :deferred-rows) [])
            lnum-digit-width (or (. built :lnum-digit-width) 1)]
        (debug-log (join-str " " ["info render"
                                  (.. "hits=" (# idxs))
                                  (.. "lines=" (# lines))]))
        (set session.info-highlight-fill-token (+ 1 (or session.info-highlight-fill-token 0)))
        (set session.info-highlight-fill-pending? false)
        (fit-info-width! session lines)
        (ensure-regular-info-buffer-shape! session render-stop)
        (let [bo (. vim.bo session.info-buf)]
          (set (. bo :modifiable) true))
        (let [[ok-set err-set] [(pcall vim.api.nvim_buf_set_lines session.info-buf (- render-start 1) render-stop false lines)]]
          (when-not ok-set
            (debug-log (.. "info set_lines failed: " (tostring err-set)))))
        (vim.api.nvim_buf_clear_namespace session.info-buf info-content-ns (- render-start 1) render-stop)
        (apply-info-highlights! session info-content-ns highlights)
        (schedule-info-highlight-fill! session refs (info-max-width-now session) lnum-digit-width deferred-rows)
        (let [bo (. vim.bo session.info-buf)]
          (set (. bo :modifiable) false))
        (set-info-topline! session visible-start)
        (refresh-info-statusline! session)))

    (fn render-current-range!
      [session meta]
      (let [total (# (or meta.buf.indices []))
            [start-index stop-index] (info-visible-range session meta total info-max-lines)
            overscan (math.max 1 (info-height session))
            render-start (math.max 1 (- start-index overscan))
            render-stop (math.min total (+ stop-index overscan))]
        (render-info-lines! session meta render-start render-stop start-index stop-index)
        (sync-info-selection! session meta)
        [start-index stop-index]))

    (fn schedule-regular-line-meta-refresh!
      [session meta start-index stop-index]
      (let [refs (or meta.buf.source-refs [])
            idxs (or meta.buf.indices [])
            first-row (and (> (# idxs) 0) (. idxs start-index))
            first-ref (and first-row (. refs first-row))
            path (ref-path session first-ref)]
        (var rerender! nil)
        (set rerender!
             (fn []
               (when (and session
                          session.info-buf
                          (vim.api.nvim_buf_is_valid session.info-buf)
                          (not session.project-mode)
                          session.single-file-info-ready)
                 (if (or session.scroll-animating?
                         session.scroll-command-view
                         session.scroll-sync-pending
                         session.selection-refresh-pending)
                     (when-not session.info-line-meta-refresh-pending
                       (set session.info-line-meta-refresh-pending true)
                       (vim.defer_fn
                         (fn []
                           (set session.info-line-meta-refresh-pending false)
                           (rerender!))
                         90))
                     (let [[start1 stop1] (render-current-range! session meta)]
                       (set session.info-start-index start1)
                       (set session.info-stop-index stop1))))))
        (when (and session.single-file-info-fetch-ready
                   (~= path "")
                   (= 1 (vim.fn.filereadable path)))
          (let [lnums []]
            (for [i start-index stop-index]
              (let [src-idx (. idxs i)
                    ref (. refs src-idx)]
                (when (and ref
                           (= (ref-path session ref) path)
                           (= (type ref.lnum) "number"))
                  (table.insert lnums ref.lnum))))
            (table.sort lnums)
            (when (> (# lnums) 0)
              (let [first-lnum (. lnums 1)
                    last-lnum (. lnums (# lnums))
                    range-key (.. path ":" start-index ":" stop-index ":" first-lnum ":" last-lnum)]
                (when (~= range-key session.info-line-meta-range-key)
                  (set session.info-line-meta-range-key range-key)
                  ((. file-info :ensure-file-status-async!)
                    session
                    path
                    (fn []
                      (when (= range-key session.info-line-meta-range-key)
                        (rerender!))))
                  ((. file-info :ensure-line-meta-range-async!)
                    session
                    path
                    lnums
                    (fn []
                      (when (= range-key session.info-line-meta-range-key)
                        (rerender!)))))))))))

    (fn update-regular!
      [session refresh-lines]
      (when (and session.info-render-suspended?
                 (not session.prompt-animating?)
                 (not session.startup-initializing))
        (set session.info-post-fade-refresh? nil)
        (set session.info-render-suspended? false))
      (when (and (not session.info-render-suspended?)
                 session.info-buf
                 (vim.api.nvim_buf_is_valid session.info-buf))
        (let [meta session.meta
              _ (refresh-info-statusline! session)
              force-refresh? (or (= session.info-render-sig nil)
                                 (= session.info-start-index nil)
                                 (= session.info-stop-index nil))
              selected1 (+ meta.selected_index 1)
              idxs (or meta.buf.indices [])
              overscan (math.max 1 (info-height session))
              [wanted-start wanted-stop] (info-visible-range session meta (# idxs) info-max-lines)
              render-start (if (> (# idxs) 0) (math.max 1 (- wanted-start overscan)) 1)
              render-stop (if (> (# idxs) 0) (math.min (# idxs) (+ wanted-stop overscan)) 0)
              start-index (or session.info-start-index 1)
              stop-index (or session.info-stop-index 0)
              rendered-start (or session.info-render-start 1)
              rendered-stop (or session.info-render-stop 0)
              out-of-range (or (< selected1 start-index) (> selected1 stop-index))
              range-changed (or (~= wanted-start start-index)
                                (~= wanted-stop stop-index))
              rendered-range-changed (or (< wanted-start rendered-start)
                                        (> wanted-stop rendered-stop)
                                        (~= render-start rendered-start)
                                        (~= render-stop rendered-stop))
              sig (join-str
                    "|"
                    [(# idxs)
                     (indices-slice-sig idxs render-start render-stop)
                     (refs-slice-sig session meta.buf.source-refs idxs render-start render-stop)
                     render-start
                     render-stop
                     (or session.active-source-key "")
                     (or session.info-file-entry-view "")
                     (info-max-width-now session)
                     (info-height session)
                     vim.o.columns
                     (str (clj.boolean session.single-file-info-ready))
                     (str (clj.boolean session.single-file-info-fetch-ready))])]
          (if (or force-refresh?
                  refresh-lines
                  out-of-range
                  range-changed
                  rendered-range-changed
                  (~= session.info-render-sig sig))
              (do
                (when refresh-lines
                  (set session.info-line-meta-range-key nil))
                (set session.info-render-sig sig)
                (render-info-lines! session meta render-start render-stop wanted-start wanted-stop)
                (set session.info-start-index wanted-start)
                (set session.info-stop-index wanted-stop)
                (sync-info-selection! session meta)
                (schedule-regular-line-meta-refresh! session meta wanted-start wanted-stop))
              (do
                (set-info-topline! session wanted-start)
                (sync-info-selection! session meta))))))

    {:fit-info-width! fit-info-width!
     :info-visible-range info-visible-range
     :render-info-lines! render-info-lines!
     :sync-info-selection! sync-info-selection!
     :update-regular! update-regular!}))

M
