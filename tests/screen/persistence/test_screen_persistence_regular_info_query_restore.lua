local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['regular info window does not blank when query narrows and broadens'] = H.timed_case(function()
  H.open_meta_with_lines({
    'alpha first',
    'beta second',
    'gamma third',
    'alpha fourth',
    'beta fifth',
    'gamma sixth',
    'alpha seventh',
    'beta eighth',
    'gamma ninth',
    'alpha tenth',
  })

  H.wait_for(function()
    local snap = H.session_info_snapshot()
    return snap and snap.line ~= ''
  end, 4000)

  H.start_info_blank_watch(700)
  H.type_prompt_human('alpha', 25)
  H.wait_for(function() return H.session_query_text() == 'alpha' end, 4000)
  H.wait_for(function()
    local snap = H.session_info_snapshot()
    return snap and snap.line ~= ''
  end, 4000)
  H.wait_for(function() return H.info_blank_watch_done() end, 2000)
  eq(H.info_blank_seen(), false)

  H.start_info_blank_watch(700)
  H.type_prompt_tokens({ '<BS>', '<BS>', '<BS>', '<BS>', '<BS>' }, 35)
  H.wait_for(function() return H.session_query_text() == '' end, 4000)
  H.wait_for(function()
    local snap = H.session_info_snapshot()
    return snap and snap.line ~= ''
  end, 4000)
  H.wait_for(function() return H.info_blank_watch_done() end, 2000)
  eq(H.info_blank_seen(), false)
end)

return T
