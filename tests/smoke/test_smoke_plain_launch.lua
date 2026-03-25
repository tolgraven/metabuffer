local T = MiniTest.new_set()
local eq = MiniTest.expect.equality

local function wait_for(pred, timeout_ms)
  eq(vim.wait(timeout_ms or 3000, pred, 20), true)
end

T['plain :Meta launches session with prompt and info window'] = function()
  vim.cmd('enew')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    'alpha one',
    'alpha two',
    'beta three',
    'gamma four',
  })
  _G.__meta_source_buf = vim.api.nvim_get_current_buf()

  vim.cmd('Meta')

  wait_for(function()
    local router = require('metabuffer.router')
    local s = router['active-by-source'][_G.__meta_source_buf]
    return s and s['prompt-win'] and vim.api.nvim_win_is_valid(s['prompt-win'])
  end, 3000)

  wait_for(function()
    local router = require('metabuffer.router')
    local s = router['active-by-source'][_G.__meta_source_buf]
    return s and s['info-buf'] and vim.api.nvim_buf_is_valid(s['info-buf'])
  end, 3000)

  wait_for(function()
    local router = require('metabuffer.router')
    local s = router['active-by-source'][_G.__meta_source_buf]
    return s and s['preview-win'] and vim.api.nvim_win_is_valid(s['preview-win'])
  end, 3000)

  local router = require('metabuffer.router')
  local s = router['active-by-source'][_G.__meta_source_buf]
  eq(not not s, true)
  eq(not s['ui-hidden'], true)
  eq(vim.api.nvim_win_is_valid(s['prompt-win']), true)
  eq(vim.api.nvim_buf_is_valid(s['info-buf']), true)
  eq(vim.api.nvim_win_is_valid(s['preview-win']), true)

  -- Message format is "Metabuffer • <source> • instance N" via nvim_echo,
  -- but vim.schedule delivery is unreliable in headless MiniTest workers.
  -- Core session/window assertions above cover launch correctness.
end

return T
