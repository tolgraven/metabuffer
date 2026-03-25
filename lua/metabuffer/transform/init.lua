-- [nfnl] fnl/metabuffer/transform/init.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local custom_mod = require("metabuffer.custom")
local hex = require("metabuffer.transform.hex")
local strings = require("metabuffer.transform.strings")
local b64 = require("metabuffer.transform.b64")
local bplist = require("metabuffer.transform.bplist")
local json = require("metabuffer.transform.json")
local xml = require("metabuffer.transform.xml")
local css = require("metabuffer.transform.css")
local M = {}
local builtin_modules = {bplist, hex, strings, b64, json, xml, css}
local function modules()
  local out = {}
  for _, mod in ipairs(builtin_modules) do
    table.insert(out, mod)
  end
  for _, mod in ipairs(custom_mod.modules("transform")) do
    table.insert(out, mod)
  end
  return out
end
local function state_key(name)
  return ("include-" .. (name or ""))
end
local function effective_state_key(name)
  return ("effective-" .. state_key(name))
end
local function setting_key(name)
  return ("default-include-" .. (name or ""))
end
local function module_key(mod)
  return (mod["transform-key"] or "")
end
local function all_specs()
  local out = {}
  for _, mod in ipairs(modules()) do
    local specs
    if (type(mod["query-directive-specs"]) == "function") then
      specs = mod["query-directive-specs"]()
    else
      specs = (mod["query-directive-specs"] or {})
    end
    for _0, spec in ipairs(specs) do
      table.insert(out, spec)
    end
  end
  return out
end
M["query-directive-specs"] = all_specs
M.modules = function()
  return modules()
end
M["module-keys"] = function()
  local out = {}
  for _, mod in ipairs(modules()) do
    table.insert(out, module_key(mod))
  end
  return out
end
local function session_flag(session, name)
  return ((session and session["effective-transforms"] and session["effective-transforms"][name]) or (session and session["transform-flags"] and session["transform-flags"][name]) or (session and session[effective_state_key(name)]) or (session and session[state_key(name)]))
end
M["enabled-map"] = function(parsed, session, settings)
  local out = {}
  for _, mod in ipairs(modules()) do
    local name = module_key(mod)
    local key = state_key(name)
    local parsed_v = (parsed and parsed[key])
    local session_v = session_flag(session, name)
    local setting_v = (settings and settings[setting_key(name)])
    local module_default = mod["default-enabled"]
    local value
    if (parsed_v ~= nil) then
      value = parsed_v
    else
      if (session_v ~= nil) then
        value = session_v
      else
        if (setting_v ~= nil) then
          value = setting_v
        else
          value = module_default
        end
      end
    end
    out[name] = clj.boolean(value)
  end
  return out
end
local function compat_key(mod)
  local specs
  if (type(mod["query-directive-specs"]) == "function") then
    specs = mod["query-directive-specs"]()
  else
    specs = (mod["query-directive-specs"] or {})
  end
  local spec = specs[1]
  return (spec and spec["compat-key"])
end
M["apply-flags!"] = function(target, flags)
  if target then
    target["transform-flags"] = vim.deepcopy((flags or {}))
    target["effective-transforms"] = vim.deepcopy((flags or {}))
    for _, mod in ipairs(modules()) do
      local name = module_key(mod)
      local enabled = clj.boolean((flags or {})[name])
      local key = state_key(name)
      local compat = compat_key(mod)
      target[key] = enabled
      target[effective_state_key(name)] = enabled
      if compat then
        target[compat] = enabled
      else
      end
    end
  else
  end
  return target
end
M["compat-view"] = function(flags)
  local out = {}
  for _, mod in ipairs(modules()) do
    local name = module_key(mod)
    local enabled = clj.boolean((flags or {})[name])
    local key = state_key(name)
    local compat = compat_key(mod)
    out[key] = enabled
    if compat then
      out[compat] = enabled
    else
    end
  end
  return out
end
M.signature = function(flags)
  local parts = {}
  for _, mod in ipairs(modules()) do
    local name = module_key(mod)
    if flags[name] then
      table.insert(parts, name)
    else
    end
  end
  return table.concat(parts, "|")
end
local function identity_view(lines)
  local out = {}
  local line_map = {}
  local row_meta = {}
  for lnum, line in ipairs((lines or {})) do
    table.insert(out, (line or ""))
    table.insert(line_map, lnum)
    table.insert(row_meta, {["source-lnum"] = lnum, ["source-text"] = (line or ""), ["source-group-id"] = lnum, ["source-group-kind"] = "line", ["transform-chain"] = {}})
  end
  return {lines = out, ["line-map"] = line_map, ["row-meta"] = row_meta}
end
local function file_view(lines, transform_name)
  local out = {}
  local line_map = {}
  local row_meta = {}
  for _, line in ipairs((lines or {})) do
    table.insert(out, (line or ""))
    table.insert(line_map, 1)
    table.insert(row_meta, {["source-lnum"] = 1, ["source-group-id"] = 1, ["source-group-kind"] = "file", ["transform-chain"] = {transform_name}})
  end
  return {lines = out, ["line-map"] = line_map, ["row-meta"] = row_meta}
end
local function limited_lines(lines)
  local cap = 400
  if (#(lines or {}) <= cap) then
    return (lines or {})
  else
    local out = {}
    for i = 1, cap do
      table.insert(out, lines[i])
    end
    table.insert(out, "... [transform truncated]")
    return out
  end
end
local function wrap_one_line(line, width, linebreak_3f)
  local txt = (line or "")
  local maxw = math.max(1, (width or 1))
  local out = {}
  if (vim.fn.strdisplaywidth(txt) <= maxw) then
    return {txt}
  else
    local rest = txt
    while (#rest > 0) do
      if (vim.fn.strdisplaywidth(rest) <= maxw) then
        table.insert(out, rest)
        rest = ""
      else
        local chars = vim.fn.strchars(rest)
        local cut0 = 1
        local cut = cut0
        for i = 1, chars do
          if (vim.fn.strdisplaywidth(vim.fn.strcharpart(rest, 0, i)) <= maxw) then
            cut = i
          else
          end
        end
        if (linebreak_3f and (cut > 1)) then
          local chunk0 = vim.fn.strcharpart(rest, 0, cut)
          local ws = string.match(chunk0, ".*()%s+%S*$")
          if (ws and (ws > 1)) then
            cut = (ws - 1)
          else
          end
        else
        end
        local chunk = vim.trim(vim.fn.strcharpart(rest, 0, cut))
        local next_rest = vim.trim(vim.fn.strcharpart(rest, cut))
        local function _14_()
          if (chunk == "") then
            return vim.fn.strcharpart(rest, 0, cut)
          else
            return chunk
          end
        end
        table.insert(out, _14_())
        rest = next_rest
      end
    end
    if (#out > 0) then
      return out
    else
      return {""}
    end
  end
end
local function wrap_view(view, width, linebreak_3f)
  local out = {}
  local line_map = {}
  local row_meta = {}
  for idx, line in ipairs((view.lines or {})) do
    local mapped = (view["line-map"][idx] or idx)
    local meta = (view["row-meta"][idx] or {["source-lnum"] = mapped, ["source-text"] = (line or ""), ["source-group-id"] = mapped, ["source-group-kind"] = "line", ["transform-chain"] = {}})
    local chunks = wrap_one_line(line, width, linebreak_3f)
    for _, chunk in ipairs(chunks) do
      table.insert(out, chunk)
      table.insert(line_map, mapped)
      table.insert(row_meta, vim.deepcopy(meta))
    end
  end
  return {lines = out, ["line-map"] = line_map, ["row-meta"] = row_meta}
end
local function apply_line_transform(view, mod, ctx)
  local out = {}
  local line_map = {}
  local row_meta = {}
  for idx, line in ipairs((view.lines or {})) do
    local orig_lnum = (view["line-map"][idx] or idx)
    local meta0 = (view["row-meta"][idx] or {["source-lnum"] = orig_lnum, ["source-text"] = (line or ""), ["source-group-id"] = orig_lnum, ["source-group-kind"] = "line", ["transform-chain"] = {}})
    local local_ctx = vim.tbl_extend("force", ctx, {lnum = orig_lnum})
    if mod["should-apply-line?"](line, local_ctx) then
      local produced = limited_lines(mod["apply-line"](line, local_ctx))
      if (#produced > 0) then
        for _, item in ipairs(produced) do
          table.insert(out, (item or ""))
          table.insert(line_map, orig_lnum)
          table.insert(row_meta, vim.tbl_extend("force", vim.deepcopy(meta0), {["transform-chain"] = vim.list_extend(vim.deepcopy((meta0["transform-chain"] or {})), {module_key(mod)})}))
        end
      else
        table.insert(out, (line or ""))
        table.insert(line_map, orig_lnum)
        table.insert(row_meta, vim.deepcopy(meta0))
      end
    else
      table.insert(out, (line or ""))
      table.insert(line_map, orig_lnum)
      table.insert(row_meta, vim.deepcopy(meta0))
    end
  end
  return {lines = out, ["line-map"] = line_map, ["row-meta"] = row_meta}
end
local function module_by_name(name)
  local found = nil
  local out = found
  for _, mod in ipairs(modules()) do
    if (not out and (module_key(mod) == name)) then
      out = mod
    else
    end
  end
  return out
end
local function reverse_line_group(meta, lines, ctx)
  local chain = vim.deepcopy((meta["transform-chain"] or {}))
  local current = vim.deepcopy((lines or {}))
  local cur = current
  for i = #chain, 1, -1 do
    local mod = module_by_name(chain[i])
    local f = (mod and mod["reverse-line"])
    if (type(f) == "function") then
      cur = (f(cur, ctx) or cur)
    else
      cur = nil
    end
  end
  return cur
end
local function reverse_file_group(meta, lines, ctx)
  local chain = vim.deepcopy((meta["transform-chain"] or {}))
  local out = nil
  local cur = out
  for i = #chain, 1, -1 do
    local mod = module_by_name(chain[i])
    local f = (mod and mod["reverse-file"])
    if (type(f) == "function") then
      cur = f((cur or lines), ctx)
    else
      cur = nil
    end
  end
  return cur
end
M["reverse-group"] = function(meta, lines, ctx)
  local kind = (meta["source-group-kind"] or "line")
  local chain = (meta["transform-chain"] or {})
  if (kind == "file") then
    local blob = reverse_file_group(meta, lines, ctx)
    if blob then
      return {kind = "rewrite-bytes", bytes = blob}
    else
      return {error = "non-reversible file transform"}
    end
  else
    local collapsed
    if (#chain > 0) then
      collapsed = reverse_line_group(meta, lines, ctx)
    else
      collapsed = {table.concat((lines or {}), "")}
    end
    if (collapsed and (#collapsed == 1)) then
      return {kind = "replace", text = (collapsed[1] or "")}
    else
      return {error = "non-reversible line transform"}
    end
  end
end
M["apply-view"] = function(path, raw_lines, ctx)
  local flags = ((ctx and ctx.transforms) or {})
  local wrap_width = (ctx and ctx["wrap-width"])
  local linebreak_3f
  if ((ctx and ctx.linebreak) == nil) then
    linebreak_3f = true
  else
    linebreak_3f = clj.boolean(ctx.linebreak)
  end
  local file_view0 = nil
  local file_view1 = file_view0
  for _, mod in ipairs(modules()) do
    if (not file_view1 and flags[module_key(mod)] and (type(mod["should-apply-file?"]) == "function") and (type(mod["apply-file"]) == "function") and mod["should-apply-file?"](path, raw_lines, ctx)) then
      local produced = mod["apply-file"](path, raw_lines, ctx)
      if ((type(produced) == "table") and (#produced > 0)) then
        file_view1 = file_view(limited_lines(produced), module_key(mod))
      else
      end
    else
    end
  end
  local view0
  local or_30_ = file_view1
  if not or_30_ then
    local view = identity_view(raw_lines)
    local current = view
    for _, mod in ipairs(modules()) do
      if (flags[module_key(mod)] and (type(mod["should-apply-line?"]) == "function") and (type(mod["apply-line"]) == "function")) then
        current = apply_line_transform(current, mod, ctx)
      else
      end
    end
    or_30_ = current
  end
  view0 = or_30_
  if (wrap_width and (wrap_width > 0)) then
    return wrap_view(view0, wrap_width, linebreak_3f)
  else
    return view0
  end
end
M["active-names"] = function(flags)
  local out = {}
  for _, mod in ipairs(modules()) do
    local name = module_key(mod)
    if (flags or {})[name] then
      table.insert(out, name)
    else
    end
  end
  return out
end
return M
