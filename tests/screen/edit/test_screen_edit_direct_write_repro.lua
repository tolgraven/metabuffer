local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['focused results insert writes persists through accept and jump traversal'] = H.timed_case(function()
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
  H.dump_state('after open')

  H.type_prompt_text('beta')
  H.wait_for(function() return H.session_hit_count() == 1 end, 4000)
  H.dump_state('after filter')
  H.type_prompt('<M-CR>')
  H.wait_for(function()
    return H.session_results_focused()
  end, 4000)
  H.dump_state('after focus results')

  child.type_keys('o')
  child.type_keys('beta inserted')
  child.type_keys('<Esc>')
  H.dump_state('after insert')
  child.cmd('write')
  H.dump_state('after write')

  eq(H.read_file(path), {
    'alpha one',
    'alpha two',
    'beta target',
    'beta inserted',
    'gamma four',
  })

  child.type_keys('j')
  child.type_keys('<CR>')
  H.dump_state('after accept')
  H.wait_for(function()
    return H.current_buf_name_matches(path) and H.current_line() == 4
  end, 4000)

  child.cmd('normal! <C-o>')
  H.dump_state('after first C-o')
  H.wait_for(function() return H.session_active() end, 4000)
  H.wait_for(function() return not H.session_ui_hidden() end, 4000)

  child.cmd('normal! <C-o>')
  H.dump_state('after second C-o')
  H.wait_for(function()
    return H.current_buf_name_matches(path)
  end, 4000)

  child.cmd('normal! <C-i>')
  H.dump_state('after C-i')
  H.wait_for(function() return H.session_active() end, 4000)
  H.wait_for(function() return not H.session_ui_hidden() end, 4000)

  eq(H.read_file(path), {
    'alpha one',
    'alpha two',
    'beta target',
    'beta inserted',
    'gamma four',
  })
end)

return T
