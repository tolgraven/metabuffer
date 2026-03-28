local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

local function configure_animated_meta()
  child.lua([[
    require('metabuffer').setup({
      ui = {
        animation = {
          enabled = true,
          backend = 'mini',
          time_scale = 1.0,
        },
      },
    })
  ]])
end

T['Esc during animated startup stays hidden after settle'] = H.timed_case(function()
  configure_animated_meta()

  child.cmd('edit README.md')
  child.cmd('normal! 40G')
  local before = H.current_cursor()

  child.type_keys(':', 'Meta', '<CR>')
  H.dump_state('double/esc/after-open')
  H.wait_for(function()
    return H.session_active()
  end, 3000)
  H.dump_state('double/esc/after-active')

  child.type_keys('<Esc>')
  H.dump_state('double/esc/after-esc')
  H.wait_for(function()
    return H.session_ui_hidden()
  end, 3000)
  H.dump_state('double/esc/after-hidden')

  local after_cancel = H.current_cursor()
  child.lua('vim.wait(700)')
  H.dump_state('double/esc/after-wait')
  local after_wait = H.current_cursor()

  eq(H.current_buf_name(), H.buf_name(1))
  eq(after_cancel[1], before[1])
  eq(after_wait[1], before[1])
  eq(H.session_ui_hidden(), true)
end)

return T
