(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})
(local lineno-mod (require :metabuffer.window.lineno))
(local source-mod (require :metabuffer.source))
(local path-hl (require :metabuffer.path_highlight))
(local util (require :metabuffer.util))

(fn ext-start-in-file
  [file]
  (let [txt (or file "")
        n (# txt)]
    (var dot 0)
    (for [i n 1 -1]
      (when (and (= dot 0) (= (string.sub txt i i) "."))
        (set dot i)))
    (if (and (> dot 1) (< dot n))
        dot
        0)))

(fn icon-field
  [icon]
  (if (and (= (type icon) "string") (~= icon ""))
      (let [text (.. icon " ")]
        {:text text :width (vim.fn.strdisplaywidth text)})
      {:text "" :width 0}))

(fn compact-dir
  [dir]
  (if (or (= dir "") (= dir "."))
      ""
      (let [parts (vim.split dir "/" {:plain true})
            out []]
        (each [_ p (ipairs (or parts []))]
          (when (~= p "")
            (table.insert out (string.sub p 1 1))))
        (if (= (# out) 0)
            ""
            (.. (table.concat out "/") "/")))))

(fn compact-dir-keep-last
  [dir]
  (if (or (= dir "") (= dir "."))
      ""
      (let [parts0 (vim.split dir "/" {:plain true})
            parts []]
        (each [_ p (ipairs (or parts0 []))]
          (when (~= p "")
            (table.insert parts p)))
        (let [n (# parts)]
          (if (= n 0)
              ""
              (if (= n 1)
                  (.. (. parts 1) "/")
                  (let [out []]
                    (for [i 1 (- n 1)]
                      (table.insert out (string.sub (. parts i) 1 1)))
                    (table.insert out (. parts n))
                    (.. (table.concat out "/") "/"))))))))

(fn fit-path-into-width
  [path path-width]
  "Shrink directory segments so file path fits the info window width budget."
  (let [dir0 (vim.fn.fnamemodify path ":h")
        dir (if (or (= dir0 ".") (= dir0 "")) "" (.. dir0 "/"))
        file (vim.fn.fnamemodify path ":t")
        budget (math.max 1 path-width)
        full (.. dir file)]
    (if (<= (# full) budget)
        [dir file]
        (let [kdir (compact-dir-keep-last dir0)
              keep-last (.. kdir file)]
          (if (<= (# keep-last) budget)
              [kdir file]
              (let [cdir (compact-dir dir0)
                    compact (.. cdir file)]
                (if (<= (# compact) budget)
                    [cdir file]
                    (if (> (# file) budget)
                        ["" (if (> budget 1)
                                (.. "…" (string.sub file (+ (- (# file) budget) 2)))
                                (string.sub file (+ (- (# file) budget) 1)))]
                        (let [dir-budget (math.max 0 (- budget (# file)))
                              short-dir (if (<= (# cdir) dir-budget)
                                            cdir
                                            (if (> dir-budget 1)
                                                (.. "…" (string.sub cdir (+ (- (# cdir) dir-budget) 2)))
                                                (string.sub cdir (+ (- (# cdir) dir-budget) 1))))]
                          [short-dir file])))))))))

(fn info-range
  [selected-index total cap]
  (if (or (<= total 0) (<= cap 0))
      [1 0]
      (if (<= total cap)
          [1 total]
          (let [sel (math.max 1 (math.min total (+ selected-index 1)))
                half (math.floor (/ cap 2))
                start (math.max 1 (math.min (- sel half) (+ (- total cap) 1)))
                stop (math.min total (+ start cap -1))]
            [start stop]))))

(fn numeric-max
  [vals default]
  (if (or (not vals) (= (# vals) 0))
      default
      (let [m (or (. vals 1) default)]
        (var out m)
        (each [_ v (ipairs vals)]
          (when (> v out)
            (set out v)))
        out)))

(fn M.new
  [opts]
  "Create right-side info window renderer/synchronizer."
  (let [deps (or opts {})
        floating_window_mod (. deps :floating-window-mod)
        info_min_width (. deps :info-min-width)
        info_max_width (. deps :info-max-width)
        info_max_lines (. deps :info-max-lines)
        info_height (. deps :info-height)
        debug_log (. deps :debug-log)
        update_preview (. deps :update-preview)
        read_file_lines_cached (. deps :read-file-lines-cached)
        animation_mod (. deps :animation-mod)
        animate_enter? (. deps :animate-enter?)
        info_fade_ms (. deps :info-fade-ms)]
    (do

  (local info_window_config
    (fn
    [session width height]
    (let [host-win (if (and session
                            session.meta
                            session.meta.win
                            (vim.api.nvim_win_is_valid session.meta.win.window))
                       session.meta.win.window
                       session.prompt-win)]
    (if session.window-local-layout
        {:relative "win"
         :win host-win
         :anchor "NE"
         :row 0
         :col (vim.api.nvim_win_get_width host-win)
         :width width
         :height height}
        {:relative "editor"
         :anchor "NE"
         :row 1
         :col vim.o.columns
         :width width
         :height height}))))

  (local ensure_info_window!
    (fn
    [session]
    (when-not (and session.info-win (vim.api.nvim_win_is_valid session.info-win))
      (let [buf (vim.api.nvim_create_buf false true)
            width info_min_width
            height (info_height session)
            target (info_window_config session width height)
            animate-info? (and animation_mod
                               animate_enter?
                               (animate_enter? session)
                               (animation_mod.enabled? session :info)
                               (not session.info-animated?))
            cfg (if animate-info?
                    (let [start (vim.deepcopy target)]
                      (set (. start :col) (+ (. target :col) 8))
                      start)
                    target)
            win (floating_window_mod.new vim buf cfg)]
        (set session.info-buf buf)
        (set session.info-win win.window)
        (let [bo (. vim.bo buf)]
          (set (. bo :buftype) "nofile")
          (set (. bo :bufhidden) "wipe")
          (set (. bo :swapfile) false)
          (set (. bo :modifiable) false)
          (set (. bo :filetype) "metabuffer"))
        (let [wo (. vim.wo win.window)]
          (set (. wo :statusline) "")
          (set (. wo :winbar) "")
          (set (. wo :number) false)
          (set (. wo :relativenumber) false)
          (set (. wo :wrap) false)
          (set (. wo :linebreak) false)
          (set (. wo :signcolumn) "no")
          (set (. wo :foldcolumn) "0")
          (set (. wo :spell) false))
        (when animate-info?
          (set session.info-animated? true)
          (pcall vim.api.nvim_set_option_value "winblend" 85 {:win session.info-win})
          (vim.defer_fn
            (fn []
              (when (and session.info-win (vim.api.nvim_win_is_valid session.info-win))
                (animation_mod.animate-float!
                  session
                  "info-enter"
                  session.info-win
                  cfg
                  target
                  85
                  (or vim.g.meta_float_winblend 13)
                  (animation_mod.duration-ms session :info (or info_fade_ms 220)))))
            (if (and animation_mod (animation_mod.enabled? session :prompt))
                (animation_mod.duration-ms session :prompt 140)
                0))))))))

  (fn settle-info-window!
    [session]
    (when (and session.info-win (vim.api.nvim_win_is_valid session.info-win))
      (let [width (vim.api.nvim_win_get_width session.info-win)
            height (info_height session)
            cfg (info_window_config session width height)]
        (pcall vim.api.nvim_win_set_config session.info-win cfg))))

  (fn close-info-window!
    [session]
    (when (and session.info-win (vim.api.nvim_win_is_valid session.info-win))
      (pcall vim.api.nvim_win_close session.info-win true))
    (set session.info-win nil)
    (set session.info-buf nil))

  (fn fit-info-width!
    [session lines]
    (when (and session.info-win (vim.api.nvim_win_is_valid session.info-win))
      (let [widths (vim.tbl_map (fn [line] (vim.fn.strdisplaywidth (or line ""))) (or lines []))
            max-len (numeric-max widths 0)
            needed max-len
            host-width (if (and session.window-local-layout
                                session.meta
                                session.meta.win
                                (vim.api.nvim_win_is_valid session.meta.win.window))
                           (vim.api.nvim_win_get_width session.meta.win.window)
                           (if session.window-local-layout
                               (vim.api.nvim_win_get_width session.prompt-win)
                               vim.o.columns))
            max-available (math.max info_min_width (math.floor (* host-width 0.34)))
            upper (math.min info_max_width max-available)
            target (math.max info_min_width (math.min needed upper))
            height (info_height session)
            cfg (info_window_config session target height)]
        (pcall vim.api.nvim_win_set_config session.info-win cfg))))

  (fn info-max-width-now
    [session]
    (let [host-width (if (and session
                              session.window-local-layout
                              session.meta
                              session.meta.win
                              (vim.api.nvim_win_is_valid session.meta.win.window))
                         (vim.api.nvim_win_get_width session.meta.win.window)
                         (if (and session session.window-local-layout)
                             (vim.api.nvim_win_get_width session.prompt-win)
                             vim.o.columns))
          max-available (math.max info_min_width (math.floor (* host-width 0.34)))]
      (math.min info_max_width max-available)))

  (fn info-visible-range
    [session meta total cap]
    (if (or (<= total 0) (<= cap 0))
        [1 0]
        (if (and session
                 meta
                 meta.win
                 (vim.api.nvim_win_is_valid meta.win.window))
            (let [view (vim.api.nvim_win_call meta.win.window (fn [] (vim.fn.winsaveview)))
                  top (math.max 1 (math.min total (or (. view :topline) 1)))
                  height (math.max 1 (vim.api.nvim_win_get_height meta.win.window))
                  stop0 (math.min total (+ top height -1))
                  shown (math.max 1 (+ (- stop0 top) 1))]
              (if (<= shown cap)
                  [top stop0]
                  [top (+ top cap -1)]))
            (info-range meta.selected_index total cap))))

  (fn build-info-lines
    [session refs idxs target-width start-index stop-index read_file_lines_cached]
    (let [line-hl "LineNr"
          signcol-display-width 2
          file-hl (if (= 1 (vim.fn.hlexists "NERDTreeFile"))
                      "NERDTreeFile"
                      (if (= 1 (vim.fn.hlexists "NetrwPlain"))
                          "NetrwPlain"
                          (if (= 1 (vim.fn.hlexists "NvimTreeFileName"))
                              "NvimTreeFileName"
                              "Normal")))
          lnum-digit-width (let [limit (math.min (# idxs) info_max_lines)
                           max-lnum-len (if (> limit 0)
                                            (let [lens []]
                                              (for [i 1 limit]
                                                (let [src-idx (. idxs i)
                                                      ref (. refs src-idx)
                                                      lnum (tostring (or (and ref ref.lnum) src-idx))]
                                                  (table.insert lens (# lnum))))
                                              (numeric-max lens 1))
                                            1)]
                       (lineno-mod.digit-width-from-max-len max-lnum-len))
          lnum-field-width (+ lnum-digit-width 1)
          path-width (math.max 1 (- target-width lnum-field-width signcol-display-width))
          lines []
          highlights []]
      (if (= (# idxs) 0)
          (table.insert lines "No matches")
          (for [i start-index stop-index]
              (let [src-idx (. idxs i)
                    ref (. refs src-idx)
                    view-mode (or session.info-file-entry-view "meta")
                    lnum (tostring (or (and ref ref.lnum) src-idx))
                    lnum-cell0 (lineno-mod.lnum-cell lnum lnum-digit-width)
                    base-path (vim.fn.fnamemodify (or (and ref ref.path) "[Current Buffer]") ":~:.")
                    info-view (source-mod.info-view
                               session
                               ref
                               {:mode view-mode
                                :path-width path-width
                                :read-file-lines-cached read_file_lines_cached})
                    sign (or (. info-view :sign) {:text "  " :hl "LineNr"})
                    sign-raw (or (. sign :text) "")
                    sign-pad (math.max 0 (- signcol-display-width (vim.fn.strdisplaywidth sign-raw)))
                    sign-prefix (.. sign-raw (string.rep " " sign-pad))
                    sign-hl (or (. sign :hl) "LineNr")
                    sign-width (# sign-prefix)
                    sign-glyph-start1 (or (string.find sign-prefix "%S") 0)
                    sign-glyph (vim.trim sign-prefix)
                    sign-glyph-start (if (> sign-glyph-start1 0)
                                         (- sign-glyph-start1 1)
                                         -1)
                    sign-glyph-end (if (and (> sign-glyph-start1 0) (> (# sign-glyph) 0))
                                       (+ sign-glyph-start (# sign-glyph))
                                       -1)
                    path (or (. info-view :path) base-path)
                    icon-path (or (. info-view :icon-path) path)
                    show-icon? (if (= (. info-view :show-icon) nil) true (. info-view :show-icon))
                    highlight-dir? (if (= (. info-view :highlight-dir) nil) true (. info-view :highlight-dir))
                    highlight-file? (if (= (. info-view :highlight-file) nil) true (. info-view :highlight-file))
                    suffix0 (or (. info-view :suffix) "")
                    suffix-prefix (if (> (# suffix0) 0)
                                      (or (. info-view :suffix-prefix) "  ")
                                      "")
                    suffix-hls (or (. info-view :suffix-highlights) [])
                    icon-info (util.devicon-info icon-path file-hl)
                    icon (or (. icon-info :icon) "")
                    iconf (icon-field icon)
                    icon-prefix (if show-icon? (. iconf :text) "")
                    icon-hl (or (. icon-info :icon-hl) file-hl)
                    icon-width (if show-icon? (. iconf :width) 0)
                    [dir file0] (fit-path-into-width path (math.max 1 (- path-width icon-width)))
                    this-file-hl (or (. icon-info :file-hl) file-hl)
                    row (# lines)
                    line (.. sign-prefix lnum-cell0 icon-prefix dir file0 suffix-prefix suffix0)
                    sign-start 0
                    sign-end (+ sign-start sign-width)
                    num-start sign-end
                    num-end (+ num-start (# lnum-cell0))
                    icon-start num-end
                    icon-end (+ icon-start (# icon-prefix))
                    dir-start icon-end
                    file-start (+ dir-start (# dir))
                    suffix-start (+ file-start (# file0) (# suffix-prefix))]
                (table.insert lines line)
                (when (> sign-width 0)
                  ;; Fake signcolumn base to keep stable background even for empty rows.
                  (table.insert highlights [row "SignColumn" sign-start sign-end]))
                (when (and (> sign-glyph-end sign-glyph-start) (> sign-width 0))
                  (table.insert highlights [row sign-hl
                                            (+ sign-start sign-glyph-start)
                                            (+ sign-start sign-glyph-end)]))
                (table.insert highlights [row line-hl num-start num-end])
                (when (> (# icon-prefix) 0)
                  (table.insert highlights [row icon-hl icon-start icon-end]))
                (when (and highlight-dir? (> (# dir) 0))
                  (each [_ dr (ipairs (path-hl.ranges-for-dir dir dir-start))]
                    (table.insert highlights [row dr.hl dr.start dr.end])))
                (when (and highlight-file? (> (# file0) 0))
                  (table.insert highlights [row this-file-hl file-start (+ file-start (# file0))]))
                (when (and highlight-file? (> (# file0) 0))
                  (let [dot (ext-start-in-file file0)]
                    (when (> dot 0)
                      (table.insert highlights
                                    [row icon-hl
                                     (+ file-start (- dot 1))
                                     (+ file-start (# file0))]))))
                (when (> (# suffix0) 0)
                  (table.insert highlights [row "Comment" suffix-start (+ suffix-start (# suffix0))]))
                (each [_ sh (ipairs suffix-hls)]
                  (let [s (+ suffix-start (or sh.start 0))
                        e (+ suffix-start (or sh.end 0))]
                    (when (> e s)
                      (table.insert highlights [row (or sh.hl "Comment") s e])))))))
      {:lines lines :highlights highlights}))

  (fn render-info-lines!
    [session meta start-index stop-index]
    (let [refs (or meta.buf.source-refs [])
          idxs (or meta.buf.indices [])
          _ (set session.info-start-index start-index)
          _ (set session.info-stop-index stop-index)
          built (build-info-lines session refs idxs (info-max-width-now session) start-index stop-index read_file_lines_cached)
          raw-lines (. built :lines)
          lines (if (= (type raw-lines) "table")
                    (vim.tbl_map tostring raw-lines)
                    [(tostring raw-lines)])
          highlights (or (. built :highlights) [])
          ns (vim.api.nvim_create_namespace "MetaInfoWindow")]
      (debug_log (.. "info render hits=" (tostring (# idxs))
                     " lines=" (tostring (# lines))))
      (let [bo (. vim.bo session.info-buf)]
        (set (. bo :modifiable) true))
      (fit-info-width! session lines)
      (let [[ok-set err-set] [(pcall vim.api.nvim_buf_set_lines session.info-buf 0 -1 false lines)]]
        (when-not ok-set
          (debug_log (.. "info set_lines failed: " (tostring err-set)))))
      (vim.api.nvim_buf_clear_namespace session.info-buf ns 0 -1)
      (each [_ h (ipairs highlights)]
        (vim.api.nvim_buf_add_highlight session.info-buf ns (. h 2) (. h 1) (. h 3) (. h 4)))
      (let [bo (. vim.bo session.info-buf)]
        (set (. bo :modifiable) false))))

  (fn sync-info-cursor!
    [session meta]
    (when (vim.api.nvim_win_is_valid session.info-win)
      (let [info-lines (vim.api.nvim_buf_line_count session.info-buf)
            start-index (or session.info-start-index 1)
            selected1 (+ meta.selected_index 1)
            row (if (> info-lines 0)
                    (math.max 1 (math.min (+ (- selected1 start-index) 1) info-lines))
                    1)]
        (when (> info-lines 0)
          (let [[ok-cur err-cur] [(pcall vim.api.nvim_win_set_cursor session.info-win [row 0])]]
            (when-not ok-cur
              (debug_log (.. "info set_cursor failed: " (tostring err-cur)))))))))

  (fn update-regular!
    [session]
    (close-info-window! session)
    (update_preview session))

  (fn update-project!
    [session refresh-lines]
    (update_preview session)
    (ensure_info_window! session)
    (settle-info-window! session)
    (debug_log (.. "info enter refresh=" (tostring refresh-lines)
                   " selected=" (tostring session.meta.selected_index)
                   " info-win=" (tostring session.info-win)
                   " info-buf=" (tostring session.info-buf)))
    (when (and session.info-win (vim.api.nvim_win_is_valid session.info-win))
      (pcall vim.api.nvim_set_option_value "statusline" "" {:win session.info-win})
      (pcall vim.api.nvim_set_option_value "winbar" "" {:win session.info-win}))
    (when (and session.info-buf (vim.api.nvim_buf_is_valid session.info-buf))
      (let [meta session.meta]
        (let [selected1 (+ meta.selected_index 1)
              [wanted-start wanted-stop] (info-visible-range session meta (# (or meta.buf.indices [])) info_max_lines)
              start-index (or session.info-start-index 1)
              stop-index (or session.info-stop-index 0)
              out-of-range (or (< selected1 start-index) (> selected1 stop-index))
              range-changed (or (~= wanted-start start-index) (~= wanted-stop stop-index))]
          (when (or refresh-lines out-of-range range-changed)
            (let [idxs (or meta.buf.indices [])
                  sig (.. (tostring idxs)
                          "|"
                          (tostring (# idxs))
                          "|"
                          (tostring wanted-start)
                          "|"
                          (tostring wanted-stop)
                          "|"
                          (tostring (info-max-width-now session))
                          "|"
                          (tostring (info_height session))
                          "|"
                          (tostring vim.o.columns))]
              ;; Selection can move outside currently rendered slice while
              ;; indices/layout stay identical. Re-render to recenter.
              (when (or out-of-range range-changed (~= session.info-render-sig sig))
                (set session.info-render-sig sig)
                (render-info-lines! session meta wanted-start wanted-stop))))
          (sync-info-cursor! session meta)))))

  {:close-window! close-info-window!
   :update! (fn [session refresh-lines]
              (let [refresh-lines (if (= refresh-lines nil) true refresh-lines)]
                (if session.project-mode
                    (update-project! session refresh-lines)
                    (update-regular! session))))}))

M
