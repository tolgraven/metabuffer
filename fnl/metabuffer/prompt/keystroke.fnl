(local key (require :metabuffer.prompt.key))

(local M {})

(local mt {})
(fn mt.__tostring [self]
  (local out [])
  (each [_ k (ipairs self)]
    (table.insert out (or k.char "")))
  (table.concat out ""))

(fn tokenise [expr]
  (if (not (= (type expr) "string"))
      expr
      (if (or (string.find expr "\128" 1 true)
              (vim.startswith expr "<80>"))
          ;; Treat Vim's internal keycode strings/bytes (for example "<80>kb")
          ;; as a single token so key parsing can canonicalize them.
          [expr]
      (let [out []
            len (# expr)]
        (var i 1)
        (while (<= i len)
          (if (= (string.sub expr i i) "<")
              (let [j (string.find expr ">" i true)]
                (if j
                    (do
                      (table.insert out (string.sub expr i j))
                      (set i (+ j 1)))
                    (do
                      (table.insert out (string.sub expr i i))
                      (set i (+ i 1)))))
              (do
                (table.insert out (string.sub expr i i))
                (set i (+ i 1)))))
        out))))

(fn M.startswith [lhs rhs]
  (if (< (# lhs) (# rhs))
      false
      (do
        (var ok true)
        (for [i 1 (# rhs)]
          (when (and ok (~= (. (. lhs i) :code) (. (. rhs i) :code)))
            (set ok false)))
        ok)))

(fn M.parse [nvim expr]
  (if (= (type expr) "table")
      (setmetatable expr mt)
      (let [tokens (tokenise expr)
            out []]
        (each [_ t (ipairs tokens)]
          (table.insert out (key.parse nvim t)))
        (setmetatable out mt))))

(fn M.concat [a b]
  (local out [])
  (each [_ x (ipairs a)] (table.insert out x))
  (each [_ x (ipairs b)] (table.insert out x))
  (setmetatable out mt))

M
