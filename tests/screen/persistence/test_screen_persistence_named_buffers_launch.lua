local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.shared_child_hooks() })

local function unnamed_buffers()
  return child.lua_get([[
    (function()
      local all = vim.fn.getbufinfo()
      local out = {}
      for _, info in ipairs(all) do
        if (info.name or '') == '' then
          out[#out + 1] = {
            bufnr = info.bufnr,
            listed = info.listed == 1,
            loaded = info.loaded == 1,
            hidden = info.hidden == 1,
            windows = vim.tbl_map(function(win) return win end, info.windows or {}),
          }
        end
      end
      return out
    end)()
  ]])
end

T['Meta-owned buffers have stable names instead of [No Name]'] = H.timed_case(function()
  local path = H.write_temp_file({
    'alpha one',
    'beta two',
    'gamma three',
  }, '.txt')

  child.cmd('edit ' .. path)
  H.set_source_buf_to_current()
  child.type_keys(':', 'Meta', '<CR>')
  H.wait_for(function()
    return H.session_active() and H.session_preview_visible() and H.session_info_snapshot() ~= nil
  end, 3000)

  local names = child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return nil end
      local bufs = {
        s.meta and s.meta.buf and s.meta.buf.buffer or nil,
        s['prompt-buf'],
        s['preview-buf'],
        s['info-buf'],
      }
      local out = {}
      for _, buf in ipairs(bufs) do
        if buf and vim.api.nvim_buf_is_valid(buf) then
          out[#out + 1] = vim.api.nvim_buf_get_name(buf)
        end
      end
      return out
    end)()
  ]])

  eq(type(names), 'table')
  for _, name in ipairs(names) do
    eq(type(name), 'string')
    eq(name ~= '', true)
  end
end)

T['preview split creation does not leave unnamed listed buffers behind'] = H.timed_case(function()
  local path = H.write_temp_file({
    'local alpha = 1',
    'local beta = 2',
    'print(alpha + beta)',
  }, '.lua')

  child.cmd('edit ' .. path)
  H.set_source_buf_to_current()
  child.type_keys(':', 'Meta', '<CR>')
  H.wait_for(function()
    return H.session_active() and H.session_preview_visible()
  end, 3000)

  local unnamed = unnamed_buffers()
  eq(type(unnamed), 'table')
  eq(#unnamed, 0)
end)

return T
