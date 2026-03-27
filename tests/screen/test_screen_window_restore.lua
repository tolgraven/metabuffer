local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

local function session_layout()
  return H.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not (s and s.meta and s.meta.win and vim.api.nvim_win_is_valid(s.meta.win.window)) then
        return nil
      end
      return {
        main = vim.api.nvim_win_get_height(s.meta.win.window),
        prompt = (s['prompt-win'] and vim.api.nvim_win_is_valid(s['prompt-win'])) and vim.api.nvim_win_get_height(s['prompt-win']) or -1,
        preview = (s['preview-win'] and vim.api.nvim_win_is_valid(s['preview-win'])) and vim.api.nvim_win_get_height(s['preview-win']) or -1,
        tab_count = #vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(s.meta.win.window)),
      }
    end)()
  ]])
end

T['restores layout after external split closes'] = H.timed_case(function()
  local lines = {}
  for i = 1, 240 do
    lines[#lines + 1] = ('window restore line %03d'):format(i)
  end
  H.open_meta_with_lines(lines)

  H.wait_for(function()
    local l = session_layout()
    return l and l.prompt > 0 and l.preview > 0
  end, 4000)

  local before = session_layout()

  H.child.lua([[vim.cmd('botright 8new')]])
  H.wait_for(function()
    local now = session_layout()
    return now and now.tab_count == before.tab_count + 1
  end, 4000)

  H.child.lua([[vim.cmd('close')]])

  H.wait_for(function()
    local now = session_layout()
    return now
      and now.tab_count == before.tab_count
      and now.main == before.main
      and now.prompt == before.prompt
      and now.preview == before.preview
  end, 5000)

  local after = session_layout()
  eq(after.tab_count, before.tab_count)
  eq(after.main, before.main)
  eq(after.prompt, before.prompt)
  eq(after.preview, before.preview)
end)

T['manual prompt resize becomes new expected layout'] = H.timed_case(function()
  local lines = {}
  for i = 1, 240 do
    lines[#lines + 1] = ('manual resize line %03d'):format(i)
  end
  H.open_meta_with_lines(lines)

  H.wait_for(function()
    local l = session_layout()
    return l and l.prompt > 1 and l.preview > 0
  end, 4000)

  local before = session_layout()
  local target_prompt = math.max(2, before.prompt + 2)

  H.set_prompt_win_height(target_prompt)

  H.wait_for(function()
    local now = session_layout()
    return now and now.prompt == target_prompt
  end, 3000)

  local resized = session_layout()

  H.child.lua([[vim.cmd('botright 6new')]])
  H.wait_for(function()
    local now = session_layout()
    return now and now.tab_count == before.tab_count + 1
  end, 4000)

  H.child.lua([[vim.cmd('close')]])

  H.wait_for(function()
    local now = session_layout()
    return now
      and now.tab_count == before.tab_count
      and now.prompt == target_prompt
      and now.main == resized.main
      and now.preview == resized.preview
  end, 5000)

  local after = session_layout()
  eq(after.prompt, target_prompt)
  eq(after.main, resized.main)
  eq(after.preview, resized.preview)
end)

return T
