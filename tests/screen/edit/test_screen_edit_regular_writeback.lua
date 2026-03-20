local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

local function enter_results_edit_mode()
  child.lua([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      assert(s and s['prompt-buf'], 'missing metabuffer session')
      router['enter-edit-mode'](s['prompt-buf'])
    end)()
  ]])
end

T['contiguous plain-meta edits patch the real file region in place'] = H.timed_case(function()
  local path = child.lua_get([[
    (function()
      local path = vim.fn.tempname() .. '.txt'
      vim.fn.writefile({ 'alpha', 'beta', 'gamma' }, path)
      return path
    end)()
  ]])

  child.cmd('edit ' .. path)
  child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
  child.type_keys(':', 'Meta', '<CR>')
  H.wait_for(function()
    return H.session_active()
  end, 3000)

  child.cmd('stopinsert')
  enter_results_edit_mode()
  child.type_keys('g', 'g')
  child.type_keys('o')
  child.type_keys('insert-after-alpha')
  child.type_keys('<Esc>')
  child.cmd('write')

  eq(child.lua_get(string.format([[
    return vim.fn.readfile(%q)
  ]], path)), { 'alpha', 'insert-after-alpha', 'beta', 'gamma' })
end)

T['filtered regular-meta direct edits still write back to the source file'] = H.timed_case(function()
  local path = child.lua_get([[
    (function()
      local path = vim.fn.tempname() .. '.txt'
      vim.fn.writefile({
        'alpha one',
        'alpha two',
        'beta target',
        'gamma four',
      }, path)
      return path
    end)()
  ]])

  child.cmd('edit ' .. path)
  child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
  child.type_keys(':', 'Meta', '<CR>')
  H.wait_for(function() return H.session_active() end, 3000)

  H.type_prompt_text('beta')
  H.wait_for(function() return H.session_hit_count() == 1 end, 3000)
  H.type_prompt('<M-CR>')
  H.wait_for(function()
    return child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        if not s then return false end
        return vim.api.nvim_get_current_win() == s.meta.win.window
      end)()
    ]])
  end, 3000)

  child.type_keys('c', 'c')
  child.type_keys('beta changed')
  child.type_keys('<Esc>')
  child.cmd('write')

  eq(child.lua_get(string.format([[
    return vim.fn.readfile(%q)
  ]], path)), {
    'alpha one',
    'alpha two',
    'beta changed',
    'gamma four',
  })
end)

T['filtered regular-meta direct inserts write back to the source file'] = H.timed_case(function()
  local path = child.lua_get([[
    (function()
      local path = vim.fn.tempname() .. '.txt'
      vim.fn.writefile({
        'alpha one',
        'alpha two',
        'beta target',
        'gamma four',
      }, path)
      return path
    end)()
  ]])

  child.cmd('edit ' .. path)
  child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
  child.type_keys(':', 'Meta', '<CR>')
  H.wait_for(function() return H.session_active() end, 3000)

  H.type_prompt_text('beta')
  H.wait_for(function() return H.session_hit_count() == 1 end, 3000)
  H.type_prompt('<M-CR>')
  H.wait_for(function()
    return child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        if not s then return false end
        return vim.api.nvim_get_current_win() == s.meta.win.window
      end)()
    ]])
  end, 3000)

  child.type_keys('o')
  child.type_keys('beta inserted')
  child.type_keys('<Esc>')
  child.cmd('write')

  eq(child.lua_get(string.format([[
    return vim.fn.readfile(%q)
  ]], path)), {
    'alpha one',
    'alpha two',
    'beta target',
    'beta inserted',
    'gamma four',
  })
end)

T['filtered project-meta direct inserts write back without explicit edit-mode entry'] = H.timed_case(function()
  local root = H.make_temp_project()

  H.open_project_meta_in_dir(root, 'main.txt')
  H.type_prompt_text('other')
  H.wait_for(function()
    return H.session_hit_count() == 1
  end, 6000)
  H.type_prompt('<M-CR>')
  H.wait_for(function()
    return child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        if not s then return false end
        return vim.api.nvim_get_current_win() == s.meta.win.window
      end)()
    ]])
  end, 3000)

  child.type_keys('o')
  child.type_keys('insert-after-other')
  child.type_keys('<Esc>')
  child.cmd('write')

  eq(child.lua_get(string.format([[
    return vim.fn.readfile(%q)
  ]], root .. '/doc/readme.md')), {
    'meta docs',
    'metam docs',
    'other',
    'insert-after-other',
  })
end)

return T
