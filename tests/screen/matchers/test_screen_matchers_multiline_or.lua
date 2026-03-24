local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['multiple prompt lines match as OR by default'] = H.timed_case(function()
  H.open_meta_with_lines({
    'alpha first',
    'beta second',
    'gamma third',
  })

  child.lua([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      assert(s and s['prompt-buf'], 'missing prompt buffer')
      vim.api.nvim_buf_set_lines(s['prompt-buf'], 0, -1, false, { 'alpha', 'beta' })
      vim.api.nvim_exec_autocmds('TextChangedI', { buffer = s['prompt-buf'] })
    end)()
  ]])

  H.wait_for(function()
    return H.session_hit_count() == 2
  end, 3000)

  local lines = child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local out = {}
      for _, idx in ipairs(s.meta.buf.indices or {}) do
        out[#out + 1] = s.meta.buf.content[idx]
      end
      return out
    end)()
  ]])

  eq(lines, { 'alpha first', 'beta second' })

  local hls = child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local ns = s['prompt-hl-ns']
      local prompt = {
        row1 = vim.api.nvim_buf_get_extmarks(s['prompt-buf'], ns, { 0, 0 }, { 0, -1 }, { details = true }),
        row2 = vim.api.nvim_buf_get_extmarks(s['prompt-buf'], ns, { 1, 0 }, { 1, -1 }, { details = true }),
      }
      local matches = vim.api.nvim_win_call(s.meta.win.window, function()
        return vim.fn.getmatches()
      end)
      local groups = {}
      for _, item in ipairs(matches) do
        groups[#groups + 1] = item.group
      end
      return {
        prompt_row1 = prompt.row1,
        prompt_row2 = prompt.row2,
        groups = groups,
      }
    end)()
  ]])

  local function has_prompt_group(extmarks, group)
    for _, mark in ipairs(extmarks or {}) do
      local details = mark[4] or {}
      if details.hl_group == group then
        return true
      end
    end
    return false
  end

  local function has_group(groups, target)
    for _, group in ipairs(groups or {}) do
      if group == target then
        return true
      end
    end
    return false
  end

  eq(has_prompt_group(hls.prompt_row1, 'MetaPromptText1'), true)
  eq(has_prompt_group(hls.prompt_row2, 'MetaPromptText2'), true)
  eq(has_group(hls.groups, 'MetaSearchHitAll1'), true)
  eq(has_group(hls.groups, 'MetaSearchHitAll2'), true)
end)

return T
