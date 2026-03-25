local T = MiniTest.new_set()
local eq = MiniTest.expect.equality

local function wait_for(pred, timeout_ms)
  eq(vim.wait(timeout_ms or 6000, pred, 20), true)
end

T['plain :Meta! launches project session with prompt and info window'] = function()
  require('metabuffer').setup({
    project_bootstrap_delay_ms = 400,
    project_bootstrap_idle_delay_ms = 400,
    ui = {
      animation = {
        enabled = true,
        loading_indicator = true,
        backend = 'mini',
      },
    },
  })

  vim.cmd('cd ' .. vim.fn.getcwd())
  vim.cmd('edit README.md')
  _G.__meta_source_buf = vim.api.nvim_get_current_buf()

  vim.cmd('Meta!')

  wait_for(function()
    local router = require('metabuffer.router')
    local s = router['active-by-source'][_G.__meta_source_buf]
    return s and s['prompt-win'] and vim.api.nvim_win_is_valid(s['prompt-win'])
  end, 6000)

  wait_for(function()
    local router = require('metabuffer.router')
    local s = router['active-by-source'][_G.__meta_source_buf]
    return s and s['info-buf'] and vim.api.nvim_buf_is_valid(s['info-buf'])
  end, 6000)

  wait_for(function()
    local router = require('metabuffer.router')
    local s = router['active-by-source'][_G.__meta_source_buf]
    return s and s['preview-win'] and vim.api.nvim_win_is_valid(s['preview-win'])
  end, 6000)

  local router = require('metabuffer.router')
  local s = router['active-by-source'][_G.__meta_source_buf]
  eq(not not s, true)
  eq(s['project-mode'], true)
  eq(not s['ui-hidden'], true)
  eq(vim.api.nvim_win_is_valid(s['prompt-win']), true)
  eq(vim.api.nvim_buf_is_valid(s['info-buf']), true)
  eq(vim.api.nvim_win_is_valid(s['preview-win']), true)
end

return T
