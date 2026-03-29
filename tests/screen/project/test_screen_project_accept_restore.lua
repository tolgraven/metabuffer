local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['project <CR> hides Meta UI but restores full state when returning to results buffer'] = H.timed_case(function()
  local root = H.make_temp_project()
  H.open_project_meta_in_dir(root, 'main.txt')

  H.type_prompt_text('meta')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)
  H.type_prompt('<C-n>')
  H.wait_for(function()
    return H.session_preview_contains('contains meta token')
  end, 4000)

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
  local accepted_buf = H.current_buf()
  eq(type(accepted_buf), 'number')

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
    return H.current_buf_matches(state_before.results_buf)
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

  eq(H.current_buf_matches(state_before.results_buf), true)

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
  H.wait_for(function()
    return H.session_preview_contains('contains meta token')
  end, 4000)

  child.cmd('normal! <C-i>')

  H.wait_for(function()
    return H.current_buf_matches(accepted_buf)
  end)
  H.wait_for(function()
    return H.session_ui_hidden()
  end, 4000)

  child.cmd('normal! <C-o>')

  H.wait_for(function()
    return H.current_buf_matches(state_before.results_buf)
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
  H.wait_for(function()
    return H.session_preview_contains('contains meta token')
  end, 4000)
end)

T['project <CR> edits the selected file through a cwd-relative path'] = H.timed_case(function()
  local root = H.make_temp_project()
  H.open_project_meta_in_dir(root, 'main.txt')

  H.type_prompt_text('#file:lua/mod.lua')
  H.wait_for(function()
    local ref = H.session_selected_ref()
    return type(ref) == 'table' and ref.path and H.str_contains(ref.path, 'lua/mod.lua')
  end, 6000)

  local hist_before = H.child.fn.histnr(':')
  H.type_prompt('<CR>')

  H.wait_for(function()
    return H.child.fn.histnr(':') > hist_before
  end, 4000)

  local cmd = H.child.fn.histget(':', -1)
  eq(type(cmd), 'string')
  eq(H.str_contains(cmd, 'edit '), true)
  eq(H.str_contains(cmd, 'lua/mod.lua'), true)
  eq(H.str_contains(cmd, root), false)
end)

return T
