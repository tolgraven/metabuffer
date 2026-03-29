local conjure = require('metabuffer.compat.conjure')
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

local function buf_var(buf, key)
  return vim.api.nvim_buf_get_var(buf, key)
end

local function apply_handler()
  return conjure.events['on-buf-create!'][1].handler
end

local function restore_handler()
  return conjure.events['on-buf-teardown!'][1].handler
end

T['conjure compat disables and restores buffer-local state'] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].omnifunc = 'v:lua.test_omnifunc'
  vim.api.nvim_buf_set_var(buf, 'conjure#mapping#doc_word', true)
  vim.api.nvim_buf_set_var(buf, 'conjure#log#hud#enabled', true)

  apply_handler()({ buf = buf })

  eq(vim.bo[buf].omnifunc, '')
  eq(buf_var(buf, 'conjure_disable'), true)
  eq(buf_var(buf, 'conjure#client_on_load'), false)
  eq(buf_var(buf, 'conjure#mapping#enable_ft_mappings'), false)
  eq(buf_var(buf, 'conjure#mapping#enable_defaults'), false)
  eq(buf_var(buf, 'conjure#mapping#doc_word'), false)
  eq(buf_var(buf, 'conjure#log#hud#enabled'), false)

  restore_handler()({ buf = buf })

  eq(vim.bo[buf].omnifunc, 'v:lua.test_omnifunc')
  eq(buf_var(buf, 'conjure#mapping#doc_word'), true)
  eq(buf_var(buf, 'conjure#log#hud#enabled'), true)
  eq(pcall(buf_var, buf, 'conjure_disable'), false)
end

return T
