(local M {})
(local lineno-mod (require :metabuffer.window.lineno))
(local source-mod (require :metabuffer.source))
(local path-hl (require :metabuffer.path_highlight))
(local util (require :metabuffer.util))
(local helper-mod (require :metabuffer.window.info_helpers))

(local str (. helper-mod :str))
(local fit-path-into-width (. helper-mod :fit-path-into-width))
(local numeric-max (. helper-mod :numeric-max))

(fn M.new
  [opts]
  "Build info-row render and highlight-fill helpers."
  (let [{: info-content-ns : info-height : refresh-info-statusline!
         : read-file-lines-cached : read-file-view-cached
         : ext-start-in-file : icon-field} (or opts {})]
    (fn apply-highlights!
      [session ns highlights]
      (each [_ h (ipairs (or highlights []))]
        (vim.api.nvim_buf_add_highlight session.info-buf ns (. h 2) (. h 1) (. h 3) (. h 4))))

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

    (fn schedule-highlight-fill!
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

    {:apply-highlights! apply-highlights!
     :build-info-lines build-info-lines
     :schedule-highlight-fill! schedule-highlight-fill!}))

M
