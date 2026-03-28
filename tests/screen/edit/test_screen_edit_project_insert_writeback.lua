local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['filtered project-meta direct inserts write back without explicit edit-mode entry'] = H.timed_case(function()
  local root = H.make_temp_project()

  H.open_project_meta_in_dir(root, 'main.txt')
  H.type_prompt_text('other')
  H.wait_for(function()
    return H.session_hit_count() == 1
  end, 6000)
  H.type_prompt('<M-CR>')
  H.wait_for(function()
    return H.session_results_focused()
  end, 3000)

  child.type_keys('o')
  child.type_keys('insert-after-other')
  child.type_keys('<Esc>')
  child.cmd('write')

  eq(H.read_file(root .. '/doc/readme.md'), {
    'meta docs',
    'metam docs',
    'other',
    'insert-after-other',
  })
end)

return T
