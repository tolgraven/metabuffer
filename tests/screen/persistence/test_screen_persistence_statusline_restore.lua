local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['cancel restores original window statusline and winhighlight'] = H.timed_case(function()
  H.child.cmd('enew')
  H.child.lua([[
    vim.wo.statusline = 'ORIGINAL STATUS'
    vim.wo.winhighlight = 'StatusLine:DiffText,StatusLineNC:DiffAdd'
    vim.wo.colorcolumn = '80,120,160,200,240'
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
        colorcolumn = vim.api.nvim_get_option_value('colorcolumn', { win = vim.api.nvim_get_current_win() }),
      }
    end)()
  ]])

  eq(restored.statusline, 'ORIGINAL STATUS')
  eq(restored.winhighlight, 'StatusLine:DiffText,StatusLineNC:DiffAdd')
  eq(restored.colorcolumn, '80,120,160,200,240')
end)

T['cancel after help-hide cycle restores original window statusline and winhighlight'] = H.timed_case(function()
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

  H.type_prompt('<Esc>')
  H.child.type_keys(':', 'help help', '<CR>')

  H.wait_for(function()
    return H.session_ui_hidden()
  end, 3000)

  H.child.cmd('quit')

  H.wait_for(function()
    return not H.session_ui_hidden()
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

T['project cancel restores original window statusline and winhighlight'] = H.timed_case(function()
  H.open_fixture_file('README.md')
  H.child.lua([[
    vim.wo.statusline = 'ORIGINAL STATUS'
    vim.wo.winhighlight = 'StatusLine:DiffText,StatusLineNC:DiffAdd'
  ]])

  H.child.type_keys(':', 'Meta!', '<CR>')

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

  H.wait_for(function()
    return H.session_active()
  end, 3000)

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

  H.wait_for(function()
    return H.session_ui_hidden()
  end, 3000)
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
  H.wait_for(function()
    return not H.session_ui_hidden()
  end, 3000)

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
      vim.wo.statusline = 'AIRLINE STATUS'
      vim.wo.winhighlight = 'StatusLine:DiffDelete,StatusLineNC:DiffChange'
    end
    vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter' }, {
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
  H.child.lua("_G.__meta_source_buf = vim.api.nvim_get_current_buf()")
  H.child.type_keys(':', 'Meta', '<CR>')

  H.wait_for(function()
    return H.session_active()
  end, 3000)

  H.type_prompt('<CR>')
  H.wait_for(function()
    return H.session_ui_hidden()
  end, 3000)
  H.wait_for(function()
    return H.child.lua_get('vim.api.nvim_get_current_buf() == _G.__meta_source_buf')
  end, 3000)

  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        return vim.api.nvim_get_option_value('statusline', { win = vim.api.nvim_get_current_win() }) == 'AIRLINE STATUS'
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
      vim.wo.statusline = 'AIRLINE STATUS'
      vim.wo.winhighlight = 'StatusLine:DiffDelete,StatusLineNC:DiffChange'
    end
    vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter', 'WinEnter' }, {
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
  H.child.lua("_G.__meta_source_buf = vim.api.nvim_get_current_buf()")
  H.child.type_keys(':', 'Meta', '<CR>')

  H.wait_for(function()
    return H.session_active()
  end, 3000)

  H.focus_prompt('insert')
  H.child.type_keys('<Esc>')
  H.wait_for(function()
    return H.session_ui_hidden()
  end, 3000)
  H.wait_for(function()
    return H.child.lua_get('vim.api.nvim_get_current_buf() == _G.__meta_source_buf')
  end, 3000)

  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        return vim.api.nvim_get_option_value('statusline', { win = vim.api.nvim_get_current_win() }) == 'AIRLINE STATUS'
          and vim.api.nvim_get_option_value('winhighlight', { win = vim.api.nvim_get_current_win() }) == 'StatusLine:DiffDelete,StatusLineNC:DiffChange'
          and (_G.__meta_airline_refreshes or 0) > 1
      end)()
    ]])
  end, 3000)
end)

return T
