(local M {})

(set M.transform-key "css")
(set M.query-directive-specs
     [{:kind "toggle"
       :long "css"
       :token-key :include-css
       :doc "Pretty-print minified CSS lines."
       :compat-key :css}])

(fn repeat
  [s n]
  (string.rep (or s "") (math.max 0 (or n 0))))

(fn pretty-css-lines
  [line]
  (let [txt (or line "")
        normalized (-> txt
                       (string.gsub "%s*{%s*" " {\n")
                       (string.gsub "%s*}%s*" "\n}\n")
                       (string.gsub "%s*;%s*" ";\n"))
        tokens (vim.split normalized "\n" {:plain true :trimempty true})
        out []
        depth0 0]
    (var depth depth0)
    (each [_ token (ipairs tokens)]
      (let [trimmed (vim.trim token)]
        (when (= trimmed "}")
          (set depth (math.max 0 (- depth 1))))
        (table.insert out (.. (repeat "  " depth) trimmed))
        (when (vim.endswith trimmed "{")
          (set depth (+ depth 1)))))
    out))

(fn M.should-apply-line?
  [line _ctx]
  (let [trimmed (vim.trim (or line ""))]
    (and (> (# trimmed) 40)
         (not= nil (string.find trimmed "{" 1 true))
         (not= nil (string.find trimmed "}" 1 true))
         (not= nil (string.find trimmed ";" 1 true)))))

(fn M.apply-line
  [line _ctx]
  (pretty-css-lines line))

(fn M.reverse-line
  [lines _ctx]
  (let [parts []
        prev-open? false]
    (var prev-open prev-open?)
    (each [_ raw (ipairs (or lines []))]
      (let [trimmed (vim.trim (or raw ""))]
        (when (~= trimmed "")
          (if (= trimmed "}")
              (table.insert parts "}")
              (do
                (when (and (> (# parts) 0)
                           (not prev-open)
                           (not (vim.endswith (. parts (# parts)) "{"))
                           (~= trimmed "}"))
                  (let [tail (. parts (# parts))]
                    (when (and tail (not (vim.endswith tail "{")) (not (vim.endswith tail ";")))
                      (set (. parts (# parts)) (.. tail " ")))))
                (table.insert parts trimmed)))
          (set prev-open (vim.endswith trimmed "{")))))
    [(table.concat parts "")]))

M
