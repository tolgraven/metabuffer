(import-macros {: when-let
                 : if-let
                 : when-some
                 : if-some
                 : when-not
                 : def
                 : defn}
  :io.gitlab.andreyorst.cljlib.core)
(local str (require :io.gitlab.andreyorst.cljlib.string))
(local str-join (. str :join))
(local str-lower-case (. str :lower-case))
(local str-substring (. str :substring))
(local str-match (. str :match))

(def join-pattern "\\|")
(def ext-pattern ".*()%.")

(defn split-input
  [text]
  "Public API: M.split-input."
  (vim.split (or text "") "%s+" {:trimempty true}))

(defn convert2regex-pattern
  [text]
  "Public API: M.convert2regex-pattern."
  (str-join join-pattern (split-input text)))

(defn assign-content
  [buf lines]
  "Public API: M.assign-content."
  (let [view (vim.fn.winsaveview)]
    (let [bo (. vim.bo buf)]
      (set (. bo :modifiable) true))
    (vim.api.nvim_buf_set_lines buf 0 -1 false lines)
    (let [bo (. vim.bo buf)]
      (set (. bo :modifiable) false))
    (vim.fn.winrestview view)))

(defn escape-vim-pattern
  [text]
  "Public API: M.escape-vim-pattern."
  (vim.fn.escape (or text "") "\\^$~.*[]"))

(defn query-is-lower
  [query]
  "Public API: M.query-is-lower."
  (= (str-lower-case query) (or query "")))

(defn buf-valid?
  [buf]
  "Public API: M.buf-valid?."
  (and buf (vim.api.nvim_buf_is_valid buf)))

(defn win-valid?
  [win]
  "Public API: M.win-valid?."
  (and win (vim.api.nvim_win_is_valid win)))

(defn deepcopy
  [x]
  "Public API: M.deepcopy."
  (vim.deepcopy x))

(defn clamp
  [n lo hi]
  "Public API: M.clamp."
  (math.max lo (math.min hi n)))

(defn build-group-names
  [prefix count]
  "Public API: M.build-group-names."
  (let [groups []]
    (for [i 1 count]
      (table.insert groups (.. prefix i)))
    groups))

(defn ext-from-path
  [path]
  "Public API: M.ext-from-path."
  (let [file (vim.fn.fnamemodify (or path "") ":t")
        dot (str-match file ext-pattern)]
    (if (and dot (> dot 0) (< dot (# file)))
        (str-substring file (+ dot 1))
        "")))

(defn devicon-info
  [path fallback-hl]
  "Public API: M.devicon-info."
  (let [file (vim.fn.fnamemodify (or path "") ":t")
        ext (ext-from-path path)
        [ok-web web] [(pcall require :nvim-web-devicons)]]
    (if (and ok-web web)
        (let [[ok-i icon icon-hl] [(pcall web.get_icon file ext {:default true})]
              next-hl (if (and ok-i (= (type icon-hl) "string") (~= icon-hl ""))
                          icon-hl
                          fallback-hl)]
          {:icon (if (and ok-i (= (type icon) "string") (~= icon "")) icon "")
           :icon-hl next-hl
           :ext-hl next-hl
           :file-hl fallback-hl})
        (if (= 1 (vim.fn.exists "*WebDevIconsGetFileTypeSymbol"))
            (let [icon (vim.fn.WebDevIconsGetFileTypeSymbol file)]
              {:icon (if (and (= (type icon) "string") (~= icon "")) icon "")
               :icon-hl fallback-hl
               :ext-hl fallback-hl
               :file-hl fallback-hl})
            {:icon ""
             :icon-hl fallback-hl
             :ext-hl fallback-hl
             :file-hl fallback-hl}))))

(defn buf-lines
  [buf]
  "Public API: M.buf-lines."
  (vim.api.nvim_buf_get_lines buf 0 -1 false))

(defn cursor
  []
  "Public API: M.cursor."
  (vim.api.nvim_win_get_cursor 0))

(defn set-cursor
  [row col]
  "Public API: M.set-cursor."
  (vim.api.nvim_win_set_cursor 0 [row (or col 0)]))

{:split-input split-input
 :convert2regex-pattern convert2regex-pattern
 :assign-content assign-content
 :escape-vim-pattern escape-vim-pattern
 :query-is-lower query-is-lower
 :buf-valid? buf-valid?
 :win-valid? win-valid?
 :deepcopy deepcopy
 :clamp clamp
 :build-group-names build-group-names
 :ext-from-path ext-from-path
 :devicon-info devicon-info
 :buf-lines buf-lines
 :cursor cursor
 :set-cursor set-cursor}
