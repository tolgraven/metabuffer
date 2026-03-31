-- [nfnl] fnl/metabuffer/prompt/prompt.fnl
local caret_mod = require("metabuffer.prompt.caret")
local history_mod = require("metabuffer.prompt.history")
local action_mod = require("metabuffer.prompt.action")
local keymap_mod = require("metabuffer.prompt.keymap")
local util = require("metabuffer.prompt.util")
local debug = require("metabuffer.debug")
local M = {}
M.STATUS_PROGRESS = 0
M.STATUS_ACCEPT = 1
M.STATUS_CANCEL = 2
M.STATUS_INTERRUPT = 3
M.STATUS_PAUSE = 4
M.INSERT_MODE_INSERT = 1
M.INSERT_MODE_REPLACE = 2
M.DEFAULT_HARVEST_INTERVAL = 0.033
local function debug_log(msg)
  return debug.log("prompt", msg)
end
local function is_action_keystroke(s)
  return ((type(s) == "string") and vim.startswith(s, "<") and vim.endswith(s, ">") and string.match(string.sub(s, 2, (#s - 1)), "^%w+:%w+.*$"))
end
local function insert_text_21(self, txt)
  local locus = self.caret["get-locus"]()
  self.text = (self.caret["get-backward-text"]() .. txt .. self.caret["get-selected-text"]() .. self.caret["get-forward-text"]())
  return self.caret["set-locus"]((locus + #txt))
end
local function replace_text_21(self, txt)
  local locus = self.caret["get-locus"]()
  self.text = (self.caret["get-backward-text"]() .. txt .. string.sub(self.caret["get-forward-text"](), #txt))
  return self.caret["set-locus"]((locus + #txt))
end
local function update_text_21(self, txt)
  if (self["insert-mode"] == M.INSERT_MODE_INSERT) then
    return insert_text_21(self, txt)
  else
    return replace_text_21(self, txt)
  end
end
local function redraw_prompt_21(self)
  local backward = self.caret["get-backward-text"]()
  local selected = self.caret["get-selected-text"]()
  local forward = self.caret["get-forward-text"]()
  vim.cmd(table.concat({"redraw", util.build_echon_expr(self.prefix, self["highlight-prefix"]), util.build_echon_expr(backward, self["highlight-text"]), util.build_echon_expr(selected, self["highlight-caret"]), util.build_echon_expr(forward, self["highlight-text"])}, "|"))
  if self["is-macvim"] then
    return vim.cmd("redraw")
  else
    return nil
  end
end
local function on_keypress(self, keystroke)
  local s = tostring(keystroke)
  if is_action_keystroke(s) then
    local action = string.sub(s, 2, (#s - 1))
    local ret = self.action.call(self, action)
    if (type(ret) == "number") then
      return ret
    else
      return nil
    end
  else
    return update_text_21(self, s)
  end
end
local function run_prompt_loop_21(self)
  local status = (self["on-init"]() or M.STATUS_PROGRESS)
  debug_log(("[prompt] start status=" .. tostring(status)))
  do
    local timeoutlen
    if vim.o.timeout then
      timeoutlen = (vim.o.timeoutlen / 1000)
    else
      timeoutlen = nil
    end
    local function _6_()
      status = (self["on-update"](status) or M.STATUS_PROGRESS)
      debug_log(("[prompt] post-init-update status=" .. tostring(status)))
      while (status == M.STATUS_PROGRESS) do
        self["on-redraw"]()
        local stroke = self.keymap.harvest(self.nvim, timeoutlen, self["on-harvest"], self["harvest-interval"])
        debug_log(("[prompt] stroke=" .. tostring(stroke)))
        status = (self["on-keypress"](stroke) or M.STATUS_PROGRESS)
        debug_log(("[prompt] post-keypress status=" .. tostring(status)))
        status = (self["on-update"](status) or status)
      end
      return nil
    end
    local ok,err = pcall(_6_)
    if not ok then
      debug_log(("[prompt] error=" .. tostring(err)))
      if ((err == "Keyboard interrupt") or string.find(tostring(err), "Keyboard interrupt")) then
        status = M.STATUS_INTERRUPT
      else
        error(err)
      end
    else
    end
  end
  if (self.text ~= "") then
    vim.fn.histadd("input", self.text)
  else
  end
  debug_log(("[prompt] term status=" .. tostring(status)))
  return self["on-term"](status)
end
M.new = function(nvim)
  local self = {nvim = nvim, text = "", prefix = "", ["insert-mode"] = M.INSERT_MODE_INSERT, ["highlight-prefix"] = "Question", ["highlight-text"] = "None", ["highlight-caret"] = "IncSearch", ["harvest-interval"] = M.DEFAULT_HARVEST_INTERVAL, ["is-macvim"] = ((1 == vim.fn.has("gui_running")) and (1 == vim.fn.has("mac")))}
  self.caret = caret_mod.new(self, 0)
  self.history = history_mod.new(self)
  self.action = action_mod["default-action"]()
  self.keymap = keymap_mod.from_rules(nvim, keymap_mod["default-keymap-rules"]())
  self["insert-text"] = function(txt)
    return insert_text_21(self, txt)
  end
  self["replace-text"] = function(txt)
    return replace_text_21(self, txt)
  end
  self["update-text"] = function(txt)
    return update_text_21(self, txt)
  end
  self["redraw-prompt"] = function()
    return redraw_prompt_21(self)
  end
  self["on-init"] = function()
    return vim.fn.inputsave()
  end
  self["on-update"] = function(status)
    return status
  end
  self["on-redraw"] = function()
    return self["redraw-prompt"]()
  end
  self["on-harvest"] = function()
    return nil
  end
  self["on-keypress"] = function(keystroke)
    return on_keypress(self, keystroke)
  end
  self["on-term"] = function(status)
    vim.fn.inputrestore()
    return status
  end
  self.store = function()
    return {text = self.text, ["caret-locus"] = self.caret["get-locus"]()}
  end
  self.restore = function(condition)
    self.text = condition.text
    return self.caret["set-locus"](condition["caret-locus"])
  end
  self.start = function()
    return run_prompt_loop_21(self)
  end
  return self
end
return M
