local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

local function parse_loading_files(winbar)
  local stripped = (winbar or ''):gsub('%%#[^#]+#', ''):gsub('%%=', '')
  local done, total = stripped:match('loading%s+(%d+)/(%d+)%s+files')
  return tonumber(done or ''), tonumber(total or '')
end

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

T['project loading keeps visible info rows real while winbar shows progress'] = H.timed_case(function()
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

  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        return s
          and s['lazy-stream-done'] ~= true
          and #(s.meta.buf.indices or {}) > 0
          and true or false
      end)()
    ]])
  end, 6000)

  H.scroll_main_and_wait('page-down', 4000)

  H.wait_for(function()
    local snap = H.session_info_snapshot()
    local winbar = H.session_info_winbar()
    local info_view = H.session_info_view()
    local main_view = H.session_main_view()
    local line = snap and snap.line or ''
    local skeleton = line == '.... ... ......'
      or line == '..... .... .....'
      or line == '... ..... ......'
      or line == '.... ...... ....'
    return type(snap) == 'table'
      and type(winbar) == 'string'
      and winbar ~= ''
      and skeleton == false
      and type(info_view) == 'table'
      and type(main_view) == 'table'
      and info_view.topline == main_view.topline
  end, 6000)
end)

T['project page scroll does not restart lazy stream progress'] = H.timed_case(function()
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

  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        return s
          and s['lazy-stream-done'] ~= true
          and (s['lazy-stream-next'] or 0) > 3
          and true or false
      end)()
    ]])
  end, 6000)

  local before_done, before_total = parse_loading_files(H.session_info_winbar())
  local before = H.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return { next = -1, token = -1, stream_id = -1, hits = -1 } end
      return {
        next = s['lazy-stream-next'] or 0,
        token = s['project-bootstrap-token'] or 0,
        stream_id = s['lazy-stream-id'] or 0,
        hits = #(s.meta.buf.indices or {}),
      }
    end)()
  ]])

  H.scroll_main_and_wait('page-down', 4000)
  H.child.lua('vim.wait(120)')

  local after = H.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return { next = -1, token = -1, stream_id = -1, hits = -1 } end
      return {
        next = s['lazy-stream-next'] or 0,
        token = s['project-bootstrap-token'] or 0,
        stream_id = s['lazy-stream-id'] or 0,
        hits = #(s.meta.buf.indices or {}),
      }
    end)()
  ]])

  eq(after.token, before.token)
  eq(after.stream_id, before.stream_id)
  eq(after.next >= before.next, true)
  eq(after.hits >= before.hits, true)
  if before_done and before_total then
    local after_done, after_total = parse_loading_files(H.session_info_winbar())
    eq(after_total, before_total)
    eq((after_done or -1) >= before_done, true)
  end
end)

return T
