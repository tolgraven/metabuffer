local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

local function stays_closed_for(ms)
  return child.lua_get(string.format([[
    (function()
      local router = require('metabuffer.router')
      local source_buf = _G.__meta_source_buf
      local started = vim.uv.hrtime()
      local budget = %d * 1000000
      while (vim.uv.hrtime() - started) < budget do
        vim.wait(20)
        if router['active-by-source'][source_buf] ~= nil then
          return false
        end
      end
      return true
    end)()
  ]], ms))
end

T['cancel closes session and it does not reopen'] = H.timed_case(function()
  H.open_meta_with_lines({
    'alpha one',
    'beta two',
    'gamma three',
  })

  H.close_meta_prompt()
  H.wait_for(function() return not H.session_active() end, 3000)
  eq(stays_closed_for(300), true)
end)

T['accept closes session and it does not reopen'] = H.timed_case(function()
  H.open_meta_with_lines({
    'alpha one',
    'beta meta two',
    'gamma meta three',
  })

  H.type_prompt_text('meta')
  H.wait_for(function() return H.session_hit_count() == 2 end, 3000)

  H.type_prompt('<CR>')
  H.wait_for(function() return not H.session_active() end, 3000)
  eq(stays_closed_for(300), true)
end)

return T
