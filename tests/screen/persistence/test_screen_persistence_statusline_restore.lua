local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['cancel restores original window statusline and winhighlight'] = H.timed_case(function()
  H.child.cmd('enew')
  H.child.lua([[
    vim.wo.statusline = 'ORIGINAL STATUS'
    vim.wo.winhighlight = 'StatusLine:DiffText,StatusLineNC:DiffAdd'
  ]])
  H.child.api.nvim_buf_set_lines(0, 0, -1, false, {
    'alpha one',
    'alpha two',
    'beta three',
  })
  H.child.lua("_G.__meta_source_buf = vim.api.nvim_get_current_buf()")
  H.child.type_keys(':', 'Meta', '<CR>')

  H.wait_for(function()
    return H.session_active()
  end, 3000)

  H.close_meta_prompt()

  H.wait_for(function()
    return not H.session_active()
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
end)

return T
