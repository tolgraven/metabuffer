-- [nfnl] fnl/metabuffer/window/info.fnl
local M = {}
local lineno_mod = require("metabuffer.window.lineno")
local source_mod = require("metabuffer.source")
local path_hl = require("metabuffer.path_highlight")
local util = require("metabuffer.util")
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
    return {dir, file}
  else
    local kdir = compact_dir_keep_last(dir0)
    local keep_last = (kdir .. file)
    if (#keep_last <= budget) then
      return {kdir, file}
    else
      local cdir = compact_dir(dir0)
      local compact = (cdir .. file)
      if (#compact <= budget) then
        return {cdir, file}
      else
        if (#file > budget) then
          local function _12_()
            if (budget > 1) then
              return ("\226\128\166" .. string.sub(file, ((#file - budget) + 2)))
            else
              return string.sub(file, ((#file - budget) + 1))
            end
          end
          return {"", _12_()}
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
          return {short_dir, file}
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
M.new = function(opts)
  local deps = (opts or {})
  local floating_window_mod = deps["floating-window-mod"]
  local info_min_width = deps["info-min-width"]
  local info_max_width = deps["info-max-width"]
  local info_max_lines = deps["info-max-lines"]
  local info_height = deps["info-height"]
  local debug_log = deps["debug-log"]
  local update_preview = deps["update-preview"]
  local read_file_lines_cached = deps["read-file-lines-cached"]
  local animation_mod = deps["animation-mod"]
  local animate_enter_3f = deps["animate-enter?"]
  local info_fade_ms = deps["info-fade-ms"]
  local info_window_config = nil
  local function _23_(session, width, height)
    local host_win
    if (session and session.meta and session.meta.win and vim.api.nvim_win_is_valid(session.meta.win.window)) then
      host_win = session.meta.win.window
    else
      host_win = session["prompt-win"]
    end
    if session["window-local-layout"] then
      return {relative = "win", win = host_win, anchor = "NE", row = 0, col = vim.api.nvim_win_get_width(host_win), width = width, height = height}
    else
      return {relative = "editor", anchor = "NE", row = 1, col = vim.o.columns, width = width, height = height}
    end
  end
  info_window_config = _23_
  local ensure_info_window = nil
  local function _26_(session)
    if not (session["info-win"] and vim.api.nvim_win_is_valid(session["info-win"])) then
      local buf = vim.api.nvim_create_buf(false, true)
      local width = info_min_width
      local height = info_height(session)
      local target = info_window_config(session, width, height)
      local animate_info_3f = (animation_mod and animate_enter_3f and animate_enter_3f(session) and animation_mod["enabled?"](session, "info") and not session["info-animated?"])
      local cfg
      if animate_info_3f then
        local start = vim.deepcopy(target)
        start["col"] = (target.col + 8)
        cfg = start
      else
        cfg = target
      end
      local win = floating_window_mod.new(vim, buf, cfg)
      session["info-buf"] = buf
      session["info-win"] = win.window
      do
        local bo = vim.bo[buf]
        bo["buftype"] = "nofile"
        bo["bufhidden"] = "wipe"
        bo["swapfile"] = false
        bo["modifiable"] = false
        bo["filetype"] = "metabuffer"
      end
      do
        local wo = vim.wo[win.window]
        wo["statusline"] = ""
        wo["winbar"] = ""
        wo["number"] = false
        wo["relativenumber"] = false
        wo["wrap"] = false
        wo["linebreak"] = false
        wo["signcolumn"] = "no"
        wo["foldcolumn"] = "0"
        wo["spell"] = false
      end
      if animate_info_3f then
        session["info-animated?"] = true
        pcall(vim.api.nvim_set_option_value, "winblend", 85, {win = session["info-win"]})
        local function _28_()
          if (session["info-win"] and vim.api.nvim_win_is_valid(session["info-win"])) then
            return animation_mod["animate-float!"](session, "info-enter", session["info-win"], cfg, target, 85, (vim.g.meta_float_winblend or 13), animation_mod["duration-ms"](session, "info", (info_fade_ms or 220)))
          else
            return nil
          end
        end
        local function _30_()
          if (animation_mod and animation_mod["enabled?"](session, "prompt")) then
            return animation_mod["duration-ms"](session, "prompt", 140)
          else
            return 0
          end
        end
        return vim.defer_fn(_28_, _30_())
      else
        return nil
      end
    else
      return nil
    end
  end
  ensure_info_window = _26_
  local function settle_info_window_21(session)
    if (session["info-win"] and vim.api.nvim_win_is_valid(session["info-win"])) then
      local width = vim.api.nvim_win_get_width(session["info-win"])
      local height = info_height(session)
      local cfg = info_window_config(session, width, height)
      return pcall(vim.api.nvim_win_set_config, session["info-win"], cfg)
    else
      return nil
    end
  end
  local function close_info_window_21(session)
    if (session["info-win"] and vim.api.nvim_win_is_valid(session["info-win"])) then
      pcall(vim.api.nvim_win_close, session["info-win"], true)
    else
    end
    session["info-win"] = nil
    session["info-buf"] = nil
    return nil
  end
  local function fit_info_width_21(session, lines)
    if (session["info-win"] and vim.api.nvim_win_is_valid(session["info-win"])) then
      local widths
      local function _35_(line)
        return vim.fn.strdisplaywidth((line or ""))
      end
      widths = vim.tbl_map(_35_, (lines or {}))
      local max_len = numeric_max(widths, 0)
      local needed = max_len
      local host_width
      if (session["window-local-layout"] and session.meta and session.meta.win and vim.api.nvim_win_is_valid(session.meta.win.window)) then
        host_width = vim.api.nvim_win_get_width(session.meta.win.window)
      else
        if session["window-local-layout"] then
          host_width = vim.api.nvim_win_get_width(session["prompt-win"])
        else
          host_width = vim.o.columns
        end
      end
      local max_available = math.max(info_min_width, math.floor((host_width * 0.34)))
      local upper = math.min(info_max_width, max_available)
      local target = math.max(info_min_width, math.min(needed, upper))
      local height = info_height(session)
      local cfg = info_window_config(session, target, height)
      return pcall(vim.api.nvim_win_set_config, session["info-win"], cfg)
    else
      return nil
    end
  end
  local function info_max_width_now(session)
    local host_width
    if (session and session["window-local-layout"] and session.meta and session.meta.win and vim.api.nvim_win_is_valid(session.meta.win.window)) then
      host_width = vim.api.nvim_win_get_width(session.meta.win.window)
    else
      if (session and session["window-local-layout"]) then
        host_width = vim.api.nvim_win_get_width(session["prompt-win"])
      else
        host_width = vim.o.columns
      end
    end
    local max_available = math.max(info_min_width, math.floor((host_width * 0.34)))
    return math.min(info_max_width, max_available)
  end
  local function info_visible_range(session, meta, total, cap)
    if ((total <= 0) or (cap <= 0)) then
      return {1, 0}
    else
      if (session and meta and meta.win and vim.api.nvim_win_is_valid(meta.win.window)) then
        local view
        local function _41_()
          return vim.fn.winsaveview()
        end
        view = vim.api.nvim_win_call(meta.win.window, _41_)
        local top = math.max(1, math.min(total, (view.topline or 1)))
        local height = math.max(1, vim.api.nvim_win_get_height(meta.win.window))
        local stop0 = math.min(total, (top + height + -1))
        local shown = math.max(1, ((stop0 - top) + 1))
        if (shown <= cap) then
          return {top, stop0}
        else
          return {top, (top + cap + -1)}
        end
      else
        return info_range(meta.selected_index, total, cap)
      end
    end
  end
  local function build_info_lines(session, refs, idxs, target_width, start_index, stop_index, read_file_lines_cached0)
    local line_hl = "LineNr"
    local signcol_display_width = 2
    local file_hl
    if (1 == vim.fn.hlexists("NERDTreeFile")) then
      file_hl = "NERDTreeFile"
    else
      if (1 == vim.fn.hlexists("NetrwPlain")) then
        file_hl = "NetrwPlain"
      else
        if (1 == vim.fn.hlexists("NvimTreeFileName")) then
          file_hl = "NvimTreeFileName"
        else
          file_hl = "Normal"
        end
      end
    end
    local lnum_digit_width
    do
      local limit = math.min(#idxs, info_max_lines)
      local max_lnum_len
      if (limit > 0) then
        local lens = {}
        for i = 1, limit do
          local src_idx = idxs[i]
          local ref = refs[src_idx]
          local lnum = tostring(((ref and ref.lnum) or src_idx))
          table.insert(lens, #lnum)
        end
        max_lnum_len = numeric_max(lens, 1)
      else
        max_lnum_len = 1
      end
      lnum_digit_width = lineno_mod["digit-width-from-max-len"](max_lnum_len)
    end
    local lnum_field_width = (lnum_digit_width + 1)
    local path_width = math.max(1, (target_width - lnum_field_width - signcol_display_width))
    local lines = {}
    local highlights = {}
    if (#idxs == 0) then
      table.insert(lines, "No matches")
    else
      for i = start_index, stop_index do
        local src_idx = idxs[i]
        local ref = refs[src_idx]
        local view_mode = (session["info-file-entry-view"] or "meta")
        local lnum = tostring(((ref and ref.lnum) or src_idx))
        local lnum_cell0 = lineno_mod["lnum-cell"](lnum, lnum_digit_width)
        local base_path = vim.fn.fnamemodify(((ref and ref.path) or "[Current Buffer]"), ":~:.")
        local info_view = source_mod["info-view"](session, ref, {mode = view_mode, ["path-width"] = path_width, ["read-file-lines-cached"] = read_file_lines_cached0})
        local sign = (info_view.sign or {text = "  ", hl = "LineNr"})
        local sign_raw = (sign.text or "")
        local sign_pad = math.max(0, (signcol_display_width - vim.fn.strdisplaywidth(sign_raw)))
        local sign_prefix = (sign_raw .. string.rep(" ", sign_pad))
        local sign_hl = (sign.hl or "LineNr")
        local sign_width = #sign_prefix
        local sign_glyph_start1 = (string.find(sign_prefix, "%S") or 0)
        local sign_glyph = vim.trim(sign_prefix)
        local sign_glyph_start
        if (sign_glyph_start1 > 0) then
          sign_glyph_start = (sign_glyph_start1 - 1)
        else
          sign_glyph_start = -1
        end
        local sign_glyph_end
        if ((sign_glyph_start1 > 0) and (#sign_glyph > 0)) then
          sign_glyph_end = (sign_glyph_start + #sign_glyph)
        else
          sign_glyph_end = -1
        end
        local path = (info_view.path or base_path)
        local icon_path = (info_view["icon-path"] or path)
        local show_icon_3f
        if (info_view["show-icon"] == nil) then
          show_icon_3f = true
        else
          show_icon_3f = info_view["show-icon"]
        end
        local highlight_dir_3f
        if (info_view["highlight-dir"] == nil) then
          highlight_dir_3f = true
        else
          highlight_dir_3f = info_view["highlight-dir"]
        end
        local highlight_file_3f
        if (info_view["highlight-file"] == nil) then
          highlight_file_3f = true
        else
          highlight_file_3f = info_view["highlight-file"]
        end
        local suffix0 = (info_view.suffix or "")
        local suffix_prefix
        if (#suffix0 > 0) then
          suffix_prefix = (info_view["suffix-prefix"] or "  ")
        else
          suffix_prefix = ""
        end
        local suffix_hls = (info_view["suffix-highlights"] or {})
        local icon_info = util["devicon-info"](icon_path, file_hl)
        local icon = (icon_info.icon or "")
        local iconf = icon_field(icon)
        local icon_prefix
        if show_icon_3f then
          icon_prefix = iconf.text
        else
          icon_prefix = ""
        end
        local icon_hl = (icon_info["icon-hl"] or file_hl)
        local icon_width
        if show_icon_3f then
          icon_width = iconf.width
        else
          icon_width = 0
        end
        local _let_57_ = fit_path_into_width(path, math.max(1, (path_width - icon_width)))
        local dir = _let_57_[1]
        local file0 = _let_57_[2]
        local this_file_hl = (icon_info["file-hl"] or file_hl)
        local row = #lines
        local line = (sign_prefix .. lnum_cell0 .. icon_prefix .. dir .. file0 .. suffix_prefix .. suffix0)
        local sign_start = 0
        local sign_end = (sign_start + sign_width)
        local num_start = sign_end
        local num_end = (num_start + #lnum_cell0)
        local icon_start = num_end
        local icon_end = (icon_start + #icon_prefix)
        local dir_start = icon_end
        local file_start = (dir_start + #dir)
        local suffix_start = (file_start + #file0 + #suffix_prefix)
        table.insert(lines, line)
        if (sign_width > 0) then
          table.insert(highlights, {row, "SignColumn", sign_start, sign_end})
        else
        end
        if ((sign_glyph_end > sign_glyph_start) and (sign_width > 0)) then
          table.insert(highlights, {row, sign_hl, (sign_start + sign_glyph_start), (sign_start + sign_glyph_end)})
        else
        end
        table.insert(highlights, {row, line_hl, num_start, num_end})
        if (#icon_prefix > 0) then
          table.insert(highlights, {row, icon_hl, icon_start, icon_end})
        else
        end
        if (highlight_dir_3f and (#dir > 0)) then
          for _, dr in ipairs(path_hl["ranges-for-dir"](dir, dir_start)) do
            table.insert(highlights, {row, dr.hl, dr.start, dr["end"]})
          end
        else
        end
        if (highlight_file_3f and (#file0 > 0)) then
          table.insert(highlights, {row, this_file_hl, file_start, (file_start + #file0)})
        else
        end
        if (highlight_file_3f and (#file0 > 0)) then
          local dot = ext_start_in_file(file0)
          if (dot > 0) then
            table.insert(highlights, {row, icon_hl, (file_start + (dot - 1)), (file_start + #file0)})
          else
          end
        else
        end
        if (#suffix0 > 0) then
          table.insert(highlights, {row, "Comment", suffix_start, (suffix_start + #suffix0)})
        else
        end
        for _, sh in ipairs(suffix_hls) do
          local s = (suffix_start + (sh.start or 0))
          local e = (suffix_start + (sh["end"] or 0))
          if (e > s) then
            table.insert(highlights, {row, (sh.hl or "Comment"), s, e})
          else
          end
        end
      end
    end
    return {lines = lines, highlights = highlights}
  end
  local function render_info_lines_21(session, meta, start_index, stop_index)
    local refs = (meta.buf["source-refs"] or {})
    local idxs = (meta.buf.indices or {})
    local _
    session["info-start-index"] = start_index
    _ = nil
    local _0
    session["info-stop-index"] = stop_index
    _0 = nil
    local built = build_info_lines(session, refs, idxs, info_max_width_now(session), start_index, stop_index, read_file_lines_cached)
    local raw_lines = built.lines
    local lines
    if (type(raw_lines) == "table") then
      lines = vim.tbl_map(tostring, raw_lines)
    else
      lines = {tostring(raw_lines)}
    end
    local highlights = (built.highlights or {})
    local ns = vim.api.nvim_create_namespace("MetaInfoWindow")
    debug_log(("info render hits=" .. tostring(#idxs) .. " lines=" .. tostring(#lines)))
    do
      local bo = vim.bo[session["info-buf"]]
      bo["modifiable"] = true
    end
    fit_info_width_21(session, lines)
    do
      local ok_set,err_set = pcall(vim.api.nvim_buf_set_lines, session["info-buf"], 0, -1, false, lines)
      if not ok_set then
        debug_log(("info set_lines failed: " .. tostring(err_set)))
      else
      end
    end
    vim.api.nvim_buf_clear_namespace(session["info-buf"], ns, 0, -1)
    for _1, h in ipairs(highlights) do
      vim.api.nvim_buf_add_highlight(session["info-buf"], ns, h[2], h[1], h[3], h[4])
    end
    local bo = vim.bo[session["info-buf"]]
    bo["modifiable"] = false
    return nil
  end
  local function sync_info_cursor_21(session, meta)
    if vim.api.nvim_win_is_valid(session["info-win"]) then
      local info_lines = vim.api.nvim_buf_line_count(session["info-buf"])
      local start_index = (session["info-start-index"] or 1)
      local selected1 = (meta.selected_index + 1)
      local row
      if (info_lines > 0) then
        row = math.max(1, math.min(((selected1 - start_index) + 1), info_lines))
      else
        row = 1
      end
      if (info_lines > 0) then
        local ok_cur,err_cur = pcall(vim.api.nvim_win_set_cursor, session["info-win"], {row, 0})
        if not ok_cur then
          return debug_log(("info set_cursor failed: " .. tostring(err_cur)))
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
  local function update_regular_21(session)
    close_info_window_21(session)
    return update_preview(session)
  end
  local function update_project_21(session, refresh_lines)
    update_preview(session)
    ensure_info_window(session)
    settle_info_window_21(session)
    debug_log(("info enter refresh=" .. tostring(refresh_lines) .. " selected=" .. tostring(session.meta.selected_index) .. " info-win=" .. tostring(session["info-win"]) .. " info-buf=" .. tostring(session["info-buf"])))
    if (session["info-win"] and vim.api.nvim_win_is_valid(session["info-win"])) then
      pcall(vim.api.nvim_set_option_value, "statusline", "", {win = session["info-win"]})
      pcall(vim.api.nvim_set_option_value, "winbar", "", {win = session["info-win"]})
    else
    end
    if (session["info-buf"] and vim.api.nvim_buf_is_valid(session["info-buf"])) then
      local meta = session.meta
      local selected1 = (meta.selected_index + 1)
      local _let_75_ = info_visible_range(session, meta, #(meta.buf.indices or {}), info_max_lines)
      local wanted_start = _let_75_[1]
      local wanted_stop = _let_75_[2]
      local start_index = (session["info-start-index"] or 1)
      local stop_index = (session["info-stop-index"] or 0)
      local out_of_range = ((selected1 < start_index) or (selected1 > stop_index))
      local range_changed = ((wanted_start ~= start_index) or (wanted_stop ~= stop_index))
      if (refresh_lines or out_of_range or range_changed) then
        local idxs = (meta.buf.indices or {})
        local sig = (tostring(idxs) .. "|" .. tostring(#idxs) .. "|" .. tostring(wanted_start) .. "|" .. tostring(wanted_stop) .. "|" .. tostring(info_max_width_now(session)) .. "|" .. tostring(info_height(session)) .. "|" .. tostring(vim.o.columns))
        if (out_of_range or range_changed or (session["info-render-sig"] ~= sig)) then
          session["info-render-sig"] = sig
          render_info_lines_21(session, meta, wanted_start, wanted_stop)
        else
        end
      else
      end
      return sync_info_cursor_21(session, meta)
    else
      return nil
    end
  end
  local function _79_(session, refresh_lines)
    local refresh_lines0
    if (refresh_lines == nil) then
      refresh_lines0 = true
    else
      refresh_lines0 = refresh_lines
    end
    if session["project-mode"] then
      return update_project_21(session, refresh_lines0)
    else
      return update_regular_21(session)
    end
  end
  return {["close-window!"] = close_info_window_21, ["update!"] = _79_}
end
return M
