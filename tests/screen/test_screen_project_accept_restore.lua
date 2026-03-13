local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['project <CR> hides Meta UI but restores full state when returning to results buffer'] = H.timed_case(function()
  local root = H.make_temp_project()
  H.open_project_meta_in_dir(root, 'main.txt')

  H.type_prompt_human('meta', 90)
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)
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
  eq(type(state_before.results_buf), 'number')

  child.cmd('stopinsert')
  H.type_prompt('<CR>')

  H.wait_for(function()
    return child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        if not s then return false end
        local pwin = s['prompt-win']
        return (pwin == nil) or (not vim.api.nvim_win_is_valid(pwin))
      end)()
    ]])
  end)

  child.cmd('normal! <C-o>')

  H.wait_for(function()
    return child.lua_get(string.format('vim.api.nvim_get_current_buf() == %d', state_before.results_buf))
  end)

  H.wait_for(function()
    return child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        if not s then return false end
        local pwin = s['prompt-win']
        return pwin and vim.api.nvim_win_is_valid(pwin)
      end)()
    ]])
  end)

  eq(child.lua_get(string.format('vim.api.nvim_get_current_buf() == %d', state_before.results_buf)), true)

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

return T
