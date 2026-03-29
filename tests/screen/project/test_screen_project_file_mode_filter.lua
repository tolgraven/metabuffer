local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['typing inline #file filter narrows file entries and highlights arg separately'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_text('#file')
  H.wait_for(function() return H.session_file_entry_hit_count() > 0 end, 6000)

  local all_count = H.session_file_entry_hit_count()
  eq(type(all_count), 'number')
  eq(all_count > 1, true)

  H.type_prompt_text('#file:README')
  H.wait_for(function()
    local n = H.session_file_entry_hit_count()
    return n > 0 and n < all_count
  end, 6000)

  local filtered_count = H.session_file_entry_hit_count()
  eq(filtered_count > 0, true)
  eq(filtered_count < all_count, true)

  local has_flag_hl, has_arg_hl = H.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local ns = s['prompt-hl-ns']
      local marks = vim.api.nvim_buf_get_extmarks(s['prompt-buf'], ns, { 0, 0 }, { 0, -1 }, { details = true })
      local flag_hl, arg_hl = false, false
      for _, mark in ipairs(marks or {}) do
        local details = mark[4] or {}
        if details.hl_group == 'MetaPromptFlagTextOn' then
          flag_hl = true
        elseif details.hl_group == 'MetaPromptFileArg' then
          arg_hl = true
        end
      end
      return { flag_hl, arg_hl }
    end)()
  ]])
  eq(has_flag_hl, true)
  eq(has_arg_hl, true)
end)

T['backspacing from #file help does not leave an errmsg'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_text('#file')
  H.wait_for(function() return H.session_prompt_text() == '#file' end, 6000)

  H.type_prompt_tokens({ '<BS>' }, 20)
  H.wait_for(function() return H.session_prompt_text() == '#fil' end, 6000)
  H.wait_for(function()
    return H.child.lua_get([[(function() return vim.v.errmsg == '' end)()]])
  end, 6000)
end)

T['directive help popup stays above the prompt, mirrors prompt highlighting, and closes on focus loss'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_text('#file:README')
  local help = nil
  H.wait_for(function()
    help = H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        if not (s and s['directive-help-win'] and vim.api.nvim_win_is_valid(s['directive-help-win'])) then
          return nil
        end
        local prompt_pos = vim.api.nvim_win_get_position(s['prompt-win'])
        local help_pos = vim.api.nvim_win_get_position(s['directive-help-win'])
        local ns = s['directive-help-hl-ns']
        local marks = vim.api.nvim_buf_get_extmarks(s['directive-help-buf'], ns, { 0, 0 }, { 0, -1 }, { details = true })
        local flag_hl, arg_hl = false, false
        for _, mark in ipairs(marks or {}) do
          local details = mark[4] or {}
          if details.hl_group == 'MetaPromptFlagTextOn' then
            flag_hl = true
          elseif details.hl_group == 'MetaPromptFileArg' then
            arg_hl = true
          end
        end
        return {
          prompt_row = prompt_pos[1],
          help_row = help_pos[1],
          flag_hl = flag_hl,
          arg_hl = arg_hl,
        }
      end)()
    ]])
    return help ~= nil
  end, 6000)

  eq(help.help_row < help.prompt_row, true)
  eq(help.flag_hl, true)
  eq(help.arg_hl, true)

  H.child.lua([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      vim.cmd('stopinsert')
      vim.api.nvim_set_current_win(s.meta.win.window)
    end)()
  ]])
  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        return not (s and s['directive-help-win'] and vim.api.nvim_win_is_valid(s['directive-help-win']))
      end)()
    ]])
  end, 6000)
end)

T['directive help follows completion selection changes'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_text('#b')
  local before = nil
  H.wait_for(function()
    before = H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        if not (s and s['directive-help-buf'] and vim.api.nvim_buf_is_valid(s['directive-help-buf'])) then
          return nil
        end
        local info = vim.fn.complete_info({ 'selected', 'items' })
        return {
          selected = info.selected,
          help = vim.api.nvim_buf_get_lines(s['directive-help-buf'], 0, 1, false)[1] or '',
        }
      end)()
    ]])
    return before ~= nil and before.help ~= ''
  end, 6000)

  H.type_prompt_tokens({ '<C-n>', '<C-n>' }, 20)

  H.wait_for(function()
    local after = H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        if not (s and s['directive-help-buf'] and vim.api.nvim_buf_is_valid(s['directive-help-buf'])) then
          return nil
        end
        local info = vim.fn.complete_info({ 'selected', 'items' })
        local item = (info.items or {})[(info.selected or -1) + 1]
        return {
          selected = info.selected,
          item = item and item.word or '',
          help = vim.api.nvim_buf_get_lines(s['directive-help-buf'], 0, 1, false)[1] or '',
        }
      end)()
    ]])
    return after
      and after.selected >= 1
      and after.item ~= ''
      and after.help == after.item
      and after.help ~= before.help
  end, 6000)
end)

T['directive help closes when prompt accepts a hit'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_text('#file:README')
  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        return not not (s and s['directive-help-win'] and vim.api.nvim_win_is_valid(s['directive-help-win']))
      end)()
    ]])
  end, 6000)

  H.type_prompt('<CR>')

  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        return not not (s and (s['ui-hidden'] or not s['prompt-win'])) and not (s and s['directive-help-win'] and vim.api.nvim_win_is_valid(s['directive-help-win']))
      end)()
    ]])
  end, 6000)
end)

return T
