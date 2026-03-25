local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['regular preview keeps a valid preview window/context after launch'] = H.timed_case(function()
  child.cmd('enew')
  child.api.nvim_buf_set_lines(0, 0, -1, false, {
    'line 1',
    'line 2',
    'line 3',
    'line 4',
    'line 5',
    'line 6',
    'line 7',
    'line 8 target',
    'line 9',
    'line 10',
    'line 11',
  })
  child.lua([[
    _G.__meta_source_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_win_set_cursor(0, { 8, 0 })
  ]])
  child.type_keys(':', 'Meta', '<CR>')

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
        view = vim.api.nvim_win_call(win, function()
          return vim.fn.winsaveview()
        end),
        matches = vim.api.nvim_win_call(win, function()
          return vim.fn.getmatches()
        end),
      }
    end)()
  ]])

  eq(type(state), 'table')
  eq(state.preview_buf ~= state.source_buf, true)
  eq(type(state.number), 'boolean')
  eq(type(state.preview_name), 'string')
  eq(state.preview_name ~= '', true)
  eq(state.view.lnum >= 1, true)
  eq(state.view.topline >= 1, true)
  eq(type(state.matches), 'table')
  eq(state.matches[1].group, 'MetaWindowCursorLine')
end)

return T
