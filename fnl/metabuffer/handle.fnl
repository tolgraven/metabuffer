(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(fn valid-buf?
  [x]
  (and (= (type x) "number")
       (pcall vim.api.nvim_buf_is_valid x)
       (vim.api.nvim_buf_is_valid x)))

(fn valid-win?
  [x]
  (and (= (type x) "number")
       (pcall vim.api.nvim_win_is_valid x)
       (vim.api.nvim_win_is_valid x)))

(fn get-local-opt
  [name target]
  (if (valid-buf? target)
      (let [[ok v] [(pcall vim.api.nvim_get_option_value name {:buf target})]]
        (if ok
            v
            (if (valid-win? target)
                (let [[wok wv] [(pcall vim.api.nvim_get_option_value name {:win target})]]
                  (if wok wv (vim.api.nvim_get_option_value name {:scope "local"})))
                (vim.api.nvim_get_option_value name {:scope "local"}))))
      (if (valid-win? target)
          (let [[ok v] [(pcall vim.api.nvim_get_option_value name {:win target})]]
            (if ok v (vim.api.nvim_get_option_value name {:scope "local"})))
          (vim.api.nvim_get_option_value name {:scope "local"}))))

(fn set-local-opt
  [name value target]
  (if (valid-buf? target)
      (let [[ok _] [(pcall vim.api.nvim_set_option_value name value {:buf target})]]
        (if (not ok)
            (if (valid-win? target)
                (let [[wok _w] [(pcall vim.api.nvim_set_option_value name value {:win target})]]
                  (if (not wok)
                      (pcall vim.api.nvim_set_option_value name value {:scope "local"})))
                (pcall vim.api.nvim_set_option_value name value {:scope "local"}))))
      (if (valid-win? target)
          (let [[ok _] [(pcall vim.api.nvim_set_option_value name value {:win target})]]
            (if (not ok)
                (pcall vim.api.nvim_set_option_value name value {:scope "local"})))
          (pcall vim.api.nvim_set_option_value name value {:scope "local"}))))

(fn M.new
  [nvim target model opts-from-model opts]
  "Create a handle that stores/restores window or buffer local options."
  (let [self {:nvim nvim
              :target target
              :model (or model target)
              :saved-opts {}
              :terminated false}]
    (fn self.store-opts
      [names _origin]
      (each [_ name (ipairs (or names []))]
        (set (. self.saved-opts name) (get-local-opt name _origin))))

    (fn self.apply-opts
      [tbl]
      (each [k v (pairs (or tbl {}))]
        (set-local-opt k v self.target)))

    (fn self.push-opt
      [name value]
      (set (. self.saved-opts name) (get-local-opt name self.target))
      (set-local-opt name value self.target))

    (fn self.pop-opt
      [name]
      (let [v (. self.saved-opts name)]
        (when (~= v nil)
          (set-local-opt name v self.target))))

    (fn self.restore-opts
      []
      (self.apply-opts self.saved-opts))

    (fn self.destroy
      []
      (when (not self.terminated)
        (self.restore-opts)
        (set self.terminated true)))

    (self.store-opts opts-from-model model)
    (self.apply-opts opts)
    self))

M
