local digraph_mod = require("metabuffer.prompt.digraph")
local util = require("metabuffer.prompt.util")
local M = {}
M.ACTION_PATTERN = "^(%w+:%w+):?(.*)$"
M.new = function()
  local self = {registry = {}}
  self.clear = function()
    self.registry = {}
    return nil
  end
  self.register = function(name, callback)
    self.registry[name] = callback
    return nil
  end
  self.unregister = function(name, fail_silently)
    if self.registry[name] then
      self.registry[name] = nil
      return nil
    else
      if not fail_silently then
        return error(name)
      else
        return nil
      end
    end
  end
  self.register_from_rules = function(rules)
    for _, r in ipairs(rules) do
      self.register(r[1], r[2])
    end
    return nil
  end
  self.call = function(prompt, action)
    local name = (string.match(action, "^(%w+:%w+)") or action)
    local params = (string.match(action, "^%w+:%w+:(.*)$") or "")
    local label = string.match(name, ":(%w+)$")
    local alt = (label and ("prompt:" .. label))
    if (not self.registry[name] and alt and self.registry[alt]) then
      name = alt
    else
    end
    if self.registry[name] then
      return self.registry[name](prompt, params)
    else
      return error(("No action \"" .. name .. "\" has registered."))
    end
  end
  return self
end
local function _prompt_mod()
  return require("metabuffer.prompt.prompt")
end
local function _accept(_, _0)
  local p = _prompt_mod()
  return p.STATUS_ACCEPT
end
local function _cancel(_, _0)
  local p = _prompt_mod()
  return p.STATUS_CANCEL
end
local function _toggle_insert_mode(prompt, _)
  local p = _prompt_mod()
  if (prompt["insert-mode"] == p.INSERT_MODE_INSERT) then
    prompt["insert-mode"] = p.INSERT_MODE_REPLACE
    return nil
  else
    prompt["insert-mode"] = p.INSERT_MODE_INSERT
    return nil
  end
end
local function _delete_char_before_caret(prompt, _)
  local l = prompt.caret["get-locus"]()
  if (l > 0) then
    prompt.text = (string.sub(prompt.text, 1, (l - 1)) .. string.sub(prompt.text, (l + 1)))
    return prompt.caret["set-locus"]((l - 1))
  else
    return nil
  end
end
local function _delete_word_before_caret(prompt, _)
  local l = prompt.caret["get-locus"]()
  if (l > 0) then
    local back = prompt.caret["get-backward-text"]()
    local new = string.gsub(back, "[%w_]+%s*$", "", 1)
    local removed = (#back - #new)
    prompt.text = (new .. prompt.caret["get-selected-text"]() .. prompt.caret["get-forward-text"]())
    return prompt.caret["set-locus"]((l - removed))
  else
    return nil
  end
end
local function _delete_char_after_caret(prompt, _)
  if (prompt.caret["get-locus"]() < prompt.caret.tail()) then
    prompt.text = (prompt.caret["get-backward-text"]() .. prompt.caret["get-selected-text"]() .. string.sub(prompt.caret["get-forward-text"](), 2))
    return nil
  else
    return nil
  end
end
local function _delete_word_after_caret(prompt, _)
  local fwd = prompt.caret["get-forward-text"]()
  local trimmed = string.gsub(fwd, "^%s*[%w_]+%s*", "", 1)
  prompt.text = (prompt.caret["get-backward-text"]() .. prompt.caret["get-selected-text"]() .. trimmed)
  return nil
end
local function _delete_char_under_caret(prompt, _)
  prompt.text = (prompt.caret["get-backward-text"]() .. prompt.caret["get-forward-text"]())
  return nil
end
local function _delete_word_under_caret(prompt, _)
  if (prompt.text ~= "") then
    local back = string.gsub(prompt.caret["get-backward-text"](), "[%w_]+$", "", 1)
    local fwd = string.gsub(prompt.caret["get-forward-text"](), "^[%w_]+", "", 1)
    prompt.text = (back .. fwd)
    return prompt.caret["set-locus"](#back)
  else
    return nil
  end
end
local function _delete_text_before_caret(prompt, _)
  prompt.text = prompt.caret["get-forward-text"]()
  return prompt.caret["set-locus"](0)
end
local function _delete_text_after_caret(prompt, _)
  prompt.text = prompt.caret["get-backward-text"]()
  return prompt.caret["set-locus"](#prompt.text)
end
local function _delete_entire_text(prompt, _)
  prompt.text = ""
  return prompt.caret["set-locus"](0)
end
local function _move_caret_to_left(prompt, _)
  return prompt.caret["set-locus"]((prompt.caret["get-locus"]() - 1))
end
local function _move_caret_to_right(prompt, _)
  return prompt.caret["set-locus"]((prompt.caret["get-locus"]() + 1))
end
local function _move_caret_to_head(prompt, _)
  return prompt.caret["set-locus"](prompt.caret.head())
end
local function _move_caret_to_lead(prompt, _)
  return prompt.caret["set-locus"](prompt.caret.lead())
end
local function _move_caret_to_tail(prompt, _)
  return prompt.caret["set-locus"](prompt.caret.tail())
end
local function _move_caret_to_one_word_left(prompt, _)
  local txt = prompt.caret["get-backward-text"]()
  local new = string.gsub(txt, "%S+%s?$", "", 1)
  local off = (#txt - #new)
  local _10_
  if (off == 0) then
    _10_ = 1
  else
    _10_ = off
  end
  return prompt.caret["set-locus"]((prompt.caret["get-locus"]() - _10_))
end
local function _move_caret_to_one_word_right(prompt, _)
  local txt = prompt.caret["get-forward-text"]()
  local new = string.gsub(txt, "^%S+", "", 1)
  return prompt.caret["set-locus"]((prompt.caret["get-locus"]() + 1 + (#txt - #new)))
end
local function _move_caret_to_left_anchor(prompt, _)
  local anchor = util.int2char(util.getchar())
  local idx = string.find(prompt.caret["get-backward-text"](), anchor, 1, true)
  if idx then
    return prompt.caret["set-locus"]((idx - 1))
  else
    return nil
  end
end
local function _move_caret_to_right_anchor(prompt, _)
  local anchor = util.int2char(util.getchar())
  local idx = string.find(prompt.caret["get-forward-text"](), anchor, 1, true)
  if idx then
    return prompt.caret["set-locus"]((prompt.caret["get-locus"]() + idx))
  else
    return nil
  end
end
local function _assign_previous_text(prompt, _)
  prompt.text = prompt.history.previous()
  return prompt.caret["set-locus"](prompt.caret.tail())
end
local function _assign_next_text(prompt, _)
  prompt.text = prompt.history.next()
  return prompt.caret["set-locus"](prompt.caret.tail())
end
local function _assign_previous_matched_text(prompt, _)
  prompt.text = prompt.history["previous-match"]()
  return prompt.caret["set-locus"](prompt.caret.tail())
end
local function _assign_next_matched_text(prompt, _)
  prompt.text = prompt.history["next-match"]()
  return prompt.caret["set-locus"](prompt.caret.tail())
end
local function _paste_from_register(prompt, _)
  local st = prompt.store()
  prompt["update-text"]("\"")
  prompt["redraw-prompt"]()
  local reg = util.int2char(util.getchar())
  prompt.restore(st)
  return prompt["update-text"](vim.fn.getreg(reg))
end
local function _paste_from_default_register(prompt, _)
  return prompt["update-text"](vim.fn.getreg(vim.v.register))
end
local function _yank_to_register(prompt, _)
  local st = prompt.store()
  prompt["update-text"]("'")
  prompt["redraw-prompt"]()
  local reg = util.int2char(util.getchar())
  prompt.restore(st)
  return vim.fn.setreg(reg, prompt.text)
end
local function _yank_to_default_register(prompt, _)
  return vim.fn.setreg(vim.v.register, prompt.text)
end
local function _insert_special(prompt, _)
  local st = prompt.store()
  prompt["update-text"]("^")
  prompt["redraw-prompt"]()
  local code = util.getchar()
  prompt.restore(st)
  local function _14_()
    if (code == "<BS>") then
      return 8
    else
      return code
    end
  end
  return prompt["update-text"](util.int2repr(_14_()))
end
local function _insert_digraph(prompt, _)
  local st = prompt.store()
  prompt["update-text"]("?")
  prompt["redraw-prompt"]()
  local dg = digraph_mod.new()
  local ch = dg.retrieve(dg)
  prompt.restore(st)
  return prompt["update-text"](ch)
end
M.DEFAULT_ACTION = M.new()
M.DEFAULT_ACTION.register_from_rules({{"prompt:accept", _accept}, {"prompt:cancel", _cancel}, {"prompt:toggle_insert_mode", _toggle_insert_mode}, {"prompt:delete_char_before_caret", _delete_char_before_caret}, {"prompt:delete_word_before_caret", _delete_word_before_caret}, {"prompt:delete_char_after_caret", _delete_char_after_caret}, {"prompt:delete_word_after_caret", _delete_word_after_caret}, {"prompt:delete_char_under_caret", _delete_char_under_caret}, {"prompt:delete_word_under_caret", _delete_word_under_caret}, {"prompt:delete_text_before_caret", _delete_text_before_caret}, {"prompt:delete_text_after_caret", _delete_text_after_caret}, {"prompt:delete_entire_text", _delete_entire_text}, {"prompt:move_caret_to_left", _move_caret_to_left}, {"prompt:move_caret_to_one_word_left", _move_caret_to_one_word_left}, {"prompt:move_caret_to_left_anchor", _move_caret_to_left_anchor}, {"prompt:move_caret_to_right", _move_caret_to_right}, {"prompt:move_caret_to_one_word_right", _move_caret_to_one_word_right}, {"prompt:move_caret_to_right_anchor", _move_caret_to_right_anchor}, {"prompt:move_caret_to_head", _move_caret_to_head}, {"prompt:move_caret_to_lead", _move_caret_to_lead}, {"prompt:move_caret_to_tail", _move_caret_to_tail}, {"prompt:assign_previous_text", _assign_previous_text}, {"prompt:assign_next_text", _assign_next_text}, {"prompt:assign_previous_matched_text", _assign_previous_matched_text}, {"prompt:assign_next_matched_text", _assign_next_matched_text}, {"prompt:paste_from_register", _paste_from_register}, {"prompt:paste_from_default_register", _paste_from_default_register}, {"prompt:yank_to_register", _yank_to_register}, {"prompt:yank_to_default_register", _yank_to_default_register}, {"prompt:insert_special", _insert_special}, {"prompt:insert_digraph", _insert_digraph}})
return M
