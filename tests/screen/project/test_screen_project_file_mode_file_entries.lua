local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['file flag enables file-entry hits filtered by file token'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_text('#file README.md')
  H.wait_for(function() return H.session_query_text() == '' end, 6000)
  H.wait_for(function() return H.session_file_entry_hit_count() > 0 end, 6000)
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
            return false
          end
        end
        return true
      end)()
    ]])
  end, 6000)

  local first_line = H.session_first_file_entry_line()
  eq(type(first_line), 'string')
  eq(string.sub(first_line, 1, 1) == '/', false)

  local dbg = H.session_debug_out()
  eq(H.str_contains(dbg, '+fil'), true)
end)

return T
