local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['project flags are consumed and reflected in debug/statusline'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')

  H.type_prompt_human('#hidden #deps #nolazy meta', 100)
  H.wait_for(function() return H.session_query_text() == 'meta' end, 6000)
  H.wait_for(function() return H.session_prompt_text() == 'meta' end, 6000)

  local dbg = H.session_debug_out()
  eq(H.str_contains(dbg, '+hid'), true)
  eq(H.str_contains(dbg, '+dep'), true)
  eq(H.str_contains(dbg, 'nlz'), true)

  local sl = H.session_statusline()
  eq(H.str_contains(sl, '+hid'), true)
  eq(H.str_contains(sl, '+dep'), true)
end)

T['file flag enables file-entry hits filtered by file token'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_human('#file README.md', 90)
  H.wait_for(function() return H.session_query_text() == '' end, 6000)
  H.wait_for(function() return H.session_file_entry_hit_count() > 0 end, 6000)
  local first_line = H.session_first_file_entry_line()
  eq(type(first_line), 'string')
  eq(string.sub(first_line, 1, 1) == '/', false)

  local dbg = H.session_debug_out()
  eq(H.str_contains(dbg, '+fil'), true)
end)

T['file shortcut token ./query enables file mode and applies file token'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_human('./README.md', 90)
  H.wait_for(function() return H.session_query_text() == '' end, 6000)
  H.wait_for(function() return H.session_file_entry_hit_count() > 0 end, 6000)
  local first_line = H.session_first_file_entry_line()
  eq(type(first_line), 'string')
  eq(string.find(string.lower(first_line), 'readme', 1, true) ~= nil, true)

  local dbg = H.session_debug_out()
  eq(H.str_contains(dbg, '+fil'), true)
end)

T['file flag token is separate from normal query terms on same line'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_human('#file README lua', 90)
  H.wait_for(function() return H.session_query_text() == 'lua' end, 6000)
  H.wait_for(function() return H.session_file_entry_hit_count() > 0 end, 6000)
end)

T['file token constrains regular hits to matching paths'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_human('local #file lua', 90)
  H.wait_for(function() return H.session_query_text() == 'local' end, 6000)
  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        if not s then return false end
        local idxs = s.meta.buf.indices or {}
        local refs = s.meta.buf['source-refs'] or {}
        local has_non_file = false
        for _, src_idx in ipairs(idxs) do
          local ref = refs[src_idx]
          if ref and ref.kind ~= 'file-entry' then
            has_non_file = true
            local path = (ref.path or '')
            if not string.find(path:lower(), 'lua', 1, true) then
              return false
            end
          end
        end
        return has_non_file
      end)()
    ]])
  end, 6000)
end)

return T
