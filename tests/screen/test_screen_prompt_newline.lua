local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['prompt-newline action inserts newline in prompt'] = H.timed_case(function()
  H.open_meta_with_lines({
    'alpha one',
    'beta two',
    'gamma three',
  })

  H.type_prompt_text('alpha')

  -- Use the router API directly since <S-CR> is not distinguishable
  -- from <CR> in headless Neovim.
  H.child.lua([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      assert(s and s['prompt-buf'], 'missing prompt buffer')
      router['prompt-newline'](s['prompt-buf'])
    end)()
  ]])

  H.type_prompt_text('beta')

  H.wait_for(function()
    return H.session_query_text() == 'alpha\nbeta'
  end, 3000)

  local prompt_lines = H.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      assert(s and s['prompt-buf'], 'missing prompt buffer')
      return vim.api.nvim_buf_get_lines(s['prompt-buf'], 0, -1, false)
    end)()
  ]])

  eq(prompt_lines, { 'alpha', 'beta' })
end)

return T
