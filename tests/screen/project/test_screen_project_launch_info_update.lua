local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['info window updates automatically when typing in prompt during project mode'] = H.timed_case(function()
  -- Use a project where scanning completes quickly
  local root = H.make_temp_project()
  H.child.cmd("cd " .. root)
  H.child.cmd("edit " .. root .. "/main.txt")
  H.set_source_buf_to_current()
  
  -- Start project mode
  H.child.type_keys(":", "Meta!", "<CR>")
  
  -- Wait for scanning to finish and info window to show something (initial state)
  H.wait_for(function()
    local snap = H.session_info_snapshot()
    local winbar = H.session_info_winbar()
    return snap and snap.line ~= '' and H.str_contains(snap.line, "main.txt") and type(winbar) == 'string' and winbar ~= ''
  end, 5000)

  local initial_snap = H.session_info_snapshot()
  local initial_winbar = H.session_info_winbar()
  eq(initial_snap.count > 0, true, "Info window should contain rendered lines immediately after :Meta! launch")
  eq(initial_snap.line ~= '', true, "Info window should not stay empty until a later resize")
  eq(type(initial_winbar), 'string', "Info window winbar should be populated during project startup")
  eq(initial_winbar ~= '', true, "Info window winbar should expose startup/loading state")

  H.wait_for(function()
    local snap = H.session_info_snapshot()
    return snap and snap.count > 0 and snap.line ~= '' and not H.str_contains(snap.line, 'bootstrapping')
  end, 5000)

  local settled_snap = H.session_info_snapshot()
  eq(settled_snap.count > 0, true, "Info window should still be populated after project loading finishes")
  eq(settled_snap.line ~= '', true, "Info window should not go blank after the loading phase")

  -- Now type a query that filters the list. 
  -- We expect info window to update its content.
  -- In this fixture, 'lua/mod.lua' has 'metabuffer'
  H.type_prompt_human('metabuffer', 50)
  
  -- Wait for query to be applied
  H.wait_for(function() return H.session_query_text() == 'metabuffer' end, 2000)
  
  -- Wait for hits to update
  H.wait_for(function() return H.session_hit_count() > 0 end, 2000)

  -- Wait for info window to change from initial state
  H.wait_for(function()
    local snap = H.session_info_snapshot()
    return snap and snap.line ~= initial_snap.line
  end, 2000)

  -- Check if info window correctly shows 'mod.lua' (since it should be the top hit for 'metabuffer')
  local snap = H.session_info_snapshot()
  eq(H.str_contains(snap.line, "mod.lua"), true, "Info window should update to show mod.lua after typing query")
end)

return T
