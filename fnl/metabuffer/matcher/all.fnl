(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local base (require :metabuffer.matcher.base))
(local util (require :metabuffer.util))

(local M {})

(fn parse-term
  [raw]
  (let [token (or raw "")
        negated (and (> (# token) 1) (= (string.sub token 1 1) "!"))
        body0 (if negated (string.sub token 2) token)
        anchor-start (and (> (# body0) 0) (= (string.sub body0 1 1) "^"))
        body1 (if anchor-start (string.sub body0 2) body0)
        anchor-end (and (> (# body1) 0) (= (string.sub body1 (# body1)) "$"))
        body2 (if anchor-end (string.sub body1 1 (- (# body1) 1)) body1)]
    {:negated negated
     :anchor-start anchor-start
     :anchor-end anchor-end
     :needle body2}))

(fn term-match?
  [term line]
  (let [needle (or (. term :needle) "")]
    (if (= needle "")
        true
        (if (. term :anchor-start)
            (if (. term :anchor-end)
                (= line needle)
                (vim.startswith line needle))
            (if (. term :anchor-end)
                (vim.endswith line needle)
                (not (not (string.find line needle 1 true))))))))

(fn term-highlight-pattern
  [term]
  (let [needle (or (. term :needle) "")]
    (if (= needle "")
        ""
        (base.escape-vim-patterns needle))))

(fn M.new
  []
  "Public API: M.new."
  (base.new "all"
    {:get-highlight-pattern
      (fn [_ query]
        (let [items []]
          (each [_ raw (ipairs (util.split-input query))]
            (let [term (parse-term raw)
                  pat (term-highlight-pattern term)]
              (when (and (~= pat "") (not (. term :negated)))
                (table.insert items {:group "MetaSearchHitAll"
                                     :pattern (.. "\\%(" pat "\\)")}))))
          items))
     :filter
      (fn [_ query indices candidates ignorecase]
        (let [terms (vim.tbl_map parse-term (util.split-input query))
              out []]
          (when ignorecase
            (each [_ t (ipairs terms)]
              (set (. t :needle) (string.lower (or (. t :needle) "")))))
          (each [_ idx (ipairs indices)]
            (let [line (. candidates idx)
                  probe (if ignorecase (string.lower line) line)]
              (var ok true)
              (each [_ term (ipairs terms)]
                (let [hit? (term-match? term probe)
                      pass? (if (. term :negated) (not hit?) hit?)]
                  (when (and ok (not pass?))
                    (set ok false))))
              (when ok
                (table.insert out idx))))
          out))}))

M
