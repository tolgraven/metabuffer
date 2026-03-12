local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['editing results buffer directly and :write propagates edits to source files'] = H.timed_case(function()
  local root = H.make_temp_project()
  H.open_project_meta_in_dir(root, 'main.txt')

  H.type_prompt_human('meta', 80)
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  local info_before = H.session_info_snapshot()
  eq(type(info_before), 'table')

  child.cmd('stopinsert')
  child.lua([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if s and s.meta and s.meta.win and vim.api.nvim_win_is_valid(s.meta.win.window) then
        vim.api.nvim_set_current_win(s.meta.win.window)
      end
    end)()
  ]])

  local info_after = H.session_info_snapshot()
  eq(type(info_after), 'table')

  local target = child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local meta = s and s.meta or nil
      if not meta then return nil end
      local idx = (meta.buf.indices or {})[1]
      local ref = idx and (meta.buf['source-refs'] or {})[idx] or nil
      if not ref then return nil end
      return { path = ref.path or '', lnum = ref.lnum or 0, old = meta.buf.content[idx] or '' }
    end)()
  ]])
  eq(type(target), 'table')
  eq(type(target.path), 'string')

  local replacement = target.old .. ' [edited-by-meta] meta'
  child.lua(string.format([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local buf = s.meta.buf.buffer
      vim.api.nvim_buf_set_lines(buf, 0, 1, false, { %q })
    end)()
  ]], replacement))

  child.cmd('write')

  local file_line = child.lua_get(string.format([[
    (function()
      local lines = vim.fn.readfile(%q)
      return lines[%d] or ''
    end)()
  ]], target.path, target.lnum))
  eq(file_line, replacement)
  H.wait_for(function() return H.session_preview_contains('[edited-by-meta]') end, 3000)

  child.type_keys('gg')
  child.type_keys('o')
  child.type_keys('inserted-from-meta')
  child.type_keys('<Esc>')
  child.cmd('write')
  local inserted = child.lua_get(string.format([[
    (function()
      local lines = vim.fn.readfile(%q)
      return lines[%d] or ''
    end)()
  ]], target.path, target.lnum + 1))
  eq(inserted, 'inserted-from-meta')

  child.cmd('Meta')
  H.wait_for(function() return H.session_active() end, 3000)
  H.wait_for(function() return H.session_prompt_text() == 'meta' end, 3000)
end)

return T
