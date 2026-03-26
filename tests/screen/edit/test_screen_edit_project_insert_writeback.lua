local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

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
    vim.fn.readfile(%q)
  ]], root .. '/doc/readme.md')), {
    'meta docs',
    'metam docs',
    'other',
    'insert-after-other',
  })
end)

return T
