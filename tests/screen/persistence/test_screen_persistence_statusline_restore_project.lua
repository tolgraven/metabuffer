local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['project cancel restores original window statusline and winhighlight'] = H.timed_case(function()
  H.edit_fixture_file('README.md')
  H.child.lua([[
    vim.wo.statusline = 'ORIGINAL STATUS'
    vim.wo.winhighlight = 'StatusLine:DiffText,StatusLineNC:DiffAdd'
  ]])

  H.child.type_keys(':', 'Meta!', '<CR>')
  H.wait_for(H.session_active, 3000)

  H.close_meta_prompt()
  H.wait_for(H.session_not_visible, 3000)

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
