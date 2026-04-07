local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['regular info rerenders after hidden-session reopen'] = H.timed_case(function()
  H.open_meta_with_lines({
    'alpha one',
    'beta two',
    'gamma three',
    'delta four',
    'epsilon five',
    'zeta six',
    'eta seven',
    'theta eight',
  })

  H.wait_for(function()
    local snap = H.session_info_snapshot()
    return snap and snap.line ~= ''
  end, 4000)

  local before = H.session_info_snapshot()
  eq(type(before), 'table')
  eq(before.line ~= '', true)

  H.child.lua([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      assert(s and s['prompt-buf'], 'missing prompt buffer')
      router.cancel(s['prompt-buf'])
    end)()
  ]])
  H.wait_for(function() return H.session_ui_hidden() end, 3000)

  H.child.cmd('Meta')

  H.wait_for(function()
    return H.session_active() and not H.session_ui_hidden()
  end, 4000)
  H.wait_for(function()
    local snap = H.session_info_snapshot()
    return snap and snap.line ~= ''
  end, 4000)

  local after = H.session_info_snapshot()
  eq(type(after), 'table')
  eq(after.line ~= '', true)
  eq(after.count > 0, true)
end)

return T
