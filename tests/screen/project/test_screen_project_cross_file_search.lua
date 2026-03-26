local H = require('tests.screen.support.screen_helpers')

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['project mode shows content from files other than launch file'] = H.timed_case(function()
  local root = H.make_temp_project()
  H.open_project_meta_in_dir(root, 'main.txt')

  -- Wait for project bootstrap to load all sources (more than just main.txt).
  H.wait_for(function() return H.session_source_path_count() > 1 end, 6000)

  -- Search for text that only exists in doc/readme.md, not in main.txt.
  H.type_prompt_text('meta docs')
  H.wait_for(function() return H.session_query_text() == 'meta docs' end, 3000)
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  -- Verify the matching line actually comes from another file.
  local lines = H.session_result_lines()
  local found_docs = false
  for _, line in ipairs(lines) do
    if line:find('meta docs') then
      found_docs = true
      break
    end
  end
  MiniTest.expect.equality(found_docs, true)
end)

return T
