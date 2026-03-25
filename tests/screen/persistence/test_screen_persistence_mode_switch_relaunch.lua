local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['hidden regular session does not intercept later project launch'] = H.timed_case(function()
  H.edit_fixture_file('README.md')

  child.type_keys(':', 'Meta', '<CR>')
  H.wait_for(function()
    return H.session_active() and not H.session_ui_hidden()
  end, 3000)
  eq(H.session_project_mode(), false)

  child.lua([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      assert(s and s['prompt-buf'], 'missing prompt buffer')
      router.cancel(s['prompt-buf'])
    end)()
  ]])
  H.wait_for(function()
    return H.session_ui_hidden()
  end, 3000)

  child.type_keys(':', 'Meta!', '<CR>')

  H.wait_for(function()
    return H.session_active() and not H.session_ui_hidden()
  end, 4000)
  eq(H.session_project_mode(), true)
end)

return T
