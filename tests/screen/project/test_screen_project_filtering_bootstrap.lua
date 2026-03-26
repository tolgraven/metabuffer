local H = require('tests.screen.support.screen_helpers')

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['project mode bootstraps source expansion without prompt input'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  local initial_paths = H.session_source_path_count()
  H.wait_for(function()
    return H.session_source_path_count() > initial_paths
  end, 6000)
end)

T['bootstrap renders streamed content into result buffer'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  -- Wait for lazy streaming to finish (source paths grow beyond initial)
  H.wait_for(function()
    return H.session_source_path_count() > 1
  end, 6000)
  -- Verify the actual Neovim buffer has more lines than just the initial file.
  -- Before the fix, indices/content were populated but render was never called,
  -- leaving the result buffer showing only the startup file.
  local rendered = H.session_result_lines()
  local source_count = H.session_source_path_count()
  MiniTest.expect.equality(source_count > 1, true)
  MiniTest.expect.equality(#rendered > 10, true)
end)

return T
