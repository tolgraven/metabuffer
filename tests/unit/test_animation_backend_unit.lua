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
  vim.cmd('enew')
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_set_height(win, 1)

  local animate_calls = 0
  local tick_heights = {}
  local done_height

  with_stubbed_mini_animate({
    gen_timing = {
      cubic = function()
        return function()
          return 0
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
    animate = function(step_action)
      animate_calls = animate_calls + 1
      for step = 0, 2 do
        if not step_action(step) then break end
      end
    end,
  }, function()
    animation['animate-win-height-stepwise!']({
      ['animation-settings'] = {
        prompt = { backend = 'mini' },
      },
    }, 'prompt-enter', win, 1, 4, 140, {
      ['tick!'] = function(height)
        table.insert(tick_heights, height)
      end,
      ['done!'] = function(height)
        done_height = height
      end,
    })
  end)

  eq(animate_calls, 1)
  eq(tick_heights[1], 1)
  eq(tick_heights[2], 2)
  eq(tick_heights[3], 4)
  eq(done_height, 4)
  eq(vim.api.nvim_win_get_height(win), 4)
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
      for step = 0, 8 do
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
  eq(cfg.col[false], 1)
  eq(cfg.width, 12)
  eq(cfg.height, 4)
  eq(blend, 13)
  eq(done_cfg.width, 12)

  pcall(vim.api.nvim_win_close, win, true)
end

return T
