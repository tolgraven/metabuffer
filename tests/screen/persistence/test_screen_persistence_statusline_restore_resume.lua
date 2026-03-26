local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['regular accept restores origin window statusline and reapplies Meta statusline on resume'] = H.timed_case(function()
  H.child.cmd('enew')
  H.child.lua([[
    vim.wo.statusline = 'ORIGINAL STATUS'
    vim.wo.winhighlight = 'StatusLine:DiffText,StatusLineNC:DiffAdd'
  ]])
  H.child.api.nvim_buf_set_lines(0, 0, -1, false, {
    'alpha meta one',
    'alpha meta two',
    'beta three',
  })
  H.child.lua("_G.__meta_source_buf = vim.api.nvim_get_current_buf()")
  H.child.type_keys(':', 'Meta', '<CR>')
  H.wait_for(H.session_active, 3000)

  local state = H.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return nil end
      return {
        results_buf = s.meta.buf.buffer,
        prompt_buf = s['prompt-buf'],
      }
    end)()
  ]])
  eq(type(state), 'table')

  H.type_prompt('<CR>')
  H.wait_for(H.session_ui_hidden, 3000)
  H.wait_for(function()
    return H.child.lua_get('vim.api.nvim_get_current_buf() == _G.__meta_source_buf')
  end, 3000)

  local restored = H.child.lua_get([[
    (function()
      return {
        statusline = vim.api.nvim_get_option_value('statusline', { win = vim.api.nvim_get_current_win() }),
        winhighlight = vim.api.nvim_get_option_value('winhighlight', { win = vim.api.nvim_get_current_win() }),
      }
    end)()
  ]])

  eq(restored.statusline, 'ORIGINAL STATUS')
  eq(restored.winhighlight, 'StatusLine:DiffText,StatusLineNC:DiffAdd')

  H.child.cmd('normal! <C-o>')
  H.wait_for(function()
    return H.child.lua_get(string.format('vim.api.nvim_get_current_buf() == %d', state.results_buf))
  end, 3000)
  H.wait_for(function() return not H.session_ui_hidden() end, 3000)

  local resumed = H.child.lua_get([[
    (function()
      return {
        statusline = vim.api.nvim_get_option_value('statusline', { win = vim.api.nvim_get_current_win() }),
        winhighlight = vim.api.nvim_get_option_value('winhighlight', { win = vim.api.nvim_get_current_win() }),
      }
    end)()
  ]])

  eq(type(resumed.statusline), 'string')
  eq(type(resumed.winhighlight), 'string')
  eq(resumed.statusline == 'ORIGINAL STATUS', false)
  eq(resumed.winhighlight == 'StatusLine:DiffText,StatusLineNC:DiffAdd', false)
end)

return T
