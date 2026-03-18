local session_view = require('metabuffer.session.view')
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['restore-meta-view preserves source viewport during project startup'] = function()
  vim.cmd('enew')
  local buf = vim.api.nvim_get_current_buf()
  local lines = {}
  for i = 1, 120 do
    lines[i] = ('line %03d'):format(i)
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local win = vim.api.nvim_get_current_win()
  local meta = {
    win = { window = win },
    buf = { buffer = buf },
    ['selected_line'] = function()
      return 37
    end,
  }

  vim.api.nvim_win_call(win, function()
    vim.fn.winrestview({ topline = 1, lnum = 1, col = 0, leftcol = 0 })
  end)

  session_view['restore-meta-view!'](
    meta,
    { topline = 30, lnum = 37, col = 0, leftcol = 0 },
    { ['project-mode'] = true, ['startup-initializing'] = true, ['project-mode-starting?'] = true },
    nil
  )

  local view = vim.api.nvim_win_call(win, function()
    return vim.fn.winsaveview()
  end)

  eq(view.lnum, 37)
  eq(view.topline, 30)
end

T['restore-meta-view ignores source viewport after project startup'] = function()
  vim.cmd('enew')
  local buf = vim.api.nvim_get_current_buf()
  local lines = {}
  for i = 1, 120 do
    lines[i] = ('line %03d'):format(i)
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local win = vim.api.nvim_get_current_win()
  local meta = {
    win = { window = win },
    buf = { buffer = buf },
    ['selected_line'] = function()
      return 37
    end,
  }

  vim.api.nvim_win_call(win, function()
    vim.fn.winrestview({ topline = 30, lnum = 37, col = 0, leftcol = 0 })
  end)

  session_view['restore-meta-view!'](
    meta,
    { topline = 3, lnum = 10, col = 0, leftcol = 0 },
    { ['project-mode'] = true, ['startup-initializing'] = false, ['project-mode-starting?'] = false },
    nil
  )

  local view = vim.api.nvim_win_call(win, function()
    return vim.fn.winsaveview()
  end)

  eq(view.lnum, 37)
  eq(view.topline, 30)
end

return T
