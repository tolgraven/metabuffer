(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
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
(var reverse-termcodes nil)

(set M.EXTRA_KEYS
  ["<LeftMouse>"
   "<LeftRelease>"
   "<MiddleMouse>"
   "<MiddleRelease>"
   "<RightMouse>"
   "<RightRelease>"
   "<2-LeftMouse>"
   "<ScrollWheelUp>"
   "<ScrollWheelDown>"])

(fn canonical-token
  [s]
  (if (and (= (type s) "string")
           (vim.startswith s "<")
           (vim.endswith s ">"))
      (let [inner (string.sub s 2 (- (# s) 1))]
        (if (string.find inner ":" 1 true)
            s
            (.. "<" (string.upper inner) ">")))
      s))

(fn ensure-reverse-termcodes
  []
  (when (not reverse-termcodes)
    (set reverse-termcodes {})
    (let [tokens []]
      (each [_ v (pairs M.SPECIAL_KEYS)]
        (table.insert tokens v))
      (each [_ v (ipairs M.EXTRA_KEYS)]
        (table.insert tokens v))
      (each [_ tok (ipairs tokens)]
        (let [canonical (canonical-token tok)
              encoded (vim.keycode tok)
              trans (vim.fn.keytrans encoded)]
          (set (. reverse-termcodes encoded) canonical)
          (set (. reverse-termcodes trans) canonical)))))
  reverse-termcodes)

(fn decode-special-string
  [s]
  (when (= (type s) "string")
    (. (ensure-reverse-termcodes) s)))

(fn normalize
  [expr]
  (if (= (type expr) "number")
      (canonical-token (vim.fn.keytrans (util.int2char expr)))
      (= (type expr) "string")
      (if (and (vim.startswith expr "<") (vim.endswith expr ">"))
          (canonical-token expr)
          (or (decode-special-string expr)
              (let [trans (vim.fn.keytrans expr)]
                (or (decode-special-string trans)
                    (canonical-token trans)))))
      (tostring expr)))

(fn M.represent
  [_ code]
  "Public API: M.represent."
  (if (= (type code) "number")
      (canonical-token (vim.fn.keytrans (util.int2char code)))
      (= (type code) "string")
      code
      (tostring code)))

(fn M.parse
  [_ expr]
  "Public API: M.parse."
  (local k (normalize expr))
  (if (. cache k)
      (. cache k)
      (let [char (M.represent nil k)
            obj {:code k :char char}]
        (set (. cache k) obj)
        obj)))

M
