-- [nfnl] fnl/metabuffer/router/util.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local transform_mod = require("metabuffer.transform")
local config_mod = require("metabuffer.config")
local M = {}
local prompt_height_state_file = (vim.fn.stdpath("state") .. "/metabuffer_prompt_height")
local results_wrap_state_file = (vim.fn.stdpath("state") .. "/metabuffer_results_wrap")
local function read_prompt_height_state()
  local ok,fh = pcall(io.open, prompt_height_state_file, "r")
  if (ok and fh) then
    local line = fh:read("*l")
    local _ = fh:close()
    local n = tonumber((line or ""))
    if (n and (n > 0)) then
      return n
    else
      return nil
    end
  else
    return nil
  end
end
local function write_prompt_height_state_21(h)
  if (h and (h > 0)) then
    local ok,fh = pcall(io.open, prompt_height_state_file, "w")
    if (ok and fh) then
      fh:write(tostring(h))
      return fh:close()
    else
      return nil
    end
  else
    return nil
  end
end
local function read_results_wrap_state()
  local ok,fh = pcall(io.open, results_wrap_state_file, "r")
  if (ok and fh) then
    local line = vim.trim((fh:read("*l") or ""))
    local _ = fh:close()
    if ((line == "1") or (line == "true")) then
      return true
    elseif (line == "0") then
      return false
    else
      return nil
    end
  else
    return nil
  end
end
local function write_results_wrap_state_21(enabled)
  if (enabled ~= nil) then
    local ok,fh = pcall(io.open, results_wrap_state_file, "w")
    if (ok and fh) then
      local function _7_()
        if enabled then
          return "1"
        else
          return "0"
        end
      end
      fh:write(_7_())
      return fh:close()
    else
      return nil
    end
  else
    return nil
  end
end
M["prompt-height"] = function()
  return (tonumber(vim.g.meta_prompt_height) or tonumber(vim.g["meta#prompt_height"]) or read_prompt_height_state() or 7)
end
M["persist-prompt-height!"] = function(session)
  if (session and session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"])) then
    local ok,h = pcall(vim.api.nvim_win_get_height, session["prompt-win"])
    if (ok and h and (h > 0)) then
      vim.g.meta_prompt_height = h
      vim.g["meta#prompt_height"] = h
      return write_prompt_height_state_21(h)
    else
      return nil
    end
  else
    return nil
  end
end
M["results-wrap-enabled?"] = function()
  local v = read_results_wrap_state()
  if (v == nil) then
    return nil
  else
    return v
  end
end
M["persist-results-wrap!"] = function(session)
  if (session and session.meta and session.meta.win and session.meta.win.window and vim.api.nvim_win_is_valid(session.meta.win.window)) then
    local ok,wrap_3f = pcall(vim.api.nvim_get_option_value, "wrap", {win = session.meta.win.window})
    if ok then
      return write_results_wrap_state_21(clj.boolean(wrap_3f))
    else
      return nil
    end
  else
    return nil
  end
end
M["info-height"] = function(session)
  if (session and (session["startup-initializing"] or session["prompt-animating?"] or session["animate-enter?"]) and session["source-view"]) then
    local host_height = (session["source-view"]._meta_win_height or (session["origin-win"] and vim.api.nvim_win_is_valid(session["origin-win"]) and vim.api.nvim_win_get_height(session["origin-win"])) or (session.meta and session.meta.win and vim.api.nvim_win_is_valid(session.meta.win.window) and vim.api.nvim_win_get_height(session.meta.win.window)) or 0)
    local prompt_height = math.max(1, (session["prompt-target-height"] or M["prompt-height"]()))
    return math.max(7, (host_height - prompt_height))
  elseif (session and session.meta and session.meta.win and vim.api.nvim_win_is_valid(session.meta.win.window)) then
    return math.max(7, vim.api.nvim_win_get_height(session.meta.win.window))
  elseif (session and session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"])) then
    local p_row_col = vim.api.nvim_win_get_position(session["prompt-win"])
    local p_row = p_row_col[1]
    return math.max(7, (p_row - 2))
  else
    return math.max(7, (vim.o.lines - (M["prompt-height"]() + 4)))
  end
end
M["prompt-lines"] = function(session)
  if (session and (type(session["prompt-buf"]) == "number") and vim.api.nvim_buf_is_valid(session["prompt-buf"])) then
    return vim.api.nvim_buf_get_lines(session["prompt-buf"], 0, -1, false)
  else
    return {}
  end
end
M["prompt-text"] = function(session)
  return table.concat(M["prompt-lines"](session), "\n")
end
M["mark-prompt-buffer!"] = function(buf)
  if (buf and vim.api.nvim_buf_is_valid(buf)) then
    pcall(vim.api.nvim_buf_set_var, buf, "autopairs_enabled", false)
    pcall(vim.api.nvim_buf_set_var, buf, "AutoPairsDisabled", 1)
    pcall(vim.api.nvim_buf_set_var, buf, "delimitMate_enabled", 0)
    pcall(vim.api.nvim_buf_set_var, buf, "pear_tree_disable", 1)
    pcall(vim.api.nvim_buf_set_var, buf, "endwise_disable", 1)
    pcall(vim.api.nvim_buf_set_var, buf, "cmp_enabled", false)
    return pcall(vim.api.nvim_buf_set_var, buf, "meta_prompt", true)
  else
    return nil
  end
end
M["set-prompt-text!"] = function(session, text)
  if (session and vim.api.nvim_buf_is_valid(session["prompt-buf"])) then
    session["last-prompt-text"] = (text or "")
    local lines
    if (text == "") then
      lines = {""}
    else
      lines = vim.split(text, "\n", {plain = true})
    end
    local row = #lines
    local col = #lines[row]
    vim.api.nvim_buf_set_lines(session["prompt-buf"], 0, -1, false, lines)
    pcall(vim.api.nvim_win_set_cursor, session["prompt-win"], {row, col})
    if (session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"])) then
      pcall(vim.api.nvim_set_option_value, "wrap", true, {win = session["prompt-win"]})
      return pcall(vim.api.nvim_set_option_value, "linebreak", true, {win = session["prompt-win"]})
    else
      return nil
    end
  else
    return nil
  end
end
M["current-buffer-path"] = function(buf)
  local and_21_ = buf and vim.api.nvim_buf_is_valid(buf)
  if and_21_ then
    local ok,name = pcall(vim.api.nvim_buf_get_name, buf)
    if (ok and (type(name) == "string") and (name ~= "")) then
      and_21_ = name
    else
      and_21_ = nil
    end
  end
  return and_21_
end
M["meta-buffer-name"] = function(session)
  if session["project-mode"] then
    return "Metabuffer"
  else
    local original_name = M["current-buffer-path"](session["source-buf"])
    local base_name
    if ((type(original_name) == "string") and (original_name ~= "")) then
      base_name = vim.fn.fnamemodify(original_name, ":t")
    else
      base_name = "[No Name]"
    end
    return (base_name .. " \226\128\162 Metabuffer")
  end
end
M["ensure-source-refs!"] = function(meta)
  if not meta.buf["source-refs"] then
    meta.buf["source-refs"] = {}
  else
  end
  if (#meta.buf["source-refs"] < #meta.buf.content) then
    local path = (M["current-buffer-path"](meta.buf.model) or "[Current Buffer]")
    local model_buf = (meta.buf.model and vim.api.nvim_buf_is_valid(meta.buf.model) and meta.buf.model)
    for i = (#meta.buf["source-refs"] + 1), #meta.buf.content do
      table.insert(meta.buf["source-refs"], {path = path, lnum = i, buf = model_buf, line = meta.buf.content[i]})
    end
  else
  end
  return meta.buf["source-refs"]
end
M["selected-ref"] = function(meta)
  local src_idx = meta.buf.indices[(meta.selected_index + 1)]
  local refs = (meta.buf["source-refs"] or {})
  return (src_idx and refs[src_idx])
end
M["clear-file-caches!"] = function(router, session)
  if router then
    router["project-file-cache"] = {}
  else
  end
  if session then
    session["preview-file-cache"] = {}
    session["info-file-head-cache"] = {}
    session["info-file-meta-cache"] = {}
    session["ts-expand-bufs"] = {}
    session["info-line-meta-range-key"] = nil
    session["info-render-sig"] = nil
    if (session.meta and (type(session.meta["_filter-cache"]) == "table")) then
      session.meta["_filter-cache"] = {}
      session.meta["_filter-cache-line-count"] = #(session.meta.buf.content or {})
      return nil
    else
      return nil
    end
  else
    return nil
  end
end
local function hidden_path_3f(path)
  local parts = vim.split(path, "/", {plain = true})
  local step
  local function step0(idx)
    if (idx > #parts) then
      return false
    else
      local p = parts[idx]
      return (((p ~= "") and (string.sub(p, 1, 1) == ".")) or step0((idx + 1)))
    end
  end
  step = step0
  return step(1)
end
local function dep_path_3f(settings, path)
  local parts = vim.split(path, "/", {plain = true})
  local step
  local function step0(idx)
    if (idx > #parts) then
      return false
    else
      return (settings["dep-dir-names"][parts[idx]] or step0((idx + 1)))
    end
  end
  step = step0
  return step(1)
end
M["allow-project-path?"] = function(settings, rel, include_hidden, include_deps)
  local s = (rel or "")
  if ((s == "") or (s == ".")) then
    return false
  elseif (vim.startswith(s, ".git/") or string.find(s, "/.git/", 1, true)) then
    return false
  elseif (not include_hidden and hidden_path_3f(s)) then
    return false
  elseif (not include_deps and dep_path_3f(settings, s)) then
    return false
  elseif "else" then
    return true
  else
    return nil
  end
end
M["project-file-list"] = function(settings, root, include_hidden, include_ignored, include_deps)
  local cache
  local and_34_ = vim.g.__meta_project_file_list_cache
  if and_34_ then
    local _35_
    if include_hidden then
      _35_ = "1"
    else
      _35_ = "0"
    end
    local _37_
    if include_ignored then
      _37_ = "1"
    else
      _37_ = "0"
    end
    local _39_
    if include_deps then
      _39_ = "1"
    else
      _39_ = "0"
    end
    and_34_ = vim.g.__meta_project_file_list_cache[(root .. "|" .. _35_ .. "|" .. _37_ .. "|" .. _39_)]
  end
  cache = and_34_
  if cache then
    return cache
  else
    local rg_bin = (settings["project-rg-bin"] or "rg")
    if (1 == vim.fn.executable(rg_bin)) then
      local cmd = {rg_bin}
      local _
      for _0, arg in ipairs((settings["project-rg-base-args"] or {})) do
        table.insert(cmd, arg)
      end
      _ = nil
      local _0
      if include_hidden then
        _0 = table.insert(cmd, "--hidden")
      else
        _0 = nil
      end
      local _1
      if include_ignored then
        for _2, arg in ipairs((settings["project-rg-include-ignored-args"] or {})) do
          table.insert(cmd, arg)
        end
        _1 = nil
      else
        _1 = nil
      end
      local _2
      if not include_deps then
        for _3, glob in ipairs((settings["project-rg-deps-exclude-globs"] or {})) do
          table.insert(cmd, "--glob")
          table.insert(cmd, glob)
        end
        _2 = nil
      else
        _2 = nil
      end
      local rel = vim.fn.systemlist(cmd)
      local function _44_(p)
        return vim.fn.fnamemodify((root .. "/" .. p), ":p")
      end
      return vim.tbl_map(_44_, (rel or {}))
    else
      return vim.fn.globpath(root, (settings["project-fallback-glob-pattern"] or "**/*"), true, true)
    end
  end
end
local function ui_attached_3f()
  return (#vim.api.nvim_list_uis() > 0)
end
M["lazy-streaming-allowed?"] = function(settings, query_mod, session)
  return (session and session["project-mode"] and query_mod["truthy?"](settings["project-lazy-enabled"]) and (not query_mod["truthy?"](settings["project-lazy-disable-headless"]) or ui_attached_3f()))
end
M["session-active?"] = function(active_by_prompt, session)
  return (session and session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session))
end
M["canonical-path"] = function(path)
  if ((type(path) == "string") and (path ~= "")) then
    return vim.fn.fnamemodify(path, ":p")
  else
    return nil
  end
end
M["path-under-root?"] = function(path, root)
  local p = M["canonical-path"](path)
  local r = M["canonical-path"](root)
  return (p and r and vim.startswith(p, r))
end
local function contains_nul_byte_3f(s)
  local ok,match_3f = pcall(string.find, s, "\0", 1, true)
  return (ok and clj.boolean((match_3f ~= nil)))
end
local function suspicious_binary_head_3f(s)
  local ok_n,n = pcall(string.len, s)
  if (not ok_n or not (type(n) == "number")) then
    return false
  else
    if (n == 0) then
      return false
    else
      local bad0 = 0
      local bad = bad0
      for i = 1, n do
        local ok_b,b = pcall(string.byte, s, i)
        if (ok_b and b and ((b < 9) or (b == 11) or (b == 12) or ((b > 13) and (b < 32)) or (b == 127))) then
          bad = (bad + 1)
        else
        end
      end
      return ((bad / n) > 0.1)
    end
  end
end
local function binary_head_3f(head)
  return ((type(head) == "string") and (contains_nul_byte_3f(head) or suspicious_binary_head_3f(head)))
end
local function settings_project_max_file_bytes(settings)
  local fallback = config_mod.defaults.options
  local fallback_max = ((fallback and fallback.project_max_file_bytes) or 1048576)
  return ((settings and settings["project-max-file-bytes"]) or (settings and settings.project_max_file_bytes) or fallback_max)
end
local function read_file_head_bytes(path, n)
  local uv = (vim.uv or vim.loop)
  if (uv and uv.fs_open and uv.fs_read and uv.fs_close and path) then
    local ok_open,fd = pcall(uv.fs_open, path, "r", 438)
    if (ok_open and fd) then
      local ok_read,chunk = pcall(uv.fs_read, fd, (n or 256), 0)
      pcall(uv.fs_close, fd)
      if (ok_read and (type(chunk) == "string")) then
        return chunk
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
local function read_file_bytes(path)
  local uv = (vim.uv or vim.loop)
  if (uv and uv.fs_open and uv.fs_read and uv.fs_close and path) then
    local ok_open,fd = pcall(uv.fs_open, path, "r", 438)
    if (ok_open and fd) then
      local ok_stat,stat = pcall(uv.fs_fstat, fd)
      local size
      if (ok_stat and (type(stat) == "table")) then
        size = stat.size
      else
        size = nil
      end
      local ok_read,chunk = pcall(uv.fs_read, fd, (size or 0), 0)
      pcall(uv.fs_close, fd)
      if (ok_read and (type(chunk) == "string")) then
        return chunk
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
local function bytes__3elines(s)
  if not (type(s) == "string") then
    return {}
  else
    local norm = string.gsub(s, "\r\n", "\n")
    local lines = vim.split(norm, "\n", {plain = true})
    if ((#lines > 0) and (lines[#lines] == "")) then
      table.remove(lines)
    else
    end
    return lines
  end
end
M["binary-file?"] = function(settings, path)
  if (not path or (0 == vim.fn.filereadable(path))) then
    return false
  else
    local size = vim.fn.getfsize(path)
    local mtime = vim.fn.getftime(path)
    local max_bytes = settings_project_max_file_bytes(settings)
    local cache = (settings["project-file-cache"] or {})
    local _
    settings["project-file-cache"] = cache
    _ = nil
    local cached = cache[path]
    if ((size < 0) or (size > max_bytes)) then
      return false
    else
      if ((type(cached) == "table") and (cached.size == size) and (cached.mtime == mtime) and (cached.binary ~= nil)) then
        return clj.boolean(cached.binary)
      else
        local head = read_file_head_bytes(path, 256)
        local bin_3f = binary_head_3f(head)
        local prev_lines = ((type(cached) == "table") and cached.lines)
        local _60_
        if (type(prev_lines) == "table") then
          _60_ = prev_lines
        else
          _60_ = nil
        end
        cache[path] = {size = size, mtime = mtime, binary = clj.boolean(bin_3f), lines = _60_}
        return clj.boolean(bin_3f)
      end
    end
  end
end
M["read-file-view-cached"] = function(settings, path, opts)
  local function binary_header_line(size)
    local kb = math.max(1, math.floor((math.max(0, (size or 0)) / 1024)))
    return ("binary " .. tostring(kb) .. " KB")
  end
  local function binary_default_lines(size)
    return {binary_header_line(size)}
  end
  local include_binary = (opts and opts["include-binary"])
  local transforms0 = ((opts and opts.transforms) or {})
  local transforms
  if (opts and opts["hex-view"] and (transforms0.hex == nil)) then
    transforms = vim.tbl_extend("force", transforms0, {hex = true})
  else
    transforms = transforms0
  end
  local wrap_width = (opts and opts["wrap-width"])
  local linebreak_3f
  if ((opts and opts.linebreak) == nil) then
    linebreak_3f = true
  else
    linebreak_3f = clj.boolean(opts.linebreak)
  end
  local transform_sig
  local _67_
  if linebreak_3f then
    _67_ = "1"
  else
    _67_ = "0"
  end
  transform_sig = (transform_mod.signature(transforms) .. "|w:" .. tostring((wrap_width or 0)) .. "|lb:" .. _67_)
  if (not path or (0 == vim.fn.filereadable(path))) then
    return nil
  else
    local size = vim.fn.getfsize(path)
    local mtime = vim.fn.getftime(path)
    local max_bytes = settings_project_max_file_bytes(settings)
    local cache = (settings["project-file-cache"] or {})
    local _
    settings["project-file-cache"] = cache
    _ = nil
    local cached = cache[path]
    if ((size < 0) or (size > max_bytes)) then
      return nil
    else
      if ((type(cached) == "table") and (cached.size == size) and (cached.mtime == mtime)) then
        if cached.binary then
          if include_binary then
            local views = (cached.views or {})
            local found = views[transform_sig]
            if (type(found) == "table") then
              return found
            else
              local raw_lines = (cached["raw-lines"] or binary_default_lines(size))
              local ctx = {binary = true, size = size, head = cached.head, transforms = transforms}
              local view = transform_mod["apply-view"](path, raw_lines, ctx)
              views[transform_sig] = view
              cached["views"] = views
              return view
            end
          else
            return nil
          end
        else
          local views = (cached.views or {})
          local found = views[transform_sig]
          if (type(found) == "table") then
            return found
          else
            local raw_lines
            local or_71_ = cached.lines
            if not or_71_ then
              local text = read_file_bytes(path)
              local ls = bytes__3elines(text)
              if (type(ls) == "table") then
                cached["lines"] = ls
              else
              end
              or_71_ = (ls or {})
            end
            raw_lines = or_71_
            local ctx = {size = size, head = (cached.head or read_file_head_bytes(path, 4096)), transforms = transforms, binary = false}
            local view = transform_mod["apply-view"](path, raw_lines, ctx)
            views[transform_sig] = view
            cached["views"] = views
            return view
          end
        end
      else
        local head = read_file_head_bytes(path, 4096)
        if binary_head_3f(head) then
          local entry = {size = size, mtime = mtime, binary = true, head = head}
          if include_binary then
            local raw_lines = binary_default_lines(size)
            local ctx = {binary = true, size = size, head = head, transforms = transforms}
            local view = transform_mod["apply-view"](path, raw_lines, ctx)
            local views = {}
            if (type(raw_lines) == "table") then
              entry["raw-lines"] = raw_lines
            else
              entry["raw-lines"] = {}
            end
            views[transform_sig] = view
            entry["views"] = views
            cache[path] = entry
            return view
          else
            cache[path] = entry
            return nil
          end
        else
          local text = read_file_bytes(path)
          local lines = bytes__3elines(text)
          if (type(lines) == "table") then
            local entry = {size = size, mtime = mtime, head = head, lines = lines, views = {}, binary = false}
            local view = transform_mod["apply-view"](path, lines, {size = size, head = head, transforms = transforms, binary = false})
            local views = {}
            views[transform_sig] = view
            entry["views"] = views
            cache[path] = entry
            return view
          else
            return nil
          end
        end
      end
    end
  end
end
M["read-file-lines-cached"] = function(settings, path, opts)
  local view = M["read-file-view-cached"](settings, path, opts)
  return (view and view.lines)
end
return M
