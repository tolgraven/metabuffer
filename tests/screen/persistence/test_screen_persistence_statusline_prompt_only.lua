local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['prompt keeps count and key hints while results carries its own statusline'] = H.timed_case(function()
  H.open_meta_with_lines({
    'meta one',
    'meta two',
    'meta three',
    'meta four',
  })

  H.type_prompt_text('meta')
  H.wait_for(function() return H.session_hit_count() == 4 end, 3000)

  local prompt_sl = H.session_prompt_statusline()
  local main_sl = H.session_main_statusline()

  eq(type(prompt_sl), 'string')
  eq(#prompt_sl > 0, true)
  eq(H.str_contains(prompt_sl, 'Insert') or H.str_contains(prompt_sl, 'Normal') or H.str_contains(prompt_sl, 'Replace') or H.str_contains(prompt_sl, '𝐈') or H.str_contains(prompt_sl, '𝗡') or H.str_contains(prompt_sl, 'R'), true)
  eq(H.str_contains(prompt_sl, '4/4'), true)
  eq(H.str_contains(prompt_sl, 'C^'), true)
  eq(H.str_contains(prompt_sl, 'C-o'), true)
  eq(H.str_contains(prompt_sl, 'Cs'), true)
  eq(type(main_sl), 'string')
  eq(#main_sl > 0, true)
  eq(H.str_contains(main_sl, '4/4'), false)
  eq(H.str_contains(main_sl, 'C^'), false)
  eq(H.str_contains(main_sl, 'C-o'), false)
  eq(H.str_contains(main_sl, 'Cs'), false)

  child.cmd('stopinsert')
  child.lua([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      assert(s and s['prompt-buf'], 'missing metabuffer session')
      router['enter-edit-mode'](s['prompt-buf'])
      local buf = s.meta.buf.buffer
      vim.api.nvim_buf_set_lines(buf, 0, 1, false, { 'meta one changed' })
    end)()
  ]])

  H.wait_for(function()
    return H.str_contains(H.session_main_statusline(), '[+]')
  end, 3000)
end)

return T
