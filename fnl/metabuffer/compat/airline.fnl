(fn win-valid?
  [win]
  (and win (vim.api.nvim_win_is_valid win)))

(fn disable!
  [{: win}]
  "Disable airline statusline on a Meta-owned window."
  (when (win-valid? win)
    (pcall vim.api.nvim_win_set_var win "airline_disable_statusline" 1)))

(fn enable!
  [{: win}]
  "Re-enable airline statusline when a Meta window is torn down."
  (when (win-valid? win)
    (pcall vim.api.nvim_win_del_var win "airline_disable_statusline")))

{:name :airline
 :domain :compat
 :events
 {:on-win-create!  {:handler disable!
                    :priority 10}
  :on-win-teardown! {:handler enable!
                     :priority 90}}}
