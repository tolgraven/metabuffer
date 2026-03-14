local H = require('tests.screen.support.screen_helpers')

local T = MiniTest.new_set({ hooks = H.case_hooks() })

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

return T
