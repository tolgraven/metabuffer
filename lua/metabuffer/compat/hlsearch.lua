-- [nfnl] fnl/metabuffer/compat/hlsearch.fnl
local function clear_21(_args)
  return pcall(vim.cmd, "silent! nohlsearch")
end
local function restore_21(_args)
  vim.o.hlsearch = true
  return nil
end
return {name = "hlsearch", domain = "compat", events = {["on-session-start!"] = {handler = clear_21, priority = 80}, ["on-accept!"] = {handler = restore_21, priority = 80}, ["on-cancel!"] = {handler = clear_21, priority = 80}, ["on-restore-ui!"] = {handler = clear_21, priority = 80}}}
