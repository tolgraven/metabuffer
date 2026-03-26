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
  H.wait_for(H.session_active, 3000)

  child.cmd('stopinsert')
  enter_results_edit_mode()
  child.type_keys('g', 'g')
  child.type_keys('o')
  child.type_keys('insert-after-alpha')
  child.type_keys('<Esc>')
  child.cmd('write')

  eq(child.lua_get(string.format([[
    vim.fn.readfile(%q)
  ]], path)), { 'alpha', 'insert-after-alpha', 'beta', 'gamma' })
end)

return T
