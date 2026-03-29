local H = require('tests.screen.support.screen_helpers')

local T = MiniTest.new_set({ hooks = H.shared_child_hooks() })

T['accept hands statusline control back to statusline plugins on origin window'] = H.timed_case(function()
  H.child.cmd('enew')
  H.child.lua([[
    _G.__meta_airline_refreshes = 0
    local aug = vim.api.nvim_create_augroup('MetaAirlineMock', { clear = true })
    local function refresh()
      local ok = pcall(vim.api.nvim_win_get_var, 0, 'airline_disable_statusline')
      if ok then
        return
      end
      _G.__meta_airline_refreshes = _G.__meta_airline_refreshes + 1
      local normal = not vim.api.nvim_get_mode().mode:match('^i')
      vim.wo.statusline = normal and 'AIRLINE N' or 'AIRLINE I'
      vim.wo.winhighlight = normal and 'StatusLine:DiffDelete,StatusLineNC:DiffChange' or 'StatusLine:DiffAdd,StatusLineNC:DiffText'
    end
    vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter', 'WinEnter', 'InsertEnter', 'InsertLeave' }, {
      group = aug,
      callback = refresh,
    })
    refresh()
  ]])
  H.child.api.nvim_buf_set_lines(0, 0, -1, false, {
    'alpha one',
    'alpha two',
    'beta three',
  })
  H.set_source_buf_to_current()
  H.child.type_keys(':', 'Meta', '<CR>')
  H.wait_for(H.session_active, 3000)

  H.type_prompt('<CR>')
  H.wait_for(H.session_ui_hidden, 3000)
  H.wait_for(function()
    return H.current_buf_is_source()
  end, 3000)

  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        return vim.api.nvim_get_option_value('statusline', { win = vim.api.nvim_get_current_win() }) == 'AIRLINE N'
          and vim.api.nvim_get_option_value('winhighlight', { win = vim.api.nvim_get_current_win() }) == 'StatusLine:DiffDelete,StatusLineNC:DiffChange'
          and (_G.__meta_airline_refreshes or 0) > 1
      end)()
    ]])
  end, 3000)
end)

T['cancel hands statusline control back to statusline plugins on origin window'] = H.timed_case(function()
  H.child.cmd('enew')
  H.child.lua([[
    _G.__meta_airline_refreshes = 0
    local aug = vim.api.nvim_create_augroup('MetaAirlineMockCancel', { clear = true })
    local function refresh()
      local ok = pcall(vim.api.nvim_win_get_var, 0, 'airline_disable_statusline')
      if ok then
        return
      end
      _G.__meta_airline_refreshes = _G.__meta_airline_refreshes + 1
      local normal = not vim.api.nvim_get_mode().mode:match('^i')
      vim.wo.statusline = normal and 'AIRLINE N' or 'AIRLINE I'
      vim.wo.winhighlight = normal and 'StatusLine:DiffDelete,StatusLineNC:DiffChange' or 'StatusLine:DiffAdd,StatusLineNC:DiffText'
    end
    vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter', 'WinEnter', 'InsertEnter', 'InsertLeave' }, {
      group = aug,
      callback = refresh,
    })
    refresh()
  ]])
  H.child.api.nvim_buf_set_lines(0, 0, -1, false, {
    'alpha one',
    'alpha two',
    'beta three',
  })
  H.set_source_buf_to_current()
  H.child.type_keys(':', 'Meta', '<CR>')
  H.wait_for(H.session_active, 3000)

  H.focus_prompt('insert')
  H.child.type_keys('<Esc>')
  H.wait_for(H.session_ui_hidden, 3000)
  H.wait_for(function()
    return H.current_buf_is_source()
  end, 3000)

  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        return vim.api.nvim_get_option_value('statusline', { win = vim.api.nvim_get_current_win() }) == 'AIRLINE N'
          and vim.api.nvim_get_option_value('winhighlight', { win = vim.api.nvim_get_current_win() }) == 'StatusLine:DiffDelete,StatusLineNC:DiffChange'
          and (_G.__meta_airline_refreshes or 0) > 1
      end)()
    ]])
  end, 3000)
end)

return T
