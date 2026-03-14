local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['rapid mode toggles during lazy stream still settles to correct query state'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')

  H.type_prompt_human('meta', 70)
  child.lua([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return end
      for _ = 1, 6 do
        s.meta.switch_mode('case')
        s.meta.switch_mode('syntax')
      end
    end)()
  ]])

  H.wait_for(function() return H.session_query_text() == 'meta' end, 6000)
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  local matcher = H.session_matcher_name()
  local case_mode = H.session_case_mode()
  eq(type(matcher), 'string')
  eq(matcher ~= '', true)
  eq(type(case_mode), 'string')
  eq(case_mode ~= '', true)
end)

return T
