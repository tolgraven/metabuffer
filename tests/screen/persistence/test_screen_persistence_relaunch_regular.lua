local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['regular :Meta from origin buffer creates a fresh session after Esc hides previous one'] = H.timed_case(function()
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

  child.type_keys('<Esc>')

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
      assert(s and s.meta and s.meta.buf, 'missing fresh session')
      return {
        results_buf = s.meta.buf.buffer,
        prompt_buf = s['prompt-buf'],
      }
    end)()
  ]])

  eq(second.results_buf == first.results_buf, false)
  eq(second.prompt_buf == first.prompt_buf, false)
end)

T['raw prompt-mode Esc then :Meta relaunches without callback errors'] = H.timed_case(function()
  child.cmd('edit README.md')
  child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
  child.cmd('Meta')
  vim.loop.sleep(150)

  child.lua([[vim.cmd("normal! \027")]])
  vim.loop.sleep(100)

  child.cmd('Meta')

  H.wait_for(function()
    return H.session_active()
  end, 3000)
  H.wait_for(function()
    return H.session_prompt_win_height() > 0
  end, 3000)
end)

return T
