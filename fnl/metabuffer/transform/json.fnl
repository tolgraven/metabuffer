(local M {})

(set M.transform-key "json")
(set M.query-directive-specs
     [{:kind "toggle"
       :long "json"
       :token-key :include-json
       :doc "Pretty-print minified JSON lines."
       :compat-key :json}])

(fn repeat
  [s n]
  (string.rep (or s "") (math.max 0 (or n 0))))

(fn is-array?
  [v]
  (= (vim.fn.type v) vim.v.t_list))

(fn is-dict?
  [v]
  (= (vim.fn.type v) vim.v.t_dict))

(fn sorted-keys
  [tbl]
  (let [out []]
    (each [k _ (pairs tbl)]
      (table.insert out k))
    (table.sort out)
    out))

(fn format-json
  [v indent]
  (let [n (or indent 0)
        pad (repeat "  " n)
        inner (repeat "  " (+ n 1))]
    (if (is-array? v)
        (let [out ["["]]
          (each [i x (ipairs v)]
            (table.insert out (.. inner (format-json x (+ n 1)) (if (< i (# v)) "," ""))))
          (table.insert out (.. pad "]"))
          (table.concat out "\n"))
        (if (is-dict? v)
            (let [keys (sorted-keys v)
                  out ["{"]]
              (each [i k (ipairs keys)]
                (table.insert out
                              (.. inner
                                  (vim.json.encode k)
                                  ": "
                                  (format-json (. v k) (+ n 1))
                                  (if (< i (# keys)) "," ""))))
              (table.insert out (.. pad "}"))
              (table.concat out "\n"))
            (vim.json.encode v)))))

(fn M.should-apply-line?
  [line _ctx]
  (let [trimmed (vim.trim (or line ""))]
    (if (and (> (# trimmed) 40)
             (or (vim.startswith trimmed "{")
                 (vim.startswith trimmed "["))
             (not= nil (string.find trimmed ":" 1 true)))
        (let [[ok _] [(pcall vim.json.decode trimmed)]]
          ok)
        false)))

(fn M.apply-line
  [line _ctx]
  (let [trimmed (vim.trim (or line ""))
        [ok decoded] [(pcall vim.json.decode trimmed)]]
    (when ok
      (vim.split (format-json decoded 0) "\n" {:plain true :trimempty false}))))

(fn minify-json
  [txt]
  (let [s (or txt "")
        chars {}
        in-string? false
        escape? false]
    (var in-string in-string?)
    (var escape escape?)
    (for [i 1 (# s)]
      (let [ch (string.sub s i i)]
        (if in-string
            (do
              (table.insert chars ch)
              (if escape
                  (set escape false)
                  (if (= ch "\\")
                      (set escape true)
                      (when (= ch "\"")
                        (set in-string false)))))
            (if (= ch "\"")
                (do
                  (table.insert chars ch)
                  (set in-string true)
                  (set escape false))
                (when (not (string.match ch "%s"))
                  (table.insert chars ch))))))
    (table.concat chars "")))

(fn M.reverse-line
  [lines _ctx]
  (let [joined (table.concat (or lines []) "\n")
        compact (minify-json joined)
        [ok _] [(pcall vim.json.decode compact)]]
    (when ok
      [compact])))

M
