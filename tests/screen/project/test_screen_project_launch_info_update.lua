local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

local function strip_statusline(s)
  return (s or ''):gsub('%%#[^#]+#', ''):gsub('%%=', '')
end

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
    local still_loading = H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        return not not (s and s['info-project-loading-active?'])
      end)()
    ]])
    return snap
      and snap.line ~= ''
      and H.str_contains(snap.line, "main.txt")
      and ((type(winbar) == 'string' and winbar ~= '') or not still_loading)
  end, 5000)

  local initial_snap = H.session_info_snapshot()
  local initial_winbar = H.session_info_winbar()
  local initial_info_view = H.session_info_view()
  eq(initial_snap.count > 0, true, "Info window should contain rendered lines immediately after :Meta! launch")
  eq(initial_snap.line ~= '', true, "Info window should not stay empty until a later resize")
  eq(type(initial_winbar), 'string', "Info window winbar should be populated during project startup")

  H.wait_for(function()
    local snap = H.session_info_snapshot()
    return snap and snap.count > 0 and snap.line ~= '' and not H.str_contains(snap.line, 'bootstrapping')
  end, 5000)
  H.wait_for(function()
    return H.session_info_winbar() == ''
  end, 5000)

  local settled_snap = H.session_info_snapshot()
  local settled_winbar = H.session_info_winbar()
  local settled_info_view = H.session_info_view()
  eq(settled_snap.count > 0, true, "Info window should still be populated after project loading finishes")
  eq(settled_snap.line ~= '', true, "Info window should not go blank after the loading phase")
  eq(settled_winbar, '', "Info window winbar should clear after project loading finishes")
  if initial_winbar ~= '' and initial_info_view and settled_info_view then
    eq(initial_info_view.topline, settled_info_view.topline)
    eq(initial_info_view.selected_row, settled_info_view.selected_row)
  end

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

T['project loading animates the main statusline pulse while bootstrap is pending'] = H.timed_case(function()
  local root = H.make_temp_project()
  H.child.lua([[
    require('metabuffer').setup({
      project_bootstrap_delay_ms = 300,
      project_bootstrap_idle_delay_ms = 300,
      ui = {
        animation = {
          enabled = true,
          loading_indicator = true,
          backend = 'mini',
        },
      },
    })
  ]])
  H.child.cmd("cd " .. root)
  H.child.cmd("edit " .. root .. "/main.txt")
  H.set_source_buf_to_current()
  H.child.type_keys(':', 'Meta!', '<CR>')

  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        return not not (s
          and s['project-bootstrap-pending']
          and s['loading-anim-phase'] ~= nil
          and s['results-statusline-pulse-active?'])
      end)()
    ]])
  end, 6000)

  eq(H.str_contains(strip_statusline(H.session_main_statusline()), 'Working'), true)

  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        return not not (s and s['project-bootstrapped'] and s['lazy-stream-done'])
      end)()
    ]])
  end, 6000)

  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        return not not (s and s['loading-anim-phase'] == nil and not s['results-statusline-pulse-active?'])
      end)()
    ]])
  end, 6000)
end)

return T
