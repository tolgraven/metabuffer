local T = MiniTest.new_set()

T['reload with compile succeeds and keeps plugin commands available'] = function()
  local root = vim.fn.getcwd()

  vim.cmd('source ' .. root .. '/plugin/metabuffer.lua')

  local ok, err = pcall(function()
    require('metabuffer').reload({ compile = true })
  end)

  MiniTest.expect.equality(ok, true)
  MiniTest.expect.equality(vim.fn.exists(':Meta'), 2)

  if not ok then
    error(err)
  end
end

return T
