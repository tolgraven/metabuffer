local H = require('tests.screen.support.screen_helpers')

local T = MiniTest.new_set({ hooks = H.case_hooks() })

local function focus_results_window()
  H.child.lua([[
    local r = require("metabuffer.router")
    for _, s in pairs(r["active-by-prompt"]) do
      if s and s.meta and s.meta.win
         and vim.api.nvim_win_is_valid(s.meta.win.window) then
        vim.api.nvim_set_current_win(s.meta.win.window)
        vim.cmd("stopinsert")
        break
      end
    end
  ]])
  vim.loop.sleep(200)
end

local function cursor()
  return H.child.lua_get('vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())')
end

T['results buffer navigation'] = MiniTest.new_set()

T['results buffer navigation']['cursor stays where user places it'] = H.timed_case(function()
  local lines = {}
  for i = 1, 20 do
    lines[#lines + 1] = ('line %02d content'):format(i)
  end

  H.open_meta_with_lines(lines)
  H.wait_for(function() return H.session_hit_count() == 20 end)

  focus_results_window()

  H.child.lua('vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), {5, 0})')
  vim.loop.sleep(400)

  local pos = cursor()
  H.eq(pos[1], 5, 'cursor line should stay at 5 after set_cursor')
end)

T['results buffer navigation']['j/k moves cursor normally'] = H.timed_case(function()
  local lines = {}
  for i = 1, 20 do
    lines[#lines + 1] = ('line %02d content'):format(i)
  end

  H.open_meta_with_lines(lines)
  H.wait_for(function() return H.session_hit_count() == 20 end)

  focus_results_window()

  local start = cursor()

  H.child.type_keys('j')
  vim.loop.sleep(300)
  local after_j = cursor()
  H.eq(after_j[1], start[1] + 1, 'j should move cursor down one line')

  H.child.type_keys('j')
  vim.loop.sleep(300)
  local after_jj = cursor()
  H.eq(after_jj[1], start[1] + 2, 'second j should move cursor down again')

  H.child.type_keys('k')
  vim.loop.sleep(300)
  local after_k = cursor()
  H.eq(after_k[1], start[1] + 1, 'k should move cursor back up one line')
end)

T['results buffer navigation']['mouse click position sticks'] = H.timed_case(function()
  local lines = {}
  for i = 1, 20 do
    lines[#lines + 1] = ('line %02d content'):format(i)
  end

  H.open_meta_with_lines(lines)
  H.wait_for(function() return H.session_hit_count() == 20 end)

  focus_results_window()

  H.child.lua('vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), {10, 0})')
  vim.loop.sleep(400)

  local pos = cursor()
  H.eq(pos[1], 10, 'cursor should stay at clicked line')
end)

return T
