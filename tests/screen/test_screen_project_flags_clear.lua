local H = require('tests.screen.support.screen_helpers')

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['clearing file token removes stale file filtering'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_text('#file png')
  H.wait_for(function() return H.session_query_text() == '' end, 6000)
  H.wait_for(function() return H.session_file_entry_hit_count() >= 0 end, 6000)

  H.type_prompt('<C-u>')
  H.wait_for(function() return H.session_prompt_text() == '' end, 6000)
  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        if not s then return false end
        local q = s.meta['file-query-lines'] or {}
        return #q == 0
      end)()
    ]])
  end, 6000)
  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        if not s then return false end
        local idxs = s.meta.buf.indices or {}
        local refs = s.meta.buf['source-refs'] or {}
        local has_non_png = false
        for _, src_idx in ipairs(idxs) do
          local ref = refs[src_idx]
          if ref and ref.kind == 'file-entry' then
            local p = (ref.path or ''):lower()
            if not string.find(p, 'png', 1, true) then
              has_non_png = true
              break
            end
          end
        end
        return has_non_png
      end)()
    ]])
  end, 6000)
end)

return T
