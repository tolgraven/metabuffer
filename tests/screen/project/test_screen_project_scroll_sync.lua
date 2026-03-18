local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['project scroll keeps results cursor, info window, and selection in sync'] = H.timed_case(function()
  local root = H.make_temp_project()
  H.open_project_meta_in_dir(root, 'main.txt')

  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)
  H.type_prompt_human('meta', 20)
  H.wait_for(function() return H.session_query_text() == 'meta' end, 6000)

  H.scroll_main_and_wait('page-down', 4000)

  local cursor = H.session_main_cursor()
  local ref = H.session_selected_ref()
  local snap = H.session_info_snapshot()

  eq(type(cursor), 'table')
  eq(type(ref), 'table')
  eq(type(snap), 'table')
  eq(ref.lnum, cursor[1])
  eq(H.str_contains(snap.line, vim.fn.fnamemodify(ref.path, ':t')), true)
  eq(H.str_contains(snap.line, tostring(ref.lnum)), true)
end)

return T
