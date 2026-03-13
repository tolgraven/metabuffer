(import-macros {: when-let
                 : if-let
                 : when-some
                 : if-some
                 : when-not
                 : cond}
  :io.gitlab.andreyorst.cljlib.core)
(local M {})

(fn M.truthy?
  [v]
  "Public API: M.truthy?."
  (or (= v true) (= v 1) (= v "1") (= v "true")))

(fn option-prefix
  []
  (if-let [p (. vim.g "meta#prefix")]
    (if (and (= (type p) "string") (~= p ""))
      p
      "#")
    "#"))

(fn parse-option-token
  [tok]
  (let [prefix (option-prefix)
        hidden-on (or (= tok "#hidden") (= tok "+hidden") (= tok "#+hidden") (= tok (.. prefix "hidden")))
        hidden-off (or (= tok "#nohidden") (= tok "-hidden") (= tok "#-hidden") (= tok (.. prefix "nohidden")))
        ignored-on (or (= tok "#ignored") (= tok "+ignored") (= tok "#+ignored") (= tok (.. prefix "ignored")))
        ignored-off (or (= tok "#noignored") (= tok "-ignored") (= tok "#-ignored") (= tok (.. prefix "noignored")))
        deps-on (or (= tok "#deps") (= tok "+deps") (= tok "#+deps") (= tok (.. prefix "deps")))
        deps-off (or (= tok "#nodeps") (= tok "-deps") (= tok "#-deps") (= tok (.. prefix "nodeps")))
        binary-on (or (= tok "#binary") (= tok "+binary") (= tok "#+binary") (= tok (.. prefix "binary")))
        binary-off (or (= tok "#nobinary") (= tok "-binary") (= tok "#-binary") (= tok (.. prefix "nobinary")))
        hex-on (or (= tok "#hex") (= tok "+hex") (= tok "#+hex") (= tok (.. prefix "hex")))
        hex-off (or (= tok "#nohex") (= tok "-hex") (= tok "#-hex") (= tok (.. prefix "nohex")))
        prefilter-off (or (= tok "#escape") (= tok "+escape") (= tok "#+escape") (= tok (.. prefix "escape")) (= tok "#noprefilter") (= tok "-prefilter") (= tok "#-prefilter") (= tok (.. prefix "noprefilter")))
        prefilter-on (or (= tok "#prefilter") (= tok "+prefilter") (= tok "#+prefilter") (= tok (.. prefix "prefilter")))
        lazy-off (or (= tok "#nolazy") (= tok "-lazy") (= tok "#-lazy") (= tok (.. prefix "nolazy")))
        lazy-on (or (= tok "#lazy") (= tok "+lazy") (= tok "#+lazy") (= tok (.. prefix "lazy")))
        files-off (or (= tok "#nofile") (= tok "-file") (= tok "#-file") (= tok (.. prefix "nofile")))
        files-on (or (= tok "#file") (= tok "+file") (= tok "#+file") (= tok (.. prefix "file")))
        history-merge? (= tok "#history")
        save-tag (or (string.match tok "^#save:(.+)$")
                     (string.match tok (.. "^" (vim.pesc prefix) "save:(.+)$")))
        saved-tag (string.match tok "^##(.+)$")
        saved-browser? (= tok "##")]
    (cond
      hidden-on [:hidden true]
      hidden-off [:hidden false]
      ignored-on [:ignored true]
      ignored-off [:ignored false]
      deps-on [:deps true]
      deps-off [:deps false]
      binary-on [:binary true]
      binary-off [:binary false]
      hex-on [:hex true]
      hex-off [:hex false]
      prefilter-off [:prefilter false]
      prefilter-on [:prefilter true]
      lazy-off [:lazy false]
      lazy-on [:lazy true]
      files-off [:files false]
      files-on [:files true]
      history-merge? [:history true]
      save-tag [:save-tag save-tag]
      (and saved-tag (~= (vim.trim saved-tag) "")) [:saved-tag (vim.trim saved-tag)]
      saved-browser? [:saved-browser true])))

(fn escaped-prefix-token
  [tok]
  (let [t (or tok "")
        prefix (option-prefix)
        escaped-prefix (.. "\\" prefix)]
    (if (and (> (# t) (# escaped-prefix))
             (vim.startswith t escaped-prefix))
      (string.sub t 2)
      nil)))

(fn prefix-directive-token?
  [tok]
  (let [t (or tok "")
        prefix (option-prefix)]
    (and (~= t prefix)
         (vim.startswith t prefix))))

(fn assoc-option
  [acc k v]
  (let [next (vim.deepcopy acc)]
    (set (. next k) v)
    next))

(fn unquote-token
  [tok]
  (let [t (or tok "")
        n (# t)]
    (if (>= n 2)
      (let [lead (string.sub t 1 1)
            tail (string.sub t n n)]
        (if (or (and (= lead "\"") (= tail "\""))
                (and (= lead "'") (= tail "'")))
          (string.sub t 2 (- n 1))
          t))
      t)))

(fn file-query-shortcut-token
  [tok]
  (let [t (or tok "")]
    (if (= t "./")
      :await
      (string.match t "^%./(.+)$"))))

(fn parse-parts
  [parts idx state]
  (if (> idx (# parts))
    state
    (let [tok (. parts idx)]
      (if-let [escaped (escaped-prefix-token tok)]
        (let [next (vim.deepcopy state)]
          (table.insert (. next :keep) escaped)
          (parse-parts parts (+ idx 1) next))
        (if-let [shortcut (file-query-shortcut-token tok)]
          (let [next (assoc-option state :files true)]
            (if (= shortcut :await)
              (parse-parts parts (+ idx 1) (assoc-option next :file-await-token true))
              (let [next2 (vim.deepcopy next)]
                (table.insert (. next2 :file-lines) (unquote-token shortcut))
                (set (. next2 :file-await-token) false)
                (parse-parts parts (+ idx 1) next2))))
          (if-let [parsed (parse-option-token tok)]
            (let [next (assoc-option state (. parsed 1) (. parsed 2))]
              (if (= (. parsed 1) :files)
                (parse-parts parts (+ idx 1) (assoc-option next :file-await-token true))
                (parse-parts parts (+ idx 1) next)))
            (if (prefix-directive-token? tok)
              (parse-parts parts (+ idx 1) state)
              (if (and (. state :file-await-token) (~= (vim.trim tok) ""))
                (let [next (vim.deepcopy state)]
                  (table.insert (. next :file-lines) (unquote-token tok))
                  (set (. next :file-await-token) false)
                  (parse-parts parts (+ idx 1) next))
                (let [next (vim.deepcopy state)]
                  (table.insert (. next :keep) tok)
                  (parse-parts parts (+ idx 1) next))))))))))

(fn parse-line
  [acc line]
  (let [trimmed (vim.trim (or line ""))]
    (if (= trimmed "")
      (let [next (vim.deepcopy acc)]
        (table.insert (. next :lines) "")
        next)
      (let [parts (vim.split trimmed "%s+" {:trimempty true})
            state (parse-parts parts 1 (assoc-option acc :keep []))
            next (vim.deepcopy state)]
        (table.insert (. next :lines) (table.concat (. state :keep) " "))
        (set (. next :keep) nil)
        (set (. next :file-await-token) false)
        next))))

(fn parse-lines
  [lines idx state]
  (if (> idx (# lines))
    state
    (parse-lines lines (+ idx 1) (parse-line state (. lines idx)))))

(fn M.parse-query-lines
  [lines]
  "Public API: M.parse-query-lines."
  (let [init {:lines []
              :hidden nil
              :ignored nil
              :deps nil
              :binary nil
              :hex nil
              :prefilter nil
              :lazy nil
              :files nil
              :history nil
              :save-tag nil
              :saved-tag nil
              :saved-browser nil
              :file-lines []
              :file-await-token false}]
    (let [parsed (parse-lines (or lines []) 1 init)]
      (set (. parsed :include-hidden) (. parsed :hidden))
      (set (. parsed :include-ignored) (. parsed :ignored))
      (set (. parsed :include-deps) (. parsed :deps))
      (set (. parsed :include-binary) (. parsed :binary))
      (set (. parsed :include-hex) (. parsed :hex))
      (set (. parsed :include-files) (. parsed :files))
      parsed)))

(fn M.parse-query-text
  [query]
  "Public API: M.parse-query-text."
  (if (and (= (type query) "string") (~= query ""))
    (let [lines (vim.split query "\n" {:plain true})
          parsed (M.parse-query-lines lines)]
      {:query (table.concat (. parsed :lines) "\n")
       :lines (or (. parsed :lines) [])
       :include-hidden (. parsed :hidden)
       :include-ignored (. parsed :ignored)
       :include-deps (. parsed :deps)
       :include-binary (. parsed :binary)
       :include-hex (. parsed :hex)
       :include-files (. parsed :files)
       :prefilter (. parsed :prefilter)
       :lazy (. parsed :lazy)
       :file-lines (or (. parsed :file-lines) [])
       :history (. parsed :history)
       :save-tag (. parsed :save-tag)
       :saved-tag (. parsed :saved-tag)
       :saved-browser (. parsed :saved-browser)})
    {:query query
     :lines (if (and (= (type query) "string") (~= query ""))
                (vim.split query "\n" {:plain true})
                [])
     :include-hidden nil
     :include-ignored nil
     :include-deps nil
     :include-binary nil
     :include-hex nil
     :include-files nil
     :prefilter nil
     :lazy nil
     :file-lines []
     :history nil
     :save-tag nil
     :saved-tag nil
     :saved-browser nil}))

(fn lines-has-active?
  [lines idx]
  (if (> idx (# lines))
    false
    (or (~= (vim.trim (or (. lines idx) "")) "")
        (lines-has-active? lines (+ idx 1)))))

(fn M.query-lines-has-active?
  [lines]
  "Public API: M.query-lines-has-active?."
  (lines-has-active? (or lines []) 1))

M
