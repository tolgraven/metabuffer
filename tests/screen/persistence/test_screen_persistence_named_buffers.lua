local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['Meta-owned buffers have stable names instead of [No Name]'] = H.timed_case(function()
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
  child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
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

T['accept and resume do not accumulate unnamed split buffers'] = H.timed_case(function()
  H.open_meta_with_lines({
    'alpha one',
    'alpha two',
    'beta three',
  })

  H.type_prompt('<CR>')
  H.wait_for(function()
    return H.session_ui_hidden()
  end, 3000)

  H.child.cmd('normal! <C-o>')
  H.wait_for(function()
    return not H.session_ui_hidden()
  end, 3000)

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

T['preview split creation does not leave unnamed listed buffers behind'] = H.timed_case(function()
  local path = child.lua_get([[
    (function()
      local path = vim.fn.tempname() .. '.lua'
      vim.fn.writefile({
        'local alpha = 1',
        'local beta = 2',
        'print(alpha + beta)',
      }, path)
      return path
    end)()
  ]])

  child.cmd('edit ' .. path)
  child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
  child.type_keys(':', 'Meta', '<CR>')

  H.wait_for(function()
    return H.session_active() and H.session_preview_visible()
  end, 3000)

  local unnamed = child.lua_get([[
    (function()
      local listed = vim.fn.getbufinfo({ buflisted = 1 })
      local out = {}
      for _, info in ipairs(listed) do
        if (info.name or '') == '' then
          out[#out + 1] = info.bufnr
        end
      end
      return out
    end)()
  ]])

  eq(type(unnamed), 'table')
  eq(#unnamed, 0)
end)

T['plain Meta then Esc does not leave unnamed listed buffers behind'] = H.timed_case(function()
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
  child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
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
    return child.lua_get('vim.api.nvim_get_current_buf() == _G.__meta_source_buf')
  end, 3000)

  local unnamed = child.lua_get([[
    (function()
      local listed = vim.fn.getbufinfo({ buflisted = 1 })
      local out = {}
      for _, info in ipairs(listed) do
        if (info.name or '') == '' then
          out[#out + 1] = info.bufnr
        end
      end
      return out
    end)()
  ]])

  eq(type(unnamed), 'table')
  eq(#unnamed, 0)
end)

return T
