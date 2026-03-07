(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local prompt (require :metabuffer.prompt.prompt))
(local M {})
(set M.Prompt prompt)
M
