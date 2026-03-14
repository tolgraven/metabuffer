local H = require('tests.screen.support.screen_helpers')

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['file flag token is separate from normal query terms on same line'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_text('#file README lua')
  H.wait_for(function() return H.session_query_text() == 'lua' end, 6000)
  H.wait_for(function() return H.session_file_entry_hit_count() > 0 end, 6000)
end)

T['file flag without file token keeps existing regular hits'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_text('local')
  H.wait_for(function() return H.session_query_text() == 'local' end, 6000)

  H.type_prompt_text(' #file')
  H.wait_for(function() return H.session_query_text() == 'local' end, 6000)
  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        if not s then return false end
        local idxs = s.meta.buf.indices or {}
        local refs = s.meta.buf['source-refs'] or {}
        for _, src_idx in ipairs(idxs) do
          local ref = refs[src_idx]
          if ref and ref.kind ~= 'file-entry' then
            return true
          end
        end
        return false
      end)()
    ]])
  end, 6000)
end)

T['file token constrains regular hits to matching paths'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_text('local #file lua')
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
