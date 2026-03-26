local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

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

T['repeated Meta launch does not accumulate hidden unnamed buffers'] = H.timed_case(function()
  local path = child.lua_get([[
    (function()
      local path = vim.fn.tempname() .. '.txt'
      vim.fn.writefile({
        'alpha one',
        'beta two',
        'gamma three',
      }, path)
      return path
    end)()
  ]])

  child.cmd('edit ' .. path)

  for _ = 1, 3 do
    child.type_keys(':', 'Meta', '<CR>')
    H.wait_for(function()
      return H.session_active() and H.session_preview_visible() and H.session_info_snapshot() ~= nil
    end, 3000)
    child.type_keys('<Esc>')
    H.wait_for(H.session_ui_hidden, 3000)
  end

  local unnamed = unnamed_buffers()
  eq(type(unnamed), 'table')
  eq(#unnamed, 0)
end)

return T
