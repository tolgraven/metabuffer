local animation = require('metabuffer.window.animation')
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

local function with_stubbed_mini_animate(stub, f)
  local old = package.loaded['mini.animate']
  package.loaded['mini.animate'] = stub
  animation['reset-mini-animate-cache!']()

  local ok, err = pcall(f)

  package.loaded['mini.animate'] = old
  animation['reset-mini-animate-cache!']()

  if not ok then error(err) end
end

T['prompt height animation can use mini resize backend'] = function()
  -- Close all splits so the single window has max height (avoids E36 in batch)
  vim.cmd('only | enew')
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_set_height(win, 1)

  local setup_calls = 0
  local execute_after_calls = {}
  local done_height

  with_stubbed_mini_animate({
    setup = function(config)
      setup_calls = setup_calls + 1
      eq(config.cursor.enable, true)
      eq(config.resize.enable, true)
      eq(config.scroll.enable, true)
    end,
    gen_timing = {
      cubic = function()
        return function()
          return 0
        end
      end,
      linear = function()
        return function()
          return 0
        end
      end,
    },
    gen_subscroll = {
      equal = function()
        return function()
          return { 1 }
        end
      end,
    },
    gen_subresize = {
      equal = function()
        return function(from_sizes, to_sizes)
          eq(from_sizes.prompt.height, 1)
          eq(to_sizes.prompt.height, 4)
          return {
            { prompt = { height = 2, width = 1 } },
            { prompt = { height = 4, width = 1 } },
          }
        end
      end,
    },
    execute_after = function(kind, action)
      table.insert(execute_after_calls, kind)
      action()
    end,
  }, function()
    animation['animate-win-height-stepwise!']({
      ['animation-settings'] = {
        backend = 'mini',
        prompt = {},
        scroll = {},
      },
    }, 'prompt-enter', win, 1, 4, 140, {
      ['done!'] = function(height)
        done_height = height
      end,
    })
  end)

  eq(setup_calls, 1)
  eq(execute_after_calls[1], 'resize')
  eq(done_height, 4)
  eq(vim.api.nvim_win_get_height(win), 4)
end

T['scroll animation can delegate completion to mini execute_after'] = function()
  vim.cmd('enew')
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_win_set_buf(win, buf)

  local setup_calls = 0
  local execute_after_calls = {}
  local done_view

  with_stubbed_mini_animate({
    setup = function(config)
      setup_calls = setup_calls + 1
      eq(config.scroll.enable, true)
      eq(config.resize.enable, true)
    end,
    gen_timing = {
      cubic = function()
        return function()
          return 0
        end
      end,
      linear = function()
        return function()
          return 0
        end
      end,
    },
    gen_subscroll = {
      equal = function()
        return function()
          return { 1 }
        end
      end,
    },
    gen_subresize = {
      equal = function()
        return function()
          return { { prompt = { height = 1, width = 1 } } }
        end
      end,
    },
    execute_after = function(kind, action)
      table.insert(execute_after_calls, kind)
      action()
    end,
  }, function()
    animation['animate-scroll-view!']({
      ['prompt-buf'] = nil,
      ['info-buf'] = nil,
      ['animation-settings'] = {
        backend = 'mini',
        prompt = {},
        scroll = {},
      },
    }, 'scroll', win,
    { topline = 1, lnum = 1, leftcol = 0, col = 0 },
    { topline = 12, lnum = 15, leftcol = 0, col = 0 },
    140,
    {
      ['done!'] = function(view)
        done_view = view
      end,
    })

    vim.wait(200, function()
      return #execute_after_calls > 0
    end)
  end)

  eq(setup_calls, 1)
  eq(execute_after_calls[1], 'scroll')
  eq(done_view.topline, 12)
  eq(vim.api.nvim_win_call(win, vim.fn.winsaveview).topline, 12)
end

T['info float animation can use mini open helpers'] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, false, {
    relative = 'editor',
    row = 1,
    col = 1,
    width = 10,
    height = 2,
    style = 'minimal',
  })

  local animate_calls = 0
  local blend_calls = {}
  local done_cfg

  with_stubbed_mini_animate({
    gen_timing = {
      cubic = function()
        return function()
          return 0
        end
      end,
    },
    gen_winblend = {
      linear = function(opts)
        eq(opts.from, 100)
        eq(opts.to, 13)
        return function(step, total)
          table.insert(blend_calls, { step, total })
          return math.floor(opts.from + ((opts.to - opts.from) * step / total))
        end
      end,
    },
    animate = function(step_action)
      animate_calls = animate_calls + 1
      for step = 0, 100 do
        if not step_action(step) then break end
      end
    end,
  }, function()
    animation['animate-float!']({
      ['animation-settings'] = {
        info = { backend = 'mini' },
      },
    }, 'info-enter', win,
    { relative = 'editor', row = 1, col = 9, width = 10, height = 2, style = 'minimal' },
    { relative = 'editor', row = 1, col = 1, width = 12, height = 4, style = 'minimal' },
    100, 13, 220, {
      kind = 'info',
      ['done!'] = function(cfg)
        done_cfg = cfg
      end,
    })
  end)

  local cfg = vim.api.nvim_win_get_config(win)
  local blend = vim.api.nvim_get_option_value('winblend', { win = win })

  eq(animate_calls, 1)
  eq(#blend_calls > 0, true)
  local col_val = (type(cfg.col) == 'table') and cfg.col[false] or cfg.col
  eq(col_val, 1)
  eq(cfg.width, 12)
  eq(cfg.height, 4)
  eq(blend, 13)
  eq(done_cfg.width, 12)

  pcall(vim.api.nvim_win_close, win, true)
end

return T
