local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['regular <CR> hides Meta UI and remains resumable across back-forward traversal'] = H.timed_case(function()
  H.open_meta_with_lines({
    'alpha meta one',
    'alpha meta two',
    'beta other',
    'gamma other',
  })

  H.type_prompt_text('meta')
  H.wait_for(function() return H.session_hit_count() == 2 end, 3000)
  H.type_prompt('<C-n>')

  local state_before = child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return nil end
      return {
        prompt = table.concat(vim.api.nvim_buf_get_lines(s['prompt-buf'], 0, -1, false), '\n'),
        selected = s.meta.selected_index or 0,
        results_buf = s.meta.buf.buffer,
      }
    end)()
  ]])
  eq(type(state_before), 'table')

  H.type_prompt('<CR>')
  H.wait_for(function() return H.session_ui_hidden() end, 3000)
  H.wait_for(function()
    return child.lua_get('vim.api.nvim_get_current_buf() == _G.__meta_source_buf')
  end, 3000)

  child.cmd('normal! <C-o>')

  H.wait_for(function()
    return child.lua_get(string.format('vim.api.nvim_get_current_buf() == %d', state_before.results_buf))
  end, 3000)
  H.wait_for(function()
    return not H.session_ui_hidden()
  end, 3000)

  local state_after = child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return nil end
      return {
        prompt = table.concat(vim.api.nvim_buf_get_lines(s['prompt-buf'], 0, -1, false), '\n'),
        selected = s.meta.selected_index or 0,
      }
    end)()
  ]])
  eq(state_after.prompt, state_before.prompt)
  eq(state_after.selected, state_before.selected)

  child.cmd('normal! <C-o>')
  H.wait_for(function()
    return child.lua_get('vim.api.nvim_get_current_buf() == _G.__meta_source_buf')
  end, 3000)
  child.lua('vim.wait(120, function() return false end, 20)')

  child.cmd('normal! <C-i>')
  H.wait_for(function()
    return H.session_active()
  end, 3000)
  H.wait_for(function()
    return child.lua_get(string.format('vim.api.nvim_get_current_buf() == %d', state_before.results_buf))
  end, 3000)
  H.wait_for(function()
    return not H.session_ui_hidden()
  end, 3000)
end)

T['regular <CR> does not reveal the old source viewport before jumping to the hit'] = H.timed_case(function()
  child.cmd('enew')
  child.api.nvim_buf_set_lines(0, 0, -1, false, {
    'alpha first',
    'beta second',
    'gamma third',
    'delta fourth',
    'epsilon fifth',
    'zeta sixth',
    'eta seventh',
    'theta eighth',
  })
  child.lua([[
    _G.__meta_source_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_win_set_cursor(0, {8, 0})
  ]])
  child.type_keys(':', 'Meta', '<CR>')
  H.wait_for(function() return H.session_active() end, 3000)

  H.type_prompt_text('alpha')
  H.wait_for(function() return H.session_hit_count() == 1 end, 3000)

  child.lua([[
    _G.__meta_accept_rows = {}
    local src = _G.__meta_source_buf
    local grp = vim.api.nvim_create_augroup('MetaAcceptTrace', { clear = true })
    vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter', 'CursorMoved', 'CursorMovedI' }, {
      group = grp,
      buffer = src,
      callback = function()
        local cur = vim.api.nvim_win_get_cursor(0)
        table.insert(_G.__meta_accept_rows, cur[1])
      end,
    })
  ]])

  H.type_prompt('<CR>')
  H.wait_for(function()
    return child.lua_get('vim.api.nvim_get_current_buf() == _G.__meta_source_buf')
  end, 3000)

  local rows = child.lua_get([[
    (function()
      return _G.__meta_accept_rows or {}
    end)()
  ]])

  eq(type(rows), 'table')
  eq(#rows > 0, true)
  for _, row in ipairs(rows) do
    eq(row, 1)
  end
end)

return T
