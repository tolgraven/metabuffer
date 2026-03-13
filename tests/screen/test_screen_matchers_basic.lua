local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['filters short tokens and supports prompt edit hotkeys'] = H.timed_case(function()
  H.open_meta_with_lines({
    'lua api',
    'meta plugin',
    'metamorph check',
    'tolerance token',
    'topic branch',
    'other',
  })

  H.type_prompt_human('meta', 90)
  H.wait_for(function() return H.session_query_text() == 'meta' end)
  H.wait_for(function() return H.session_hit_count() == 2 end)

  H.type_prompt('<C-a>')
  H.type_prompt('^')
  H.type_prompt('<C-e>')
  H.type_prompt('$')
  H.wait_for(function() return H.session_query_text() == '^meta$' end)

  H.type_prompt('<C-u>')
  H.wait_for(function() return H.session_query_text() == '' end)
  H.type_prompt_human('metabuffer', 70)
  H.type_prompt('<C-u>')
  H.type_prompt('<C-y>')
  H.wait_for(function() return H.session_query_text() == 'metabuffer' end)
end)

T['fuzzy matcher is testable via key switch and non-contiguous query'] = H.timed_case(function()
  H.open_meta_with_lines({
    'metabuffer router',
    'meta flow',
    'router util',
    'other line',
  })

  eq(H.session_matcher_name(), 'all')
  H.type_prompt('<C-^>')
  H.wait_for(function() return H.session_matcher_name() == 'fuzzy' end)

  H.type_prompt_human('mbr', 80)
  H.wait_for(function() return H.session_query_text() == 'mbr' end)
  H.wait_for(function() return H.session_hit_count() == 1 end)
end)

T['regex matcher supports regex tokens and returns expected hits'] = H.timed_case(function()
  H.open_meta_with_lines({
    'valid abc',
    'valid xyz',
    'valid 123',
    'other row',
  })

  H.type_prompt('<C-^><C-^>')
  H.wait_for(function() return H.session_matcher_name() == 'regex' end)

  H.type_prompt_human('valid', 80)
  H.type_prompt(' ')
  H.type_prompt_human('\\w.*', 80)

  H.wait_for(function() return H.session_query_text() == 'valid \\w.*' end)
  H.wait_for(function() return H.session_hit_count() == 3 end)

  H.type_prompt_tokens({ '<BS>', '<BS>' }, 80)
  H.wait_for(function() return H.session_query_text() == 'valid \\w' end)
  H.wait_for(function() return H.session_hit_count() == 3 end)
end)

T['main-window hotkeys move selection and keep statusline live'] = H.timed_case(function()
  H.open_meta_with_lines({
    'meta one',
    'meta two',
    'meta three',
    'meta four',
  })

  H.type_prompt_human('meta', 80)
  H.wait_for(function() return H.session_hit_count() == 4 end)

  child.cmd('stopinsert')
  H.type_prompt('<C-n>')
  H.type_prompt('<C-n>')
  local ref = H.session_selected_ref()
  eq(type(ref), 'table')
  eq(ref.lnum > 1, true)

  local sl = H.session_statusline()
  eq(type(sl), 'string')
  eq(#sl > 0, true)
end)

T['main hotkeys support newline token insertion and prompt/results toggle'] = H.timed_case(function()
  H.open_meta_with_lines({
    'alpha first',
    'beta second',
    'gamma third',
  })

  H.type_prompt_human('alpha', 80)
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
