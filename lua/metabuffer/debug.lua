-- [nfnl] fnl/metabuffer/debug.fnl
local M = {}
M["enabled?"] = function()
  return ((vim.g["meta#debug"] == 1) or (vim.g["meta#debug"] == true))
end
M.log = function(scope, msg)
  if M["enabled?"]() then
    local path = (vim.g["meta#debug_log"] or "/tmp/metabuffer-debug.log")
    local prefix
    if ((type(scope) == "string") and (scope ~= "")) then
      prefix = ("[" .. scope .. "] ")
    else
      prefix = ""
    end
    local line = (os.date("%Y-%m-%d %H:%M:%S") .. " " .. prefix .. tostring(msg))
    return pcall(vim.fn.writefile, {line}, path, "a")
  else
    return nil
  end
end
return M
