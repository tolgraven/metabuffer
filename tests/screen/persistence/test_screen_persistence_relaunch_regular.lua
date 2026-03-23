local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['regular :Meta can relaunch from origin buffer after Esc hides session'] = H.timed_case(function()
  H.open_meta_with_lines({
    'alpha one',
    'alpha two',
    'beta three',
  })

  local first = child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      assert(s and s.meta and s.meta.buf, 'missing session')
      return {
        results_buf = s.meta.buf.buffer,
        prompt_buf = s['prompt-buf'],
      }
    end)()
  ]])

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
  eq(child.lua_get('vim.api.nvim_get_current_buf() == _G.__meta_source_buf'), true)

  child.type_keys(':', 'Meta', '<CR>')

  H.wait_for(function()
    return H.session_active() and not H.session_ui_hidden()
  end, 3000)
  H.wait_for(function()
    return H.session_prompt_win_height() > 0
  end, 3000)

  local second = child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      assert(s and s.meta and s.meta.buf, 'missing restored session')
      return {
        results_buf = s.meta.buf.buffer,
        prompt_buf = s['prompt-buf'],
      }
    end)()
  ]])

  eq(second.results_buf, first.results_buf)
  eq(second.prompt_buf, first.prompt_buf)
end)

return T
