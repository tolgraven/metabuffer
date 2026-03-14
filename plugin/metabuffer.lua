-- [nfnl] fnl/plugin/metabuffer.fnl
if (vim.g.loaded_metabuffer == 1) then
  return nil
else
  vim.g.loaded_metabuffer = 1
  if (vim.g.fennel_lua_version == nil) then
    vim.g["fennel_lua_version"] = "5.1"
  else
  end
  if (vim.g.fennel_use_luajit == nil) then
    if jit then
      vim.g["fennel_use_luajit"] = 1
    else
      vim.g["fennel_use_luajit"] = 0
    end
  else
  end
  local m = require("metabuffer")
  return m.setup()
end
