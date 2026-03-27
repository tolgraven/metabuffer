(fn buf-valid?
  [buf]
  (and buf (vim.api.nvim_buf_is_valid buf)))

(fn close-completion-ui!
  []
  "Close lingering completion preview windows."
  (pcall vim.cmd "silent! pclose"))

(fn disable-native-completion-for-buf!
  [buf]
  "Disable native completion providers on prompt buffers.
   Keeps Meta's own directive completefunc while clearing foreign providers."
  (when (buf-valid? buf)
    (let [bo (. vim.bo buf)
          completefunc (or (. bo :completefunc) "")]
      (when (~= completefunc "v:lua.__meta_directive_completefunc")
        (set (. bo :completefunc) ""))
      (set (. bo :omnifunc) "")
      (set (. bo :complete) "")
      (set (. bo :completeopt) "menuone,noselect,noinsert"))))

(fn disable-completion-for-buf!
  [buf]
  "Disable both nvim-cmp and native completion affordances for a prompt buffer."
  (when (buf-valid? buf)
    (disable-native-completion-for-buf! buf)
    (close-completion-ui!)
    (let [[ok cmp] [(pcall require :cmp)]]
      (when ok
        (pcall cmp.setup.buffer {:enabled false})
        (pcall cmp.abort)))))

(fn disable-cmp-for-buf!
  [{: buf}]
  "Disable completion on prompt buffers at creation and on next tick.
   Expected output: cmp menu closed and native completion providers disabled."
  (disable-completion-for-buf! buf)
  (vim.schedule (fn [] (disable-completion-for-buf! buf))))

(fn disable-cmp-on-insert!
  [{: session}]
  "Re-disable completion on InsertEnter in case external plugins re-arm it."
  (when (and session session.prompt-buf (buf-valid? session.prompt-buf))
    (disable-completion-for-buf! session.prompt-buf)))

{:name :cmp
 :domain :compat
 :events
 {:on-buf-create!   {:handler disable-cmp-for-buf!
                     :priority 30
                     :role-filter :prompt}
  :on-insert-enter! {:handler disable-cmp-on-insert!
                     :priority 30}}}
