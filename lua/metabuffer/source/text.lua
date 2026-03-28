-- [nfnl] fnl/metabuffer/source/text.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local path_hl = require("metabuffer.path_highlight")
local util = require("metabuffer.util")
local file_info = require("metabuffer.source.file_info")
local M = {}
M["provider-key"] = "text"
local function ref_path(session, ref)
  local or_1_ = (ref and ref.path)
  if not or_1_ then
    local and_2_ = session and session["source-buf"] and vim.api.nvim_buf_is_valid(session["source-buf"])
    if and_2_ then
      local name = vim.api.nvim_buf_get_name(session["source-buf"])
      if ((type(name) == "string") and (name ~= "")) then
        and_2_ = name
      else
        and_2_ = nil
      end
    end
    or_1_ = and_2_
  end
  return (or_1_ or "")
end
local function icon_field(icon)
  if ((type(icon) == "string") and (icon ~= "")) then
    local text = (icon .. " ")
    return {text = text, width = vim.fn.strdisplaywidth(text)}
  else
    return {text = "", width = 0}
  end
end
local function split_source_path(path)
  local p = (path or "")
  local rel
  if (p ~= "") then
    rel = vim.fn.fnamemodify(p, ":~:.")
  else
    rel = "[Current Buffer]"
  end
  local dir = vim.fn.fnamemodify(rel, ":h")
  local file = vim.fn.fnamemodify(rel, ":t")
  local dir_part
  if (dir and (dir ~= ".") and (dir ~= "")) then
    dir_part = (dir .. "/")
  else
    dir_part = ""
  end
  return {dir = dir_part, file = file, path = rel}
end
local function ext_range(file, file_start)
  local n = #(file or "")
  local dot = string.match((file or ""), ".*()%.")
  if (dot and (dot > 1) and (dot < n)) then
    return {start = (file_start + (dot - 1)), ["end"] = (file_start + n)}
  else
    return {start = 0, ["end"] = 0}
  end
end
M["path-prefix"] = function(ref)
  local parts = split_source_path(ref.path)
  local icon_info = util["file-icon-info"]((ref.path or ""), "Normal")
  local iconf = icon_field((icon_info.icon or ""))
  local icon_prefix = iconf.text
  local dir = (parts.dir or "")
  local file = (parts.file or "")
  local dir_start = #icon_prefix
  local file_start = (dir_start + #dir)
  local ex = ext_range(file, file_start)
  return {text = (icon_prefix .. dir .. file), ["lnum-end"] = 0, ["icon-start"] = 0, ["icon-end"] = #icon_prefix, ["icon-hl"] = (icon_info["icon-hl"] or "Normal"), ["dir-ranges"] = path_hl["ranges-for-dir"](dir, dir_start), ["file-start"] = file_start, ["file-end"] = (file_start + #file), ["file-hl"] = (icon_info["file-hl"] or "Normal"), ["ext-start"] = ex.start, ["ext-end"] = ex["end"], ["ext-hl"] = (icon_info["ext-hl"] or "Normal"), dir = dir, file = file, path = (parts.path or "")}
end
M["hit-prefix"] = function(_ref)
  return {text = "", ["lnum-end"] = 0, ["icon-start"] = 0, ["icon-end"] = 0, ["icon-hl"] = "MetaSourceFile", ["dir-ranges"] = {}, ["file-start"] = 0, ["file-end"] = 0, ["file-hl"] = "MetaSourceFile", ["ext-start"] = 0, ["ext-end"] = 0, ["ext-hl"] = "MetaSourceFile", dir = "", file = "", path = ""}
end
M["info-path"] = function(ref, full_path_3f)
  local path0 = ((ref and ref.path) or "")
  if (path0 == "") then
    return "[Current Buffer]"
  else
    if full_path_3f then
      return vim.fn.fnamemodify(path0, ":.")
    else
      return vim.fn.fnamemodify(path0, ":~:.")
    end
  end
end
M["info-suffix"] = function(_session, _ref, _mode, _read_file_lines_cached, _read_file_view_cached)
  return ""
end
M["info-meta"] = function(_session, _ref)
  return nil
end
local function source_sign(_ref)
  return util["icon-sign"]({category = "", name = "", fallback = "\243\176\136\148", hl = "MetaSourceFile"})
end
M["info-view"] = function(session, ref, ctx)
  local mode = ((ctx and ctx.mode) or "meta")
  local read_file_lines_cached = (ctx and ctx["read-file-lines-cached"])
  local read_file_view_cached = (ctx and ctx["read-file-view-cached"])
  local single_source_3f = clj.boolean((ctx and ctx["single-source?"]))
  local sign = source_sign(ref)
  if single_source_3f then
    local path = ref_path(session, ref)
    if (session["single-file-info-ready"] and ref and (path ~= "") and ref.lnum and (1 == vim.fn.filereadable(path))) then
      local view = file_info["line-meta-info-view"](session, path, ref.lnum, 1)
      view["sign"] = sign
      return view
    else
      return {path = "", ["icon-path"] = "", sign = sign, suffix = M["info-suffix"](session, ref, mode, read_file_lines_cached, read_file_view_cached), ["suffix-prefix"] = "", ["suffix-highlights"] = {}, ["highlight-dir"] = false, ["highlight-file"] = false, ["show-icon"] = false}
    end
  else
    return {path = M["info-path"](ref, false), ["icon-path"] = M["info-path"](ref, false), ["show-icon"] = true, ["highlight-dir"] = true, ["highlight-file"] = true, sign = sign, suffix = M["info-suffix"](session, ref, mode, read_file_lines_cached, read_file_view_cached), ["suffix-prefix"] = "  ", ["suffix-highlights"] = {}}
  end
end
M["preview-filetype"] = function(ref)
  if (ref and ref.buf and vim.api.nvim_buf_is_valid(ref.buf)) then
    return vim.bo[ref.buf].filetype
  else
    if (ref and ref.path) then
      local ok,ft = pcall(vim.filetype.match, {filename = ref.path})
      if (ok and (type(ft) == "string")) then
        return ft
      else
        return ""
      end
    else
      return ""
    end
  end
end
local function trim_or_pad_lines(lines, target)
  local out = {}
  for _, line in ipairs((lines or {})) do
    if (#out < target) then
      table.insert(out, (line or ""))
    else
    end
  end
  while (#out < target) do
    table.insert(out, "")
  end
  return out
end
M["preview-lines"] = function(session, ref, height, read_file_lines_cached, read_file_view_cached)
  local h = math.max(1, height)
  local lnum = math.max(1, ((ref and ref["preview-lnum"]) or (ref and ref.lnum) or 1))
  local start = math.max(1, (lnum - 1))
  if (ref and ref.buf and vim.api.nvim_buf_is_valid(ref.buf)) then
    local stop = (start + h + -1)
    return {["start-lnum"] = start, ["focus-lnum"] = lnum, lines = trim_or_pad_lines(vim.api.nvim_buf_get_lines(ref.buf, (start - 1), stop, false), h)}
  else
    if (ref and ref.path and (1 == vim.fn.filereadable(ref.path))) then
      local view = ((read_file_view_cached and read_file_view_cached(ref.path, {["include-binary"] = (session and session["effective-include-binary"]), transforms = ((session and session["effective-transforms"]) or (session and session["transform-flags"]) or {})})) or {lines = (read_file_lines_cached(ref.path, {["include-binary"] = (session and session["effective-include-binary"]), ["hex-view"] = (session and session["effective-include-hex"])}) or {}), ["line-map"] = {}})
      local all = (view.lines or {})
      local line_map = (view["line-map"] or {})
      local start_idx0 = nil
      local start_idx = start_idx0
      for idx, mapped in ipairs(line_map) do
        if (not start_idx and (mapped == lnum)) then
          start_idx = idx
        else
        end
      end
      local start_idx1 = (start_idx or start)
      local stop = (start_idx1 + h + -1)
      local slice = {}
      for i = start_idx1, stop do
        table.insert(slice, (all[i] or ""))
      end
      return {["start-lnum"] = start, ["focus-lnum"] = lnum, lines = trim_or_pad_lines(slice, h)}
    else
      return {["start-lnum"] = 1, ["focus-lnum"] = 1, lines = trim_or_pad_lines({}, h)}
    end
  end
end
local function apply_op_to_loaded_buffer_21(buf, op, delta)
  if (op.kind == "rewrite-bytes") then
    local path = vim.api.nvim_buf_get_name(buf)
    local uv = (vim.uv or vim.loop)
    local bytes = (op.bytes or "")
    local ok_3f = (uv and uv.fs_open and uv.fs_write and uv.fs_close and path)
    if ok_3f then
      local ok_open,fd = pcall(uv.fs_open, path, "w", 420)
      if (ok_open and fd) then
        pcall(uv.fs_write, fd, bytes, 0)
        pcall(uv.fs_close, fd)
      else
      end
      return {delta, 1}
    else
      return {delta, 0}
    end
  elseif (op.kind == "replace") then
    local lnum = (op.lnum + delta)
    local line_count = vim.api.nvim_buf_line_count(buf)
    if ((lnum >= 1) and (lnum <= line_count)) then
      local old = (vim.api.nvim_buf_get_lines(buf, (lnum - 1), lnum, false)[1] or "")
      local new = (op.text or "")
      if (old ~= new) then
        vim.api.nvim_buf_set_lines(buf, (lnum - 1), lnum, false, {new})
        return {delta, 1}
      else
        return {delta, 0}
      end
    else
      return {delta, 0}
    end
  elseif (op.kind == "delete") then
    local lnum = (op.lnum + delta)
    local line_count = vim.api.nvim_buf_line_count(buf)
    if ((lnum >= 1) and (lnum <= line_count)) then
      vim.api.nvim_buf_set_lines(buf, (lnum - 1), lnum, false, {})
      return {(delta - 1), 1}
    else
      return {delta, 0}
    end
  elseif (op.kind == "insert-before") then
    local ins = (op.lines or {})
    local lnum = (op.lnum + delta)
    local pos = math.max(1, math.min((vim.api.nvim_buf_line_count(buf) + 1), lnum))
    if (#ins > 0) then
      vim.api.nvim_buf_set_lines(buf, (pos - 1), (pos - 1), false, ins)
      return {(delta + #ins), #ins}
    else
      return {delta, 0}
    end
  else
    local ins = (op.lines or {})
    local lnum = (op.lnum + delta)
    local pos = math.max(0, math.min(vim.api.nvim_buf_line_count(buf), lnum))
    if (#ins > 0) then
      vim.api.nvim_buf_set_lines(buf, pos, pos, false, ins)
      return {(delta + #ins), #ins}
    else
      return {delta, 0}
    end
  end
end
local function apply_op_to_lines_21(lines, op, delta)
  if (op.kind == "rewrite-bytes") then
    return {delta, 0}
  elseif (op.kind == "replace") then
    local lnum = (op.lnum + delta)
    if ((lnum >= 1) and (lnum <= #lines) and (lines[lnum] ~= op.text)) then
      lines[lnum] = op.text
      return {delta, 1}
    else
      return {delta, 0}
    end
  elseif (op.kind == "delete") then
    local lnum = (op.lnum + delta)
    if ((lnum >= 1) and (lnum <= #lines)) then
      table.remove(lines, lnum)
      return {(delta - 1), 1}
    else
      return {delta, 0}
    end
  elseif (op.kind == "insert-before") then
    local ins = (op.lines or {})
    local lnum = (op.lnum + delta)
    local pos = math.max(1, math.min((#lines + 1), lnum))
    if (#ins > 0) then
      for i = 1, #ins do
        table.insert(lines, (pos + i + -1), ins[i])
      end
      return {(delta + #ins), #ins}
    else
      return {delta, 0}
    end
  else
    local ins = (op.lines or {})
    local lnum = (op.lnum + delta)
    local pos = math.max(0, math.min(#lines, lnum))
    if (#ins > 0) then
      for i = 1, #ins do
        table.insert(lines, (pos + i), ins[i])
      end
      return {(delta + #ins), #ins}
    else
      return {delta, 0}
    end
  end
end
M["apply-write-ops!"] = function(ops)
  local post_lines = {}
  local touched_paths = {}
  local total = 0
  local any_write = false
  for path, per_file in pairs((ops or {})) do
    local bufnr = vim.fn.bufnr(path)
    if (bufnr and (bufnr > 0) and vim.api.nvim_buf_is_loaded(bufnr)) then
      local bo = vim.bo[bufnr]
      local old_mod = bo.modifiable
      local old_ro = bo.readonly
      bo["modifiable"] = true
      bo["readonly"] = false
      local delta = 0
      local changed = 0
      for _, op in ipairs((per_file or {})) do
        local _let_33_ = apply_op_to_loaded_buffer_21(bufnr, op, delta)
        local next_delta = _let_33_[1]
        local bump = _let_33_[2]
        delta = next_delta
        changed = (changed + bump)
      end
      bo["modifiable"] = old_mod
      bo["readonly"] = old_ro
      if (changed > 0) then
        local function _34_()
          return vim.cmd("silent keepalt noautocmd write")
        end
        local ok_write = pcall(vim.api.nvim_buf_call, bufnr, _34_)
        if ok_write then
          any_write = true
          total = (total + changed)
          touched_paths[path] = true
          post_lines[path] = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        else
          local ok_read,lines0 = pcall(vim.api.nvim_buf_get_lines, bufnr, 0, -1, false)
          if (ok_read and (type(lines0) == "table")) then
            local ok_fallback = pcall(vim.fn.writefile, lines0, path)
            if ok_fallback then
              any_write = true
              total = (total + changed)
              touched_paths[path] = true
              post_lines[path] = lines0
            else
            end
          else
          end
        end
      else
      end
    else
      local ok_read,lines0 = pcall(vim.fn.readfile, path)
      if ((ok_read and (type(lines0) == "table")) or ((#(per_file or {}) > 0) and (per_file[1].kind == "rewrite-bytes"))) then
        local lines = vim.deepcopy(lines0)
        local delta = 0
        local changed = 0
        for _, op in ipairs((per_file or {})) do
          if (op.kind == "rewrite-bytes") then
            local uv = (vim.uv or vim.loop)
            local bytes = (op.bytes or "")
            if (uv and uv.fs_open and uv.fs_write and uv.fs_close) then
              local ok_open,fd = pcall(uv.fs_open, path, "w", 420)
              if (ok_open and fd) then
                pcall(uv.fs_write, fd, bytes, 0)
                pcall(uv.fs_close, fd)
                changed = (changed + 1)
              else
              end
            else
            end
          else
            local _let_41_ = apply_op_to_lines_21(lines, op, delta)
            local next_delta = _let_41_[1]
            local bump = _let_41_[2]
            delta = next_delta
            changed = (changed + bump)
          end
        end
        if (changed > 0) then
          if ((#(per_file or {}) > 0) and (per_file[1].kind == "rewrite-bytes")) then
            any_write = true
            total = (total + changed)
            touched_paths[path] = true
            post_lines[path] = vim.fn.readfile(path)
          else
            local ok_write = pcall(vim.fn.writefile, lines, path)
            if ok_write then
              any_write = true
              total = (total + changed)
              touched_paths[path] = true
              post_lines[path] = lines
            else
            end
          end
        else
        end
      else
      end
    end
  end
  return {wrote = any_write, changed = total, ["post-lines"] = post_lines, paths = touched_paths, renames = {}}
end
return M
