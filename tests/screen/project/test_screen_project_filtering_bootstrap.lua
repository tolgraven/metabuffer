local H = require('tests.screen.support.screen_helpers')

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['project mode bootstraps source expansion without prompt input'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  local initial_paths = H.session_source_path_count()
  H.wait_for(function()
    return H.session_source_path_count() > initial_paths
  end, 6000)
end)

return T
