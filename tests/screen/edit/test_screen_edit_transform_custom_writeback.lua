local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['custom transform edits write back through reverse shell command'] = H.timed_case(function()
  child.lua([[
    require('metabuffer.custom')['configure!']({
      transforms = {
        upper = {
          from = { 'tr', 'a-z', 'A-Z' },
          to = { 'tr', 'A-Z', 'a-z' },
          doc = 'Uppercase lines.',
        },
      },
    })
  ]])

  local path = H.write_temp_file({ 'hello world', 'tail' }, '.txt')

  child.cmd('edit ' .. path)
  H.set_source_buf_to_current()
  child.type_keys(':', 'Meta', '<CR>')
  H.wait_for(H.session_active, 3000)

  H.type_prompt_text('#transform:upper')
  H.wait_for(function()
    local lines = H.session_result_lines()
    return type(lines) == 'table' and lines[1] == 'HELLO WORLD'
  end, 3000)

  H.type_prompt('<M-CR>')
  H.wait_for(function()
    return H.session_results_focused()
  end, 3000)

  child.type_keys('c', 'c')
  child.type_keys('CHANGED TEXT')
  child.type_keys('<Esc>')
  child.cmd('write')

  eq(H.read_file(path), {
    'changed text',
    'tail',
  })
end)

return T
