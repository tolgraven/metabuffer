local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['project hit buffer and info window stay in sync while typing and deleting'] = H.timed_case(function()
  local root = H.make_temp_project()
  H.open_project_meta_in_dir(root, 'main.txt')

  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)
  H.type_prompt_human('meta', 25)
  H.wait_for(function() return H.session_query_text() == 'meta' end, 6000)

  H.type_prompt('<C-n>')
  H.type_prompt('<C-n>')

  local ref = H.session_selected_ref()
  local snap = H.session_info_snapshot()
  eq(type(ref), 'table')
  eq(type(snap), 'table')
  eq(snap.count > 0, true)
  eq(H.str_contains(snap.line, vim.fn.fnamemodify(ref.path, ':t')), true)
  eq(H.str_contains(snap.line, tostring(ref.lnum)), true)

  local narrowed_hits = H.session_hit_count()
  H.type_prompt_tokens({ '<BS>', '<BS>' }, 110)
  H.wait_for(function() return H.session_query_text() == 'me' end, 6000)
  H.wait_for(function() return H.session_hit_count() >= narrowed_hits end, 6000)

  local ref2 = H.session_selected_ref()
  local snap2 = H.session_info_snapshot()
  eq(type(ref2), 'table')
  eq(type(snap2), 'table')
  eq(H.str_contains(snap2.line, vim.fn.fnamemodify(ref2.path, ':t')), true)
  eq(H.str_contains(snap2.line, tostring(ref2.lnum)), true)
end)

T['project info refreshes after scrolling and then filtering'] = H.timed_case(function()
  local root = H.make_temp_project()
  H.open_project_meta_in_dir(root, 'main.txt')

  H.wait_for(function() return H.session_hit_count() > 20 end, 6000)
  H.scroll_main_and_wait('page-down', 4000)

  local before = H.session_info_snapshot()
  eq(type(before), 'table')
  eq(before.line ~= '', true)

  H.type_prompt_human('meta', 25)
  H.wait_for(function() return H.session_query_text() == 'meta' end, 6000)
  H.wait_for(function()
    local ref = H.session_selected_ref()
    local snap = H.session_info_snapshot()
    return type(ref) == 'table'
      and type(snap) == 'table'
      and H.str_contains(snap.line, vim.fn.fnamemodify(ref.path, ':t'))
      and H.str_contains(snap.line, tostring(ref.lnum))
  end, 6000)

  local ref = H.session_selected_ref()
  local snap = H.session_info_snapshot()
  eq(H.str_contains(snap.line, vim.fn.fnamemodify(ref.path, ':t')), true)
  eq(H.str_contains(snap.line, tostring(ref.lnum)), true)
end)

return T
