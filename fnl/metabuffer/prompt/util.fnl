(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(set M.ESCAPE_ECHO {
  ["\\"] "\\\\"
  ["\""] "\\\""
})

(fn M.get_encoding
  []
  (or vim.o.encoding "utf-8"))

(fn M.ensure_bytes
  [seed]
  (if (= (type seed) "string")
      seed
      (tostring seed)))

(fn M.ensure_str
  [seed]
  (if (= (type seed) "string") seed (tostring seed)))

(fn M.int2char
  [code]
  (vim.fn.nr2char code))

(fn M.int2repr
  [code]
  (if (= (type code) "number")
      (M.int2char code)
      (tostring code)))

(fn M.getchar
  [& args]
  (let [unpack-fn (or table.unpack unpack)
        packed [(pcall vim.fn.getchar (unpack-fn args))]
        ok (. packed 1)
        ret (. packed 2)]
    (if (not ok)
        0
        (if (= (type ret) "number")
            (do
              (when (= ret 3)
                (error "Keyboard interrupt"))
              ret)
            (M.ensure_str ret)))))

(fn M.build_echon_expr
  [text hl]
  (local safe (string.gsub (string.gsub (or text "") "\\\\" "\\\\\\\\") "\"" "\\\\\""))
  (string.format "echohl %s|echon \"%s\"" (or hl "None") safe))

(fn M.build_keyword_pattern_set
  [_]
  ;; pragmatic Vim-compatible fallback
  {:pattern "[%w_]" :inverse "[^%w_]"})

(fn M.build_keywords_regex
  [_]
  (vim.regex "\\k\\+"))

M
