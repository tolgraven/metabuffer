(fn buf-valid?
  [buf]
  (and buf (vim.api.nvim_buf_is_valid buf)))

(fn disable-common!
  [{: buf}]
  "Disable heavy buffer-local plugin helpers on any Meta-owned buffer."
  (when (buf-valid? buf)
    (pcall vim.api.nvim_buf_set_var buf "conjure_disable" true)
    (pcall vim.api.nvim_buf_set_var buf "lsp_disabled" 1)
    (pcall vim.api.nvim_buf_set_var buf "gitgutter_enabled" 0)
    (pcall vim.api.nvim_buf_set_var buf "gitsigns_disable" true)
    (pcall vim.diagnostic.enable false {:bufnr buf})))

(fn disable-prompt-pairs!
  [{: buf}]
  "Disable auto-pair / completion / endwise helpers on the prompt buffer."
  (when (buf-valid? buf)
    (pcall vim.api.nvim_buf_set_var buf "autopairs_enabled" false)
    (pcall vim.api.nvim_buf_set_var buf "AutoPairsDisabled" 1)
    (pcall vim.api.nvim_buf_set_var buf "delimitMate_enabled" 0)
    (pcall vim.api.nvim_buf_set_var buf "pear_tree_disable" 1)
    (pcall vim.api.nvim_buf_set_var buf "endwise_disable" 1)
    (pcall vim.api.nvim_buf_set_var buf "cmp_enabled" false)
    (pcall vim.api.nvim_buf_set_var buf "meta_prompt" true)))

(fn mark-preview!
  [{:buf buf :transient? transient?}]
  "Set the meta_preview marker on preview buffers."
  (when (and (buf-valid? buf)
             (if (= transient? nil) true transient?))
    (pcall vim.api.nvim_buf_set_var buf "meta_preview" true)))

{:name :buffer-plugins
 :domain :compat
 :events
 {:on-buf-create!
  [{:handler disable-common!
    :priority 10}
   {:handler disable-prompt-pairs!
    :priority 20
    :role-filter :prompt}
   {:handler mark-preview!
    :priority 20
    :role-filter :preview}]}}
