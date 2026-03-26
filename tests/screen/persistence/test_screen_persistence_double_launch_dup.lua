local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['second :Meta during active startup does not create a duplicate session'] = H.timed_case(function()
  child.cmd('enew')
  child.api.nvim_buf_set_lines(0, 0, -1, false, {
    'alpha one', 'alpha two', 'beta three',
    'gamma four', 'delta five', 'epsilon six',
  })
  child.lua("_G.__meta_source_buf = vim.api.nvim_get_current_buf()")
  child.type_keys(':', 'Meta', '<CR>', ':', 'Meta', '<CR>')
  H.dump_state('double/dup/after-double-meta')

  H.wait_for(function()
    return H.session_active() and H.session_preview_visible() and H.session_info_snapshot() ~= nil
  end, 4000)
  H.dump_state('double/dup/after-waits')

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

return T
