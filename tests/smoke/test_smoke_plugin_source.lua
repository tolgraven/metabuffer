local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['plugin source loads and exposes :Meta without external bc module'] = H.timed_case(function()
  local root = H.child.fn.getcwd()

  H.child.cmd('source ' .. root .. '/plugin/metabuffer.lua')

  eq(H.child.fn.exists(':Meta'), 2)

  H.child.cmd('enew')
  H.child.api.nvim_buf_set_lines(0, 0, -1, false, {
    'alpha one',
    'alpha two',
    'beta three',
    'gamma four',
  })
  H.child.lua("_G.__meta_source_buf = vim.api.nvim_get_current_buf()")
  H.child.type_keys(':', 'Meta', '<CR>')

  H.wait_for(function()
    return H.session_active()
  end, 3000)

  eq(H.session_active(), true)
end)

return T
