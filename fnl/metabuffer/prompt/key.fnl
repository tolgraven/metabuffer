(local util (require :metabuffer.prompt.util))

(local M {})

(set M.SPECIAL_KEYS {
  :CR "<CR>"
  :ESC "<Esc>"
  :BS "<BS>"
  :TAB "<Tab>"
  :S-TAB "<S-Tab>"
  :DEL "<Del>"
  :LEFT "<Left>"
  :RIGHT "<Right>"
  :UP "<Up>"
  :DOWN "<Down>"
  :INSERT "<Insert>"
  :HOME "<Home>"
  :END "<End>"
  :PAGEUP "<PageUp>"
  :PAGEDOWN "<PageDown>"
})

(local cache {})

(fn canonical-token [s]
  (if (and (= (type s) "string")
           (vim.startswith s "<")
           (vim.endswith s ">"))
      (let [inner (string.sub s 2 (- (# s) 1))]
        (if (string.find inner ":" 1 true)
            s
            (.. "<" (string.upper inner) ">")))
      s))

(fn normalize [expr]
  (if (= (type expr) "number")
      (canonical-token (vim.fn.keytrans (util.int2char expr)))
      (= (type expr) "string")
      (if (and (vim.startswith expr "<") (vim.endswith expr ">"))
          (canonical-token expr)
          (canonical-token (vim.fn.keytrans expr)))
      (tostring expr)))

(fn M.represent [_ code]
  (if (= (type code) "number")
      (canonical-token (vim.fn.keytrans (util.int2char code)))
      (= (type code) "string")
      code
      (tostring code)))

(fn M.parse [_ expr]
  (local k (normalize expr))
  (if (. cache k)
      (. cache k)
      (let [char (M.represent nil k)
            obj {:code k :char char}]
        (tset cache k obj)
        obj)))

M
