(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(if (= vim.g.loaded_metabuffer 1)
    nil
    (do
      (set vim.g.loaded_metabuffer 1)
      (let [m (require :metabuffer)]
        (m.setup))))
