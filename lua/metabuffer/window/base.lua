-- [nfnl] fnl/metabuffer/window/base.fnl
local handle = require("metabuffer.handle")
local M = {}
M.new = function(nvim, win, opts_to_stash, opts)
  local self = handle.new(nvim, win, win, opts_to_stash, opts)
  self.window = win
  self["set-statusline"] = function(text)
    local wo = vim.wo[self.window]
    wo["statusline"] = text
    return nil
  end
  self["set-cursor"] = function(row, col)
    return vim.api.nvim_win_set_cursor(self.window, {row, (col or 0)})
  end
  self["set-row"] = function(row, addjump)
    if addjump then
      return vim.cmd((":" .. tostring(row)))
    else
      return self["set-cursor"](row)
    end
  end
  self["set-col"] = function(col)
    local cur = vim.api.nvim_win_get_cursor(self.window)
    return self["set-cursor"](cur[1], col)
  end
  self["set-buf"] = function(buf)
    return vim.api.nvim_win_set_buf(self.window, buf)
  end
  return self
end
return M
