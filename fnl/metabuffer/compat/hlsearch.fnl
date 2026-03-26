(fn clear!
  [_args]
  "Clear hlsearch highlight."
  (pcall vim.cmd "silent! nohlsearch"))

(fn restore!
  [_args]
  "Restore hlsearch so the search register highlights normally."
  (set vim.o.hlsearch true))

{:name :hlsearch
 :domain :compat
 :events
 {:on-session-start! {:handler clear!
                      :priority 80}
  :on-accept!        {:handler restore!
                      :priority 80}
  :on-cancel!        {:handler clear!
                      :priority 80}
  :on-restore-ui!    {:handler clear!
                      :priority 80}}}
