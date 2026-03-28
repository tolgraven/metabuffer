local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['filtered regular-meta direct inserts write back to the source file'] = H.timed_case(function()
  local path = H.write_temp_file({
    'alpha one',
    'alpha two',
    'beta target',
    'gamma four',
  }, '.txt')

  child.cmd('edit ' .. path)
  H.set_source_buf_to_current()
  child.type_keys(':', 'Meta', '<CR>')
  H.wait_for(H.session_active, 3000)

  H.type_prompt_text('beta')
  H.wait_for(function() return H.session_hit_count() == 1 end, 3000)
  H.type_prompt('<M-CR>')
  H.wait_for(function()
    return H.session_results_focused()
  end, 3000)

  child.type_keys('o')
  child.type_keys('beta inserted')
  child.type_keys('<Esc>')
  child.cmd('write')

  eq(H.read_file(path), {
    'alpha one',
    'alpha two',
    'beta target',
    'beta inserted',
    'gamma four',
  })
end)

return T
