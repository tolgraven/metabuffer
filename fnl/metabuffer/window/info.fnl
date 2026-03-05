(local M {})

(fn ext-from-path [path]
  (let [file (vim.fn.fnamemodify (or path "") ":t")
        dot (string.match file ".*()%.")]
    (if (and dot (> dot 0) (< dot (# file)))
        (string.sub file (+ dot 1))
        "")))

(fn devicon-for-path [path fallback-hl]
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

(fn icon-field [icon]
  (if (and (= (type icon) "string") (~= icon ""))
      (let [text (.. icon " ")]
        {:text text :width (vim.fn.strdisplaywidth text)})
      {:text "" :width 0}))

(fn compact-dir [dir]
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

(fn compact-dir-keep-last [dir]
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

(fn fit-path-into-width [path path-width]
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
                        ["" (if (> budget 3)
                                (.. "..." (string.sub file (+ (- (# file) budget) 4)))
                                (string.sub file (+ (- (# file) budget) 1)))]
                        (let [dir-budget (math.max 0 (- budget (# file)))
                              short-dir (if (<= (# cdir) dir-budget)
                                            cdir
                                            (if (> dir-budget 3)
                                                (.. "..." (string.sub cdir (+ (- (# cdir) dir-budget) 4)))
                                                (string.sub cdir (+ (- (# cdir) dir-budget) 1))))]
                          [short-dir file])))))))))

(fn info-range [selected-index total cap]
  (if (or (<= total 0) (<= cap 0))
      [1 0]
      (if (<= total cap)
          [1 total]
          (let [sel (math.max 1 (math.min total (+ selected-index 1)))
                half (math.floor (/ cap 2))
                start (math.max 1 (math.min (- sel half) (+ (- total cap) 1)))
                stop (math.min total (+ start cap -1))]
            [start stop]))))

(fn lnum-width-from-max-len [max-len]
  (math.max 2 (# (tostring (math.max 1 (or max-len 1))))))

(fn lnum-cell [lnum width]
  (let [s (tostring lnum)]
    (.. (string.rep " " (math.max 0 (- width (# s)))) s " ")))

(fn numeric-max [vals default]
  (if (or (not vals) (= (# vals) 0))
      default
      (let [m (or (. vals 1) default)]
        (var out m)
        (each [_ v (ipairs vals)]
          (when (> v out)
            (set out v)))
        out)))

(fn M.new [opts]
  (local floating-window-mod (. opts :floating-window-mod))
  (local info-min-width (. opts :info-min-width))
  (local info-max-width (. opts :info-max-width))
  (local info-max-lines (. opts :info-max-lines))
  (local info-height (. opts :info-height))
  (local debug-log (. opts :debug-log))
  (local update-preview (. opts :update-preview))

  (fn ensure-info-window! [session]
    (when (not (and session.info-win (vim.api.nvim_win_is_valid session.info-win)))
      (let [buf (vim.api.nvim_create_buf false true)
            width info-min-width
            height (info-height session)
            col vim.o.columns
            row 1
            win (floating-window-mod.new vim buf {:width width :height height :col col :row row})]
        (set session.info-buf buf)
        (set session.info-win win.window)
        (let [bo (. vim.bo buf)]
          (set (. bo :buftype) "nofile")
          (set (. bo :bufhidden) "wipe")
          (set (. bo :swapfile) false)
          (set (. bo :modifiable) false)
          (set (. bo :filetype) "metabuffer")))))

  (fn close-info-window! [session]
    (when (and session.info-win (vim.api.nvim_win_is_valid session.info-win))
      (pcall vim.api.nvim_win_close session.info-win true))
    (set session.info-win nil)
    (set session.info-buf nil))

  (fn fit-info-width! [session lines]
    (when (and session.info-win (vim.api.nvim_win_is_valid session.info-win))
      (let [widths (vim.tbl_map (fn [line] (# line)) (or lines []))
            max-len (numeric-max widths 0)
            needed max-len
            max-available (math.max info-min-width (math.floor (* vim.o.columns 0.34)))
            upper (math.min info-max-width max-available)
            target (math.max info-min-width (math.min needed upper))
            height (info-height session)
            cfg {:relative "editor"
                 :anchor "NE"
                 :row 1
                 :col vim.o.columns
                 :width target
                 :height height}]
        (pcall vim.api.nvim_win_set_config session.info-win cfg))))

  (fn info-max-width-now []
    (let [max-available (math.max info-min-width (math.floor (* vim.o.columns 0.34)))]
      (math.min info-max-width max-available)))

  (fn info-visible-range [session meta total cap]
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

  (fn build-info-lines [meta refs idxs target-width start-index stop-index]
    (let [line-hl "LineNr"
          dir-hl (if (= 1 (vim.fn.hlexists "NERDTreeDir"))
                     "NERDTreeDir"
                     (if (= 1 (vim.fn.hlexists "NetrwDir")) "NetrwDir" "Directory"))
          file-hl (if (= 1 (vim.fn.hlexists "NERDTreeFile"))
                      "NERDTreeFile"
                      (if (= 1 (vim.fn.hlexists "NetrwPlain"))
                          "NetrwPlain"
                          (if (= 1 (vim.fn.hlexists "NvimTreeFileName"))
                              "NvimTreeFileName"
                              "Normal")))
          lnum-width (let [limit (math.min (# idxs) info-max-lines)
                           max-lnum-len (if (> limit 0)
                                            (let [lens []]
                                              (for [i 1 limit]
                                                (let [src-idx (. idxs i)
                                                      ref (. refs src-idx)
                                                      lnum (tostring (or (and ref ref.lnum) src-idx))]
                                                  (table.insert lens (# lnum))))
                                              (numeric-max lens 1))
                                            1)]
                       (lnum-width-from-max-len max-lnum-len))
          path-width (math.max 1 (- target-width lnum-width))
          lines []
          highlights []]
      (if (= (# idxs) 0)
          (table.insert lines "No hits")
          (do
            (for [i start-index stop-index]
              (let [src-idx (. idxs i)
                    ref (. refs src-idx)
                    lnum (tostring (or (and ref ref.lnum) src-idx))
                    lnum-cell0 (lnum-cell lnum lnum-width)
                    path (vim.fn.fnamemodify (or (and ref ref.path) "[Current Buffer]") ":~:.")
                    icon-info (devicon-for-path path file-hl)
                    icon (or (. icon-info :icon) "")
                    iconf (icon-field icon)
                    icon-prefix (. iconf :text)
                    icon-hl (or (. icon-info :icon-hl) file-hl)
                    icon-width (. iconf :width)
                    [dir file0] (fit-path-into-width path (math.max 1 (- path-width icon-width)))
                    file (.. icon-prefix file0)
                    this-file-hl (or (. icon-info :file-hl) file-hl)
                    row (# lines)
                    line (.. lnum-cell0 icon-prefix dir file0)
                    num-start 0
                    num-end (+ num-start (# lnum-cell0))
                    icon-start num-end
                    icon-end (+ icon-start (# icon-prefix))
                    dir-start icon-end
                    file-start (+ dir-start (# dir))]
                (table.insert lines line)
                (table.insert highlights [row line-hl num-start num-end])
                (when (> (# icon-prefix) 0)
                  (table.insert highlights [row icon-hl icon-start icon-end]))
                (when (> (# dir) 0)
                  (table.insert highlights [row dir-hl dir-start (+ dir-start (# dir))]))
                (table.insert highlights [row this-file-hl file-start (+ file-start (# file0))])))))
      {:lines lines :highlights highlights}))

  (fn render-info-lines! [session meta start-index stop-index]
    (let [refs (or meta.buf.source-refs [])
          idxs (or meta.buf.indices [])
          _ (set session.info-start-index start-index)
          _ (set session.info-stop-index stop-index)
          built (build-info-lines meta refs idxs (info-max-width-now) start-index stop-index)
          raw-lines (. built :lines)
          lines (if (= (type raw-lines) "table")
                    (vim.tbl_map tostring raw-lines)
                    [(tostring raw-lines)])
          highlights (or (. built :highlights) [])
          ns (vim.api.nvim_create_namespace "MetaInfoWindow")]
      (debug-log (.. "info render hits=" (tostring (# idxs))
                     " lines=" (tostring (# lines))))
      (let [bo (. vim.bo session.info-buf)]
        (set (. bo :modifiable) true))
      (fit-info-width! session lines)
      (let [[ok-set err-set] [(pcall vim.api.nvim_buf_set_lines session.info-buf 0 -1 false lines)]]
        (when (not ok-set)
          (debug-log (.. "info set_lines failed: " (tostring err-set)))))
      (vim.api.nvim_buf_clear_namespace session.info-buf ns 0 -1)
      (each [_ h (ipairs highlights)]
        (vim.api.nvim_buf_add_highlight session.info-buf ns (. h 2) (. h 1) (. h 3) (. h 4)))
      (let [bo (. vim.bo session.info-buf)]
        (set (. bo :modifiable) false))))

  (fn sync-info-cursor! [session meta]
    (when (vim.api.nvim_win_is_valid session.info-win)
      (let [idxs (or meta.buf.indices [])
            info-lines (vim.api.nvim_buf_line_count session.info-buf)
            start-index (or session.info-start-index 1)
            stop-index (or session.info-stop-index (math.min (# idxs) info-max-lines))
            hits-shown (if (>= stop-index start-index) (+ (- stop-index start-index) 1) 0)
            hits-total (# idxs)
            status (.. " Hits " hits-shown "/" hits-total " ")
            selected1 (+ meta.selected_index 1)
            row (if (> info-lines 0)
                    (math.max 1 (math.min (+ (- selected1 start-index) 1) info-lines))
                    1)]
        (pcall vim.api.nvim_win_set_option session.info-win "statusline" status)
        (when (> info-lines 0)
          (let [[ok-cur err-cur] [(pcall vim.api.nvim_win_set_cursor session.info-win [row 0])]]
            (when (not ok-cur)
              (debug-log (.. "info set_cursor failed: " (tostring err-cur)))))))))

  (fn update-regular! [session]
    (close-info-window! session)
    (update-preview session))

  (fn update-project! [session refresh-lines]
    (ensure-info-window! session)
    (debug-log (.. "info enter refresh=" (tostring refresh-lines)
                   " selected=" (tostring session.meta.selected_index)
                   " info-win=" (tostring session.info-win)
                   " info-buf=" (tostring session.info-buf)))
    (when (and session.info-buf (vim.api.nvim_buf_is_valid session.info-buf))
      (let [meta session.meta]
        (let [selected1 (+ meta.selected_index 1)
              [wanted-start wanted-stop] (info-visible-range session meta (# (or meta.buf.indices [])) info-max-lines)
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
                          (tostring (info-max-width-now))
                          "|"
                          (tostring (info-height session))
                          "|"
                          (tostring vim.o.columns))]
              ;; Selection can move outside currently rendered slice while
              ;; indices/layout stay identical. Re-render to recenter.
              (when (or out-of-range range-changed (~= session.info-render-sig sig))
                (set session.info-render-sig sig)
                (render-info-lines! session meta wanted-start wanted-stop))))
          (sync-info-cursor! session meta))))
    (update-preview session))

  {:close-window! close-info-window!
   :update! (fn [session refresh-lines]
              (let [refresh-lines (if (= refresh-lines nil) true refresh-lines)]
                (if session.project-mode
                    (update-project! session refresh-lines)
                    (update-regular! session))))})

M
