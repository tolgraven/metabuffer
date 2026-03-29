-- [nfnl] fnl/metabuffer/window/prompt.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local base = require("metabuffer.window.base")
local animation_mod = require("metabuffer.window.animation")
local directive_mod = require("metabuffer.query.directive")
local events = require("metabuffer.events")
local util = require("metabuffer.util")
local M = {}
local apply_metabuffer_window_highlights_21 = base["apply-metabuffer-window-highlights!"]
local metabuffer_winhighlight = base["metabuffer-winhighlight"]
local with_split_mins = animation_mod["with-split-mins"]
local function prompt_winhighlight()
  return (metabuffer_winhighlight() .. ",StatusLine:MetaStatuslineMiddle,StatusLineNC:MetaStatuslineMiddle")
end
local function apply_prompt_buffer_opts_21(buf)
  if (buf and vim.api.nvim_buf_is_valid(buf)) then
    local bo = vim.bo[buf]
    bo["buftype"] = "nofile"
    bo["bufhidden"] = "hide"
    bo["swapfile"] = false
    bo["modifiable"] = true
    _G.__meta_directive_completefunc = directive_mod.completefunc
    bo["completefunc"] = "v:lua.__meta_directive_completefunc"
    bo["filetype"] = "metabufferprompt"
  else
  end
  return buf
end
local function prompt_buffer_21(win)
  local buf = vim.api.nvim_win_get_buf(win)
  events.send("on-buf-create!", {buf = buf, role = "prompt"})
  util["set-buffer-name!"](buf, "[Metabuffer Prompt]")
  return apply_prompt_buffer_opts_21(buf)
end
local function prompt_window_opts_21(win)
  events.send("on-win-create!", {win = win, role = "prompt"})
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
  local function _2_()
    if (local_layout_3f and origin_win and vim.api.nvim_win_is_valid(origin_win)) then
      local function _3_()
        vim.cmd(("belowright " .. tostring(start_height) .. "new"))
        return vim.api.nvim_get_current_win()
      end
      return vim.api.nvim_win_call(origin_win, _3_)
    else
      vim.cmd(("botright " .. tostring(start_height) .. "new"))
      return vim.api.nvim_get_current_win()
    end
  end
  open_21 = _2_
  local win = with_split_mins(open_21)
  if (win and vim.api.nvim_win_is_valid(win)) then
    util["mark-transient-unnamed-buffer!"](vim.api.nvim_win_get_buf(win))
  else
  end
  return win
end
local function wipe_replaced_split_buffer_21(old_buf)
  if (old_buf and vim.api.nvim_buf_is_valid(old_buf)) then
    return util["delete-transient-unnamed-buffer!"](old_buf)
  else
    return nil
  end
end
local function new_prompt_wrapper(nvim, win, buf)
  local self = base.new(nvim, win, {}, {})
  self.buffer = buf
  self["floating?"] = false
  return self
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
  local floating_3f = clj.boolean(cfg["floating?"])
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
  prompt_window_opts_21(win)
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
  local and_12_ = origin_win and vim.api.nvim_win_is_valid(origin_win)
  if and_12_ then
    local function _13_()
      return vim.fn.winsaveview()
    end
    and_12_ = vim.api.nvim_win_call(origin_win, _13_)
  end
  saved_view = and_12_
  local split_win = open_split_win_21(origin_win, local_layout_3f, height)
  local old_buf = (split_win and vim.api.nvim_win_is_valid(split_win) and vim.api.nvim_win_get_buf(split_win))
  pcall(vim.api.nvim_win_set_buf, split_win, buf)
  wipe_replaced_split_buffer_21(old_buf)
  pcall(vim.api.nvim_win_set_height, split_win, height)
  prompt_window_opts_21(split_win)
  if (origin_win and saved_view and vim.api.nvim_win_is_valid(origin_win)) then
    local function _14_()
      return pcall(vim.fn.winrestview, saved_view)
    end
    vim.api.nvim_win_call(origin_win, _14_)
  else
  end
  if (old_win and vim.api.nvim_win_is_valid(old_win)) then
    pcall(vim.api.nvim_win_close, old_win, true)
  else
  end
  return new_prompt_wrapper(nvim, split_win, buf)
end
M["restore-hidden!"] = function(nvim, prompt_buf, opts)
  local cfg = (opts or {})
  local origin_win = cfg["origin-win"]
  local local_layout_3f
  if (cfg["window-local-layout"] == nil) then
    local_layout_3f = true
  else
    local_layout_3f = cfg["window-local-layout"]
  end
  local height = math.max(1, (cfg.height or 1))
  local split_win = open_split_win_21(origin_win, local_layout_3f, height)
  local old_buf = (split_win and vim.api.nvim_win_is_valid(split_win) and vim.api.nvim_win_get_buf(split_win))
  pcall(vim.api.nvim_win_set_buf, split_win, prompt_buf)
  wipe_replaced_split_buffer_21(old_buf)
  pcall(vim.api.nvim_win_set_height, split_win, height)
  apply_prompt_buffer_opts_21(prompt_buf)
  prompt_window_opts_21(split_win)
  return new_prompt_wrapper(nvim, split_win, prompt_buf)
end
M["restore-cursor!"] = function(prompt_win, cursor)
  if (prompt_win and vim.api.nvim_win_is_valid(prompt_win)) then
    local cursor0 = (cursor or {1, 0})
    local row = math.max(1, (cursor0[1] or 1))
    local col = math.max(0, (cursor0[2] or 0))
    local line_count = math.max(1, vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(prompt_win)))
    local row_2a = math.min(row, line_count)
    local line = (vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(prompt_win), (row_2a - 1), row_2a, false)[1] or "")
    local col_2a = math.min(col, #line)
    return pcall(vim.api.nvim_win_set_cursor, prompt_win, {row_2a, col_2a})
  else
    return nil
  end
end
M["prepare-buffer!"] = apply_prompt_buffer_opts_21
return M
