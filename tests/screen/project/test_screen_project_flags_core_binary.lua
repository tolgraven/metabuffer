local H = require('tests.screen.support.screen_helpers')
local eq = H.eq
local T = MiniTest.new_set({ hooks = H.shared_child_hooks() })

T['binary and hex flags stay visible in prompt and toggle state'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_text('#binary #hex metabuffer.png')
  H.wait_for(function() return H.session_prompt_text() == '#binary #hex metabuffer.png' end, 6000)

  H.wait_for(function()
    local dbg = H.session_debug_out()
    return H.str_contains(dbg, '+bin') and H.str_contains(dbg, '+hex')
  end, 6000)

  H.wait_for(function()
    local lines = H.session_result_lines()
    return type(lines) == 'table'
      and lines[1] == 'binary 1 KB'
      and H.str_contains(lines[2] or '', '89 50 4E 47')
      and H.str_contains(lines[2] or '', '.PNG')
  end, 6000)
end)

T['binary strings transform extracts printable chunks from binary files'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_text('#binary #strings metabuffer.png')
  H.wait_for(function() return H.session_prompt_text() == '#binary #strings metabuffer.png' end, 6000)

  H.wait_for(function()
    local lines = H.session_result_lines()
    return type(lines) == 'table'
      and lines[1] == 'binary 1 KB'
      and H.str_contains(lines[2] or '', 'IHDR')
      and H.str_contains(lines[2] or '', 'IDAT')
      and H.str_contains(lines[2] or '', 'IEND')
  end, 6000)

  eq(H.session_hit_count() > 0, true)
end)

return T
