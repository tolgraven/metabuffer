local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['#file line + content lines yields content hits from matched files'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_text('#file:window\n(fn\nset')

  H.wait_for(function()
    return H.session_hit_count() > 0
      and H.session_file_entry_hit_count() == 0
  end, 6000)

  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        if not s then return false end
        local idxs = s.meta.buf.indices or {}
        local refs = s.meta.buf['source-refs'] or {}
        local found_fn = false
        local found_set = false
        for _, src_idx in ipairs(idxs) do
          local ref = refs[src_idx]
          local path = ref and ref.path or ''
          local line = ref and ref.line or ''
          if not string.find(path, 'window', 1, true) then
            return false
          end
          if string.find(line, '(fn', 1, true) then
            found_fn = true
          end
          if string.find(line, 'set', 1, true) then
            found_set = true
          end
        end
        return found_fn and found_set
      end)()
    ]])
  end, 6000)

  eq(H.session_file_entry_hit_count(), 0)
end)

return T
