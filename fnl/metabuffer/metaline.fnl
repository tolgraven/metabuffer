(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})
(fn M.new
  [line meta]
  "Wrap a rendered line with its originating Meta context."
  {:line line :meta meta})
M
