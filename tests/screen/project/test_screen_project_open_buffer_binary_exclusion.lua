local H = require('tests.screen.support.screen_helpers')

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['open binary buffers are excluded from project results when binary mode is off'] = H.timed_case(function()
  local root = H.child.fn.getcwd()

  H.child.cmd('edit ' .. root .. '/README.md')
  H.child.cmd('vsplit ' .. root .. '/metabuffer.png')
  H.child.cmd('wincmd h')

  H.child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
  H.child.type_keys(':', 'Meta!', '<CR>')

  H.wait_for(function()
    return H.session_active() and H.session_hit_count() > 0
  end, 6000)

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
          local p = ref and (ref.path or ''):lower() or ''
          if string.find(p, 'metabuffer%.png', 1, false) then
            return false
          end
        end
        return true
      end)()
    ]])
  end, 6000)
end)

return T
