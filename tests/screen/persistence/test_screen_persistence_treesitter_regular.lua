local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['regular Meta keeps Tree-sitter highlighting active when available'] = H.timed_case(function()
  local path = child.lua_get([[
    (function()
      local path = vim.fn.tempname() .. '.lua'
      vim.fn.writefile({
        'local function demo(x)',
        '  return x + 1',
        'end',
        '',
        'return demo(41)',
      }, path)
      return path
    end)()
  ]])

  child.cmd('edit ' .. path)
  child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')

  local ts_available = child.lua_get([[
    (function()
      if not vim.treesitter then return false end
      local ok = pcall(vim.treesitter.start, 0, 'lua')
      if not ok then return false end
      local active = vim.treesitter.highlighter and vim.treesitter.highlighter.active or {}
      return active[vim.api.nvim_get_current_buf()] ~= nil
    end)()
  ]])

  if not ts_available then
    return
  end

  child.type_keys(':', 'Meta', '<CR>')
  H.wait_for(function()
    return H.session_active()
  end, 3000)

  local state = child.lua_get([[
    (function()
      local s = require('metabuffer.router')['active-by-source'][_G.__meta_source_buf]
      if not (s and s.meta and s.meta.buf) then return nil end
      local buf = s.meta.buf.buffer
      local active = vim.treesitter.highlighter and vim.treesitter.highlighter.active or {}
      return {
        filetype = vim.bo[buf].filetype,
        syntax = vim.bo[buf].syntax,
        treesitter = active[buf] ~= nil,
      }
    end)()
  ]])

  eq(type(state), 'table')
  eq(state.filetype, 'lua')
  eq(state.treesitter, true)
end)

return T
