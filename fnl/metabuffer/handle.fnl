(local M {})

(fn M.new [nvim target model opts-from-model opts]
  (local self {:nvim nvim
               :target target
               :model (or model target)
               :saved-opts {}
               :terminated false})

  (fn self.store-opts [names _origin]
    (each [_ name (ipairs (or names []))]
      (tset self.saved-opts name (vim.api.nvim_get_option_value name {:scope "local"}))))

  (fn self.apply-opts [tbl]
    (each [k v (pairs (or tbl {}))]
      (pcall vim.api.nvim_set_option_value k v {:scope "local"})))

  (fn self.push-opt [name value]
    (tset self.saved-opts name (vim.api.nvim_get_option_value name {:scope "local"}))
    (pcall vim.api.nvim_set_option_value name value {:scope "local"}))

  (fn self.pop-opt [name]
    (let [v (. self.saved-opts name)]
      (when (~= v nil)
        (pcall vim.api.nvim_set_option_value name v {:scope "local"}))))

  (fn self.restore-opts []
    (self.apply-opts self.saved-opts))

  (fn self.destroy []
    (when (not self.terminated)
      (self.restore-opts)
      (set self.terminated true)))

  (self.store-opts opts-from-model model)
  (self.apply-opts opts)
  self)

M
