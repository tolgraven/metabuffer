(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(fn M.enabled?
  []
  "Public API: M.enabled?."
  (or (= (. vim.g "meta#debug") 1)
      (= (. vim.g "meta#debug") true)))

(fn M.log
  [scope msg]
  "Public API: M.log."
  (when (M.enabled?)
    (let [path (or (. vim.g "meta#debug_log") "/tmp/metabuffer-debug.log")
          prefix (if (and (= (type scope) "string") (~= scope ""))
                     (.. "[" scope "] ")
                     "")
          line (.. (os.date "%Y-%m-%d %H:%M:%S") " " prefix (tostring msg))]
      (pcall vim.fn.writefile [line] path "a"))))

M
