(local util (require :metabuffer.prompt.util))

(local M {})

(set M.SPECIAL_KEYS {
  ["CR"] "<CR>"
  ["ESC"] "<Esc>"
  ["BS"] "<BS>"
  ["TAB"] "<Tab>"
  ["S-TAB"] "<S-Tab>"
  ["DEL"] "<Del>"
  ["LEFT"] "<Left>"
  ["RIGHT"] "<Right>"
  ["UP"] "<Up>"
  ["DOWN"] "<Down>"
  ["INSERT"] "<Insert>"
  ["HOME"] "<Home>"
  ["END"] "<End>"
  ["PAGEUP"] "<PageUp>"
  ["PAGEDOWN"] "<PageDown>"
})

(local cache {})

(fn normalize [expr]
  (cond
    (= (type expr) "number") expr
    (= (type expr) "string") expr
    true (tostring expr)))

(fn M.represent [_ code]
  (cond
    (= (type code) "number") (util.int2char code)
    (= (type code) "string") code
    true (tostring code)))

(fn M.parse [_ expr]
  (local k (normalize expr))
  (if (. cache k)
      (. cache k)
      (let [char (M.represent nil k)
            obj {:code k :char char}]
        (tset cache k obj)
        obj)))

M
