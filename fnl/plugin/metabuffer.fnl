(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(if (= vim.g.loaded_metabuffer 1)
    nil
    (do
      (set vim.g.loaded_metabuffer 1)
      (when (= (. vim.g :fennel_lua_version) nil)
        (set (. vim.g :fennel_lua_version) "5.1"))
      (when (= (. vim.g :fennel_use_luajit) nil)
        (set (. vim.g :fennel_use_luajit) (if jit 1 0)))
      (let [m (require :metabuffer)]
        (m.setup))))
