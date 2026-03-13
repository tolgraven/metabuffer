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

  H.wait_for(function()
    return type(H.session_info_snapshot()) == 'table'
  end, 3000)
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

  child.lua(string.format([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local buf = s.meta.buf.buffer
      vim.api.nvim_buf_set_lines(buf, 0, 1, false, { %q })
    end)()
  ]], target.old))
  child.cmd('write')
  local reverted = child.lua_get(string.format([[
    (function()
      local lines = vim.fn.readfile(%q)
      return lines[%d] or ''
    end)()
  ]], target.path, target.lnum))
  eq(reverted, target.old)

  child.type_keys('gg')
  child.type_keys('o')
  child.type_keys('inserted-from-meta')
  child.type_keys('<Esc>')
  H.wait_for(function()
    return child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        if not s or not s['info-buf'] or not vim.api.nvim_buf_is_valid(s['info-buf']) then return false end
        local lines = vim.api.nvim_buf_get_lines(s['info-buf'], 0, -1, false)
        for _, line in ipairs(lines) do
          if string.find(line or '', 'inserted%-from%-meta') then
            return true
          end
        end
        return false
      end)()
    ]])
  end, 3000)
  child.cmd('write')
  local inserted = child.lua_get(string.format([[
    (function()
      local lines = vim.fn.readfile(%q)
      return lines[%d] or ''
    end)()
  ]], target.path, target.lnum + 1))
  eq(inserted, 'inserted-from-meta')

  local above_target = child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local meta = s and s.meta or nil
      if not meta then return nil end
      local idxs = meta.buf.indices or {}
      local refs = meta.buf['source-refs'] or {}
      for row, src_idx in ipairs(idxs) do
        local ref = refs[src_idx]
        if ref and (ref.path or '') ~= '' and (ref.lnum or 0) > 1 then
          return { row = row, path = ref.path, lnum = ref.lnum }
        end
      end
      return nil
    end)()
  ]])
  eq(type(above_target), 'table')
  child.lua(string.format([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local win = s and s.meta and s.meta.win and s.meta.win.window
      if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_set_current_win(win)
        vim.api.nvim_win_set_cursor(win, { %d, 0 })
      end
    end)()
  ]], above_target.row))
  child.type_keys('O')
  child.type_keys('inserted-above-hit')
  child.type_keys('<Esc>')
  child.cmd('write')
  local inserted_above = child.lua_get(string.format([[
    (function()
      local lines = vim.fn.readfile(%q)
      return lines[%d] or ''
    end)()
  ]], above_target.path, above_target.lnum))
  eq(inserted_above, 'inserted-above-hit')

  child.cmd('Meta')
  H.wait_for(function() return H.session_active() end, 3000)
  H.wait_for(function() return H.session_prompt_text() == 'meta' end, 3000)
end)

return T
