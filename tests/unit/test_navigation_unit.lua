local navigation = require('metabuffer.router.navigation')
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

local function wait_for_refresh(count_fn, expected)
  vim.wait(1000, function()
    return count_fn() == expected
  end, 10)
  eq(count_fn(), expected)
end

T['scroll-main keeps selected row in sync with results viewport from prompt window'] = function()
  vim.cmd('enew')
  local meta_buf = vim.api.nvim_get_current_buf()
  local lines = {}
  for i = 1, 120 do
    lines[i] = ('line %03d'):format(i)
  end
  vim.api.nvim_buf_set_lines(meta_buf, 0, -1, false, lines)

  local meta_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_height(meta_win, 10)
  vim.api.nvim_win_call(meta_win, function()
    vim.fn.winrestview({ topline = 10, lnum = 10, col = 0, leftcol = 0 })
  end)

  vim.cmd('belowright split')
  local prompt_win = vim.api.nvim_get_current_win()
  local prompt_buf = vim.api.nvim_get_current_buf()

  local status_calls = 0
  local deps = {
    router = { ['active-by-prompt'] = {} },
    refresh = {},
    windows = {},
    mods = {},
  }
  local session = {
    ['prompt-buf'] = prompt_buf,
    meta = {
      ['selected_index'] = 9,
      win = { window = meta_win },
      buf = {
        buffer = meta_buf,
        indices = lines,
      },
      ['refresh_statusline'] = function()
        status_calls = status_calls + 1
      end,
    },
  }
  deps.router['active-by-prompt'][prompt_buf] = session

  navigation['scroll-main!'](deps, prompt_buf, 'half-down')

  local view = vim.api.nvim_win_call(meta_win, function()
    return vim.fn.winsaveview()
  end)
  local cursor = vim.api.nvim_win_get_cursor(meta_win)
  wait_for_refresh(function()
    return status_calls
  end, 1)

  eq(view.topline, 15)
  eq(cursor[1], 15)
  eq(session.meta['selected_index'], 14)

  vim.api.nvim_set_current_win(meta_win)
  vim.cmd('only')
end

T['animated scroll-main does not jump the real cursor before the animation runs'] = function()
  vim.cmd('enew')
  local meta_buf = vim.api.nvim_get_current_buf()
  local lines = {}
  for i = 1, 120 do
    lines[i] = ('line %03d'):format(i)
  end
  vim.api.nvim_buf_set_lines(meta_buf, 0, -1, false, lines)

  local meta_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_height(meta_win, 10)
  vim.api.nvim_win_call(meta_win, function()
    vim.fn.winrestview({ topline = 10, lnum = 10, col = 0, leftcol = 0 })
  end)

  vim.cmd('belowright split')
  local prompt_buf = vim.api.nvim_get_current_buf()

  local status_calls = 0
  local animate_calls = 0
  local deps = {
    router = { ['active-by-prompt'] = {} },
    refresh = {},
    windows = {},
    mods = {
      animation = {
        ['enabled?'] = function()
          return true
        end,
        ['duration-ms'] = function()
          return 140
        end,
        ['animate-view!'] = function(_, _, win, from_view, to_view)
          animate_calls = animate_calls + 1
          eq(win, meta_win)
          eq(from_view.topline, 10)
          eq(from_view.lnum, 10)
          eq(to_view.topline, 15)
          eq(to_view.lnum, 15)
        end,
      },
    },
  }
  local session = {
    ['prompt-buf'] = prompt_buf,
    meta = {
      ['selected_index'] = 9,
      win = { window = meta_win },
      buf = {
        buffer = meta_buf,
        indices = lines,
      },
      ['refresh_statusline'] = function()
        status_calls = status_calls + 1
      end,
    },
  }
  deps.router['active-by-prompt'][prompt_buf] = session

  navigation['scroll-main!'](deps, prompt_buf, 'half-down')

  local view = vim.api.nvim_win_call(meta_win, function()
    return vim.fn.winsaveview()
  end)
  local cursor = vim.api.nvim_win_get_cursor(meta_win)
  wait_for_refresh(function()
    return status_calls
  end, 1)

  eq(animate_calls, 1)
  eq(view.topline, 10)
  eq(cursor[1], 10)
  eq(session.meta['selected_index'], 14)
 
  vim.api.nvim_set_current_win(meta_win)
  vim.cmd('only')
end

T['move-selection coalesces refresh work to the latest selection'] = function()
  vim.cmd('enew')
  local meta_buf = vim.api.nvim_get_current_buf()
  local lines = {}
  for i = 1, 80 do
    lines[i] = ('line %03d'):format(i)
  end
  vim.api.nvim_buf_set_lines(meta_buf, 0, -1, false, lines)

  local meta_win = vim.api.nvim_get_current_win()
  vim.cmd('belowright split')
  local prompt_buf = vim.api.nvim_get_current_buf()

  local status_calls = 0
  local preview_calls = 0
  local info_calls = 0
  local context_calls = 0
  local deps = {
    router = { ['active-by-prompt'] = {} },
    refresh = {
      ['preview!'] = function(session)
        preview_calls = preview_calls + 1
        eq(session.meta['selected_index'], 2)
      end,
      ['info!'] = function(session)
        info_calls = info_calls + 1
        eq(session.meta['selected_index'], 2)
      end,
    },
    windows = {
      context = {
        ['update!'] = function(session)
          context_calls = context_calls + 1
          eq(session.meta['selected_index'], 2)
        end,
      },
    },
    mods = {},
  }
  local session = {
    ['prompt-buf'] = prompt_buf,
    meta = {
      ['selected_index'] = 0,
      win = { window = meta_win },
      buf = {
        buffer = meta_buf,
        indices = lines,
      },
      ['refresh_statusline'] = function()
        status_calls = status_calls + 1
      end,
    },
  }
  deps.router['active-by-prompt'][prompt_buf] = session

  navigation['move-selection!'](deps, prompt_buf, 1)
  navigation['move-selection!'](deps, prompt_buf, 1)
  navigation['move-selection!'](deps, prompt_buf, 1)

  wait_for_refresh(function()
    return status_calls
  end, 1)

  eq(session.meta['selected_index'], 2)
  eq(preview_calls, 1)
  eq(info_calls, 1)
  eq(context_calls, 1)

  vim.api.nvim_set_current_win(meta_win)
  vim.cmd('only')
end

return T
