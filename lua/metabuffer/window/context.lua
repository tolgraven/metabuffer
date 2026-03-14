-- [nfnl] fnl/metabuffer/window/context.fnl
local M = {}
local function close_window_21(session)
  if (session["context-win"] and vim.api.nvim_win_is_valid(session["context-win"])) then
    pcall(vim.api.nvim_win_close, session["context-win"], true)
  else
  end
  session["context-win"] = nil
  session["context-buf"] = nil
  return nil
end
M.new = function(_opts)
  return {["update!"] = close_window_21, ["close-window!"] = close_window_21}
end
return M
