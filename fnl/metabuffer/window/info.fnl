(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local M {})
(local lineno-mod (require :metabuffer.window.lineno))
(local source-mod (require :metabuffer.source))
(local path-hl (require :metabuffer.path_highlight))
(local util (require :metabuffer.util))
(local base-window-mod (require :metabuffer.window.base))
(local file-info (require :metabuffer.source.file_info))
(local events (require :metabuffer.events))
(local apply-metabuffer-window-highlights! (. base-window-mod :apply-metabuffer-window-highlights!))

(fn str
  [x]
  (tostring x))

(local info-content-ns (vim.api.nvim_create_namespace "MetaInfoWindow"))
(local info-selection-ns (vim.api.nvim_create_namespace "MetaInfoSelection"))

(fn join-str
  [sep xs]
  (let [out []]
    (each [_ x (ipairs (or xs []))]
      (table.insert out (str x)))
    (table.concat out (or sep ""))))

(fn range-text
  [start-index stop-index total]
  (if (<= total 0)
      "0/0"
      (.. start-index "-" stop-index "/" total)))

(fn placeholder-pulse-char
  [session]
  (let [phase (or (and session session.loading-anim-phase) 0)
        frames ["·" "•" "●" "•"]]
    (. frames (+ (% phase (# frames)) 1))))

(fn info-placeholder-line
  [session]
  (.. (placeholder-pulse-char session) " loading info"))

(fn indices-slice-sig
  [idxs start-index stop-index]
  "Return a stable signature string for a visible indices slice. Expected output: \"1,4,7\"."
  (let [out []
        idxs (or idxs [])
        start-index (math.max 1 (or start-index 1))
        stop-index (math.max 0 (or stop-index 0))]
    (for [i start-index stop-index]
      (let [v (. idxs i)]
        (when-not (= v nil)
          (table.insert out (tostring v)))))
    (table.concat out ",")))

(fn valid-info-win?
  [session]
  (and session
       (= (type session.info-win) "number")
       (vim.api.nvim_win_is_valid session.info-win)))

(fn numeric-win-id
  [x]
  (if (= (type x) "number")
      x
      (and (= (type x) "table")
           (= (type (. x :window)) "number")
           (. x :window))))

(fn session-host-win
  [session]
  (let [meta-win (and session session.meta session.meta.win (numeric-win-id session.meta.win))
        prompt-win (and session (numeric-win-id session.prompt-win))
        prompt-window-win (and session session.prompt-window (numeric-win-id session.prompt-window))
        origin-win (and session (numeric-win-id session.origin-win))]
    (or (and meta-win (vim.api.nvim_win_is_valid meta-win) meta-win)
        (and prompt-win (vim.api.nvim_win_is_valid prompt-win) prompt-win)
        (and prompt-window-win (vim.api.nvim_win_is_valid prompt-window-win) prompt-window-win)
        (and origin-win (vim.api.nvim_win_is_valid origin-win) origin-win))))

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

(fn ref-path
  [session ref]
  (or (and ref ref.path)
      (and session session.source-buf
           (vim.api.nvim_buf_is_valid session.source-buf)
           (let [name (vim.api.nvim_buf_get_name session.source-buf)]
             (when (and (= (type name) "string") (~= name ""))
               name)))
      ""))

(fn refs-slice-sig
  [session refs idxs start-index stop-index]
  "Return a stable signature for the concrete refs shown in an info slice."
  (let [out []
        refs (or refs [])
        idxs (or idxs [])]
    (for [i start-index stop-index]
      (let [src-idx (. idxs i)
            ref (. refs src-idx)]
        (table.insert out
                      (join-str
                        ":"
                        [src-idx
                         (or (ref-path session ref) "")
                         (or (and ref ref.lnum) 0)
                         (or (and ref ref.kind) "")]))))
    (table.concat out "|")))

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
        [dir file dir0]
        (let [kdir (compact-dir-keep-last dir0)
              keep-last (.. kdir file)]
          (if (<= (# keep-last) budget)
              [kdir file dir0]
              (let [cdir (compact-dir dir0)
                    compact (.. cdir file)]
                (if (<= (# compact) budget)
                    [cdir file dir0]
                    (if (> (# file) budget)
                        ["" (if (> budget 1)
                                (.. "…" (string.sub file (+ (- (# file) budget) 2)))
                                (string.sub file (+ (- (# file) budget) 1)))
                         dir0]
                        (let [dir-budget (math.max 0 (- budget (# file)))
                              short-dir (if (<= (# cdir) dir-budget)
                                            cdir
                                            (if (> dir-budget 1)
                                                (.. "…" (string.sub cdir (+ (- (# cdir) dir-budget) 2)))
                                                (string.sub cdir (+ (- (# cdir) dir-budget) 1))))]
                          [short-dir file dir0])))))))))

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
        read_file_lines_cached (. deps :read-file-lines-cached)
        read_file_view_cached (. deps :read-file-view-cached)
        animation_mod (. deps :animation-mod)
        animate_enter? (. deps :animate-enter?)
        info_fade_ms (. deps :info-fade-ms)]
  (var update! nil)
  (var info_window_config nil)
  (var project-loading-pending? nil)
  (fn info-config-signature
    [cfg]
    (join-str "|"
              [(or (. cfg :relative) "")
               (or (. cfg :win) 0)
               (or (. cfg :anchor) "")
               (or (. cfg :row) 0)
               (or (. cfg :col) 0)
               (or (. cfg :width) 0)
               (or (. cfg :height) 0)
               (str (clj.boolean (. cfg :focusable)))]))

  (fn apply-info-config-if-changed!
    [session cfg]
    (when (valid-info-win? session)
      (let [sig (info-config-signature cfg)]
        (when (~= sig session.info-config-sig)
          (set session.info-config-sig sig)
          (pcall vim.api.nvim_win_set_config session.info-win cfg)))))

  (set info_window_config
    (fn [session width height]
      (let [host-win (or (session-host-win session) (vim.api.nvim_get_current_win))]
        (if session.window-local-layout
            (let [[wb-ok wb-val] [(pcall vim.api.nvim_get_option_value "winbar" {:win host-win})]
                  has-winbar? (and wb-ok
                                   (= (type wb-val) "string")
                                   (~= wb-val ""))
                  row (if has-winbar? 1 0)
                  host-height (vim.api.nvim_win_get_height host-win)
                  max-h (math.max 1 (- host-height row 1))
                  h   (math.min (math.max 1 height) max-h)]
              {:relative "win"
               :win host-win
               :anchor "NW"
               :row row
               :col (vim.api.nvim_win_get_width host-win)
               :width width
               :height h
               :focusable false})
            {:relative "editor"
             :anchor "NE"
             :row 1
             :col vim.o.columns
             :width width
             :height height
             :focusable false}))))
  (var ensure_info_window nil)
  (set ensure_info_window
    (fn [session]
      (when-not (valid-info-win? session)
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
                        (set (. start :winblend) 100)
                        start)
                      target)
              win (floating_window_mod.new vim buf cfg)]
          (events.send :on-buf-create! {:buf buf :role :info})
          (util.set-buffer-name! buf "[Metabuffer Info]")
          (set session.info-buf buf)
          (set session.info-win win.window)
          (set session.info-config-sig (info-config-signature target))
          (events.send :on-win-create! {:win session.info-win :role :info})
          (apply-metabuffer-window-highlights! session.info-win)
          (let [bo (. vim.bo buf)]
            (set (. bo :buftype) "nofile")
            (set (. bo :bufhidden) "wipe")
            (set (. bo :swapfile) false)
            (set (. bo :modifiable) false)
            (set (. bo :filetype) ""))
          (let [wo (. vim.wo win.window)]
            (set (. wo :statusline) "")
            (set (. wo :winbar) "")
            (set (. wo :number) false)
            (set (. wo :relativenumber) false)
            (set (. wo :wrap) false)
            (set (. wo :linebreak) false)
            (set (. wo :signcolumn) "no")
            (set (. wo :foldcolumn) "0")
            (set (. wo :spell) false)
            (set (. wo :cursorline) false))
          (when animate-info?
            (set session.info-animated? true)
            (set session.info-render-suspended? true)
            (set session.info-post-fade-refresh? true)
            (pcall vim.api.nvim_set_option_value "winblend" 100 {:win session.info-win})
            (vim.defer_fn
              (fn []
                (when (valid-info-win? session)
                  (animation_mod.animate-float!
                    session
                    "info-enter"
                    session.info-win
                    cfg
                    target
                    100
                    (or vim.g.meta_float_winblend 13)
                    (animation_mod.duration-ms session :info (or info_fade_ms 220))
                    {:kind :info
                     :done! (fn [_]
                              (when (valid-info-win? session)
                                (set session.info-post-fade-refresh? nil)
                                (set session.info-render-suspended? false)
                                (update! session true)))})))
              17))))))

  (fn settle-info-window!
    [session]
    (when (valid-info-win? session)
      (let [width (vim.api.nvim_win_get_width session.info-win)
            height (info_height session)
            cfg (info_window_config session width height)]
        (apply-info-config-if-changed! session cfg))))

  (fn refresh-info-statusline!
    [session]
    "Re-apply float-local statusline options after focus/plugin redraw churn."
    (when (valid-info-win? session)
      (let [total (# (or (and session session.meta session.meta.buf session.meta.buf.indices) []))
            start-index (or session.info-start-index 1)
            stop-index (or session.info-stop-index (if (> total 0) total 0))
            range (range-text start-index stop-index total)
            title (if (project-loading-pending? session)
                      (let [streamed (math.max 0 (- (or session.lazy-stream-next 1) 1))
                            total-files (or session.lazy-stream-total 0)]
                        (if (> total-files 0)
                            (.. "Info  loading " streamed "/" total-files " files")
                            "Info  loading project"))
                      (if session.info-highlight-fill-pending?
                          (.. "Info  loading " range)
                          (.. "Info  " range)))
            winbar (.. "%#Comment#" title)]
        (pcall vim.api.nvim_set_option_value "statusline" "" {:win session.info-win})
        (pcall vim.api.nvim_set_option_value "winbar" winbar {:win session.info-win}))))

  (fn close-info-window!
    [session]
    (when (valid-info-win? session)
      (pcall vim.api.nvim_win_close session.info-win true))
    (set session.info-win nil)
    (set session.info-buf nil)
    (set session.info-config-sig nil)
    (set session.info-post-fade-refresh? nil)
    (set session.info-render-suspended? nil)
    (set session.info-highlight-fill-pending? nil)
    (set session.info-highlight-fill-token nil)
    (set session.info-line-meta-refresh-pending nil)
    (set session.info-fixed-width nil))

  (fn apply-info-highlights!
    [session ns highlights]
    (each [_ h (ipairs (or highlights []))]
      (vim.api.nvim_buf_add_highlight session.info-buf ns (. h 2) (. h 1) (. h 3) (. h 4))))

  (fn sync-info-selection-highlight!
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
    [session ref src-idx target-width lnum-digit-width read_file_lines_cached lightweight?]
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
                           :read-file-lines-cached read_file_lines_cached
                           :read-file-view-cached read_file_view_cached}))
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
          icon-info (if show-icon? (util.file-icon-info icon-path file-hl) {:icon "" :icon-hl file-hl :file-hl file-hl})
          icon (or (. icon-info :icon) "")
          iconf (icon-field icon)
          icon-prefix (if show-icon? (. iconf :text) "")
          ext-hl (or (. icon-info :ext-hl) (. icon-info :icon-hl) file-hl)
          icon-hl ext-hl
          icon-width (if show-icon? (. iconf :width) 0)
          [dir file0 dir-original] (fit-path-into-width path (math.max 1 (- path-width icon-width)))
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
    [session ns refs target-width lnum-digit-width deferred-rows]
    (let [pending (or deferred-rows [])
          batch-size (math.max 4 (math.min 24 (math.max 1 (info_height session))))]
      (if (= (# pending) 0)
          (set session.info-highlight-fill-pending? false)
          (let [token (+ 1 (or session.info-highlight-fill-token 0))]
            (set session.info-highlight-fill-token token)
            (set session.info-highlight-fill-pending? true)
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
                          built (build-info-row session ref src-idx target-width lnum-digit-width read_file_lines_cached false)
                          line (str (. built :line))
                          highlights (or (. built :highlights) [])]
                      (vim.api.nvim_buf_set_lines session.info-buf row0 (+ row0 1) false [line])
                      (vim.api.nvim_buf_clear_namespace session.info-buf ns row0 (+ row0 1))
                      (each [_ h (ipairs highlights)]
                        (vim.api.nvim_buf_add_highlight session.info-buf ns (. h 1) row0 (. h 2) (. h 3)))))
                  (if (< stop (# pending))
                      (do
                        (set next-index (+ stop 1))
                        (vim.defer_fn run-batch 17))
                      (set session.info-highlight-fill-pending? false)))
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
                selected1 (math.max 1 (math.min (+ session.meta.selected_index 1) line-count))
                view (vim.fn.winsaveview)]
            (set (. view :topline) top*)
            (set (. view :lnum) selected1)
            (set (. view :col) 0)
            (set (. view :leftcol) 0)
            (pcall vim.fn.winrestview view))))))

  (fn ensure-regular-info-buffer-shape!
    [session total]
    (when (and session.info-buf
               (vim.api.nvim_buf_is_valid session.info-buf))
      (let [needed (math.max 1 total)
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
              (vim.api.nvim_buf_set_lines
                session.info-buf
                needed
                -1
                false
                []))
          (let [bo (. vim.bo session.info-buf)]
            (set (. bo :modifiable) false))))))

  (fn fit-info-width!
    [session lines]
    (when (valid-info-win? session)
      (let [widths (vim.tbl_map (fn [line] (vim.fn.strdisplaywidth (or line ""))) (or lines []))
            max-len (numeric-max widths 0)
            needed max-len
            host-win (session-host-win session)
            host-width (if (and session.window-local-layout
                                host-win
                                (vim.api.nvim_win_is_valid host-win))
                           (vim.api.nvim_win_get_width host-win)
                           vim.o.columns)
            max-available (math.max info_min_width (math.floor (* host-width 0.34)))
            upper (math.min info_max_width max-available)
            fit-target (math.max info_min_width (math.min needed upper))
            frozen-width (and (not session.project-mode) session.info-fixed-width)
            target (or frozen-width fit-target)
            height (info_height session)
            cfg (info_window_config session target height)]
        (when (and (not session.project-mode)
                   (not frozen-width))
          (set session.info-fixed-width (math.max info_min_width fit-target)))
        (apply-info-config-if-changed! session cfg))))

  (fn info-max-width-now
    [session]
      (let [host-win (session-host-win session)
            host-width (if (and session
                                session.window-local-layout
                                host-win
                                (vim.api.nvim_win_is_valid host-win))
                           (vim.api.nvim_win_get_width host-win)
                           vim.o.columns)
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
    [session refs idxs target-width start-index stop-index _visible-start _visible-stop read_file_lines_cached]
    "Build info rows for the visible slice.  Digit-width is computed only
     over the visible range so a distant 4-digit lnum doesn't cause a
     column jump for entries currently on screen."
    (let [lnum-digit-width (let [vis-lo (math.max 1 (or _visible-start start-index))
                           vis-hi (math.min (# idxs) (or _visible-stop stop-index))
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
                    built (build-info-row
                            session
                            ref
                            src-idx
                            target-width
                            lnum-digit-width
                            read_file_lines_cached
                            false)]
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
          built (build-info-lines session refs idxs (info-max-width-now session) render-start render-stop visible-start visible-stop read_file_lines_cached)
          raw-lines (. built :lines)
          lines (if (= (type raw-lines) "table")
                    (vim.tbl_map str raw-lines)
                    [(str raw-lines)])
          highlights (or (. built :highlights) [])
          ns info-content-ns
          deferred-rows (or (. built :deferred-rows) [])
          lnum-digit-width (or (. built :lnum-digit-width) 1)]
      (debug_log (join-str " " ["info render"
                                (.. "hits=" (# idxs))
                                (.. "lines=" (# lines))]))
      (set session.info-highlight-fill-token (+ 1 (or session.info-highlight-fill-token 0)))
      (set session.info-highlight-fill-pending? false)
      (let [bo (. vim.bo session.info-buf)]
        (set (. bo :modifiable) true))
      (fit-info-width! session lines)
      (ensure-regular-info-buffer-shape! session (# idxs))
      (let [[ok-set err-set] [(pcall vim.api.nvim_buf_set_lines session.info-buf (- render-start 1) render-stop false lines)]]
        (when-not ok-set
          (debug_log (.. "info set_lines failed: " (tostring err-set)))))
      (vim.api.nvim_buf_clear_namespace session.info-buf ns (- render-start 1) render-stop)
      (apply-info-highlights! session ns highlights)
      (schedule-info-highlight-fill! session ns refs (info-max-width-now session) lnum-digit-width deferred-rows)
      (let [bo (. vim.bo session.info-buf)]
        (set (. bo :modifiable) false))
      (set-info-topline! session visible-start)
      (refresh-info-statusline! session)))

  (fn sync-info-selection!
      [session meta]
      (sync-info-selection-highlight! session meta))

  (fn render-current-range!
    [session meta]
    (let [total (# (or meta.buf.indices []))
          [start-index stop-index] (info-visible-range session meta total info_max_lines)
          overscan (math.max 1 (info_height session))
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
    (ensure_info_window session)
    (when (and session.info-render-suspended?
               (not session.prompt-animating?)
               (not session.startup-initializing))
      (set session.info-post-fade-refresh? nil)
      (set session.info-render-suspended? false))
    (settle-info-window! session)

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
            overscan (math.max 1 (info_height session))
            [wanted-start wanted-stop] (info-visible-range
                                         session
                                         meta
                                         (# idxs)
                                         info_max_lines)
            render-start (if (> (# idxs) 0)
                             (math.max 1 (- wanted-start overscan))
                             1)
            render-stop (if (> (# idxs) 0)
                            (math.min (# idxs) (+ wanted-stop overscan))
                            0)
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
                   (info_height session)
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
  (fn startup-layout-pending?
    [session]
    (let [initializing (or session.startup-initializing false)
          animating (or session.prompt-animating? false)
          pending (and session session.project-mode (or initializing animating))]
      pending))

  ;; True only during genuine project bootstrap/stream — not during lazy
  ;; re-filter refreshes triggered by scroll or query changes.
  (set project-loading-pending?
       (fn [session]
         (let [startup (startup-layout-pending? session)
               bootstrap-pending (or session.project-bootstrap-pending false)
               bootstrapped (or session.project-bootstrapped false)
               stream-done (or session.lazy-stream-done false)
               pending (and session
                            session.project-mode
                            (or startup
                                bootstrap-pending
                                (not bootstrapped)
                                (not stream-done)))]
           pending)))

  (fn render-project-loading!
    [session]
    (let [hits (# (or (. session.meta.buf :indices) []))
          total-lines (# (or (. session.meta.buf :content) []))
          streamed (math.max 0 (- (or session.lazy-stream-next 1) 1))
          total-files (or session.lazy-stream-total 0)
          bootstrapped (or session.project-bootstrapped false)
          stream-done (or session.lazy-stream-done false)
          stage (if (or session.project-bootstrap-pending (not bootstrapped))
                    "bootstrapping project sources"
                     (if session.prompt-animating?
                        "opening project mode"
                        (if stream-done
                            "finalizing project sources"
                            "streaming project sources")))
          progress (if (> total-files 0)
                       (.. streamed "/" total-files " files")
                       "scanning files")
          lines [(.. "Project Mode  " stage)
                 ""
                 (.. "Progress  " progress)
                 (.. "Hits      " hits)
                 (.. "Lines     " total-lines)]
          ns info-content-ns]
      (set session.info-start-index 1)
      (set session.info-stop-index (# lines))
      (let [bo (. vim.bo session.info-buf)]
        (set bo.modifiable true))
      (set session.info-highlight-fill-token (+ 1 (or session.info-highlight-fill-token 0)))
      (set session.info-highlight-fill-pending? false)
      (set session.info-showing-project-loading? true)
      (set session.info-render-sig nil)
      (fit-info-width! session lines)
      (vim.api.nvim_buf_set_lines session.info-buf 0 -1 false lines)
      (vim.api.nvim_buf_clear_namespace session.info-buf ns 0 -1)
      (vim.api.nvim_buf_add_highlight session.info-buf ns "Title" 0 0 -1)
      (vim.api.nvim_buf_add_highlight session.info-buf ns "Comment" 2 0 10)
      (vim.api.nvim_buf_add_highlight session.info-buf ns "Comment" 3 0 10)
      (vim.api.nvim_buf_add_highlight session.info-buf ns "Comment" 4 0 10)
      (let [bo (. vim.bo session.info-buf)]
        (set bo.modifiable false))))

  (fn update-project-startup!
    [session]
    (set session.info-project-loading-active? true)
    (ensure_info_window session)
    (when (and session.info-render-suspended?
               (not session.prompt-animating?)
               (not session.startup-initializing))
      (set session.info-post-fade-refresh? nil)
      (set session.info-render-suspended? false))
    (settle-info-window! session)
    (when (and (not session.info-render-suspended?)
               session.info-buf
               (vim.api.nvim_buf_is_valid session.info-buf))
      (render-project-loading! session)))

  (fn update-project!
    [session refresh-lines]
    (if (project-loading-pending? session)
          (update-project-startup! session)
          (do
            (ensure_info_window session)
            (when (and session.info-render-suspended?
                       (not session.prompt-animating?)
                       (not session.startup-initializing))
              (set session.info-post-fade-refresh? nil)
              (set session.info-render-suspended? false))
            (settle-info-window! session)
            (debug_log
              (join-str
                " "
                ["info enter"
                 (.. "refresh=" (str refresh-lines))
                 (.. "selected=" session.meta.selected_index)
                 (.. "info-win=" session.info-win)
                 (.. "info-buf=" session.info-buf)]))
            (refresh-info-statusline! session)
            (when (and (not session.info-render-suspended?)
                       session.info-buf
                       (vim.api.nvim_buf_is_valid session.info-buf))
              (let [meta session.meta
                    loading-finished? (clj.boolean session.info-project-loading-active?)
                    force-refresh? (or loading-finished?
                                       (clj.boolean session.info-showing-project-loading?)
                                       refresh-lines
                                       (= session.info-render-sig nil)
                                       (= session.info-start-index nil)
                                       (= session.info-stop-index nil))
                    selected1 (+ meta.selected_index 1)
                    [wanted-start wanted-stop] (info-visible-range
                                                 session
                                                 meta
                                                 (# (or meta.buf.indices []))
                                                 info_max_lines)
                    start-index (or session.info-start-index 1)
                    stop-index (or session.info-stop-index 0)
                    out-of-range (or (< selected1 start-index) (> selected1 stop-index))
                    range-changed (or (~= wanted-start start-index)
                                      (~= wanted-stop stop-index))]
                (when (or force-refresh? out-of-range range-changed)
                  (let [idxs (or meta.buf.indices [])
                        sig (join-str
                              "|"
                              [(# idxs)
                               (indices-slice-sig idxs wanted-start wanted-stop)
                               (refs-slice-sig session meta.buf.source-refs idxs wanted-start wanted-stop)
                               wanted-start
                               wanted-stop
                               (or session.active-source-key "")
                               (or session.info-file-entry-view "")
                               (info-max-width-now session)
                               (info_height session)
                               vim.o.columns])]
                    (when (or force-refresh?
                              out-of-range
                              range-changed
                              (~= session.info-render-sig sig))
                      (set session.info-render-sig sig)
                      (set session.info-project-loading-active? false)
                      (set session.info-showing-project-loading? false)
                      (render-info-lines!
                        session
                        meta
                        wanted-start
                        wanted-stop
                        wanted-start
                        wanted-stop)
                      (when loading-finished?
                        (vim.defer_fn
                          (fn []
                            (when (and session
                                       (valid-info-win? session)
                                       session.info-buf
                                       (vim.api.nvim_buf_is_valid session.info-buf)
                                       (not (project-loading-pending? session)))
                              (update! session true)))
                          17)))))
                (sync-info-selection! session meta))))))

  (set update!
       (fn [session refresh-lines]
         (let [refresh-lines (if (= refresh-lines nil) true refresh-lines)]
           (if session.project-mode
               (update-project! session refresh-lines)
               (update-regular! session refresh-lines)))))

  {:close-window! close-info-window!
   :update! update!
   :refresh-statusline! refresh-info-statusline!}))

M
