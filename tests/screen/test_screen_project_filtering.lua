local H = require('tests.screen.support.screen_helpers')

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['project mode immediate typing survives lazy stream churn'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')

  H.type_prompt_human('meta', 100)
  H.wait_for(function() return H.session_query_text() == 'meta' end, 6000)
  local meta_hits = H.session_hit_count()

  H.type_prompt_human('buffer', 90)
  H.wait_for(function() return H.session_query_text() == 'metabuffer' end, 6000)
  H.wait_for(function() return H.session_hit_count() <= meta_hits end, 6000)

  H.type_prompt_tokens({ '<BS>', '<BS>', '<BS>', '<BS>', '<BS>', '<BS>' }, 90)
  H.wait_for(function() return H.session_query_text() == 'meta' end, 6000)
  H.wait_for(function() return H.session_hit_count() >= meta_hits end, 6000)
end)

T['project mode clear query broadens and keeps source pool'] = H.timed_case(function()
  local root = H.make_temp_project()
  H.open_project_meta_in_dir(root, 'main.txt')

  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)
  local all_hits = H.session_hit_count()
  H.wait_for(function() return H.session_source_path_count() > 1 end, 6000)
  local all_sources = H.session_source_path_count()

  H.type_prompt_human('metam', 100)
  H.wait_for(function() return H.session_query_text() == 'metam' end, 6000)
  H.wait_for(function() return H.session_hit_count() < all_hits end, 6000)

  H.type_prompt('<C-u>')
  H.wait_for(function() return H.session_query_text() == '' end, 6000)
  H.wait_for(function() return H.session_hit_count() == all_hits end, 6000)
  H.wait_for(function() return H.session_source_path_count() == all_sources end, 6000)
end)

return T
