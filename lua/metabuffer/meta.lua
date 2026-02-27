local prompt_mod = require("metabuffer.prompt.prompt")
local prompt_action_mod = require("metabuffer.prompt.action")
local modeindexer = require("metabuffer.modeindexer")
local state = require("metabuffer.core.state")
local action = require("metabuffer.action")
local all_matcher = require("metabuffer.matcher.all")
local fuzzy_matcher = require("metabuffer.matcher.fuzzy")
local regex_matcher = require("metabuffer.matcher.regex")
local meta_buffer_mod = require("metabuffer.buffer.metabuffer")
local meta_window_mod = require("metabuffer.window.metawindow")
local util = require("metabuffer.util")
local M = {}
local function line_of_index(buf, idx)
  return (buf.indices[(idx + 1)] or 1)
end
M.new = function(nvim, condition)
  local cond = (condition or state["default-condition"](""))
  local self = prompt_mod.new(nvim)
  self.condition = cond
  self.selected_index = (cond["selected-index"] or 0)
  self._prev_text = ""
  self.updates = 0
  self.debug_out = ""
  self.action = prompt_action_mod["DEFAULT-ACTION"]
  self.action["register-from-rules"](action["DEFAULT-ACTION-RULES"])
  self.win = meta_window_mod.new(nvim, vim.api.nvim_get_current_win())
  self.buf = meta_buffer_mod.new(nvim, vim.api.nvim_get_current_buf())
  local function _1_(idx)
    local function _2_()
      if (idx.current() == "meta") then
        return "meta"
      else
        return nil
      end
    end
    return self.buf["apply-syntax"](_2_())
  end
  self.mode = {matcher = modeindexer.new({all_matcher.new(), fuzzy_matcher.new(), regex_matcher.new()}, (cond["matcher-index"] or 1), {["on-leave"] = "remove-highlight"}), case = modeindexer.new(state.cases, (cond["case-index"] or 1), nil), syntax = modeindexer.new(state["syntax-types"], (cond["syntax-index"] or 1), {["on-active"] = _1_})}
  self.text = (cond.text or "")
  self.caret["set-locus"]((cond["caret-locus"] or #self.text))
  self.matcher = function()
    return self.mode.matcher.current()
  end
  self.case = function()
    return self.mode.case.current()
  end
  self.syntax = function()
    return self.mode.syntax.current()
  end
  self.ignorecase = function()
    return state.ignorecase(self.case(), self.text)
  end
  self.selected_line = function()
    return line_of_index(self.buf, self.selected_index)
  end
  self.switch_mode = function(which)
    local mode_obj = self.mode[which]
    mode_obj.next()
    self._prev_text = ""
    return self.on_update(prompt_mod.STATUS_PROGRESS)
  end
  self.vim_query = function()
    if (self.text == "") then
      return ""
    else
      local caseprefix
      if self.ignorecase() then
        caseprefix = "\\c"
      else
        caseprefix = "\\C"
      end
      local matcher_obj = self.matcher()
      local pat = matcher_obj["get-highlight-pattern"](matcher_obj, self.text)
      return (caseprefix .. pat)
    end
  end
  self.refresh_statusline = function()
    local mode_name
    if (self["insert-mode"] == prompt_mod.INSERT_MODE_REPLACE) then
      mode_name = "replace"
    else
      mode_name = "insert"
    end
    local hl_prefix
    if (self.buf["syntax-type"] == "meta") then
      hl_prefix = "Meta"
    else
      hl_prefix = "Buffer"
    end
    self.win["set-statusline-state"](string.upper(string.sub(mode_name, 1, 1)), "# ", self.text, self.buf.name, #self.buf.indices, self.buf["line-count"](), self.selected_line(), self.debug_out, self.matcher().name, self.case(), hl_prefix, self.syntax())
    return vim.cmd("redrawstatus")
  end
  self.on_init = function()
    self.buf["apply-syntax"]()
    vim.api.nvim_win_set_cursor(0, {(self.selected_index + 1), 0})
    return prompt_mod.STATUS_PROGRESS
  end
  self.on_redraw = function()
    self.refresh_statusline()
    return prompt_mod.STATUS_PROGRESS
  end
  self.on_update = function(status)
    do
      local prev_text = self._prev_text
      local prev_hits = util.deepcopy(self.buf.indices)
      local prev_line = line_of_index(self.buf, self.selected_index)
      local reset_if = ((prev_text == "") or not vim.startswith(self.text, prev_text))
      self._prev_text = self.text
      self.updates = (self.updates + 1)
      self.buf["run-filter"](self.matcher(), self.text, self.ignorecase(), reset_if)
      if not vim.deep_equal(prev_hits, self.buf.indices) then
        self.buf.render()
        local idx = nil
        for i, src in ipairs(self.buf.indices) do
          if (src == prev_line) then
            idx = i
            __fnl_global__break()
          else
          end
        end
        if not idx then
          idx = self.buf["closest-index"](prev_line)
        else
        end
        if idx then
          self.selected_index = (idx - 1)
          vim.api.nvim_win_set_cursor(0, {idx, 0})
        else
        end
      else
      end
    end
    return status
  end
  self.store = function()
    return {text = self.text, ["caret-locus"] = self.caret["get-locus"](), ["selected-index"] = self.selected_index, ["matcher-index"] = self.mode.matcher.index, ["case-index"] = self.mode.case.index, ["syntax-index"] = self.mode.syntax.index, restored = true}
  end
  return self
end
return M
