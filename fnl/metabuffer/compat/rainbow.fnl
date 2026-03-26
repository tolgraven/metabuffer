(fn buf-valid?
  [buf]
  (and buf (vim.api.nvim_buf_is_valid buf)))

(fn deactivate!
  [{: buf}]
  "Deactivate rainbow_parentheses on Meta-owned buffers."
  (when (and (buf-valid? buf)
             (= 1 (vim.fn.exists "*rainbow_parentheses#deactivate")))
    (pcall vim.api.nvim_buf_set_var buf "metabuffer_rainbow_parentheses_disabled" true)
    (let [run! (fn []
                 (vim.cmd "silent! call rainbow_parentheses#deactivate()"))]
      (pcall vim.api.nvim_buf_call buf run!))))

(fn activate!
  [{: buf}]
  "Re-activate rainbow_parentheses on buffers that had it disabled."
  (when (buf-valid? buf)
    (let [[ok disabled?] [(pcall vim.api.nvim_buf_get_var buf "metabuffer_rainbow_parentheses_disabled")]]
      (when (and ok disabled? (= 1 (vim.fn.exists "*rainbow_parentheses#activate")))
        (let [run! (fn []
                     (vim.cmd "silent! call rainbow_parentheses#activate()"))]
          (pcall vim.api.nvim_buf_call buf run!))
        (pcall vim.api.nvim_buf_del_var buf "metabuffer_rainbow_parentheses_disabled")))))

{:name :rainbow
 :domain :compat
 :events
 {:on-buf-create!   {:handler deactivate!
                     :priority 30}
  :on-buf-teardown! {:handler activate!
                     :priority 70}}}
