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

return T
