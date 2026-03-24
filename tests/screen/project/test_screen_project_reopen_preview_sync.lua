local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['reopening hidden project Meta keeps preview synced with restored selection'] = H.timed_case(function()
  local root = H.make_temp_project()
  H.open_project_meta_in_dir(root, 'main.txt')

  H.type_prompt_text('meta')
  H.wait_for(function() return H.session_hit_count() > 2 end, 6000)
  H.type_prompt('<C-n>')
  H.type_prompt('<C-n>')

  local before = child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local ref = nil
      if s and s.meta then
        local src_idx = (s.meta.buf.indices or {})[(s.meta.selected_index or 0) + 1]
        ref = src_idx and (s.meta.buf['source-refs'] or {})[src_idx] or nil
      end
      local pwin = s and s['preview-win'] or nil
      local pview = nil
      if pwin and vim.api.nvim_win_is_valid(pwin) then
        pview = vim.api.nvim_win_call(pwin, function() return vim.fn.winsaveview() end)
      end
      return {
        selected_lnum = ref and (ref.preview_lnum or ref.lnum) or 0,
        preview_lnum = pview and (pview.lnum or 0) or 0,
      }
    end)()
  ]])
  eq(before.selected_lnum > 1, true)
  eq(before.preview_lnum, before.selected_lnum)

  child.lua([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      assert(s and s['prompt-buf'], 'missing prompt buffer')
      router.cancel(s['prompt-buf'])
    end)()
  ]])
  H.wait_for(function() return H.session_ui_hidden() end, 3000)

  child.type_keys(':', 'Meta!', '<CR>')

  H.wait_for(function()
    return H.session_active() and not H.session_ui_hidden() and H.session_preview_visible()
  end, 4000)

  local after = child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local ref = nil
      if s and s.meta then
        local src_idx = (s.meta.buf.indices or {})[(s.meta.selected_index or 0) + 1]
        ref = src_idx and (s.meta.buf['source-refs'] or {})[src_idx] or nil
      end
      local pwin = s and s['preview-win'] or nil
      local pview = nil
      if pwin and vim.api.nvim_win_is_valid(pwin) then
        pview = vim.api.nvim_win_call(pwin, function() return vim.fn.winsaveview() end)
      end
      return {
        selected_lnum = ref and (ref.preview_lnum or ref.lnum) or 0,
        preview_lnum = pview and (pview.lnum or 0) or 0,
      }
    end)()
  ]])

  eq(after.selected_lnum, before.selected_lnum)
  eq(after.preview_lnum, after.selected_lnum)
end)

return T
