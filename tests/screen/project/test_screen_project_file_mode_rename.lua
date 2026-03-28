local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.shared_child_hooks() })

local function focus_results_window()
  H.type_prompt('<M-CR>')
  H.wait_for(function()
    return H.session_results_focused()
  end, 3000)
end

T['project file-entry write renames file on straight line replacement'] = H.timed_case(function()
  local root = H.make_temp_project()
  H.open_project_meta_in_dir(root, 'main.txt')

  H.type_prompt_text('#file:README.md')
  H.wait_for(function() return H.session_file_entry_hit_count() > 0 end, 6000)

  focus_results_window()
  child.type_keys('c', 'c')
  child.type_keys('doc/README-renamed.md')
  child.type_keys('<Esc>')
  child.cmd('write')

  eq(H.file_readable(root .. '/README.md'), 0)
  eq(H.file_readable(root .. '/doc/README-renamed.md'), 1)
end)

T['regular Meta file-entry write renames file on straight line replacement'] = H.timed_case(function()
  local root = H.make_temp_project()
  child.cmd('edit ' .. root .. '/main.txt')
  H.set_source_buf_to_current()
  child.type_keys(':', 'Meta', '<CR>')
  H.wait_for(H.session_active, 3000)

  H.type_prompt_text('#file:README.md')
  H.wait_for(function() return H.session_file_entry_hit_count() > 0 end, 6000)

  focus_results_window()
  child.type_keys('c', 'c')
  child.type_keys('doc/README-renamed-regular.md')
  child.type_keys('<Esc>')
  child.cmd('write')

  eq(H.file_readable(root .. '/README.md'), 0)
  eq(H.file_readable(root .. '/doc/README-renamed-regular.md'), 1)
end)

return T
