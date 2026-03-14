local H = require('tests.screen.support.screen_helpers')
local child = H.child

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['main hotkeys support newline token insertion and prompt-results toggle'] = H.timed_case(function()
  H.open_meta_with_lines({
    'alpha first',
    'beta second',
    'gamma third',
  })

  H.type_prompt_text('alpha')
  H.wait_for(function() return H.session_hit_count() == 1 end)

  H.type_prompt('<M-CR>')
  H.wait_for(function()
    return child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        if not s then return false end
        local win = s.meta and s.meta.win and s.meta.win.window
        return win and vim.api.nvim_win_is_valid(win) and (vim.api.nvim_get_current_win() == win)
      end)()
    ]])
  end)

  child.type_keys('j')
  child.type_keys('#')
  H.wait_for(function() return H.session_query_text() == 'alpha\nbeta' end)
  H.wait_for(function() return H.session_hit_count() == 2 end)

  child.type_keys('<M-CR>')
  H.wait_for(function()
    return child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        if not s then return false end
        local pwin = s['prompt-win']
        return pwin and vim.api.nvim_win_is_valid(pwin) and (vim.api.nvim_get_current_win() == pwin)
      end)()
    ]])
  end)
end)

return T
