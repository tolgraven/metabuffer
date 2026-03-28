local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['json transform edits write back as compact source, not pretty-printed lines'] = H.timed_case(function()
  local path = H.write_temp_file({ '{"alpha":1,"beta":2}', 'tail' }, '.jsonl')

  child.cmd('edit ' .. path)
  H.set_source_buf_to_current()
  child.type_keys(':', 'Meta', '<CR>')
  H.wait_for(H.session_active, 3000)

  H.type_prompt_text('#json')
  H.wait_for(function()
    local lines = H.session_result_lines()
    return type(lines) == 'table' and lines[1] == '{'
  end, 3000)

  H.type_prompt('<M-CR>')
  H.wait_for(function()
    return H.session_results_focused()
  end, 3000)

  child.type_keys('j')
  child.type_keys('c', 'c')
  child.type_keys('  "alpha": 3,')
  child.type_keys('<Esc>')
  child.cmd('write')

  eq(H.read_file(path), {
    '{"alpha":3,"beta":2}',
    'tail',
  })
end)

return T
