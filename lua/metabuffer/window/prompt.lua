-- [nfnl] fnl/metabuffer/window/prompt.fnl
local base = require("metabuffer.window.base")
local animation_mod = require("metabuffer.window.animation")
local util = require("metabuffer.util")
local M = {}
local disable_airline_statusline_21 = base["disable-airline-statusline!"]
local apply_metabuffer_window_highlights_21 = base["apply-metabuffer-window-highlights!"]
local metabuffer_winhighlight = base["metabuffer-winhighlight"]
local with_split_mins = animation_mod["with-split-mins"]
local function prompt_winhighlight()
  return (metabuffer_winhighlight() .. ",StatusLine:MetaStatuslineMiddle,StatusLineNC:MetaStatuslineMiddle")
end
local function prompt_buffer_21(win)
  local buf = vim.api.nvim_win_get_buf(win)
  util["disable-heavy-buffer-features!"](buf)
  util["set-buffer-name!"](buf, "[Metabuffer Prompt]")
  do
    local bo = vim.bo[buf]
    bo["buftype"] = "nofile"
    bo["bufhidden"] = "wipe"
    bo["swapfile"] = false
    bo["modifiable"] = true
    bo["filetype"] = "metabufferprompt"
  end
  return buf
end
local function prompt_window_opts_21(win)
  disable_airline_statusline_21(win)
  apply_metabuffer_window_highlights_21(win)
  local wo = vim.wo[win]
  wo["winfixheight"] = true
  wo["number"] = false
  wo["relativenumber"] = false
  wo["signcolumn"] = "no"
  wo["foldcolumn"] = "0"
  wo["statusline"] = " "
  wo["winbar"] = ""
  wo["spell"] = false
  wo["cursorline"] = false
  wo["wrap"] = true
  wo["linebreak"] = true
  wo["winhighlight"] = prompt_winhighlight()
  wo["winblend"] = 0
  return nil
end
local function open_split_win_21(origin_win, local_layout_3f, start_height)
  local open_21
  local function _1_()
    if (local_layout_3f and origin_win and vim.api.nvim_win_is_valid(origin_win)) then
      local function _2_()
        vim.cmd(("belowright " .. tostring(start_height) .. "new"))
        return vim.api.nvim_get_current_win()
      end
      return vim.api.nvim_win_call(origin_win, _2_)
    else
      vim.cmd(("botright " .. tostring(start_height) .. "new"))
      return vim.api.nvim_get_current_win()
    end
  end
  open_21 = _1_
  return with_split_mins(open_21)
end
local function float_config(origin_win, start_height)
  local host
  if (origin_win and vim.api.nvim_win_is_valid(origin_win)) then
    host = origin_win
  else
    host = vim.api.nvim_get_current_win()
  end
  local host_width = vim.api.nvim_win_get_width(host)
  local host_height = vim.api.nvim_win_get_height(host)
  return {relative = "win", win = host, anchor = "SW", row = host_height, col = 0, width = host_width, height = math.max(1, start_height), style = "minimal"}
end
M.new = function(nvim, opts)
  local cfg = (opts or {})
  local height = (cfg.height or 3)
  local start_height = math.max(1, (cfg["start-height"] or height))
  local local_layout_3f
  if (cfg["window-local-layout"] == nil) then
    local_layout_3f = true
  else
    local_layout_3f = cfg["window-local-layout"]
  end
  local origin_win = cfg["origin-win"]
  local floating_3f = not not cfg["floating?"]
  local win
  if floating_3f then
    win = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), false, float_config(origin_win, start_height))
  else
    win = open_split_win_21(origin_win, local_layout_3f, start_height)
  end
  local self = base.new(nvim, win, {}, {})
  if floating_3f then
    pcall(vim.api.nvim_win_set_config, win, float_config(origin_win, start_height))
  else
    pcall(vim.api.nvim_win_set_height, win, start_height)
  end
  local buf = prompt_buffer_21(win)
  do
    local b = vim.b[buf]
    b["cmp_enabled"] = false
    prompt_window_opts_21(win)
  end
  self.buffer = buf
  self["floating?"] = floating_3f
  return self
end
M["handoff-to-split!"] = function(nvim, prompt_win, opts)
  local cfg = (opts or {})
  local origin_win = cfg["origin-win"]
  local local_layout_3f
  if (cfg["window-local-layout"] == nil) then
    local_layout_3f = true
  else
    local_layout_3f = cfg["window-local-layout"]
  end
  local height = math.max(1, (cfg.height or 1))
  local old_win = prompt_win.window
  local buf = prompt_win.buffer
  local saved_view
  local and_9_ = origin_win and vim.api.nvim_win_is_valid(origin_win)
  if and_9_ then
    local function _10_()
      return vim.fn.winsaveview()
    end
    and_9_ = vim.api.nvim_win_call(origin_win, _10_)
  end
  saved_view = and_9_
  local split_win = open_split_win_21(origin_win, local_layout_3f, height)
  pcall(vim.api.nvim_win_set_buf, split_win, buf)
  pcall(vim.api.nvim_win_set_height, split_win, height)
  prompt_window_opts_21(split_win)
  if (origin_win and saved_view and vim.api.nvim_win_is_valid(origin_win)) then
    local function _11_()
      return pcall(vim.fn.winrestview, saved_view)
    end
    vim.api.nvim_win_call(origin_win, _11_)
  else
  end
  if (old_win and vim.api.nvim_win_is_valid(old_win)) then
    pcall(vim.api.nvim_win_close, old_win, true)
  else
  end
  local self = base.new(nvim, split_win, {}, {})
  self.buffer = buf
  self["floating?"] = false
  return self
end
return M
