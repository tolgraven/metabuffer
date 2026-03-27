(fn buf-valid?
  [buf]
  (and buf (vim.api.nvim_buf_is_valid buf)))


(fn origin-buf
  [{: session}]
  "Return session origin buffer when valid, else nil."
  (let [buf (and session session.origin-buf)]
    (when (buf-valid? buf)
      buf)))

(fn deactivate!
  [{: session}]
  "Deactivate rainbow_parentheses on the session origin buffer."
  (let [buf (origin-buf {:session session})]
    (when buf
      (pcall vim.api.nvim_buf_set_var buf "metabuffer_rainbow_parentheses_disabled" true)
      (when (= 1 (vim.fn.exists "*rainbow_parentheses#deactivate"))
        (let [run! (fn []
                     (vim.cmd "silent! call rainbow_parentheses#deactivate()"))]
          (pcall vim.api.nvim_buf_call buf run!))))))

(fn activate!
  [{: session}]
  "Re-activate rainbow_parentheses on buffers that had it disabled."
  (let [buf (origin-buf {:session session})]
    (when buf
      (let [[ok disabled?] [(pcall vim.api.nvim_buf_get_var buf "metabuffer_rainbow_parentheses_disabled")]]
        (when (and ok disabled? (= 1 (vim.fn.exists "*rainbow_parentheses#activate")))
          (let [run! (fn []
                       (vim.cmd "silent! call rainbow_parentheses#activate()"))]
            (pcall vim.api.nvim_buf_call buf run!))
          (pcall vim.api.nvim_buf_del_var buf "metabuffer_rainbow_parentheses_disabled"))))))

{:name :rainbow
 :domain :compat
 :events
 {:on-session-start! {:handler deactivate!
                      :priority 30}
  :on-session-stop!  {:handler activate!
                      :priority 70}}}
