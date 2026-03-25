(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local M {})

(set M.transform-key "bplist")
(set M.query-directive-specs
     [{:kind "toggle"
       :long "bplist"
       :token-key :include-bplist
       :doc "Pretty-print binary plist files."
       :compat-key :bplist}])

(fn binary-plist?
  [ctx]
  (let [head (or (and ctx ctx.head) "")]
    (vim.startswith head "bplist00")))

(fn plutil-lines
  [path]
  (when (= 1 (vim.fn.executable "plutil"))
    (let [out (vim.fn.systemlist ["plutil" "-convert" "xml1" "-o" "-" path])]
      (when (= vim.v.shell_error 0)
        out))))

(fn plist->bplist
  [lines]
  (when (= 1 (vim.fn.executable "plutil"))
    (let [input (table.concat (or lines []) "\n")
          out (vim.fn.system ["plutil" "-convert" "binary1" "-o" "-" "-"] input)]
      (when (= vim.v.shell_error 0)
        out))))

(fn M.should-apply-file?
  [_path _raw-lines ctx]
  (and (clj.boolean (and ctx ctx.binary))
       (binary-plist? ctx)))

(fn M.apply-file
  [path _raw-lines _ctx]
  (plutil-lines path))

(fn M.reverse-file
  [lines _ctx]
  (plist->bplist lines))

M
