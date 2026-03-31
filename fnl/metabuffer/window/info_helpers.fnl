(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local M {})

(fn str
  [x]
  (tostring x))

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

(fn loading-skeleton-lines
  [count]
  "Return COUNT faded placeholder rows for the info window."
  (let [patterns [".... ... ......"
                  "..... .... ....."
                  "... ..... ......"
                  ".... ...... ...."]
        total (math.max 1 (or count 1))
        lines []]
    (for [i 1 total]
      (table.insert lines (. patterns (+ (% (- i 1) (# patterns)) 1))))
    lines))

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

(fn info-winbar-active?
  [session project-loading-pending?]
  "True when the info winbar should be visible for loading/progress state."
  (or (project-loading-pending? session)
      (clj.boolean (and session session.info-highlight-fill-pending?))))

(fn effective-info-height
  [session info-height _project-loading-pending?]
  (math.max 1 (info-height session)))

(set M.str str)
(set M.join-str join-str)
(set M.range-text range-text)
(set M.placeholder-pulse-char placeholder-pulse-char)
(set M.info-placeholder-line info-placeholder-line)
(set M.loading-skeleton-lines loading-skeleton-lines)
(set M.indices-slice-sig indices-slice-sig)
(set M.valid-info-win? valid-info-win?)
(set M.numeric-win-id numeric-win-id)
(set M.session-host-win session-host-win)
(set M.ext-start-in-file ext-start-in-file)
(set M.icon-field icon-field)
(set M.ref-path ref-path)
(set M.refs-slice-sig refs-slice-sig)
(set M.fit-path-into-width fit-path-into-width)
(set M.info-range info-range)
(set M.numeric-max numeric-max)
(set M.info-winbar-active? info-winbar-active?)
(set M.effective-info-height effective-info-height)

M
