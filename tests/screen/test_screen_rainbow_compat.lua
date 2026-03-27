local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

local function origin_disabled_marker_state()
  return H.child.lua_get([[
    (function()
      local buf = _G.__meta_source_buf
      if not (buf and vim.api.nvim_buf_is_valid(buf)) then
        return { valid = false, has = false, value = false }
      end
      local ok, val = pcall(vim.api.nvim_buf_get_var, buf, 'metabuffer_rainbow_parentheses_disabled')
      return { valid = true, has = ok, value = ok and not not val or false }
    end)()
  ]])
end

T['rainbow compat marks origin during session and clears on cancel'] = H.timed_case(function()
  H.open_meta_with_lines({
    'alpha one',
    'beta two',
    'gamma three',
  })

  H.wait_for(function()
    local state = origin_disabled_marker_state()
    return state.valid and state.has and state.value
  end, 3000)

  H.close_meta_prompt()

  H.wait_for(function()
    return H.session_not_visible()
  end, 3000)

  local state_after = origin_disabled_marker_state()
  eq(state_after.valid, true)
  eq(state_after.has, false)
end)

return T
