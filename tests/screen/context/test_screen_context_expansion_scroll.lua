local MiniTest = require('mini.test')
local H = require('tests.screen.support.screen_helpers')

local T = MiniTest.new_set({
  hooks = H.shared_child_hooks(),
})

T['scroll-main expands newly visible function blocks'] = H.timed_case(function()
  H.open_meta_with_lines({
    'local function first()',
    '  local keep = 1',
    '  return keep',
    'end',
    '',
    'local function second()',
    '  local needle = "lua visible"',
    '  return needle',
    'end',
    '',
    'local function third()',
    '  local needle = "lua hidden"',
    '  return needle',
    'end',
  })

  H.set_session_main_view(1, 1, 4)
  H.type_prompt_text('lua #exp:fn')
  H.wait_for(function()
    local lines = H.session_result_lines()
    return vim.tbl_contains(lines, 'local function second()')
      and not vim.tbl_contains(lines, 'local function third()')
  end, 4000)

  H.scroll_main_and_wait('page-down', 4000)
  H.wait_for(function()
    local lines = H.session_result_lines()
    return vim.tbl_contains(lines, 'local function third()')
      and vim.tbl_contains(lines, '  local needle = "lua hidden"')
  end, 4000)
end)

return T
