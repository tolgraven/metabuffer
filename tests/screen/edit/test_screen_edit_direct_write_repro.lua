local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['focused results insert writes persists through accept and jump traversal'] = H.timed_case(function()
  H.configure_animation({
    ui = {
      animation = {
        enabled = true,
        loading_indicator = true,
      },
    },
  })

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
  H.wait_for(function() return H.session_active() end, 4000)
  H.dump_state('after open')

  H.type_prompt_text('beta')
  H.wait_for(function() return H.session_hit_count() == 1 end, 4000)
  H.dump_state('after filter')
  H.type_prompt('<M-CR>')
  H.wait_for(function()
    return child.lua_get([[
      local s = require('metabuffer.router')['active-by-source'][_G.__meta_source_buf]
      return s and s.meta and s.meta.win and vim.api.nvim_get_current_win() == s.meta.win.window or false
    ]])
  end, 4000)
  H.dump_state('after focus results')

  child.type_keys('o')
  child.type_keys('beta inserted')
  child.type_keys('<Esc>')
  H.dump_state('after insert')
  child.cmd('write')
  H.dump_state('after write')

  eq(child.lua_get(string.format([[
    vim.fn.readfile(%q)
  ]], path)), {
    'alpha one',
    'alpha two',
    'beta target',
    'beta inserted',
    'gamma four',
  })

  child.type_keys('j')
  child.type_keys('<CR>')
  H.dump_state('after accept')
  H.wait_for(function()
    return child.lua_get(string.format([[
      vim.api.nvim_buf_get_name(0) == %q and vim.fn.line('.') == 4
    ]], path))
  end, 4000)

  child.cmd('normal! <C-o>')
  H.dump_state('after first C-o')
  H.wait_for(function() return H.session_active() end, 4000)
  H.wait_for(function() return not H.session_ui_hidden() end, 4000)

  child.cmd('normal! <C-o>')
  H.dump_state('after second C-o')
  H.wait_for(function()
    return child.lua_get(string.format('vim.api.nvim_buf_get_name(0) == %q', path))
  end, 4000)

  child.cmd('normal! <C-i>')
  H.dump_state('after C-i')
  H.wait_for(function() return H.session_active() end, 4000)
  H.wait_for(function() return not H.session_ui_hidden() end, 4000)

  eq(child.lua_get(string.format([[
    vim.fn.readfile(%q)
  ]], path)), {
    'alpha one',
    'alpha two',
    'beta target',
    'beta inserted',
    'gamma four',
  })
end)

return T
