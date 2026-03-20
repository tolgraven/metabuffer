local H = require('tests.screen.support.screen_helpers')
local child = H.child

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['animated regular meta can open'] = H.timed_case(function()
  H.configure_animation({
    ui = {
      animation = {
        enabled = true,
        loading_indicator = true,
      },
    },
  })

  local path = child.lua_get([[
    (function()
      local path = vim.fn.tempname() .. '.txt'
      vim.fn.writefile({
        'alpha one',
        'alpha two',
        'beta target',
        'gamma four',
      }, path)
      return path
    end)()
  ]])

  child.cmd('edit ' .. path)
  child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
  child.type_keys(':', 'Meta', '<CR>')
  H.wait_for(function() return H.session_active() end, 4000)
end)

return T
