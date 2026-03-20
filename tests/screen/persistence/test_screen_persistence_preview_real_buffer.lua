local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['regular preview reuses the real source buffer instead of a synthetic copy'] = H.timed_case(function()
  H.open_meta_with_lines({
    'local message = [[',
    '  multiline string body',
    ']]',
    'return message',
  })

  H.wait_for(function()
    return H.session_preview_visible()
  end, 3000)

  local state = child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return nil end
      local win = s['preview-win']
      if not (win and vim.api.nvim_win_is_valid(win)) then return nil end
      local buf = vim.api.nvim_win_get_buf(win)
      return {
        preview_buf = buf,
        source_buf = _G.__meta_source_buf,
        number = vim.api.nvim_get_option_value('number', { win = win }),
        preview_name = vim.api.nvim_buf_get_name(buf),
      }
    end)()
  ]])

  eq(type(state), 'table')
  eq(state.preview_buf, state.source_buf)
  eq(state.number, true)
  eq(type(state.preview_name), 'string')
  eq(state.preview_name ~= '', true)
end)

return T
