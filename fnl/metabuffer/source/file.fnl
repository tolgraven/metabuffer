(local text (require :metabuffer.source.text))
(local author-hl (require :metabuffer.author_highlight))

(local M {})

(fn file-first-line
  [session read-file-lines-cached path]
  (let [cache (or session.info-file-head-cache {})
        mtime (vim.fn.getftime path)
        found (. cache path)]
    (if (and (= (type found) "table")
             (= (. found :mtime) mtime)
             (= (type (. found :line)) "string"))
        (. found :line)
        (let [line0 (or (. (or (read-file-lines-cached path) []) 1) "")
              line (tostring line0)]
          (set (. cache path) {:mtime mtime :line line})
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
            (if (or (= txt "just now") (= txt "now")) "0m" nil)
            ""))))

(fn file-meta-line
  [meta]
  (let [mtime-text (or (. meta :mtime-text) "000000")
        git-age (or (. meta :age) "")
        age-fragment (if (~= git-age "")
                         (.. " 🕓" git-age)
                         " ")
        git-author (let [a (vim.trim (or (. meta :author) ""))]
                     (if (= a "") "?" a))]
    (.. mtime-text
        age-fragment
        "\t"
        git-author)))

(fn file-meta-data
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

(fn M.hit-prefix
  [ref]
  (text.path-prefix ref))

(fn M.info-path
  [ref full-path?]
  (text.info-path ref full-path?))

(fn M.info-suffix
  [session ref mode read-file-lines-cached]
  (let [path (and ref ref.path)]
        (if (not (and path (= 1 (vim.fn.filereadable path))))
            ""
        (if (= (or mode "meta") "meta")
            (. (file-meta-data session path) :text)
            (file-first-line session read-file-lines-cached path)))))

(fn M.info-meta
  [session ref]
  (let [path (and ref ref.path)]
    (if (and path (= 1 (vim.fn.filereadable path))
             (= (or (and ref ref.kind) "") "file-entry"))
        (file-meta-data session path)
        nil)))

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

(fn file-status-sign
  [status]
  (if (= status "untracked")
      {:text "✗ " :hl "MetaFileSignUntracked"}
      (= status "clean")
      {:text "  " :hl "MetaFileSignClean"}
      {:text "✹" :hl "MetaFileSignDirty"}))

(fn aligned-meta-suffix
  [suffix path-width]
  (let [txt (or suffix "")
        left (or (string.match txt "^([^\t]*)\t") txt)
        right (or (string.match txt "^[^\t]*\t(.*)$") "")
        left-w (vim.fn.strdisplaywidth left)
        right-w (vim.fn.strdisplaywidth right)
        pad (if (= right "")
                0
                ;; Keep one char tighter to avoid suffix overflow in narrow info windows.
                (math.max 0 (- (math.max 1 path-width) (+ left-w right-w) 1)))
        text (if (= right "")
                 left
                 (.. left (string.rep " " pad) right))
        author-start (if (= right "") -1 (+ (# left) pad))
        author-end (if (= right "") -1 (+ author-start (# right)))
        clock-start1 (string.find left "🕓" 1 true)
        age-token (if clock-start1
                      (or (string.match left "🕓([%d]+[a-z]+)$") "")
                      "")
        age-start (if (and clock-start1 (~= age-token ""))
                      (+ (- clock-start1 1) (# "🕓"))
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

(fn M.info-view
  [session ref ctx]
  (let [mode (or (and ctx ctx.mode) "meta")
        path-width (or (and ctx ctx.path-width) 1)
        read-file-lines-cached (and ctx ctx.read-file-lines-cached)
        meta (M.info-meta session ref)
        sign (file-status-sign (or (and meta (. meta :status)) ""))
        suffix0 (M.info-suffix session ref mode read-file-lines-cached)]
    (if (= mode "meta")
        (let [laid (aligned-meta-suffix suffix0 path-width)]
          {:path ""
           :icon-path (or (and ref ref.path) "")
           :show-icon false
           :highlight-dir false
           :highlight-file false
           :sign sign
           :suffix (or (. laid :text) "")
           :suffix-prefix ""
           :suffix-highlights (or (. laid :suffix-highlights) [])})
        {:path ""
         :icon-path (or (and ref ref.path) "")
         :show-icon false
         :highlight-dir false
         :highlight-file false
         :sign sign
         :suffix suffix0
         :suffix-prefix ""
         :suffix-highlights []})))

(fn M.preview-filetype
  [ref]
  (let [path (and ref ref.path)]
    (if (and (= (type path) "string") (~= path ""))
        (let [[ok ft] [(pcall vim.filetype.match {:filename path})]]
          (if (and ok (= (type ft) "string") (~= ft ""))
              ft
              "text"))
        "text")))

(fn M.preview-lines
  [session ref height read-file-lines-cached]
  ;; File-provider preview always starts from line 1 unless explicit preview-lnum is set.
  (let [r (vim.deepcopy (or ref {}))]
    ;; File entries should always preview file contents from path, never another buffer.
    (set r.buf nil)
    (if (not r.preview-lnum)
        (set r.preview-lnum 1))
    (text.preview-lines session r height read-file-lines-cached)))

M
