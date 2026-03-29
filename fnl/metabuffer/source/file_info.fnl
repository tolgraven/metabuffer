(import-macros {: when-not} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))

(local author-hl (require :metabuffer.author_highlight))
(local transform-mod (require :metabuffer.transform))

(local M {})
(var line_meta_key nil)
(var line_meta_cache_hit? nil)
(var normalized_line_numbers nil)
(var missing_line_numbers nil)
(var clear_pending_line_meta nil)
(var parse_range_blame_stdout nil)

(fn M.file-first-line
  [session read-file-lines-cached read-file-view-cached path]
  (let [cache (or session.info-file-head-cache {})
        mtime (vim.fn.getftime path)
        include-binary (clj.boolean (and session session.effective-include-binary))
        transform-sig (transform-mod.signature (or (and session session.effective-transforms) {}))
        found (. cache path)]
    (if (and (= (type found) "table")
             (= (. found :mtime) mtime)
             (= (. found :include-binary) include-binary)
             (= (. found :transform-sig) transform-sig)
             (= (type (. found :line)) "string"))
        (. found :line)
        (let [view (or (and read-file-view-cached
                            (read-file-view-cached
                              path
                              {:include-binary include-binary
                               :transforms (or (and session session.effective-transforms)
                                               (and session session.transform-flags)
                                               {})}))
                       {:lines (or (read-file-lines-cached
                                     path
                                     {:include-binary include-binary
                                      :hex-view (and session session.effective-include-hex)}) [])})
              line0 (or (. (or (. view :lines) []) 1) "")
              line (tostring line0)]
          (set (. cache path)
               {:mtime mtime
                :include-binary include-binary
                :transform-sig transform-sig
                :line line})
          (set session.info-file-head-cache cache)
          line))))

(fn git-file-status
  [path]
  (let [rel (vim.fn.fnamemodify path ":.")
        out (vim.fn.systemlist ["git" "-C" (vim.fn.getcwd) "status" "--porcelain" "--" rel])]
    (if (~= vim.v.shell_error 0)
        ""
        (let [line (or (. out 1) "")]
          (if (= line "")
              "clean"
              (if (vim.startswith line "??")
                  "untracked"
                  (let [x (string.sub line 1 1)
                        y (string.sub line 2 2)
                        staged? (~= x " ")
                        dirty? (~= y " ")]
                    (if (and staged? dirty?)
                        "staged+dirty"
                        (if staged?
                            "staged"
                            (if dirty?
                                "dirty"
                                "changed"))))))))))

(fn git-last-commit-info
  [path]
  (let [rel (vim.fn.fnamemodify path ":.")
        out (vim.fn.systemlist ["git" "-C" (vim.fn.getcwd) "log" "-1" "--format=%cr%x09%an" "--" rel])]
    (if (= vim.v.shell_error 0)
        (let [line (or (. out 1) "")
              age (or (string.match line "^([^\t]+)\t") "")
              author (or (string.match line "^[^\t]+\t(.+)$") "")]
          {:age age :author author})
        {:age "" :author ""})))

(fn git-line-blame-info
  [path lnum]
  (let [rel (vim.fn.fnamemodify path ":.")
        out (vim.fn.systemlist ["git" "-C" (vim.fn.getcwd)
                                "blame" "--line-porcelain"
                                "-L" (.. (tostring lnum) "," (tostring lnum))
                                "--" rel])]
    (if (= vim.v.shell_error 0)
        {:author (or (string.match (table.concat (or out []) "\n") "\nauthor ([^\n]+)") "")
         :author-time (or (tonumber (or (string.match (table.concat (or out []) "\n") "\nauthor%-time (%d+)") "")) 0)}
        {:author "" :author-time 0})))

(fn compact-relative-age
  [age]
  (let [txt (string.lower (vim.trim (or age "")))
        n (tonumber (or (string.match txt "^(%d+)") ""))]
    (if (= txt "")
        ""
        (or (if (string.find txt "minute") (.. (tostring (or n 1)) "m") nil)
            (if (string.find txt "hour") (.. (tostring (or n 1)) "h") nil)
            (if (or (string.find txt "day") (= txt "yesterday")) (.. (tostring (or n 1)) "d") nil)
            (if (string.find txt "week") (.. (tostring (or n 1)) "w") nil)
            (if (string.find txt "month") (.. (tostring (or n 1)) "mo") nil)
            (if (string.find txt "year") (.. (tostring (or n 1)) "y") nil)
            ""))))

(fn compact-relative-age-from-epoch
  [epoch]
  (if (and epoch (> epoch 0))
      (let [delta (math.max 0 (- (os.time) epoch))]
        (if (< delta 60)
            ""
            (< delta 3600)
            (.. (tostring (math.floor (/ delta 60))) "m")
            (< delta 86400)
            (.. (tostring (math.floor (/ delta 3600))) "h")
            (< delta (* 86400 7))
            (.. (tostring (math.floor (/ delta 86400))) "d")
            (< delta (* 86400 30))
            (.. (tostring (math.floor (/ delta (* 86400 7)))) "w")
            (< delta (* 86400 365))
            (.. (tostring (math.floor (/ delta (* 86400 30)))) "mo")
            (.. (tostring (math.floor (/ delta (* 86400 365)))) "y")))
      ""))

(fn file-meta-line
  [meta]
  (let [mtime-text (or (. meta :mtime-text) "000000")
        git-age (or (. meta :age) "")
        age-width 3
        age-fragment (if (~= git-age "")
                         (.. (string.rep " " (math.max 0 (- age-width (# git-age))))
                             git-age)
                         (string.rep " " age-width))
        git-author (let [a (vim.trim (or (. meta :author) ""))]
                     (if (= a "") "?" a))]
    (.. mtime-text " " age-fragment "\t " git-author)))

(fn M.file-meta-data
  [session path]
  (let [cache (or session.info-file-meta-cache {})
        mtime (vim.fn.getftime path)
        found (. cache path)]
    (if (and (= (type found) "table")
             (= (. found :mtime) mtime)
             (= (type (. found :text)) "string")
             (= (type (. found :status)) "string"))
        found
        (let [mtime-text (if (> mtime 0)
                             (vim.fn.strftime "%y%m%d" mtime)
                             "000000")
              git-status (git-file-status path)
              commit (git-last-commit-info path)
              git-age (compact-relative-age (or (. commit :age) ""))
              git-author (let [a (vim.trim (or (. commit :author) ""))]
                           (if (= a "") "?" a))
              meta {:mtime mtime
                    :mtime-text mtime-text
                    :status git-status
                    :age git-age
                    :author git-author}
              text (file-meta-line meta)]
          (set (. cache path) (vim.tbl_extend "force" meta {:text text}))
          (set session.info-file-meta-cache cache)
          (. cache path)))))

(fn cached-file-status
  [session path]
  (let [cache (or (and session session.info-file-status-cache) {})
        mtime (vim.fn.getftime path)
        found (. cache path)]
    (if (and (= (type found) "table")
             (= (. found :mtime) mtime)
             (= (type (. found :status)) "string"))
        (. found :status)
        nil)))

(fn file-status-cache-hit
  [session path mtime]
  (let [cache (or session.info-file-status-cache {})
        found (. cache path)]
    (and (= (type found) "table")
         (= (. found :mtime) mtime)
         (= (type (. found :status)) "string")
         (. found :status))))

(fn pending-file-status-key
  [path mtime]
  (.. path ":" (tostring mtime)))

(fn mark-file-status-pending!
  [session key]
  (let [pending (or session.info-file-status-pending {})]
    (when-not (. pending key)
      (set (. pending key) true)
      (set session.info-file-status-pending pending)
      true)))

(fn clear-file-status-pending!
  [session key]
  (let [pending (or session.info-file-status-pending {})]
    (set (. pending key) nil)
    (set session.info-file-status-pending pending)))

(fn cache-file-status!
  [session path mtime status]
  (let [cache (or session.info-file-status-cache {})]
    (set (. cache path) {:mtime mtime :status status})
    (set session.info-file-status-cache cache)
    status))

(fn git-status-line->status
  [line]
  (if (= (or line "") "")
      "clean"
      (if (vim.startswith line "??")
          "untracked"
          (let [x (string.sub line 1 1)
                y (string.sub line 2 2)
                staged? (~= x " ")
                dirty? (~= y " ")]
            (if (and staged? dirty?)
                "staged+dirty"
                (if staged?
                    "staged"
                    (if dirty?
                        "dirty"
                        "changed"))))))

(fn schedule-file-status-fetch!
  [session path mtime key on-ready]
  (vim.system
    ["git" "-C" (vim.fn.getcwd) "status" "--porcelain" "--" (vim.fn.fnamemodify path ":.")]
    {}
    (fn [obj]
      (vim.schedule
        (fn []
          (clear-file-status-pending! session key)
          (let [line (if (= (. obj :code) 0)
                         (or (. (vim.split (or (. obj :stdout) "") "\n" {:plain true}) 1) "")
                         "")
                status (git-status-line->status line)]
            (cache-file-status! session path mtime status)
            (when on-ready
              (on-ready))))))))

(fn M.ensure-file-status-async!
  [session path on-ready]
  (when (and session path (= 1 (vim.fn.filereadable path)))
    (let [mtime (vim.fn.getftime path)
          key (pending-file-status-key path mtime)
          cached (file-status-cache-hit session path mtime)]
      (if cached
          cached
          (when (mark-file-status-pending! session key)
            (schedule-file-status-fetch! session path mtime key on-ready))))))

(fn M.line-meta-data
  [session path lnum]
  (let [cache (or session.info-line-meta-cache {})
        key (.. path ":" (tostring lnum))
        mtime (vim.fn.getftime path)
        found (. cache key)]
    (if (and (= (type found) "table")
             (= (. found :mtime) mtime)
             (= (. found :lnum) lnum)
             (= (type (. found :text)) "string")
             (= (type (. found :status)) "string"))
        found
        (let [blame (git-line-blame-info path lnum)
              author-time (or (. blame :author-time) 0)
              author (let [a (vim.trim (or (. blame :author) ""))]
                       (if (= a "") "?" a))
              meta {:mtime mtime
                    :lnum lnum
                    :mtime-text (if (> author-time 0)
                                    (vim.fn.strftime "%y%m%d" author-time)
                                    "000000")
                    :status (git-file-status path)
                    :age (compact-relative-age-from-epoch author-time)
                    :author author}
              text (file-meta-line meta)]
          (set (. cache key) (vim.tbl_extend "force" meta {:text text}))
          (set session.info-line-meta-cache cache)
          (. cache key)))))

(fn line-meta-from-blame
  [session path lnum mtime blame]
  (let [author-time (or (. blame :author-time) 0)
        author (let [a (vim.trim (or (. blame :author) ""))]
                 (if (= a "") "?" a))
        meta {:mtime mtime
              :lnum lnum
              :mtime-text (if (> author-time 0)
                              (vim.fn.strftime "%y%m%d" author-time)
                              "000000")
              :status (or (cached-file-status session path) "clean")
              :age (compact-relative-age-from-epoch author-time)
              :author author}
        text (file-meta-line meta)]
    (vim.tbl_extend "force" meta {:text text})))

(set line_meta_key
  (fn [path lnum]
    (.. path ":" (tostring lnum))))

(set line_meta_cache_hit?
  (fn [cache path lnum mtime]
    (let [found (. cache (line_meta_key path lnum))]
      (and (= (type found) "table")
           (= (. found :mtime) mtime)
           (= (. found :lnum) lnum)))))

(set normalized_line_numbers
  (fn [lnums]
    (let [vals []]
      (each [_ lnum (ipairs (or lnums []))]
        (when (and (= (type lnum) "number") (> lnum 0))
          (table.insert vals lnum)))
      vals)))

(set missing_line_numbers
  (fn [cache path lnums mtime]
    (let [missing []]
      (each [_ lnum (ipairs lnums)]
        (when-not (line_meta_cache_hit? cache path lnum mtime)
          (table.insert missing lnum)))
      missing)))

(set clear_pending_line_meta
  (fn [session key]
    (let [pending (or session.info-line-meta-pending {})]
      (set (. pending key) nil)
      (set session.info-line-meta-pending pending))))

(set parse_range_blame_stdout
  (fn [stdout]
    (let [rows []
          state {:author "" :author-time 0}]
      (each [_ line (ipairs (vim.split (or stdout "") "\n" {:plain true}))]
        (when (vim.startswith line "author ")
          (set (. state :author) (string.sub line 8)))
        (when (vim.startswith line "author-time ")
          (set (. state :author-time) (or (tonumber (string.sub line 13)) 0)))
        (when (vim.startswith line "\t")
          (table.insert rows {:author (. state :author)
                              :author-time (. state :author-time)})
          (set (. state :author) "")
          (set (. state :author-time) 0)))
      rows)))

(fn M.ensure-line-meta-range-async!
  [session path lnums on-ready]
  (let [vals (normalized_line_numbers lnums)]
    (when (and session
               (= 1 (vim.fn.filereadable path))
               (> (# vals) 0))
      (let [cache (or session.info-line-meta-cache {})
            mtime (vim.fn.getftime path)
            rel (vim.fn.fnamemodify path ":.")
            missing (missing_line_numbers cache path vals mtime)]
        (when (> (# missing) 0)
          (let [start-lnum (. missing 1)
                stop-lnum (. missing (# missing))
                key (.. path ":" (tostring start-lnum) ":" (tostring stop-lnum) ":" (tostring mtime))
                pending (or session.info-line-meta-pending {})]
            (when-not (. pending key)
              (set (. pending key) true)
              (set session.info-line-meta-pending pending)
              (vim.system
                ["git" "-C" (vim.fn.getcwd)
                 "blame" "--line-porcelain"
                 "-L" (.. (tostring start-lnum) "," (tostring stop-lnum))
                 "--" rel]
                {}
                (fn [obj]
                  (vim.schedule
                    (fn []
                      (clear_pending_line_meta session key)
                      (when (and (= (. obj :code) 0)
                                 (= 1 (vim.fn.filereadable path)))
                        (let [rows (parse_range_blame_stdout (. obj :stdout))
                              cache1 (or session.info-line-meta-cache {})]
                          (for [i 1 (math.min (# missing) (# rows))]
                            (let [lnum (. missing i)
                                  blame (. rows i)
                                  meta (line-meta-from-blame session path lnum mtime blame)]
                              (set (. cache1 (line_meta_key path lnum)) meta)))
                          (set session.info-line-meta-cache cache1)))
                      (when on-ready
                        (on-ready))))))))))))))

(fn age-hl-group
  [age-token]
  (let [unit (or (string.match (or age-token "") "^%d+([a-z]+)$") "")]
    (if (= unit "m")
        "MetaFileAgeMinute"
        (= unit "h")
        "MetaFileAgeHour"
        (= unit "d")
        "MetaFileAgeDay"
        (= unit "w")
        "MetaFileAgeWeek"
        (= unit "mo")
        "MetaFileAgeMonth"
        (= unit "y")
        "MetaFileAgeYear"
        "MetaFileAge")))

(fn M.file-status-sign
  [status]
  (if (= status "untracked")
      {:text "✗ " :hl "MetaFileSignUntracked"}
      (= status "clean")
      {:text "  " :hl "MetaFileSignClean"}
      {:text "✹" :hl "MetaFileSignDirty"}))

(fn M.aligned-meta-suffix
  [suffix path-width]
  (let [txt (or suffix "")
        left (or (string.match txt "^([^\t]*)\t") txt)
        right (or (string.match txt "^[^\t]*\t(.*)$") "")
        left-w (vim.fn.strdisplaywidth left)
        right-w (vim.fn.strdisplaywidth right)
        pad (if (= right "")
                0
                (math.max 0 (- (math.max 1 path-width) (+ left-w right-w) 1)))
        text (if (= right "")
                 left
                 (.. left (string.rep " " pad) right))
        author-start (if (= right "") -1 (+ (# left) pad))
        author-end (if (= right "") -1 (+ author-start (# right)))
        age-token (or (string.match left "(%d+[a-z]+)$") "")
        age-start (if (~= age-token "")
                      (let [age-pos (string.find left (.. " " age-token) 1 true)]
                        (if age-pos age-pos -1))
                      -1)
        age-end (if (>= age-start 0) (+ age-start (# age-token)) -1)

        suffix-highlights []]
    (when (>= age-start 0)
      (table.insert suffix-highlights {:hl (age-hl-group age-token)
                                       :start age-start
                                       :end age-end}))
    (when (>= author-start 0)
      (table.insert suffix-highlights {:hl (author-hl.group-for-author right)
                                       :start author-start
                                       :end author-end}))
    {:text text :suffix-highlights suffix-highlights}))

(fn M.meta-info-view
  [session path path-width]
  (let [meta (M.file-meta-data session path)
        sign (M.file-status-sign (or (and meta (. meta :status)) ""))
        laid (M.aligned-meta-suffix (. meta :text) path-width)]
    {:path ""
     :icon-path path
     :show-icon false
     :highlight-dir false
     :highlight-file false
     :sign sign
     :suffix (or (. laid :text) "")
     :suffix-prefix ""
     :suffix-highlights (or (. laid :suffix-highlights) [])}))

(fn M.line-meta-info-view
  [session path lnum path-width]
  (let [cache (or (and session session.info-line-meta-cache) {})
        key (.. path ":" (tostring lnum))
        mtime (vim.fn.getftime path)
        found (. cache key)
        meta (or (and (= (type found) "table")
                      (= (. found :mtime) mtime)
                      (= (. found :lnum) lnum)
                      (= (type (. found :text)) "string")
                      (= (type (. found :status)) "string")
                      found)
                 {:status "clean" :text ""})
        laid (M.aligned-meta-suffix (. meta :text) path-width)]
    {:path ""
     :icon-path path
     :show-icon false
     :highlight-dir false
     :highlight-file false
     :sign {:text "  " :hl "LineNr"}
     :suffix (or (. laid :text) "")
     :suffix-prefix ""
     :suffix-highlights (or (. laid :suffix-highlights) [])}))

M
