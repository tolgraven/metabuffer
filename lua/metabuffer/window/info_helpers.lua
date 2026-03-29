-- [nfnl] fnl/metabuffer/window/info_helpers.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local M = {}
local function str(x)
  return tostring(x)
end
local function join_str(sep, xs)
  local out = {}
  for _, x in ipairs((xs or {})) do
    table.insert(out, str(x))
  end
  return table.concat(out, (sep or ""))
end
local function range_text(start_index, stop_index, total)
  if (total <= 0) then
    return "0/0"
  else
    return (start_index .. "-" .. stop_index .. "/" .. total)
  end
end
local function placeholder_pulse_char(session)
  local phase = ((session and session["loading-anim-phase"]) or 0)
  local frames = {"\194\183", "\226\128\162", "\226\151\143", "\226\128\162"}
  return frames[((phase % #frames) + 1)]
end
local function info_placeholder_line(session)
  return (placeholder_pulse_char(session) .. " loading info")
end
local function loading_skeleton_lines(count)
  local patterns = {".... ... ......", "..... .... .....", "... ..... ......", ".... ...... ...."}
  local total = math.max(1, (count or 1))
  local lines = {}
  for i = 1, total do
    table.insert(lines, patterns[(((i - 1) % #patterns) + 1)])
  end
  return lines
end
local function indices_slice_sig(idxs, start_index, stop_index)
  local out = {}
  local idxs0 = (idxs or {})
  local start_index0 = math.max(1, (start_index or 1))
  local stop_index0 = math.max(0, (stop_index or 0))
  for i = start_index0, stop_index0 do
    local v = idxs0[i]
    if not (v == nil) then
      table.insert(out, tostring(v))
    else
    end
  end
  return table.concat(out, ",")
end
local function valid_info_win_3f(session)
  return (session and (type(session["info-win"]) == "number") and vim.api.nvim_win_is_valid(session["info-win"]))
end
local function numeric_win_id(x)
  if (type(x) == "number") then
    return x
  else
    return ((type(x) == "table") and (type(x.window) == "number") and x.window)
  end
end
local function session_host_win(session)
  local meta_win = (session and session.meta and session.meta.win and numeric_win_id(session.meta.win))
  local prompt_win = (session and numeric_win_id(session["prompt-win"]))
  local prompt_window_win = (session and session["prompt-window"] and numeric_win_id(session["prompt-window"]))
  local origin_win = (session and numeric_win_id(session["origin-win"]))
  return ((meta_win and vim.api.nvim_win_is_valid(meta_win) and meta_win) or (prompt_win and vim.api.nvim_win_is_valid(prompt_win) and prompt_win) or (prompt_window_win and vim.api.nvim_win_is_valid(prompt_window_win) and prompt_window_win) or (origin_win and vim.api.nvim_win_is_valid(origin_win) and origin_win))
end
local function ext_start_in_file(file)
  local txt = (file or "")
  local n = #txt
  local dot = 0
  for i = n, 1, -1 do
    if ((dot == 0) and (string.sub(txt, i, i) == ".")) then
      dot = i
    else
    end
  end
  if ((dot > 1) and (dot < n)) then
    return dot
  else
    return 0
  end
end
local function icon_field(icon)
  if ((type(icon) == "string") and (icon ~= "")) then
    local text = (icon .. " ")
    return {text = text, width = vim.fn.strdisplaywidth(text)}
  else
    return {text = "", width = 0}
  end
end
local function ref_path(session, ref)
  local or_7_ = (ref and ref.path)
  if not or_7_ then
    local and_8_ = session and session["source-buf"] and vim.api.nvim_buf_is_valid(session["source-buf"])
    if and_8_ then
      local name = vim.api.nvim_buf_get_name(session["source-buf"])
      if ((type(name) == "string") and (name ~= "")) then
        and_8_ = name
      else
        and_8_ = nil
      end
    end
    or_7_ = and_8_
  end
  return (or_7_ or "")
end
local function refs_slice_sig(session, refs, idxs, start_index, stop_index)
  local out = {}
  local refs0 = (refs or {})
  local idxs0 = (idxs or {})
  for i = start_index, stop_index do
    local src_idx = idxs0[i]
    local ref = refs0[src_idx]
    table.insert(out, join_str(":", {src_idx, (ref_path(session, ref) or ""), ((ref and ref.lnum) or 0), ((ref and ref.kind) or "")}))
  end
  return table.concat(out, "|")
end
local function compact_dir(dir)
  if ((dir == "") or (dir == ".")) then
    return ""
  else
    local parts = vim.split(dir, "/", {plain = true})
    local out = {}
    for _, p in ipairs((parts or {})) do
      if (p ~= "") then
        table.insert(out, string.sub(p, 1, 1))
      else
      end
    end
    if (#out == 0) then
      return ""
    else
      return (table.concat(out, "/") .. "/")
    end
  end
end
local function compact_dir_keep_last(dir)
  if ((dir == "") or (dir == ".")) then
    return ""
  else
    local parts0 = vim.split(dir, "/", {plain = true})
    local parts = {}
    for _, p in ipairs((parts0 or {})) do
      if (p ~= "") then
        table.insert(parts, p)
      else
      end
    end
    local n = #parts
    if (n == 0) then
      return ""
    else
      if (n == 1) then
        return (parts[1] .. "/")
      else
        local out = {}
        for i = 1, (n - 1) do
          table.insert(out, string.sub(parts[i], 1, 1))
        end
        table.insert(out, parts[n])
        return (table.concat(out, "/") .. "/")
      end
    end
  end
end
local function fit_path_into_width(path, path_width)
  local dir0 = vim.fn.fnamemodify(path, ":h")
  local dir
  if ((dir0 == ".") or (dir0 == "")) then
    dir = ""
  else
    dir = (dir0 .. "/")
  end
  local file = vim.fn.fnamemodify(path, ":t")
  local budget = math.max(1, path_width)
  local full = (dir .. file)
  if (#full <= budget) then
    return {dir, file, dir0}
  else
    local kdir = compact_dir_keep_last(dir0)
    local keep_last = (kdir .. file)
    if (#keep_last <= budget) then
      return {kdir, file, dir0}
    else
      local cdir = compact_dir(dir0)
      local compact = (cdir .. file)
      if (#compact <= budget) then
        return {cdir, file, dir0}
      else
        if (#file > budget) then
          local _19_
          if (budget > 1) then
            _19_ = ("\226\128\166" .. string.sub(file, ((#file - budget) + 2)))
          else
            _19_ = string.sub(file, ((#file - budget) + 1))
          end
          return {"", _19_, dir0}
        else
          local dir_budget = math.max(0, (budget - #file))
          local short_dir
          if (#cdir <= dir_budget) then
            short_dir = cdir
          else
            if (dir_budget > 1) then
              short_dir = ("\226\128\166" .. string.sub(cdir, ((#cdir - dir_budget) + 2)))
            else
              short_dir = string.sub(cdir, ((#cdir - dir_budget) + 1))
            end
          end
          return {short_dir, file, dir0}
        end
      end
    end
  end
end
local function info_range(selected_index, total, cap)
  if ((total <= 0) or (cap <= 0)) then
    return {1, 0}
  else
    if (total <= cap) then
      return {1, total}
    else
      local sel = math.max(1, math.min(total, (selected_index + 1)))
      local half = math.floor((cap / 2))
      local start = math.max(1, math.min((sel - half), ((total - cap) + 1)))
      local stop = math.min(total, (start + cap + -1))
      return {start, stop}
    end
  end
end
local function numeric_max(vals, default)
  if (not vals or (#vals == 0)) then
    return default
  else
    local m = (vals[1] or default)
    local out = m
    for _, v in ipairs(vals) do
      if (v > out) then
        out = v
      else
      end
    end
    return out
  end
end
local function info_winbar_active_3f(session, project_loading_pending_3f)
  return (project_loading_pending_3f(session) or clj.boolean((session and session["info-highlight-fill-pending?"])))
end
local function effective_info_height(session, info_height, _project_loading_pending_3f)
  return math.max(1, info_height(session))
end
M.str = str
M["join-str"] = join_str
M["range-text"] = range_text
M["placeholder-pulse-char"] = placeholder_pulse_char
M["info-placeholder-line"] = info_placeholder_line
M["loading-skeleton-lines"] = loading_skeleton_lines
M["indices-slice-sig"] = indices_slice_sig
M["valid-info-win?"] = valid_info_win_3f
M["numeric-win-id"] = numeric_win_id
M["session-host-win"] = session_host_win
M["ext-start-in-file"] = ext_start_in_file
M["icon-field"] = icon_field
M["ref-path"] = ref_path
M["refs-slice-sig"] = refs_slice_sig
M["fit-path-into-width"] = fit_path_into_width
M["info-range"] = info_range
M["numeric-max"] = numeric_max
M["info-winbar-active?"] = info_winbar_active_3f
M["effective-info-height"] = effective_info_height
return M
