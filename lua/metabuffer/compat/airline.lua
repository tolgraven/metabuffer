-- [nfnl] fnl/metabuffer/compat/airline.fnl
local function win_valid_3f(win)
  return (win and vim.api.nvim_win_is_valid(win))
end
local function disable_21(_1_)
  local win = _1_.win
  if win_valid_3f(win) then
    return pcall(vim.api.nvim_win_set_var, win, "airline_disable_statusline", 1)
  else
    return nil
  end
end
local function enable_21(_3_)
  local win = _3_.win
  if win_valid_3f(win) then
    return pcall(vim.api.nvim_win_del_var, win, "airline_disable_statusline")
  else
    return nil
  end
end
return {name = "airline", domain = "compat", events = {["on-win-create!"] = {handler = disable_21, priority = 10}, ["on-win-teardown!"] = {handler = enable_21, priority = 90}}}
