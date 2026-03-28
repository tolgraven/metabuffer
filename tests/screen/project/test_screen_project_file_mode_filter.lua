local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['typing after #file space narrows file entries'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_text('#file ')
  H.wait_for(function() return H.session_file_entry_hit_count() > 0 end, 6000)

  local all_count = H.session_file_entry_hit_count()
  eq(type(all_count), 'number')
  eq(all_count > 1, true)

  H.type_prompt_text('#file README')
  H.wait_for(function()
    local n = H.session_file_entry_hit_count()
    return n > 0 and n < all_count
  end, 6000)

  local filtered_count = H.session_file_entry_hit_count()
  eq(filtered_count > 0, true)
  eq(filtered_count < all_count, true)
end)

return T
