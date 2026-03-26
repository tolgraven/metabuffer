-- [nfnl] fnl/metabuffer/custom/init.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local M = {}
local state = {config = {transforms = {}}, providers = {transform = {}}}
local function read_bytes(path)
  local uv = (vim.uv or vim.loop)
  if (uv and uv.fs_open and uv.fs_read and uv.fs_close and path) then
    local ok_open,fd = pcall(uv.fs_open, path, "r", 438)
    if (ok_open and fd) then
      local size
      local and_1_ = uv.fs_fstat
      if and_1_ then
        local ok_stat,stat = pcall(uv.fs_fstat, fd)
        and_1_ = (ok_stat and stat and stat.size)
      end
      size = (and_1_ or 0)
      local ok_read,chunk = pcall(uv.fs_read, fd, size, 0)
      pcall(uv.fs_close, fd)
      if ok_read then
        return (chunk or "")
      else
        return nil
      end
    else
      return nil
    end
  else
    return nil
  end
end
local function sorted_names(tbl)
  local out = {}
  for k, _ in pairs((tbl or {})) do
    table.insert(out, k)
  end
  table.sort(out)
  return out
end
local function normalize_command(cmd)
  if (type(cmd) == "string") then
    return {(vim.o.shell or "sh"), (vim.o.shellcmdflag or "-c"), cmd}
  else
    if (type(cmd) == "table") then
      return cmd
    else
      return nil
    end
  end
end
local function command_output(cmd, input)
  local argv = normalize_command(cmd)
  if (argv and (#argv > 0)) then
    local out = vim.fn.system(argv, (input or ""))
    if (vim.v.shell_error == 0) then
      return (out or "")
    else
      return nil
    end
  else
    return nil
  end
end
local function output_lines(txt)
  local out = vim.split((txt or ""), "\n", {plain = true, trimempty = false})
  while ((#out > 1) and (out[#out] == "")) do
    table.remove(out)
  end
  return out
end
local function detected_filetype(path)
  if ((type(path) == "string") and (path ~= "")) then
    local ok,ft = pcall(vim.filetype.match, {filename = path})
    if (ok and (type(ft) == "string") and (ft ~= "")) then
      return ft
    else
      return ""
    end
  else
    return ""
  end
end
local function accepts_filetype_3f(spec, path)
  local wanted = (spec.filetypes or {})
  local ft = detected_filetype(path)
  if ((type(wanted) == "~table") or (type(wanted) == "table")) then
    if (#wanted == 0) then
      return true
    else
      local matched = false
      local ok = matched
      for _, want in ipairs(wanted) do
        if (not ok and ((want or "") == ft)) then
          ok = true
        else
        end
      end
      return ok
    end
  else
    return true
  end
end
local function command_spec(spec, path)
  local ft = detected_filetype(path)
  local by_ft = (spec.filetype_commands or {})
  local ft_spec = ((ft ~= "") and by_ft[ft])
  if (type(ft_spec) == "table") then
    return ft_spec
  else
    return spec
  end
end
local function spec_command(spec, path, k)
  local resolved = command_spec(spec, path)
  return (resolved[k] or spec[k])
end
local function applies_to_3f(spec, path, ctx)
  local mode = (spec.applies_to or "text")
  local binary_3f = clj.boolean((ctx and ctx.binary))
  return (accepts_filetype_3f(spec, path) and ((mode == "all") or ((mode == "binary") and binary_3f) or ((mode == "text") and not binary_3f)))
end
local function line_applicable_3f(spec, path, line, ctx)
  local and_16_ = applies_to_3f(spec, path, ctx)
  if and_16_ then
    if (type(spec.should_apply_line) == "function") then
      and_16_ = clj.boolean(spec.should_apply_line(line, ctx))
    else
      if (type(spec.should_apply) == "function") then
        and_16_ = clj.boolean(spec.should_apply(line, ctx))
      else
        and_16_ = true
      end
    end
  end
  return and_16_
end
local function file_applicable_3f(spec, path, raw_lines, ctx)
  local and_19_ = applies_to_3f(spec, path, ctx)
  if and_19_ then
    if (type(spec.should_apply_file) == "function") then
      and_19_ = clj.boolean(spec.should_apply_file(path, raw_lines, ctx))
    else
      if (type(spec.should_apply) == "function") then
        and_19_ = clj.boolean(spec.should_apply(path, raw_lines, ctx))
      else
        and_19_ = true
      end
    end
  end
  return and_19_
end
local function transform_doc(name, spec)
  return (spec.doc or ("Run custom transform `" .. name .. "`."))
end
local function transform_key(name)
  return ("custom-transform:" .. name)
end
local function token_key(name)
  return ("include-" .. transform_key(name))
end
local function statusline_label(name, spec)
  return (spec.statusline or name)
end
local function line_transform_module(name, spec)
  local function _22_(line, ctx)
    return line_applicable_3f(spec, (ctx and ctx.path), line, ctx)
  end
  local function _23_(line, ctx)
    local val_110_auto = command_output(spec_command(spec, (ctx and ctx.path), "from"), (line or ""))
    if val_110_auto then
      local out = val_110_auto
      return output_lines(out)
    else
      return nil
    end
  end
  local function _25_(lines, ctx)
    local val_110_auto = spec_command(spec, (ctx and ctx.path), "to")
    if val_110_auto then
      local cmd = val_110_auto
      local val_110_auto0 = command_output(cmd, table.concat((lines or {}), "\n"))
      if val_110_auto0 then
        local out = val_110_auto0
        return {(string.gsub(out, "\n$", "") or out)}
      else
        return nil
      end
    else
      return nil
    end
  end
  return {["transform-key"] = transform_key(name), ["default-enabled"] = clj.boolean(spec.enabled), ["query-directive-specs"] = {{kind = "toggle", long = ("transform:" .. name), ["token-key"] = token_key(name), doc = transform_doc(name, spec), statusline = statusline_label(name, spec)}}, ["should-apply-line?"] = _22_, ["apply-line"] = _23_, ["reverse-line"] = _25_}
end
local function file_transform_module(name, spec)
  local function _28_(path, raw_lines, ctx)
    return file_applicable_3f(spec, ((ctx and ctx.path) or path), raw_lines, ctx)
  end
  local function _29_(path, raw_lines, _ctx)
    local ft_path = ((_ctx and _ctx.path) or path)
    local input = (read_bytes(path) or table.concat((raw_lines or {}), "\n"))
    local val_110_auto = command_output(spec_command(spec, ft_path, "from"), input)
    if val_110_auto then
      local out = val_110_auto
      return output_lines(out)
    else
      return nil
    end
  end
  local function _31_(lines, ctx)
    local val_110_auto = spec_command(spec, ((ctx and ctx.path) or ""), "to")
    if val_110_auto then
      local cmd = val_110_auto
      return command_output(cmd, table.concat((lines or {}), "\n"))
    else
      return nil
    end
  end
  return {["transform-key"] = transform_key(name), ["default-enabled"] = clj.boolean(spec.enabled), ["query-directive-specs"] = {{kind = "toggle", long = ("transform:" .. name), ["token-key"] = token_key(name), doc = transform_doc(name, spec), statusline = statusline_label(name, spec)}}, ["should-apply-file?"] = _28_, ["apply-file"] = _29_, ["reverse-file"] = _31_}
end
local function transform_module(name, spec)
  if ((spec.scope or "line") == "file") then
    return file_transform_module(name, spec)
  else
    return line_transform_module(name, spec)
  end
end
local function transform_modules(cfg)
  local out = {}
  for _, name in ipairs(sorted_names(cfg)) do
    local spec = cfg[name]
    if (type(spec) == "table") then
      table.insert(out, transform_module(name, spec))
    else
    end
  end
  return out
end
M["configure!"] = function(cfg)
  local config = vim.deepcopy((cfg or {transforms = {}}))
  local transforms = (config.transforms or {})
  state.config = {transforms = transforms}
  state.providers = {transform = transform_modules(transforms)}
  return state
end
M.modules = function(domain)
  return (state.providers[domain] or {})
end
M.config = function()
  return vim.deepcopy(state.config)
end
return M
