local info_window_mod = require('metabuffer.window.info')
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['project loading panel shows streaming progress while project settles'] = function()
  local floating = {
    new = function(_, buf, cfg)
      local win = vim.api.nvim_open_win(buf, false, vim.tbl_extend('force', {
        relative = 'editor',
        row = 1,
        col = 1,
        width = 40,
        height = 8,
        style = 'minimal',
      }, cfg or {}))
      return { window = win }
    end,
  }

  local info = info_window_mod.new({
    ['floating-window-mod'] = floating,
    ['info-min-width'] = 20,
    ['info-max-width'] = 40,
    ['info-max-lines'] = 20,
    ['info-height'] = function()
      return 8
    end,
    ['debug-log'] = function()
    end,
    ['read-file-lines-cached'] = function()
      return {}
    end,
  })

  local meta_buf = vim.api.nvim_create_buf(false, true)
  local meta_win = vim.api.nvim_get_current_win()
  local session = {
    ['project-mode'] = true,
    ['startup-initializing'] = false,
    ['prompt-animating?'] = false,
    ['project-bootstrap-pending'] = false,
    ['project-bootstrapped'] = true,
    ['lazy-refresh-pending'] = false,
    ['lazy-refresh-dirty'] = false,
    ['lazy-stream-done'] = false,
    ['lazy-stream-next'] = 4,
    ['lazy-stream-total'] = 12,
    ['window-local-layout'] = false,
    meta = {
      win = { window = meta_win },
      buf = {
        buffer = meta_buf,
        content = { 'a', 'b', 'c' },
        indices = { 1, 2, 3 },
        ['source-refs'] = {},
      },
      ['selected_index'] = 0,
    },
  }

  info['update!'](session, true)

  local lines = vim.api.nvim_buf_get_lines(session['info-buf'], 0, -1, false)
  eq(lines[1], 'Project Mode  streaming project sources')
  eq(lines[3], 'Progress  3/12 files')
  eq(lines[4], 'Hits      3')
  eq(lines[5], 'Lines     3')
end

return T
