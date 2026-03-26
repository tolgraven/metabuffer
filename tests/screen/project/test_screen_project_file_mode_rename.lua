local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.shared_child_hooks() })

local function focus_results_window()
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
end

T['project file-entry write renames file on straight line replacement'] = H.timed_case(function()
  local root = H.make_temp_project()
  H.open_project_meta_in_dir(root, 'main.txt')

  H.type_prompt_text('#file README.md')
  H.wait_for(function() return H.session_file_entry_hit_count() > 0 end, 6000)

  focus_results_window()
  child.type_keys('c', 'c')
  child.type_keys('doc/README-renamed.md')
  child.type_keys('<Esc>')
  child.cmd('write')

  eq(child.lua_get(string.format([[
    return vim.fn.filereadable(%q)
  ]], root .. '/README.md')), 0)
  eq(child.lua_get(string.format([[
    return vim.fn.filereadable(%q)
  ]], root .. '/doc/README-renamed.md')), 1)
end)

T['regular Meta file-entry write renames file on straight line replacement'] = H.timed_case(function()
  local root = H.make_temp_project()
  child.cmd('edit ' .. root .. '/main.txt')
  child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
  child.type_keys(':', 'Meta', '<CR>')
  H.wait_for(H.session_active, 3000)

  H.type_prompt_text('#file README.md')
  H.wait_for(function() return H.session_file_entry_hit_count() > 0 end, 6000)

  focus_results_window()
  child.type_keys('c', 'c')
  child.type_keys('doc/README-renamed-regular.md')
  child.type_keys('<Esc>')
  child.cmd('write')

  eq(child.lua_get(string.format([[
    return vim.fn.filereadable(%q)
  ]], root .. '/README.md')), 0)
  eq(child.lua_get(string.format([[
    return vim.fn.filereadable(%q)
  ]], root .. '/doc/README-renamed-regular.md')), 1)
end)

return T
