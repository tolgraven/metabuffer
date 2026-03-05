(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local M {})
(fn M.new [line meta]
  {:line line :meta meta})
M
