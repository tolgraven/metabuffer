local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['second straight :Meta during startup remains a no-op'] = H.timed_case(function()
  child.cmd('enew')
  child.api.nvim_buf_set_lines(0, 0, -1, false, {
    'alpha one', 'alpha two', 'beta three',
    'gamma four', 'delta five', 'epsilon six',
  })
  H.set_source_buf_to_current()
  child.type_keys(':', 'Meta', '<CR>', ':', 'Meta', '<CR>')
  H.dump_state('double/noop/after-double-meta')

  H.wait_for(function()
    return H.session_active() and H.session_preview_visible()
  end, 4000)
  H.dump_state('double/noop/after-waits')

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

return T
