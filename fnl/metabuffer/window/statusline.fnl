(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local path-highlight (require :metabuffer.path_highlight))

(local M {})

(fn M.escape
  [s]
  (string.gsub (or s "") "%%" "%%%%"))

(fn M.title-case
  [s]
  (if (and (= (type s) "string") (> (# s) 0))
      (.. (string.upper (string.sub s 1 1)) (string.lower (string.sub s 2)))
      ""))

(fn M.reset
  [group]
  (if (and (= (type group) "string") (~= group ""))
      (.. "%#" group "#")
      "%*"))

(fn path-hl
  [hl opts]
  (let [h (or hl "")]
    (if (= h "MetaPathSep")
        (or (. (or opts {}) :sep-group)
            (. (or opts {}) :file-group)
            "MetaStatuslinePathFile")
        (if (vim.startswith h "MetaPathSeg")
            (.. (or (. (or opts {}) :seg-prefix) "MetaStatuslinePathSeg")
                (string.sub h (+ (# "MetaPathSeg") 1)))
            (or (. (or opts {}) :file-group) "MetaStatuslinePathFile")))))

(fn M.render-path
  [path opts]
  (let [default-text (or (. (or opts {}) :default-text) "Preview")
        file-group (or (. (or opts {}) :file-group) "MetaStatuslinePathFile")
        base-group (or (. (or opts {}) :base-group) file-group)]
    (if (and (= (type path) "string") (~= path ""))
        (let [short (vim.fn.fnamemodify path ":~:.")
              file (vim.fn.fnamemodify short ":t")
              dir0 (vim.fn.fnamemodify short ":h")
              dir (if (= dir0 ".") "" dir0)
              dirtxt (if (= dir "") "" (.. dir "/"))
              ranges (path-highlight.ranges-for-dir dirtxt 0)
              out [(.. (M.reset base-group) " ")]]
          (each [_ dr (ipairs ranges)]
            (let [seg (string.sub dirtxt (+ (. dr :start) 1) (. dr :end))]
              (table.insert out (.. "%#" (path-hl (. dr :hl) opts) "#" (M.escape seg)))))
          (when (> (# file) 0)
            (table.insert out (.. "%#" file-group "#" (M.escape file))))
          (table.insert out (.. (M.reset base-group) " "))
          (table.concat out ""))
        (.. (M.reset base-group) " " default-text " "))))

M
