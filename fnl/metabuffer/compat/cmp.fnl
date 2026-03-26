(fn buf-valid?
  [buf]
  (and buf (vim.api.nvim_buf_is_valid buf)))

(fn disable-cmp-for-buf!
  [{: buf}]
  "Disable nvim-cmp on prompt buffers via buffer-local convention and API."
  (when (buf-valid? buf)
    (let [[ok cmp] [(pcall require :cmp)]]
      (when ok
        (pcall cmp.setup.buffer {:enabled false})
        (pcall cmp.abort)))))

(fn disable-cmp-on-insert!
  [{: session}]
  "Re-disable nvim-cmp on InsertEnter in case it re-armed itself."
  (when (and session session.prompt-buf (buf-valid? session.prompt-buf))
    (let [[ok cmp] [(pcall require :cmp)]]
      (when ok
        (pcall cmp.setup.buffer {:enabled false})
        (pcall cmp.abort)))))

{:name :cmp
 :domain :compat
 :events
 {:on-buf-create!   {:handler disable-cmp-for-buf!
                     :priority 30
                     :role-filter :prompt}
  :on-insert-enter! {:handler disable-cmp-on-insert!
                     :priority 30}}}
