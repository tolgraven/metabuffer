-- [nfnl] fnl/metabuffer/sign.fnl
local M = {}
M["buf-has-signs?"] = function(buf)
  local out = vim.fn.execute(("sign place group=* buffer=" .. buf))
  return (#out > 2)
end
M["refresh-dummy"] = function(buf)
  pcall(vim.cmd, "sign define MetaDummy")
  pcall(vim.cmd, ("sign unplace 9999 buffer=" .. buf))
  return pcall(vim.cmd, ("sign place 9999 line=1 name=MetaDummy buffer=" .. buf))
end
return M
