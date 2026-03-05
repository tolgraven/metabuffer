(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(fn M.truthy? [v]
  (or (= v true) (= v 1) (= v "1") (= v "true")))

(fn option-prefix []
  (let [p (. vim.g "meta#prefix")]
    (if (and (= (type p) "string") (~= p ""))
        p
        "#")))

(fn parse-option-token [tok]
  (let [prefix (option-prefix)
        hidden-on (or (= tok "#hidden") (= tok "+hidden") (= tok (.. prefix "hidden")))
        hidden-off (or (= tok "#nohidden") (= tok "-hidden") (= tok (.. prefix "nohidden")))
        ignored-on (or (= tok "#ignored") (= tok "+ignored") (= tok (.. prefix "ignored")))
        ignored-off (or (= tok "#noignored") (= tok "-ignored") (= tok (.. prefix "noignored")))
        deps-on (or (= tok "#deps") (= tok "+deps") (= tok (.. prefix "deps")))
        deps-off (or (= tok "#nodeps") (= tok "-deps") (= tok (.. prefix "nodeps")))
        prefilter-off (or (= tok "#escape") (= tok "+escape") (= tok (.. prefix "escape")) (= tok "#noprefilter") (= tok "-prefilter") (= tok (.. prefix "noprefilter")))
        prefilter-on (or (= tok "#prefilter") (= tok "+prefilter") (= tok (.. prefix "prefilter")))
        lazy-off (or (= tok "#nolazy") (= tok "-lazy") (= tok (.. prefix "nolazy")))
        lazy-on (or (= tok "#lazy") (= tok "+lazy") (= tok (.. prefix "lazy")))]
    (if hidden-on
        [:hidden true]
        (if hidden-off
            [:hidden false]
            (if ignored-on
                [:ignored true]
                (if ignored-off
                    [:ignored false]
                    (if deps-on
                        [:deps true]
                        (if deps-off
                            [:deps false]
                            (if prefilter-off
                                [:prefilter false]
                                (if prefilter-on
                                    [:prefilter true]
                                    (if lazy-off
                                        [:lazy false]
                                        (when lazy-on
                                          [:lazy true]))))))))))))

(fn M.parse-query-lines [lines]
  (var include-hidden nil)
  (var include-ignored nil)
  (var include-deps nil)
  (var prefilter nil)
  (var lazy nil)
  (local cleaned [])
  (each [_ line (ipairs (or lines []))]
    (local trimmed (vim.trim (or line "")))
    (if (= trimmed "")
        (table.insert cleaned "")
        (let [parts (vim.split trimmed "%s+")
              keep []]
          (each [_ tok (ipairs (or parts []))]
            (let [parsed (parse-option-token tok)]
              (if parsed
                  (let [k (. parsed 1)
                        v (. parsed 2)]
                    (if (= k :hidden)
                        (set include-hidden v)
                        (if (= k :ignored)
                            (set include-ignored v)
                            (if (= k :deps)
                                (set include-deps v)
                                (if (= k :prefilter)
                                    (set prefilter v)
                                    (when (= k :lazy)
                                      (set lazy v)))))))
                  (table.insert keep tok))))
          (table.insert cleaned (table.concat keep " ")))))
  {:lines cleaned
   :include-hidden include-hidden
   :include-ignored include-ignored
   :include-deps include-deps
   :prefilter prefilter
   :lazy lazy})

(fn M.parse-query-text [query]
  (if (not (and (= (type query) "string") (~= query "")))
      {:query query :include-hidden nil :include-ignored nil :include-deps nil :prefilter nil :lazy nil}
      (let [lines (vim.split query "\n" {:plain true})
            parsed (M.parse-query-lines lines)]
        {:query (table.concat (. parsed :lines) "\n")
         :include-hidden (. parsed :include-hidden)
         :include-ignored (. parsed :include-ignored)
         :include-deps (. parsed :include-deps)
         :prefilter (. parsed :prefilter)
         :lazy (. parsed :lazy)})))

(fn M.query-lines-has-active? [lines]
  (var has false)
  (each [_ line (ipairs (or lines []))]
    (when (and (not has) (~= (vim.trim (or line "")) ""))
      (set has true)))
  has)

M
