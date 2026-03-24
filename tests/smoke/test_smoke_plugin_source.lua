local T = MiniTest.new_set()

T['plugin source loads and exposes :Meta without external bc module'] = function()
  local root = vim.fn.getcwd()

  vim.cmd('source ' .. root .. '/plugin/metabuffer.lua')

  MiniTest.expect.equality(vim.fn.exists(':Meta'), 2)
  MiniTest.expect.equality(vim.g.loaded_metabuffer, 1)
end

return T
