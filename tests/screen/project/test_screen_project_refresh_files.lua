local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

local function set_prompt_text(text)
  H.child.lua(string.format([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      vim.api.nvim_buf_set_lines(s['prompt-buf'], 0, -1, false, { %q })
      router['on-prompt-changed'](s['prompt-buf'], true)
    end)()
  ]], text))
end

T['project cache refresh key and hidden-session restore both reload file content from disk'] = H.timed_case(function()
  local root = H.make_temp_project()
  local refresh_file = root .. '/refresh-me.txt'
  H.child.fn.writefile({ 'before token' }, refresh_file)

  H.open_project_meta_in_dir(root, 'main.txt')
  set_prompt_text('before')
  H.wait_for(function()
    return H.session_query_text() == 'before' and H.session_hit_count() > 0
  end, 6000)

  H.child.lua([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      router.cancel(s['prompt-buf'])
    end)()
  ]])
  H.wait_for(H.session_ui_hidden, 4000)

  H.child.fn.writefile({ 'after token' }, refresh_file)
  H.child.type_keys(':', 'Meta!', '<CR>')
  H.wait_for(function()
    return H.session_active() and not H.session_ui_hidden()
  end, 6000)

  set_prompt_text('after')
  H.wait_for(function()
    return H.session_query_text() == 'after' and H.session_hit_count() > 0
  end, 6000)

  H.child.fn.writefile({ 'again token' }, refresh_file)
  set_prompt_text('again')
  H.wait_for(function() return H.session_query_text() == 'again' end, 4000)
  eq(H.session_hit_count(), 0)

  H.feed_prompt_key('<LocalLeader>r', 'normal')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)
end)

return T
