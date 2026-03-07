(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local base (require :metabuffer.matcher.base))
(local util (require :metabuffer.util))

(local M {})

(fn unclosed-pattern-delims?
  [token]
  (let [n (# (or token ""))]
    (var i 1)
    (var paren 0)
    (var bracket 0)
    (while (<= i n)
      (let [ch (string.sub token i i)]
        (if (= ch "%")
            (set i (+ i 2))
            (do
              (if (= ch "(")
                  (set paren (+ paren 1))
                  (= ch ")")
                  (set paren (math.max 0 (- paren 1))))
              (if (= ch "[")
                  (set bracket (+ bracket 1))
                  (= ch "]")
                  (set bracket (math.max 0 (- bracket 1))))
              (set i (+ i 1))))))
    (or (> paren 0) (> bracket 0))))

(fn regex-token?
  [token]
  (and (= (type token) "string")
       (~= token "")
       (not (unclosed-pattern-delims? token))
       (not (not (string.find token "[\\%[%]%(%)%+%*%?%|]")))
       (let [[ok] [(pcall string.find "" token 1)]]
         ok)))

(fn unescape-token-specials
  [token]
  (let [s (or token "")
        n (# (or token ""))]
    (var i 1)
    (var out "")
    (while (<= i n)
      (let [ch (string.sub s i i)]
        (if (and (= ch "\\") (< i n))
            (let [next (string.sub s (+ i 1) (+ i 1))]
              (if (or (= next "!") (= next "^") (= next "$"))
                  (do
                    (set out (.. out next))
                    (set i (+ i 2)))
                  (do
                    (set out (.. out ch))
                    (set i (+ i 1)))))
            (do
              (set out (.. out ch))
              (set i (+ i 1))))))
    out))

(fn escaped-leading?
  [s ch]
  (vim.startswith (or s "") (.. "\\" ch)))

(fn escaped-trailing-dollar?
  [s]
  (let [txt (or s "")
        n (# txt)]
    (and (> n 1)
         (= (string.sub txt (- n 1) (- n 1)) "\\")
         (= (string.sub txt n n) "$"))))

(fn parse-term
  [raw]
  (let [token (or raw "")
        bang-only? (= token "!")
        escaped-bang? (escaped-leading? token "!")
        negated (and (not bang-only?)
                     (not escaped-bang?)
                     (= (string.sub token 1 1) "!"))
        body0 (if bang-only?
                  "!"
                  escaped-bang?
                  (string.sub token 2)
                  negated
                  (string.sub token 2)
                  token)
        escaped-caret? (escaped-leading? body0 "^")
        anchor-start (and (not escaped-caret?)
                          (> (# body0) 0)
                          (= (string.sub body0 1 1) "^"))
        body1 (if escaped-caret?
                  (string.sub body0 2)
                  anchor-start
                  (string.sub body0 2)
                  body0)
        escaped-dollar? (escaped-trailing-dollar? body1)
        anchor-end (and (not escaped-dollar?)
                        (> (# body1) 0)
                        (= (string.sub body1 (# body1)) "$"))
        body2 (if escaped-dollar?
                  (.. (string.sub body1 1 (- (# body1) 2)) "$")
                  anchor-end
                  (string.sub body1 1 (- (# body1) 1))
                  body1)
        needle (unescape-token-specials body2)
        has-needle (> (# needle) 0)
        effective-negated (and negated has-needle)]
    {:negated effective-negated
     :anchor-start anchor-start
     :anchor-end anchor-end
     :needle needle
     :regex (regex-token? needle)}))

(fn term-match?
  [term line]
  (let [needle (or (. term :needle) "")]
    (if (= needle "")
        true
        (if (. term :regex)
            (let [[ok s _] [(pcall string.find line needle 1)]]
              (and ok s))
            (if (and (. term :negated)
                     (not (. term :anchor-start))
                     (not (. term :anchor-end))
                     (not (. term :regex))
                     (not (not (string.match needle "^[%w_]+$"))))
                ;; Negation is more useful as a token exclusion than raw substring.
                (not (not (string.find line (.. "%f[%w_]" needle "%f[^%w_]"))))
                (if (. term :anchor-start)
                    (if (. term :anchor-end)
                        (= line needle)
                        (vim.startswith line needle))
                    (if (. term :anchor-end)
                        (vim.endswith line needle)
                        (not (not (string.find line needle 1 true))))))))))

(fn term-highlight-pattern
  [term]
  (let [needle (or (. term :needle) "")]
    (if (= needle "")
        ""
        (if (. term :regex)
            needle
            (base.escape-vim-patterns needle)))))

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
                (table.insert items {:group (if (. term :regex) "MetaSearchHitRegex" "MetaSearchHitAll")
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
