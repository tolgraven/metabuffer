-- [nfnl] fnl/metabuffer/router/util.fnl
local M = {}
M["prompt-height"] = function()
  return (tonumber(vim.g.meta_prompt_height) or tonumber(vim.g["meta#prompt_height"]) or 7)
end
M["persist-prompt-height!"] = function(session)
  if (session and session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"])) then
    local ok,h = pcall(vim.api.nvim_win_get_height, session["prompt-win"])
    if (ok and h and (h > 0)) then
      vim.g.meta_prompt_height = h
      vim.g["meta#prompt_height"] = h
      return nil
    else
      return nil
    end
  else
    return nil
  end
end
M["info-height"] = function(session)
  if (session and session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"])) then
    local p_row_col = vim.api.nvim_win_get_position(session["prompt-win"])
    local p_row = p_row_col[1]
    return math.max(7, (p_row - 2))
  else
    return math.max(7, (vim.o.lines - (M["prompt-height"]() + 4)))
  end
end
M["prompt-lines"] = function(session)
  if (session and vim.api.nvim_buf_is_valid(session["prompt-buf"])) then
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
    return pcall(vim.api.nvim_win_set_cursor, session["prompt-win"], {row, col})
  else
    return nil
  end
end
M["current-buffer-path"] = function(buf)
  local and_8_ = buf and vim.api.nvim_buf_is_valid(buf)
  if and_8_ then
    local ok,name = pcall(vim.api.nvim_buf_get_name, buf)
    if (ok and (type(name) == "string") and (name ~= "")) then
      and_8_ = name
    else
      and_8_ = nil
    end
  end
  return and_8_
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
    local function _21_(p)
      return vim.fn.fnamemodify((root .. "/" .. p), ":p")
    end
    return vim.tbl_map(_21_, (rel or {}))
  else
    return vim.fn.globpath(root, (settings["project-fallback-glob-pattern"] or "**/*"), true, true)
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
M["read-file-lines-cached"] = function(settings, path)
  if (not path or (0 == vim.fn.filereadable(path))) then
    return nil
  else
    local size = vim.fn.getfsize(path)
    local mtime = vim.fn.getftime(path)
    local cache = (settings["project-file-cache"] or {})
    local _
    settings["project-file-cache"] = cache
    _ = nil
    local cached = cache[path]
    if ((size < 0) or (size > settings["project-max-file-bytes"])) then
      return nil
    else
      if ((type(cached) == "table") and (cached.size == size) and (cached.mtime == mtime) and (type(cached.lines) == "table")) then
        return cached.lines
      else
        local ok,lines = pcall(vim.fn.readfile, path)
        if (ok and (type(lines) == "table")) then
          cache[path] = {size = size, mtime = mtime, lines = lines}
          return lines
        else
          return nil
        end
      end
    end
  end
end
return M
