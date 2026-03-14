local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['fennel fn expansion widens to containing fn_form'] = H.timed_case(function()
  local root = H.child.lua_get([[
    (function()
      local root = vim.fn.tempname()
      vim.fn.mkdir(root, 'p')
      vim.fn.writefile({
        '(local M {})',
        '',
        '(fn preview-window',
        '  [x]',
        '  (let [y (+ x 1)]',
        '    y))',
        '',
        'M',
      }, root .. '/probe.fnl')
      return root
    end)()
  ]])

  H.open_project_meta_in_dir(root, 'probe.fnl')
  H.type_prompt_text('preview-window #exp:fn')
  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        return s and s['expansion-mode'] == 'fn'
      end)()
    ]])
  end, 4000)
  H.wait_for(function() return H.session_hit_count() >= 4 end, 4000)

  local lines = H.session_result_lines()
  eq(vim.tbl_contains(lines, '(fn preview-window'), true)
  eq(vim.tbl_contains(lines, '  [x]'), true)
  eq(vim.tbl_contains(lines, '  (let [y (+ x 1)]'), true)
  eq(vim.tbl_contains(lines, '    y))'), true)
end)

return T
