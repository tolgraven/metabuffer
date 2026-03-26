(local M {})

(set M.transform-key "xml")
(set M.query-directive-specs
     [{:kind "toggle"
       :long "xml"
       :token-key :include-xml
       :doc "Pretty-print minified XML lines."
       :compat-key :xml}])

(fn repeat
  [s n]
  (string.rep (or s "") (math.max 0 (or n 0))))

(fn tokenize-xml
  [txt]
  (let [spaced (string.gsub (or txt "") "><" ">\n<")]
    (vim.split spaced "\n" {:plain true :trimempty true})))

(fn pretty-xml-lines
  [line]
  (let [tokens (tokenize-xml (vim.trim (or line "")))
        out []
        depth0 0]
    (var depth depth0)
    (each [_ token (ipairs tokens)]
      (let [trimmed (vim.trim token)
            close? (vim.startswith trimmed "</")
            self-close? (or (vim.endswith trimmed "/>")
                            (vim.startswith trimmed "<?")
                            (vim.startswith trimmed "<!"))
            open? (and (vim.startswith trimmed "<")
                       (not close?)
                       (not self-close?))]
        (when close?
          (set depth (math.max 0 (- depth 1))))
        (table.insert out (.. (repeat "  " depth) trimmed))
        (when open?
          (set depth (+ depth 1)))))
    out))

(fn M.should-apply-line?
  [line _ctx]
  (let [trimmed (vim.trim (or line ""))]
    (and (> (# trimmed) 40)
         (vim.startswith trimmed "<")
         (not= nil (string.find trimmed "><" 1 true)))))

(fn M.apply-line
  [line _ctx]
  (pretty-xml-lines line))

(fn M.reverse-line
  [lines _ctx]
  [(table.concat (vim.tbl_map vim.trim (or lines [])) "")])

M
