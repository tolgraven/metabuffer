-- [nfnl] fnl/metabuffer/router/util.fnl
local M = {}
local prompt_height_state_file = (vim.fn.stdpath("state") .. "/metabuffer_prompt_height")
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
  local and_12_ = buf and vim.api.nvim_buf_is_valid(buf)
  if and_12_ then
    local ok,name = pcall(vim.api.nvim_buf_get_name, buf)
    if (ok and (type(name) == "string") and (name ~= "")) then
      and_12_ = name
    else
      and_12_ = nil
    end
  end
  return and_12_
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
    local function _25_(p)
      return vim.fn.fnamemodify((root .. "/" .. p), ":p")
    end
    return vim.tbl_map(_25_, (rel or {}))
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
M["read-file-lines-cached"] = function(settings, path, opts)
  local function chunk_line(s, width)
    local txt = (s or "")
    local w = math.max(1, (width or 80))
    local out = {}
    local n = #txt
    if (n <= w) then
      return {txt}
    else
      local i = 1
      while (i <= n) do
        table.insert(out, string.sub(txt, i, math.min(n, (i + w + -1))))
        i = (i + w)
      end
      return out
    end
  end
  local function contains_nul_byte_3f(lines)
    local n = math.min(8, #(lines or {}))
    local found = false
    for i = 1, n do
      local line = (lines[i] or "")
      if string.find(line, "\0", 1, true) then
        found = true
      else
      end
    end
    return found
  end
  local function strings_lines(path0)
    if (1 == vim.fn.executable("strings")) then
      local out = vim.fn.systemlist({"strings", "-a", path0})
      if (vim.v.shell_error == 0) then
        local joined = table.concat((out or {}), " ")
        local chunks = chunk_line(joined, 80)
        return chunks
      else
        return nil
      end
    else
      return nil
    end
  end
  local function hex_lines(path0)
    if (1 == vim.fn.executable("xxd")) then
      local out = vim.fn.systemlist({"xxd", "-g", "1", "-u", path0})
      if (vim.v.shell_error == 0) then
        return out
      else
        return nil
      end
    else
      if (1 == vim.fn.executable("hexdump")) then
        local out = vim.fn.systemlist({"hexdump", "-C", path0})
        if (vim.v.shell_error == 0) then
          return out
        else
          return nil
        end
      else
        return nil
      end
    end
  end
  local include_binary = (opts and opts["include-binary"])
  local hex_view = (opts and opts["hex-view"])
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
      if ((type(cached) == "table") and (cached.size == size) and (cached.mtime == mtime)) then
        if cached.binary then
          if include_binary then
            local key
            if hex_view then
              key = "hex-lines"
            else
              key = "strings-lines"
            end
            if (type(cached[key]) == "table") then
              return cached[key]
            else
              return nil
            end
          else
            return nil
          end
        else
          if (type(cached.lines) == "table") then
            return cached.lines
          else
            return nil
          end
        end
      else
        local ok_head,head = pcall(vim.fn.readfile, path, "b", 8)
        if (ok_head and (type(head) == "table") and contains_nul_byte_3f(head)) then
          local entry = {size = size, mtime = mtime, binary = true}
          if include_binary then
            local lines
            if hex_view then
              lines = hex_lines(path)
            else
              lines = strings_lines(path)
            end
            local key
            if hex_view then
              key = "hex-lines"
            else
              key = "strings-lines"
            end
            if (type(lines) == "table") then
              entry[key] = lines
            else
              entry[key] = {}
            end
            cache[path] = entry
            return entry[key]
          else
            cache[path] = entry
            return nil
          end
        else
          local ok,lines = pcall(vim.fn.readfile, path)
          if (ok and (type(lines) == "table")) then
            cache[path] = {size = size, mtime = mtime, lines = lines, binary = false}
            return lines
          else
            return nil
          end
        end
      end
    end
  end
end
return M
