-- [nfnl] fnl/plugin/metabuffer.fnl
if (vim.g.loaded_metabuffer == 1) then
  return nil
else
  vim.g.loaded_metabuffer = 1
  local m = require("metabuffer")
  return m.setup()
end
