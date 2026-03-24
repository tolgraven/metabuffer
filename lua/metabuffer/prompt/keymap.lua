-- [nfnl] fnl/metabuffer/prompt/keymap.fnl
local key_mod = require("metabuffer.prompt.key")
local ks_mod = require("metabuffer.prompt.keystroke")
local debug = require("metabuffer.debug")
local M = {}
local function debug_log(msg)
  return debug.log("keymap", msg)
end
local function parse_flags(flags)
  local out = {expr = false, noremap = false, nowait = false}
  for _, flag in ipairs(vim.split((flags or ""), " ", {trimempty = true})) do
    if (flag == "noremap") then
      out.noremap = true
    else
      if (flag == "nowait") then
        out.nowait = true
      else
        if (flag == "expr") then
          out.expr = true
        else
          error(("Unknown flag \"" .. flag .. "\" has specified."))
        end
      end
    end
  end
  return out
end
local function parse_definition(nvim, rule)
  local lhs = rule[1]
  local rhs = rule[2]
  local flags = rule[3]
  local opts = parse_flags(flags)
  local _4_
  if opts.expr then
    _4_ = rhs
  else
    _4_ = ks_mod.parse(nvim, rhs)
  end
  return {lhs = ks_mod.parse(nvim, lhs), rhs = _4_, noremap = opts.noremap, nowait = opts.nowait, expr = opts.expr}
end
local function _getcode(_timeoutlen, callback, _interval)
  if callback then
    callback()
  else
  end
  local packed = {pcall(vim.fn.getcharstr)}
  local ok = packed[1]
  if ok then
    local code = packed[2]
    debug_log(("[keymap] raw=" .. tostring(vim.fn.keytrans(code))))
    return code
  else
    return nil
  end
end
M.new = function()
  local self = {registry = {}}
  self.clear = function()
    self.registry = {}
    return nil
  end
  self.register = function(definition)
    self.registry[tostring(definition.lhs)] = definition
    return nil
  end
  self.register_from_rule = function(nvim, rule)
    return self.register(parse_definition(nvim, rule))
  end
  self.register_from_rules = function(nvim, rules)
    for _, rule in ipairs(rules) do
      self.register_from_rule(nvim, rule)
    end
    return nil
  end
  self.filter = function(lhs)
    local out = {}
    local probe = tostring(lhs)
    for _, def in pairs(self.registry) do
      if vim.startswith(tostring(def.lhs), probe) then
        table.insert(out, def)
      else
      end
    end
    local function _9_(a, b)
      return (tostring(a.lhs) < tostring(b.lhs))
    end
    table.sort(out, _9_)
    return out
  end
  self._resolve = function(nvim, definition)
    local rhs
    if definition.expr then
      rhs = ks_mod.parse(nvim, vim.fn.eval(definition.rhs))
    else
      rhs = definition.rhs
    end
    if definition.noremap then
      return rhs
    else
      return self.resolve(nvim, rhs, true)
    end
  end
  self.resolve = function(nvim, lhs, nowait)
    local candidates = self.filter(lhs)
    local n = #candidates
    if (n == 0) then
      return lhs
    else
      if (n == 1) then
        local d = candidates[1]
        if (tostring(d.lhs) == tostring(lhs)) then
          return self._resolve(nvim, d)
        else
          return nil
        end
      else
        if nowait then
          local d = candidates[1]
          if (tostring(d.lhs) == tostring(lhs)) then
            return self._resolve(nvim, d)
          else
            return nil
          end
        else
          local d = candidates[1]
          if (d.nowait and (tostring(d.lhs) == tostring(lhs))) then
            return self._resolve(nvim, d)
          else
            return nil
          end
        end
      end
    end
  end
  self.harvest = function(nvim, timeoutlen, callback, interval)
    local previous = nil
    local resolved = nil
    local function feed_key(k)
      if previous then
        previous = ks_mod.concat(previous, {k})
      else
        previous = ks_mod.parse(nvim, {k})
      end
      local ks = self.resolve(nvim, previous, false)
      if ks then
        resolved = ks
        return nil
      else
        return nil
      end
    end
    while not resolved do
      local code = _getcode(timeoutlen, callback, interval)
      if (code == nil) then
        if previous then
          resolved = (self.resolve(nvim, previous, true) or previous)
        else
        end
      else
        local chunk
        if (type(code) == "string") then
          if string.find(code, "\128", 1, true) then
            chunk = {key_mod.parse(nvim, code)}
          else
            chunk = ks_mod.parse(nvim, code)
          end
        else
          chunk = {key_mod.parse(nvim, code)}
        end
        for _, k in ipairs(chunk) do
          if not resolved then
            feed_key(k)
          else
          end
        end
      end
    end
    debug_log(("[keymap] resolved=" .. tostring(resolved)))
    return resolved
  end
  return self
end
M.from_rules = function(nvim, rules)
  local km = M.new()
  km.register_from_rules(nvim, rules)
  return km
end
local default_keymap_rules = {{"<C-B>", "<prompt:move_caret_to_head>", "noremap"}, {"<C-E>", "<prompt:move_caret_to_tail>", "noremap"}, {"<BS>", "<prompt:delete_char_before_caret>", "noremap"}, {"<C-H>", "<prompt:delete_char_before_caret>", "noremap"}, {"<S-TAB>", "<prompt:assign_previous_text>", "noremap"}, {"<C-J>", "<prompt:accept>", "noremap"}, {"<C-K>", "<prompt:insert_digraph>", "noremap"}, {"<CR>", "<prompt:accept>", "noremap"}, {"<C-M>", "<prompt:accept>", "noremap"}, {"<C-N>", "<prompt:assign_next_text>", "noremap"}, {"<C-P>", "<prompt:assign_previous_text>", "noremap"}, {"<C-Q>", "<prompt:insert_special>", "noremap"}, {"<C-R>", "<prompt:paste_from_register>", "noremap"}, {"<C-U>", "<prompt:delete_entire_text>", "noremap"}, {"<C-V>", "<prompt:insert_special>", "noremap"}, {"<C-W>", "<prompt:delete_word_before_caret>", "noremap"}, {"<ESC>", "<prompt:cancel>", "noremap"}, {"<DEL>", "<prompt:delete_char_under_caret>", "noremap"}, {"<Left>", "<prompt:move_caret_to_left>", "noremap"}, {"<S-Left>", "<prompt:move_caret_to_one_word_left>", "noremap"}, {"<C-Left>", "<prompt:move_caret_to_one_word_left>", "noremap"}, {"<Right>", "<prompt:move_caret_to_right>", "noremap"}, {"<S-Right>", "<prompt:move_caret_to_one_word_right>", "noremap"}, {"<C-Right>", "<prompt:move_caret_to_one_word_right>", "noremap"}, {"<Up>", "<prompt:assign_previous_matched_text>", "noremap"}, {"<S-Up>", "<prompt:assign_previous_text>", "noremap"}, {"<Down>", "<prompt:assign_next_matched_text>", "noremap"}, {"<S-Down>", "<prompt:assign_next_text>", "noremap"}, {"<Home>", "<prompt:move_caret_to_head>", "noremap"}, {"<End>", "<prompt:move_caret_to_tail>", "noremap"}, {"<PageDown>", "<prompt:assign_next_text>", "noremap"}, {"<PageUp>", "<prompt:assign_previous_text>", "noremap"}, {"<INSERT>", "<prompt:toggle_insert_mode>", "noremap"}}
if (type(vim.g.meta_legacy_prompt_keymap_rules) == "table") then
  M.DEFAULT_KEYMAP_RULES = vim.g.meta_legacy_prompt_keymap_rules
else
  M.DEFAULT_KEYMAP_RULES = default_keymap_rules
end
M["default-keymap-rules"] = function()
  return M.DEFAULT_KEYMAP_RULES
end
return M
