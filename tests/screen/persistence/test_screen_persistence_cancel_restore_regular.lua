local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.shared_child_hooks() })

T['regular <Esc> hides Meta UI and remains resumable with jump forward'] = H.timed_case(function()
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

  H.focus_prompt('insert')
  child.type_keys('<Esc>')

  H.wait_for(function()
    return H.session_ui_hidden()
  end, 3000)

  local cancel_state = child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      return {
        current_buf = vim.api.nvim_get_current_buf(),
        session_exists = s ~= nil,
        ui_hidden = s and s['ui-hidden'] == true or false,
      }
    end)()
  ]])
  eq(cancel_state.current_buf, H.source_buf())
  eq(cancel_state.session_exists, true)
  eq(cancel_state.ui_hidden, true)

  child.cmd('normal! <C-i>')

  H.wait_for(function()
    return H.session_active()
  end, 3000)
  H.wait_for(function()
    return H.current_buf_matches(state_before.results_buf)
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
end)

T['Esc in normal-mode results buffer also hides Meta UI'] = H.timed_case(function()
  H.open_meta_with_lines({
    'alpha meta one',
    'alpha meta two',
    'beta other',
    'gamma other',
  })

  H.type_prompt_text('meta')
  H.wait_for(function() return H.session_hit_count() == 2 end, 3000)

  H.type_prompt('<M-CR>')
  H.wait_for(function()
    local cur = H.session_main_cursor()
    return type(cur) == 'table' and cur[1] > 0
  end, 3000)

  child.type_keys('<Esc>')

  H.wait_for(function()
    return H.session_ui_hidden()
  end, 3000)

  eq(H.session_ui_hidden(), true)
  eq(H.current_buf_is_source(), true)
end)

return T
