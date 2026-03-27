local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['project lazy streaming renders incremental content before stream completion'] = H.timed_case(function()
  H.child.lua([[
    require('metabuffer').setup({
      options = {
        project_lazy_enabled = true,
        project_lazy_min_estimated_lines = 0,
        project_lazy_chunk_size = 1,
        project_lazy_frame_budget_ms = 1,
      },
    })
  ]])

  H.open_project_meta_from_file('README.md')

  local initial_hits = H.session_hit_count()
  local initial_view = H.session_main_view()
  local initial_cursor = H.session_main_cursor()
  local initial_lnum = (initial_view and initial_view.lnum) or 0
  local initial_topline = (initial_view and initial_view.topline) or 0
  local initial_cursor_row = (initial_cursor and initial_cursor[1]) or 0

  H.wait_for(function()
    return H.child.lua_get(string.format([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        if not s then
          return false
        end
        local hits = #(s.meta.buf.indices or {})
        local done = s['lazy-stream-done'] == true
        return (not done) and (hits > %d)
      end)()
    ]], initial_hits))
  end, 6000)

  local streamed_hits = H.session_hit_count()
  eq(streamed_hits > initial_hits, true)

  local streamed_view = H.session_main_view()
  local streamed_cursor = H.session_main_cursor()
  local streamed_lnum = (streamed_view and streamed_view.lnum) or 0
  local streamed_topline = (streamed_view and streamed_view.topline) or 0
  local streamed_cursor_row = (streamed_cursor and streamed_cursor[1]) or 0
  eq(streamed_lnum, initial_lnum)
  eq(streamed_topline, initial_topline)
  eq(streamed_cursor_row, initial_cursor_row)

  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        return s and s['lazy-stream-done'] == true or false
      end)()
    ]])
  end, 6000)
end)

return T
