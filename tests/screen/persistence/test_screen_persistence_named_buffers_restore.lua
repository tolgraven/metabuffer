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

T['accept and resume do not accumulate unnamed split buffers'] = H.timed_case(function()
  H.open_meta_with_lines({
    'alpha one',
    'alpha two',
    'beta three',
  })

  H.type_prompt('<CR>')
  H.wait_for(H.session_ui_hidden, 3000)

  H.child.cmd('normal! <C-o>')
  H.wait_for(function() return not H.session_ui_hidden() end, 3000)

  local state = H.child.lua_get([[
    (function()
      local listed = vim.fn.getbufinfo({ buflisted = 1 })
      local unnamed = {}
      local current = vim.api.nvim_get_current_buf()
      local wins = #vim.api.nvim_list_wins()
      for _, info in ipairs(listed) do
        if (info.name or '') == '' then
          unnamed[#unnamed + 1] = info.bufnr
        end
      end
      return {
        unnamed = unnamed,
        current_name = vim.api.nvim_buf_get_name(current),
        wins = wins,
      }
    end)()
  ]])

  eq(type(state), 'table')
  eq(#state.unnamed, 0)
  eq(type(state.current_name), 'string')
  eq(state.current_name ~= '', true)
  eq(state.wins >= 1, true)
end)

T['plain Meta then Esc does not leave unnamed listed buffers behind'] = H.timed_case(function()
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

  child.lua([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      assert(s and s['prompt-buf'], 'missing prompt buffer')
      router.cancel(s['prompt-buf'])
    end)()
  ]])
  H.wait_for(function()
    return H.current_buf_is_source()
  end, 3000)

  local unnamed = unnamed_buffers()
  eq(type(unnamed), 'table')
  eq(#unnamed, 0)
end)

return T
