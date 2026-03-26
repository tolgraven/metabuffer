-- [nfnl] fnl/metabuffer/transform/bplist.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local M = {}
M["transform-key"] = "bplist"
M["query-directive-specs"] = {{kind = "toggle", long = "bplist", ["token-key"] = "include-bplist", doc = "Pretty-print binary plist files.", ["compat-key"] = "bplist"}}
local function binary_plist_3f(ctx)
  local head = ((ctx and ctx.head) or "")
  return vim.startswith(head, "bplist00")
end
local function plutil_lines(path)
  if (1 == vim.fn.executable("plutil")) then
    local out = vim.fn.systemlist({"plutil", "-convert", "xml1", "-o", "-", path})
    if (vim.v.shell_error == 0) then
      return out
    else
      return nil
    end
  else
    return nil
  end
end
local function plist__3ebplist(lines)
  if (1 == vim.fn.executable("plutil")) then
    local input = table.concat((lines or {}), "\n")
    local out = vim.fn.system({"plutil", "-convert", "binary1", "-o", "-", "-"}, input)
    if (vim.v.shell_error == 0) then
      return out
    else
      return nil
    end
  else
    return nil
  end
end
M["should-apply-file?"] = function(_path, _raw_lines, ctx)
  return (clj.boolean((ctx and ctx.binary)) and binary_plist_3f(ctx))
end
M["apply-file"] = function(path, _raw_lines, _ctx)
  return plutil_lines(path)
end
M["reverse-file"] = function(lines, _ctx)
  return plist__3ebplist(lines)
end
return M
