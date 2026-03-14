local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['binary and hex flags stay visible in prompt and toggle state'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_text('#binary #hex metabuffer.png')
  H.wait_for(function() return H.session_prompt_text() == '#binary #hex metabuffer.png' end, 6000)

  local dbg = H.session_debug_out()
  eq(H.str_contains(dbg, '+bin'), true)
  eq(H.str_contains(dbg, '+hex'), true)
end)

return T
