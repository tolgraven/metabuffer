local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

local function configure_animated_meta()
  child.lua([[
    require('metabuffer').setup({
      ui = {
        animation = {
          enabled = true,
          backend = 'mini',
          time_scale = 1.0,
        },
      },
    })
  ]])
end

T['second :Meta during active startup does not create a duplicate session'] = H.timed_case(function()
  configure_animated_meta()

  child.cmd('edit README.md')
  child.type_keys(':', 'Meta', '<CR>', ':', 'Meta', '<CR>')

  H.wait_for(function()
    return H.session_active() and H.session_preview_visible() and H.session_info_snapshot() ~= nil
  end, 4000)

  local state = child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local uniq = {}
      local count = 0
      for _, session in pairs(router['active-by-prompt']) do
        if session and not uniq[session] then
          uniq[session] = true
          count = count + 1
        end
      end
      local meta_bufs = {}
      for _, info in ipairs(vim.fn.getbufinfo()) do
        local name = info.name or ''
        if name:find('Metabuffer', 1, true) and not name:find('%[Metabuffer', 1) then
          meta_bufs[#meta_bufs + 1] = name
        end
      end
      return {
        sessions = count,
        wins = #vim.api.nvim_list_wins(),
        meta_bufs = meta_bufs,
      }
    end)()
  ]])

  eq(state.sessions, 1)
  eq(state.wins, 4)
  eq(#state.meta_bufs, 1)
end)

T['second straight :Meta during startup remains a no-op'] = H.timed_case(function()
  configure_animated_meta()

  child.cmd('edit README.md')
  child.type_keys(':', 'Meta', '<CR>', ':', 'Meta', '<CR>')

  H.wait_for(function()
    return H.session_active() and H.session_preview_visible()
  end, 4000)

  local state = child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local uniq = {}
      local count = 0
      local s
      for _, session in pairs(router['active-by-prompt']) do
        if session and not uniq[session] then
          uniq[session] = true
          count = count + 1
          s = session
        end
      end
      return {
        sessions = count,
        prompt = s and table.concat(vim.api.nvim_buf_get_lines(s['prompt-buf'], 0, -1, false), '\n') or '',
      }
    end)()
  ]])

  eq(state.sessions, 1)
  eq(state.prompt, '')
end)

T['Esc during animated startup stays hidden after settle'] = H.timed_case(function()
  configure_animated_meta()

  child.cmd('edit README.md')
  child.cmd('normal! 40G')
  local before = child.lua_get('vim.api.nvim_win_get_cursor(0)')

  child.type_keys(':', 'Meta', '<CR>')
  H.wait_for(function()
    return H.session_active()
  end, 3000)

  child.type_keys('<Esc>')
  H.wait_for(function()
    return H.session_ui_hidden()
  end, 3000)

  local after_cancel = child.lua_get('vim.api.nvim_win_get_cursor(0)')
  child.lua('vim.wait(700)')
  local after_wait = child.lua_get('vim.api.nvim_win_get_cursor(0)')

  eq(child.lua_get('vim.fn.bufname(vim.api.nvim_get_current_buf())'), child.lua_get('vim.fn.bufname(1)'))
  eq(after_cancel[1], before[1])
  eq(after_wait[1], before[1])
  eq(H.session_ui_hidden(), true)
end)

return T
