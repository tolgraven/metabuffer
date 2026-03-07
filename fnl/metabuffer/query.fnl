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
        hidden-toggle (or (= tok "#hidden") (= tok (.. prefix "hidden")))
        hidden-on (or (= tok "+hidden") (= tok "#+hidden"))
        hidden-off (or (= tok "#nohidden") (= tok "-hidden") (= tok "#-hidden") (= tok (.. prefix "nohidden")))
        ignored-toggle (or (= tok "#ignored") (= tok (.. prefix "ignored")))
        ignored-on (or (= tok "+ignored") (= tok "#+ignored"))
        ignored-off (or (= tok "#noignored") (= tok "-ignored") (= tok "#-ignored") (= tok (.. prefix "noignored")))
        deps-toggle (or (= tok "#deps") (= tok (.. prefix "deps")))
        deps-on (or (= tok "+deps") (= tok "#+deps"))
        deps-off (or (= tok "#nodeps") (= tok "-deps") (= tok "#-deps") (= tok (.. prefix "nodeps")))
        prefilter-off (or (= tok "#escape") (= tok "+escape") (= tok "#+escape") (= tok (.. prefix "escape")) (= tok "#noprefilter") (= tok "-prefilter") (= tok "#-prefilter") (= tok (.. prefix "noprefilter")))
        prefilter-toggle (or (= tok "#prefilter") (= tok (.. prefix "prefilter")))
        prefilter-on (or (= tok "+prefilter") (= tok "#+prefilter"))
        lazy-off (or (= tok "#nolazy") (= tok "-lazy") (= tok "#-lazy") (= tok (.. prefix "nolazy")))
        lazy-toggle (or (= tok "#lazy") (= tok (.. prefix "lazy")))
        lazy-on (or (= tok "+lazy") (= tok "#+lazy"))
        history-merge? (= tok "#history")
        save-tag (or (string.match tok "^#save:(.+)$")
                     (string.match tok (.. "^" (vim.pesc prefix) "save:(.+)$")))
        saved-tag (string.match tok "^##(.+)$")
        saved-browser? (= tok "##")]
    (cond
      hidden-toggle [:hidden "toggle"]
      hidden-on [:hidden true]
      hidden-off [:hidden false]
      ignored-toggle [:ignored "toggle"]
      ignored-on [:ignored true]
      ignored-off [:ignored false]
      deps-toggle [:deps "toggle"]
      deps-on [:deps true]
      deps-off [:deps false]
      prefilter-toggle [:prefilter "toggle"]
      prefilter-off [:prefilter false]
      prefilter-on [:prefilter true]
      lazy-toggle [:lazy "toggle"]
      lazy-off [:lazy false]
      lazy-on [:lazy true]
      history-merge? [:history true]
      save-tag [:save-tag save-tag]
      (and saved-tag (~= (vim.trim saved-tag) "")) [:saved-tag (vim.trim saved-tag)]
      saved-browser? [:saved-browser true])))

(fn M.resolve-option
  [value current]
  "Public API: M.resolve-option."
  (if (= value "toggle")
      (not (M.truthy? current))
      (if-some [v value]
        v
        current)))

(fn assoc-option
  [acc k v]
  (let [next (vim.deepcopy acc)]
    (set (. next k) v)
    next))

(fn parse-parts
  [parts idx state]
  (if (> idx (# parts))
    state
    (let [tok (. parts idx)]
      (if (vim.startswith tok "\\#")
          (let [next (vim.deepcopy state)
                literal (string.sub tok 2)]
            (table.insert (. next :keep) literal)
            (parse-parts parts (+ idx 1) next))
          (if-let [parsed (parse-option-token tok)]
            (parse-parts parts (+ idx 1) (assoc-option state (. parsed 1) (. parsed 2)))
            (if (vim.startswith tok "#")
                (let [next (assoc-option state :pending-control true)]
                  (parse-parts parts (+ idx 1) next))
                (let [next (vim.deepcopy state)]
                  (table.insert (. next :keep) tok)
                  (parse-parts parts (+ idx 1) next))))))))

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
              :prefilter nil
              :lazy nil
              :history nil
              :save-tag nil
              :saved-tag nil
              :saved-browser nil
              :pending-control false}]
    (parse-lines (or lines []) 1 init)))

(fn M.parse-query-text
  [query]
  "Public API: M.parse-query-text."
  (if (and (= (type query) "string") (~= query ""))
    (let [lines (vim.split query "\n" {:plain true})
          parsed (M.parse-query-lines lines)]
      {:query (table.concat (. parsed :lines) "\n")
       :include-hidden (. parsed :hidden)
       :include-ignored (. parsed :ignored)
       :include-deps (. parsed :deps)
       :prefilter (. parsed :prefilter)
       :lazy (. parsed :lazy)
       :history (. parsed :history)
       :save-tag (. parsed :save-tag)
       :saved-tag (. parsed :saved-tag)
       :saved-browser (. parsed :saved-browser)
       :pending-control (. parsed :pending-control)})
    {:query query
     :include-hidden nil
     :include-ignored nil
     :include-deps nil
     :prefilter nil
     :lazy nil
     :history nil
     :save-tag nil
     :saved-tag nil
     :saved-browser nil
     :pending-control false}))

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
