(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local path-highlight (require :metabuffer.path_highlight))
(local util (require :metabuffer.util))

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
            "MetaPreviewStatuslinePathFile")
        (if (vim.startswith h "MetaPathSeg")
            (.. (or (. (or opts {}) :seg-prefix) "MetaPreviewStatuslinePathSeg")
                (string.sub h (+ (# "MetaPathSeg") 1)))
            (or (. (or opts {}) :file-group) "MetaPreviewStatuslinePathFile")))))

(fn ext-statusline-group
  [path opts]
  (let [ext (util.ext-from-path path)
        file-group (or (. (or opts {}) :file-group) "MetaPreviewStatuslinePathFile")]
    (if (= ext "")
        file-group
        (let [base (path-highlight.group-for-segment ext)]
          (if (vim.startswith base "MetaPathSeg")
              (.. (or (. (or opts {}) :seg-prefix) "MetaPreviewStatuslinePathSeg")
                  (string.sub base (+ (# "MetaPathSeg") 1)))
              file-group)))))

(fn M.render-path
  [path opts]
  (let [default-text (or (. (or opts {}) :default-text) "Preview")
        file-group (or (. (or opts {}) :file-group) "MetaPreviewStatuslinePathFile")
        base-group (or (. (or opts {}) :base-group) file-group)
        left-pad (or (. (or opts {}) :left-pad) " ")
        right-pad (or (. (or opts {}) :right-pad) " ")]
    (if (and (= (type path) "string") (~= path ""))
        (let [short (vim.fn.fnamemodify path ":~:.")
              file (vim.fn.fnamemodify short ":t")
              dir0 (vim.fn.fnamemodify short ":h")
              dir (if (= dir0 ".") "" dir0)
              dirtxt (if (= dir "") "" (.. dir "/"))
              ranges (path-highlight.ranges-for-dir dirtxt 0)
              icon-info (util.file-icon-info path file-group)
              icon (or (. icon-info :icon) "")
              ext-hl (ext-statusline-group path opts)
              icon-hl ext-hl
              dot (string.match file ".*()%.")
              base-file (if (and dot (> dot 1))
                            (string.sub file 1 (- dot 1))
                            file)
              ext-file (if (and dot (> dot 0) (< dot (# file)))
                           (string.sub file dot)
                           "")
              out [(.. (M.reset base-group) left-pad)]]
          (when (> (# icon) 0)
            (table.insert out (.. "%#" icon-hl "#" (M.escape icon) " ")))
          (each [_ dr (ipairs ranges)]
            (let [seg (string.sub dirtxt (+ (. dr :start) 1) (. dr :end))]
              (table.insert out (.. "%#" (path-hl (. dr :hl) opts) "#" (M.escape seg)))))
          (when (> (# base-file) 0)
            (table.insert out (.. "%#" file-group "#" (M.escape base-file))))
          (when (> (# ext-file) 0)
            (table.insert out (.. "%#" ext-hl "#" (M.escape ext-file))))
          (table.insert out (.. (M.reset base-group) right-pad))
          (table.concat out ""))
        (.. (M.reset base-group) left-pad default-text right-pad))))

M
