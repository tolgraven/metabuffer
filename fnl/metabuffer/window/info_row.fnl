(local M {})
(local lineno-mod (require :metabuffer.window.lineno))
(local source-mod (require :metabuffer.source))
(local path-hl (require :metabuffer.path_highlight))
(local util (require :metabuffer.util))
(local helper-mod (require :metabuffer.window.info_helpers))

(local str (. helper-mod :str))
(local fit-path-into-width (. helper-mod :fit-path-into-width))
(local numeric-max (. helper-mod :numeric-max))

(local signcol-display-width 2)

(fn apply-highlights!
  [session ns highlights]
  (each [_ h (ipairs (or highlights []))]
    (vim.api.nvim_buf_add_highlight session.info-buf ns (. h 2) (. h 1) (. h 3) (. h 4))))

(fn default-file-hl
  []
  (if (= 1 (vim.fn.hlexists "NERDTreeFile"))
      "NERDTreeFile"
      (if (= 1 (vim.fn.hlexists "NetrwPlain"))
          "NetrwPlain"
          (if (= 1 (vim.fn.hlexists "NvimTreeFileName"))
              "NvimTreeFileName"
              "Normal"))))

(fn lightweight-info-view
  [base-path]
  {:path base-path
   :show-icon false
   :highlight-dir false
   :highlight-file false
   :suffix ""
   :suffix-highlights []
   :sign {:text "  " :hl "LineNr"}})

(fn info-view-for-row
  [deps session ref base-path path-width lightweight?]
  (if lightweight?
      (lightweight-info-view base-path)
      (source-mod.info-view
        session
        ref
        {:mode (or session.info-file-entry-view "meta")
         :path-width path-width
         :single-source? (and (not session.project-mode)
                              (not session.active-source-key))
         :read-file-lines-cached (. deps :read-file-lines-cached)
         :read-file-view-cached (. deps :read-file-view-cached)})))

(fn sign-parts
  [sign]
  (let [sign-raw (or (. sign :text) "")
        sign-pad (math.max 0 (- signcol-display-width (vim.fn.strdisplaywidth sign-raw)))
        sign-prefix (.. sign-raw (string.rep " " sign-pad))
        sign-glyph-start1 (or (string.find sign-prefix "%S") 0)
        sign-glyph (vim.trim sign-prefix)
        sign-glyph-start (if (> sign-glyph-start1 0) (- sign-glyph-start1 1) -1)
        sign-glyph-end (if (and (> sign-glyph-start1 0) (> (# sign-glyph) 0))
                           (+ sign-glyph-start (# sign-glyph))
                           -1)]
    {:prefix sign-prefix
     :width (# sign-prefix)
     :hl (or (. sign :hl) "LineNr")
     :highlights (or (. sign :highlights) [])
     :glyph-start sign-glyph-start
     :glyph-end sign-glyph-end}))

(fn normalized-info-view
  [base-path info-view]
  (let [path (or (. info-view :path) base-path)
        suffix (or (. info-view :suffix) "")]
    {:path path
     :icon-path (or (. info-view :icon-path) path)
     :show-icon? (if (= (. info-view :show-icon) nil) true (. info-view :show-icon))
     :highlight-dir? (if (= (. info-view :highlight-dir) nil) true (. info-view :highlight-dir))
     :highlight-file? (if (= (. info-view :highlight-file) nil) true (. info-view :highlight-file))
     :suffix suffix
     :suffix-prefix (if (> (# suffix) 0) (or (. info-view :suffix-prefix) "  ") "")
     :suffix-highlights (or (. info-view :suffix-highlights) [])
     :sign (or (. info-view :sign) {:text "  " :hl "LineNr"})}))

(fn icon-parts
  [icon-field show-icon? icon-path file-hl]
  (let [icon-info (if show-icon?
                      (util.file-icon-info icon-path file-hl)
                      {:icon "" :icon-hl file-hl :file-hl file-hl :ext-hl file-hl})
        icon (or (. icon-info :icon) "")
        iconf (icon-field icon)
        ext0 (util.ext-from-path icon-path)
        ext-bucket-hl (if (= ext0 "") nil (path-hl.group-for-segment ext0))]
    {:icon-prefix (if show-icon? (. iconf :text) "")
     :icon-width (if show-icon? (. iconf :width) 0)
     :icon-hl (or ext-bucket-hl (. icon-info :icon-hl) file-hl)
     :ext-hl (or ext-bucket-hl (. icon-info :ext-hl) (. icon-info :icon-hl) file-hl)
     :file-hl (or (. icon-info :file-hl) file-hl)}))

(fn row-layout
  [path path-width icon-width sign-prefix lnum-cell icon-prefix suffix suffix-prefix]
  (let [[dir file0 dir-original] (fit-path-into-width path (math.max 1 (- path-width icon-width)))
        sign-width (# sign-prefix)
        line (.. sign-prefix lnum-cell icon-prefix dir file0 suffix-prefix suffix)
        sign-start 0
        sign-end (+ sign-start sign-width)
        num-start sign-end
        num-end (+ num-start (# lnum-cell))
        icon-start num-end
        icon-end (+ icon-start (# icon-prefix))
        dir-start icon-end
        file-start (+ dir-start (# dir))
        suffix-start (+ file-start (# file0) (# suffix-prefix))]
    {:dir dir
     :file file0
     :dir-original dir-original
     :line line
     :sign-start sign-start
     :sign-end sign-end
     :num-start num-start
     :num-end num-end
     :icon-start icon-start
     :icon-end icon-end
     :dir-start dir-start
     :file-start file-start
     :suffix-start suffix-start}))

(fn append-sign-highlights!
  [highlights sign layout]
  (when (> (. sign :width) 0)
    (table.insert highlights ["SignColumn" (. layout :sign-start) (. layout :sign-end)]))
  (if (> (# (. sign :highlights)) 0)
      (each [_ part (ipairs (. sign :highlights))]
        (let [s (+ (. layout :sign-start) (or (. part :start) 0))
              e (+ (. layout :sign-start) (or (. part :end) 0))]
          (when (> e s)
            (table.insert highlights [(or (. part :hl) (. sign :hl)) s e]))))
      (when (and (> (. sign :glyph-end) (. sign :glyph-start)) (> (. sign :width) 0))
        (table.insert
          highlights
          [(. sign :hl)
           (+ (. layout :sign-start) (. sign :glyph-start))
           (+ (. layout :sign-start) (. sign :glyph-end))]))))

(fn append-path-highlights!
  [deps highlights row icon file-hl ext-hl]
  (table.insert highlights ["LineNr" (. row :num-start) (. row :num-end)])
  (when (> (# (. icon :icon-prefix)) 0)
    (table.insert highlights [(. icon :icon-hl) (. row :icon-start) (. row :icon-end)]))
  (when (and (. row :highlight-dir?) (> (# (. row :dir)) 0))
    (each [_ dr (ipairs (path-hl.ranges-for-dir (. row :dir) (. row :dir-start) (. row :dir-original)))]
      (table.insert highlights [dr.hl dr.start dr.end])))
  (when (and (. row :highlight-file?) (> (# (. row :file)) 0))
    (table.insert highlights [file-hl (. row :file-start) (+ (. row :file-start) (# (. row :file)))]))
  (when (and (. row :highlight-file?) (> (# (. row :file)) 0))
    (let [dot ((. deps :ext-start-in-file) (. row :file))]
      (when (> dot 0)
        (table.insert highlights [ext-hl (+ (. row :file-start) (- dot 1)) (+ (. row :file-start) (# (. row :file)))])))))

(fn append-suffix-highlights!
  [highlights row]
  (when (> (# (. row :suffix)) 0)
    (table.insert highlights ["Comment" (. row :suffix-start) (+ (. row :suffix-start) (# (. row :suffix)))]))
  (each [_ sh (ipairs (. row :suffix-highlights))]
    (let [s (+ (. row :suffix-start) (or sh.start 0))
          e (+ (. row :suffix-start) (or sh.end 0))]
      (when (> e s)
        (table.insert highlights [(or sh.hl "Comment") s e])))))

(fn row-highlight-context
  [layout info-view]
  {:dir (. layout :dir)
   :file (. layout :file)
   :dir-original (. layout :dir-original)
   :line (. layout :line)
   :sign-start (. layout :sign-start)
   :sign-end (. layout :sign-end)
   :num-start (. layout :num-start)
   :num-end (. layout :num-end)
   :icon-start (. layout :icon-start)
   :icon-end (. layout :icon-end)
   :dir-start (. layout :dir-start)
   :file-start (. layout :file-start)
   :suffix-start (. layout :suffix-start)
   :highlight-dir? (. info-view :highlight-dir?)
   :highlight-file? (. info-view :highlight-file?)
   :suffix (. info-view :suffix)
   :suffix-highlights (. info-view :suffix-highlights)})

(fn build-info-row
  [deps {: session : ref : src-idx : target-width : lnum-digit-width : lightweight?}]
  "Build one info line plus inline highlight ranges. Expected output: {:line string :highlights [...]}."
  (let [file-hl (default-file-hl)
        lnum (tostring (or (and ref ref.lnum) src-idx))
        lnum-cell (lineno-mod.lnum-cell lnum lnum-digit-width)
        base-path (vim.fn.fnamemodify (or (and ref ref.path) "[Current Buffer]") ":~:.")
        path-width (math.max 1 (- target-width (+ lnum-digit-width 1) signcol-display-width))
        info-view (normalized-info-view base-path (info-view-for-row deps session ref base-path path-width lightweight?))
        sign (sign-parts (. info-view :sign))
        icon (icon-parts (. deps :icon-field) (. info-view :show-icon?) (. info-view :icon-path) file-hl)
        layout (row-layout (. info-view :path)
                           path-width
                           (. icon :icon-width)
                           (. sign :prefix)
                           lnum-cell
                           (. icon :icon-prefix)
                           (. info-view :suffix)
                           (. info-view :suffix-prefix))
        row (row-highlight-context layout info-view)
        highlights []]
    (append-sign-highlights! highlights sign layout)
    (append-path-highlights! deps highlights row icon (. icon :file-hl) (. icon :ext-hl))
    (append-suffix-highlights! highlights row)
    {:line (. row :line) :highlights highlights}))

(fn visible-lnum-digit-width
  [refs idxs start-index stop-index visible-start visible-stop]
  (let [vis-lo (math.max 1 (or visible-start start-index))
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
    (lineno-mod.digit-width-from-max-len max-lnum-len)))

(fn build-info-lines
  [deps {: session : refs : idxs : target-width : start-index : stop-index : visible-start : visible-stop}]
  (let [lnum-digit-width (visible-lnum-digit-width refs idxs start-index stop-index visible-start visible-stop)
        lines []
        highlights []
        deferred-rows []]
    (if (= (# idxs) 0)
        (table.insert lines "No matches")
        (for [i start-index stop-index]
          (let [src-idx (. idxs i)
                ref (. refs src-idx)
                row0 (- i 1)
                built (build-info-row
                        deps
                        {:session session
                         :ref ref
                         :src-idx src-idx
                         :target-width target-width
                         :lnum-digit-width lnum-digit-width
                         :lightweight? false})]
            (table.insert lines (. built :line))
            (each [_ h (ipairs (or (. built :highlights) []))]
              (table.insert highlights [row0 (. h 1) (. h 2) (. h 3)])))))
    {:lines lines :highlights highlights :deferred-rows deferred-rows :lnum-digit-width lnum-digit-width}))

(fn apply-highlight-fill-row!
  [deps session refs target-width lnum-digit-width spec]
  (let [row0 (. spec 1)
        src-idx (. spec 2)
        ref (. refs src-idx)
        built (build-info-row
                deps
                {:session session
                 :ref ref
                 :src-idx src-idx
                 :target-width target-width
                 :lnum-digit-width lnum-digit-width
                 :lightweight? false})
        highlights []]
    (vim.api.nvim_buf_set_lines session.info-buf row0 (+ row0 1) false [(str (. built :line))])
    (vim.api.nvim_buf_clear_namespace session.info-buf (. deps :info-content-ns) row0 (+ row0 1))
    (each [_ h (ipairs (or (. built :highlights) []))]
      (table.insert highlights [row0 (. h 1) (. h 2) (. h 3)]))
    (apply-highlights! session (. deps :info-content-ns) highlights)))

(fn fill-highlight-batch!
  [deps session refs target-width lnum-digit-width pending next-index stop]
  (let [bo (. vim.bo session.info-buf)]
    (set (. bo :modifiable) true))
  (for [i next-index stop]
    (apply-highlight-fill-row! deps session refs target-width lnum-digit-width (. pending i)))
  (let [bo (. vim.bo session.info-buf)]
    (set (. bo :modifiable) false)))

(fn start-highlight-fill!
  [deps session refs target-width lnum-digit-width pending batch-size]
  (let [refresh-info-statusline! (. deps :refresh-info-statusline!)
        token (+ 1 (or session.info-highlight-fill-token 0))]
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
        (let [stop (math.min (# pending) (+ next-index batch-size -1))]
          (fill-highlight-batch! deps session refs target-width lnum-digit-width pending next-index stop)
          (if (< stop (# pending))
              (do
                (set next-index (+ stop 1))
                (vim.defer_fn run-batch 17))
              (do
                (set session.info-highlight-fill-pending? false)
                (refresh-info-statusline! session))))))
    (vim.defer_fn run-batch 17)))

(fn schedule-highlight-fill!
  [deps {: session : refs : target-width : lnum-digit-width : deferred-rows}]
  (let [pending (or deferred-rows [])
        batch-size (math.max 4 (math.min 24 (math.max 1 ((. deps :info-height) session))))]
    (if (= (# pending) 0)
        (do
          (set session.info-highlight-fill-pending? false)
          ((. deps :refresh-info-statusline!) session))
        (start-highlight-fill! deps session refs target-width lnum-digit-width pending batch-size))))

(fn M.new
  [opts]
  "Build info-row render and highlight-fill helpers."
  (let [deps (or opts {})]
    {:apply-highlights! apply-highlights!
     :build-info-lines (fn [spec] (build-info-lines deps spec))
     :schedule-highlight-fill! (fn [spec] (schedule-highlight-fill! deps spec))}))

M
