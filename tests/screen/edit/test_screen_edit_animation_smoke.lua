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

  local path = H.write_temp_file({
    'alpha one',
    'alpha two',
    'beta target',
    'gamma four',
  }, '.txt')

  child.cmd('edit ' .. path)
  H.set_source_buf_to_current()
  child.type_keys(':', 'Meta', '<CR>')
  H.wait_for(function() return H.session_active() end, 4000)
end)

return T
