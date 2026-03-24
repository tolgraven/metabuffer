local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['project info window repopulates after deleting prompt back to empty'] = H.timed_case(function()
  local root = H.make_temp_project()
  H.open_project_meta_in_dir(root, 'main.txt')

  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)
  H.wait_for(function()
    local snap = H.session_info_snapshot()
    return snap and snap.line ~= ''
  end, 6000)

  H.type_prompt_human('metabuffer', 25)
  H.wait_for(function() return H.session_query_text() == 'metabuffer' end, 6000)
  H.wait_for(function()
    local snap = H.session_info_snapshot()
    return snap and snap.line ~= ''
  end, 6000)

  H.type_prompt_tokens({ '<BS>', '<BS>', '<BS>', '<BS>', '<BS>', '<BS>', '<BS>', '<BS>', '<BS>', '<BS>' }, 50)
  H.wait_for(function() return H.session_query_text() == '' end, 6000)
  H.wait_for(function()
    local snap = H.session_info_snapshot()
    return snap and snap.count > 0 and snap.line ~= ''
  end, 6000)

  local ref = H.session_selected_ref()
  local snap = H.session_info_snapshot()
  eq(type(ref), 'table')
  eq(type(snap), 'table')
  eq(H.str_contains(snap.line, vim.fn.fnamemodify(ref.path, ':t')), true)
  eq(H.str_contains(snap.line, tostring(ref.lnum)), true)
end)

return T
