local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['project flags are consumed and reflected in debug/statusline'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')

  H.type_prompt_human('#hidden #deps #nolazy meta', 25)
  H.wait_for(function() return H.session_query_text() == 'meta' end, 6000)
  H.wait_for(function() return H.session_prompt_text() == 'meta' end, 6000)

  local dbg = H.session_debug_out()
  eq(H.str_contains(dbg, '+hid'), true)
  eq(H.str_contains(dbg, '+dep'), true)
  eq(H.str_contains(dbg, 'nlz'), true)

  local sl = H.session_statusline()
  eq(H.str_contains(sl, '+hid'), true)
  eq(H.str_contains(sl, '+dep'), true)
end)

T['binary and hex flags stay visible in prompt and toggle state'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_human('#binary #hex metabuffer.png', 90)
  H.wait_for(function() return H.session_prompt_text() == '#binary #hex metabuffer.png' end, 6000)

  local dbg = H.session_debug_out()
  eq(H.str_contains(dbg, '+bin'), true)
  eq(H.str_contains(dbg, '+hex'), true)
end)

return T
