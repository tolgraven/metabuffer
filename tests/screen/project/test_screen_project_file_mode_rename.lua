local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['file-entry write renames file on straight line replacement'] = H.timed_case(function()
  local root = H.make_temp_project()
  H.open_project_meta_in_dir(root, 'main.txt')

  H.type_prompt_text('#file README.md')
  H.wait_for(function() return H.session_file_entry_hit_count() > 0 end, 6000)

  child.cmd('stopinsert')
  child.lua(string.format([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local buf = s.meta.buf.buffer
      local win = s.meta.win.window
      vim.api.nvim_set_current_win(win)
      vim.api.nvim_buf_set_lines(buf, 0, 1, false, { %q })
    end)()
  ]], 'doc/README-renamed.md'))

  child.cmd('write')

  eq(child.lua_get(string.format([[
    return vim.fn.filereadable(%q)
  ]], root .. '/README.md')), 0)
  eq(child.lua_get(string.format([[
    return vim.fn.filereadable(%q)
  ]], root .. '/doc/README-renamed.md')), 1)
end)

return T
