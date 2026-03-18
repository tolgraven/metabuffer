-- [nfnl] fnl/metabuffer/window/info.fnl
local M = {}
local lineno_mod = require("metabuffer.window.lineno")
local source_mod = require("metabuffer.source")
local path_hl = require("metabuffer.path_highlight")
local query_mod = require("metabuffer.query")
local util = require("metabuffer.util")
local base_window_mod = require("metabuffer.window.base")
local file_info = require("metabuffer.source.file_info")
local disable_airline_statusline_21 = base_window_mod["disable-airline-statusline!"]
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
  local or_5_ = (ref and ref.path)
  if not or_5_ then
    local and_6_ = session and session["source-buf"] and vim.api.nvim_buf_is_valid(session["source-buf"])
    if and_6_ then
      local name = vim.api.nvim_buf_get_name(session["source-buf"])
      if ((type(name) == "string") and (name ~= "")) then
        and_6_ = name
      else
        and_6_ = nil
      end
    end
    or_5_ = and_6_
  end
  return (or_5_ or "")
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
          local function _17_()
            if (budget > 1) then
              return ("\226\128\166" .. string.sub(file, ((#file - budget) + 2)))
            else
              return string.sub(file, ((#file - budget) + 1))
            end
          end
          return {"", _17_()}
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
  local read_file_lines_cached = deps["read-file-lines-cached"]
  local animation_mod = deps["animation-mod"]
  local animate_enter_3f = deps["animate-enter?"]
  local info_fade_ms = deps["info-fade-ms"]
  local update_21 = nil
  local info_window_config = nil
  local function _28_(session, width, height)
    local host_win = (session_host_win(session) or vim.api.nvim_get_current_win())
    if session["window-local-layout"] then
      return {relative = "win", win = host_win, anchor = "NW", row = 0, col = vim.api.nvim_win_get_width(host_win), width = width, height = height}
    else
      return {relative = "editor", anchor = "NE", row = 1, col = vim.o.columns, width = width, height = height}
    end
  end
  info_window_config = _28_
  local ensure_info_window = nil
  local function _30_(session)
    if not valid_info_win_3f(session) then
      local buf = vim.api.nvim_create_buf(false, true)
      local width = info_min_width
      local height = info_height(session)
      local target = info_window_config(session, width, height)
      local animate_info_3f = (animation_mod and animate_enter_3f and animate_enter_3f(session) and animation_mod["enabled?"](session, "info") and not session["info-animated?"])
      local cfg
      if animate_info_3f then
        local start = vim.deepcopy(target)
        start["col"] = (target.col + 8)
        start["winblend"] = 100
        cfg = start
      else
        cfg = target
      end
      local win = floating_window_mod.new(vim, buf, cfg)
      session["info-buf"] = buf
      session["info-win"] = win.window
      disable_airline_statusline_21(session["info-win"])
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
        session["info-render-suspended?"] = true
        session["info-post-fade-refresh?"] = true
        pcall(vim.api.nvim_set_option_value, "winblend", 100, {win = session["info-win"]})
        local function _32_()
          if valid_info_win_3f(session) then
            local function _33_(_)
              if valid_info_win_3f(session) then
                session["info-post-fade-refresh?"] = nil
                session["info-render-suspended?"] = false
                return update_21(session, true)
              else
                return nil
              end
            end
            return animation_mod["animate-float!"](session, "info-enter", session["info-win"], cfg, target, 100, (vim.g.meta_float_winblend or 13), animation_mod["duration-ms"](session, "info", (info_fade_ms or 220)), {kind = "info", ["done!"] = _33_})
          else
            return nil
          end
        end
        return vim.defer_fn(_32_, 17)
      else
        return nil
      end
    else
      return nil
    end
  end
  ensure_info_window = _30_
  local function settle_info_window_21(session)
    if valid_info_win_3f(session) then
      local width = vim.api.nvim_win_get_width(session["info-win"])
      local height = info_height(session)
      local cfg = info_window_config(session, width, height)
      return pcall(vim.api.nvim_win_set_config, session["info-win"], cfg)
    else
      return nil
    end
  end
  local function close_info_window_21(session)
    if valid_info_win_3f(session) then
      pcall(vim.api.nvim_win_close, session["info-win"], true)
    else
    end
    session["info-win"] = nil
    session["info-buf"] = nil
    session["info-post-fade-refresh?"] = nil
    session["info-render-suspended?"] = nil
    session["info-highlight-fill-pending?"] = nil
    session["info-highlight-fill-token"] = nil
    session["info-fixed-width"] = nil
    return nil
  end
  local function apply_info_highlights_21(session, ns, highlights)
    for _, h in ipairs((highlights or {})) do
      vim.api.nvim_buf_add_highlight(session["info-buf"], ns, h[2], h[1], h[3], h[4])
    end
    return nil
  end
  local function build_info_row(session, ref, src_idx, target_width, lnum_digit_width, read_file_lines_cached0, lightweight_3f)
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
    local lnum = tostring(((ref and ref.lnum) or src_idx))
    local lnum_cell0 = lineno_mod["lnum-cell"](lnum, lnum_digit_width)
    local base_path = vim.fn.fnamemodify(((ref and ref.path) or "[Current Buffer]"), ":~:.")
    local path_width = math.max(1, (target_width - (lnum_digit_width + 1) - signcol_display_width))
    local info_view
    if lightweight_3f then
      info_view = {path = base_path, suffix = "", ["suffix-highlights"] = {}, sign = {text = "  ", hl = "LineNr"}, ["highlight-dir"] = false, ["highlight-file"] = false, ["show-icon"] = false}
    else
      info_view = source_mod["info-view"](session, ref, {mode = (session["info-file-entry-view"] or "meta"), ["path-width"] = path_width, ["single-source?"] = not session["project-mode"], ["read-file-lines-cached"] = read_file_lines_cached0})
    end
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
    local icon_info
    if show_icon_3f then
      icon_info = util["devicon-info"](icon_path, file_hl)
    else
      icon_info = {icon = "", ["icon-hl"] = file_hl, ["file-hl"] = file_hl}
    end
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
    local _let_53_ = fit_path_into_width(path, math.max(1, (path_width - icon_width)))
    local dir = _let_53_[1]
    local file0 = _let_53_[2]
    local this_file_hl = (icon_info["file-hl"] or file_hl)
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
    local highlights = {}
    if (sign_width > 0) then
      table.insert(highlights, {"SignColumn", sign_start, sign_end})
    else
    end
    if ((sign_glyph_end > sign_glyph_start) and (sign_width > 0)) then
      table.insert(highlights, {sign_hl, (sign_start + sign_glyph_start), (sign_start + sign_glyph_end)})
    else
    end
    table.insert(highlights, {line_hl, num_start, num_end})
    if (#icon_prefix > 0) then
      table.insert(highlights, {icon_hl, icon_start, icon_end})
    else
    end
    if (highlight_dir_3f and (#dir > 0)) then
      for _, dr in ipairs(path_hl["ranges-for-dir"](dir, dir_start)) do
        table.insert(highlights, {dr.hl, dr.start, dr["end"]})
      end
    else
    end
    if (highlight_file_3f and (#file0 > 0)) then
      table.insert(highlights, {this_file_hl, file_start, (file_start + #file0)})
    else
    end
    if (highlight_file_3f and (#file0 > 0)) then
      local dot = ext_start_in_file(file0)
      if (dot > 0) then
        table.insert(highlights, {icon_hl, (file_start + (dot - 1)), (file_start + #file0)})
      else
      end
    else
    end
    if (#suffix0 > 0) then
      table.insert(highlights, {"Comment", suffix_start, (suffix_start + #suffix0)})
    else
    end
    for _, sh in ipairs(suffix_hls) do
      local s = (suffix_start + (sh.start or 0))
      local e = (suffix_start + (sh["end"] or 0))
      if (e > s) then
        table.insert(highlights, {(sh.hl or "Comment"), s, e})
      else
      end
    end
    return {line = line, highlights = highlights}
  end
  local function schedule_info_highlight_fill_21(session, ns, refs, target_width, lnum_digit_width, deferred_rows)
    local pending = (deferred_rows or {})
    local batch_size = math.max(4, math.min(24, math.max(1, info_height(session))))
    if (#pending == 0) then
      session["info-highlight-fill-pending?"] = false
      return nil
    else
      local token = (1 + (session["info-highlight-fill-token"] or 0))
      session["info-highlight-fill-token"] = token
      session["info-highlight-fill-pending?"] = true
      local next_index = 1
      local function run_batch()
        if (session and session["info-highlight-fill-pending?"] and (token == session["info-highlight-fill-token"]) and session["info-buf"] and vim.api.nvim_buf_is_valid(session["info-buf"])) then
          local stop = math.min(#pending, (next_index + batch_size + -1))
          for i = next_index, stop do
            local spec = pending[i]
            local row0 = spec[1]
            local src_idx = spec[2]
            local ref = refs[src_idx]
            local built = build_info_row(session, ref, src_idx, target_width, lnum_digit_width, read_file_lines_cached, false)
            local line = str(built.line)
            local highlights = (built.highlights or {})
            vim.api.nvim_buf_set_lines(session["info-buf"], row0, (row0 + 1), false, {line})
            vim.api.nvim_buf_clear_namespace(session["info-buf"], ns, row0, (row0 + 1))
            for _, h in ipairs(highlights) do
              vim.api.nvim_buf_add_highlight(session["info-buf"], ns, h[1], row0, h[2], h[3])
            end
          end
          if (stop < #pending) then
            next_index = (stop + 1)
            return vim.defer_fn(run_batch, 17)
          else
            session["info-highlight-fill-pending?"] = false
            return nil
          end
        else
          return nil
        end
      end
      return vim.defer_fn(run_batch, 17)
    end
  end
  local function fit_info_width_21(session, lines)
    if valid_info_win_3f(session) then
      local widths
      local function _66_(line)
        return vim.fn.strdisplaywidth((line or ""))
      end
      widths = vim.tbl_map(_66_, (lines or {}))
      local max_len = numeric_max(widths, 0)
      local needed = max_len
      local host_win = session_host_win(session)
      local host_width
      if (session["window-local-layout"] and host_win and vim.api.nvim_win_is_valid(host_win)) then
        host_width = vim.api.nvim_win_get_width(host_win)
      else
        host_width = vim.o.columns
      end
      local max_available = math.max(info_min_width, math.floor((host_width * 0.34)))
      local upper = math.min(info_max_width, max_available)
      local fit_target = math.max(info_min_width, math.min(needed, upper))
      local frozen_width = (not session["project-mode"] and session["info-fixed-width"])
      local target = (frozen_width or fit_target)
      local height = info_height(session)
      local cfg = info_window_config(session, target, height)
      if (not session["project-mode"] and not frozen_width) then
        session["info-fixed-width"] = math.max(info_min_width, fit_target)
      else
      end
      return pcall(vim.api.nvim_win_set_config, session["info-win"], cfg)
    else
      return nil
    end
  end
  local function info_max_width_now(session)
    local host_win = session_host_win(session)
    local host_width
    if (session and session["window-local-layout"] and host_win and vim.api.nvim_win_is_valid(host_win)) then
      host_width = vim.api.nvim_win_get_width(host_win)
    else
      host_width = vim.o.columns
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
        local function _71_()
          return vim.fn.winsaveview()
        end
        view = vim.api.nvim_win_call(meta.win.window, _71_)
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
  local function build_info_lines(session, refs, idxs, target_width, start_index, stop_index, visible_rows, read_file_lines_cached0)
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
    local lines = {}
    local highlights = {}
    local deferred_rows = {}
    if (#idxs == 0) then
      table.insert(lines, "No matches")
    else
      for i = start_index, stop_index do
        local src_idx = idxs[i]
        local ref = refs[src_idx]
        local row0 = #lines
        local built = build_info_row(session, ref, src_idx, target_width, lnum_digit_width, read_file_lines_cached0, (row0 >= visible_rows))
        table.insert(lines, built.line)
        if (row0 < visible_rows) then
          for _, h in ipairs((built.highlights or {})) do
            table.insert(highlights, {row0, h[1], h[2], h[3]})
          end
        else
          table.insert(deferred_rows, {row0, src_idx})
        end
      end
    end
    return {lines = lines, highlights = highlights, ["deferred-rows"] = deferred_rows, ["lnum-digit-width"] = lnum_digit_width}
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
    local visible_rows = math.max(1, math.min(math.max(1, info_height(session)), math.max(1, ((stop_index - start_index) + 1))))
    local built = build_info_lines(session, refs, idxs, info_max_width_now(session), start_index, stop_index, visible_rows, read_file_lines_cached)
    local raw_lines = built.lines
    local lines
    if (type(raw_lines) == "table") then
      lines = vim.tbl_map(str, raw_lines)
    else
      lines = {str(raw_lines)}
    end
    local highlights = (built.highlights or {})
    local ns = vim.api.nvim_create_namespace("MetaInfoWindow")
    local deferred_rows = (built["deferred-rows"] or {})
    local lnum_digit_width = (built["lnum-digit-width"] or 1)
    debug_log(join_str(" ", {"info render", ("hits=" .. #idxs), ("lines=" .. #lines)}))
    session["info-highlight-fill-token"] = (1 + (session["info-highlight-fill-token"] or 0))
    session["info-highlight-fill-pending?"] = false
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
    apply_info_highlights_21(session, ns, highlights)
    schedule_info_highlight_fill_21(session, ns, refs, info_max_width_now(session), lnum_digit_width, deferred_rows)
    local bo = vim.bo[session["info-buf"]]
    bo["modifiable"] = false
    return nil
  end
  local function sync_info_cursor_21(session, meta)
    if valid_info_win_3f(session) then
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
          return debug_log(join_str(": ", {"info set_cursor failed", err_cur}))
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
  local function render_current_range_21(session, meta)
    local total = #(meta.buf.indices or {})
    local _let_84_ = info_visible_range(session, meta, total, info_max_lines)
    local start_index = _let_84_[1]
    local stop_index = _let_84_[2]
    render_info_lines_21(session, meta, start_index, stop_index)
    sync_info_cursor_21(session, meta)
    return {start_index, stop_index}
  end
  local function schedule_regular_line_meta_refresh_21(session, meta, start_index, stop_index)
    local refs = (meta.buf["source-refs"] or {})
    local idxs = (meta.buf.indices or {})
    local first_row = ((#idxs > 0) and idxs[start_index])
    local first_ref = (first_row and refs[first_row])
    local path = ref_path(session, first_ref)
    local rerender_21
    local function _85_()
      if (session and session["info-buf"] and vim.api.nvim_buf_is_valid(session["info-buf"]) and not session["project-mode"] and session["single-file-info-ready"]) then
        local _let_86_ = render_current_range_21(session, meta)
        local start1 = _let_86_[1]
        local stop1 = _let_86_[2]
        session["info-start-index"] = start1
        session["info-stop-index"] = stop1
        return nil
      else
        return nil
      end
    end
    rerender_21 = _85_
    if (session["single-file-info-fetch-ready"] and (path ~= "") and (1 == vim.fn.filereadable(path))) then
      local lnums = {}
      for i = start_index, stop_index do
        local src_idx = idxs[i]
        local ref = refs[src_idx]
        if (ref and (ref_path(session, ref) == path) and (type(ref.lnum) == "number")) then
          table.insert(lnums, ref.lnum)
        else
        end
      end
      table.sort(lnums)
      if (#lnums > 0) then
        local first_lnum = lnums[1]
        local last_lnum = lnums[#lnums]
        local range_key = (path .. ":" .. start_index .. ":" .. stop_index .. ":" .. first_lnum .. ":" .. last_lnum)
        if (range_key ~= session["info-line-meta-range-key"]) then
          session["info-line-meta-range-key"] = range_key
          local function _89_()
            if (range_key == session["info-line-meta-range-key"]) then
              return rerender_21()
            else
              return nil
            end
          end
          file_info["ensure-file-status-async!"](session, path, _89_)
          local function _91_()
            if (range_key == session["info-line-meta-range-key"]) then
              return rerender_21()
            else
              return nil
            end
          end
          return file_info["ensure-line-meta-range-async!"](session, path, lnums, _91_)
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
    ensure_info_window(session)
    if (session["info-render-suspended?"] and not session["prompt-animating?"] and not session["startup-initializing"]) then
      session["info-post-fade-refresh?"] = nil
      session["info-render-suspended?"] = false
    else
    end
    settle_info_window_21(session)
    if (not session["info-render-suspended?"] and session["info-buf"] and vim.api.nvim_buf_is_valid(session["info-buf"])) then
      local _let_97_ = render_current_range_21(session, session.meta)
      local start_index = _let_97_[1]
      local stop_index = _let_97_[2]
      return schedule_regular_line_meta_refresh_21(session, session.meta, start_index, stop_index)
    else
      return nil
    end
  end
  local function startup_layout_pending_3f(session)
    local initializing = (session["startup-initializing"] or false)
    local animating = (session["prompt-animating?"] or false)
    local pending = (session and session["project-mode"] and (initializing or animating))
    return pending
  end
  local function project_loading_pending_3f(session, has_query)
    local startup = startup_layout_pending_3f(session)
    local bootstrap_pending = (session["project-bootstrap-pending"] or false)
    local bootstrapped = (session["project-bootstrapped"] or false)
    local refresh_pending = (session["lazy-refresh-pending"] or false)
    local refresh_dirty = (session["lazy-refresh-dirty"] or false)
    local stream_done = (session["lazy-stream-done"] or false)
    local pending = (session and session["project-mode"] and (startup or bootstrap_pending or not bootstrapped or refresh_pending or refresh_dirty or not stream_done))
    return (pending and not has_query)
  end
  local function render_project_loading_21(session)
    local hits = #(session.meta.buf.indices or {})
    local total_lines = #(session.meta.buf.content or {})
    local streamed = math.max(0, ((session["lazy-stream-next"] or 1) - 1))
    local total_files = (session["lazy-stream-total"] or 0)
    local bootstrapped = (session["project-bootstrapped"] or false)
    local stream_done = (session["lazy-stream-done"] or false)
    local stage
    if (session["project-bootstrap-pending"] or not bootstrapped) then
      stage = "bootstrapping project"
    else
      if session["prompt-animating?"] then
        stage = "opening layout"
      else
        if stream_done then
          stage = "finalizing results"
        else
          stage = "streaming project sources"
        end
      end
    end
    local progress
    if (total_files > 0) then
      progress = (streamed .. "/" .. total_files .. " files")
    else
      progress = "scanning files"
    end
    local lines = {("Project Mode  " .. stage), "", ("Progress  " .. progress), ("Hits      " .. hits), ("Lines     " .. total_lines)}
    local ns = vim.api.nvim_create_namespace("MetaInfoWindow")
    session["info-start-index"] = 1
    session["info-stop-index"] = #lines
    do
      local bo = vim.bo[session["info-buf"]]
      bo.modifiable = true
    end
    session["info-highlight-fill-token"] = (1 + (session["info-highlight-fill-token"] or 0))
    session["info-highlight-fill-pending?"] = false
    session["info-showing-project-loading?"] = true
    session["info-render-sig"] = nil
    fit_info_width_21(session, lines)
    vim.api.nvim_buf_set_lines(session["info-buf"], 0, -1, false, lines)
    vim.api.nvim_buf_clear_namespace(session["info-buf"], ns, 0, -1)
    vim.api.nvim_buf_add_highlight(session["info-buf"], ns, "Title", 0, 0, -1)
    vim.api.nvim_buf_add_highlight(session["info-buf"], ns, "Comment", 2, 0, 8)
    vim.api.nvim_buf_add_highlight(session["info-buf"], ns, "Comment", 3, 0, 8)
    vim.api.nvim_buf_add_highlight(session["info-buf"], ns, "Comment", 4, 0, 8)
    local bo = vim.bo[session["info-buf"]]
    bo.modifiable = false
    return nil
  end
  local function update_project_startup_21(session)
    ensure_info_window(session)
    if (session["info-render-suspended?"] and not session["prompt-animating?"] and not session["startup-initializing"]) then
      session["info-post-fade-refresh?"] = nil
      session["info-render-suspended?"] = false
    else
    end
    settle_info_window_21(session)
    if (not session["info-render-suspended?"] and session["info-buf"] and vim.api.nvim_buf_is_valid(session["info-buf"])) then
      return render_project_loading_21(session)
    else
      return nil
    end
  end
  local function update_project_21(session, refresh_lines)
    local query_lines = (session.meta["query-lines"] or {})
    local has_query = query_mod["query-lines-has-active?"](query_lines)
    if project_loading_pending_3f(session, has_query) then
      return update_project_startup_21(session)
    else
      ensure_info_window(session)
      if (session["info-render-suspended?"] and not session["prompt-animating?"] and not session["startup-initializing"]) then
        session["info-post-fade-refresh?"] = nil
        session["info-render-suspended?"] = false
      else
      end
      settle_info_window_21(session)
      debug_log(join_str(" ", {"info enter", ("refresh=" .. str(refresh_lines)), ("selected=" .. session.meta.selected_index), ("info-win=" .. session["info-win"]), ("info-buf=" .. session["info-buf"])}))
      if valid_info_win_3f(session) then
        pcall(vim.api.nvim_set_option_value, "statusline", "", {win = session["info-win"]})
        pcall(vim.api.nvim_set_option_value, "winbar", "", {win = session["info-win"]})
      else
      end
      if (not session["info-render-suspended?"] and session["info-buf"] and vim.api.nvim_buf_is_valid(session["info-buf"])) then
        local meta = session.meta
        local force_refresh_3f = (not not session["info-showing-project-loading?"] or (session["info-render-sig"] == nil) or (session["info-start-index"] == nil) or (session["info-stop-index"] == nil))
        local selected1 = (meta.selected_index + 1)
        local _let_107_ = info_visible_range(session, meta, #(meta.buf.indices or {}), info_max_lines)
        local wanted_start = _let_107_[1]
        local wanted_stop = _let_107_[2]
        local start_index = (session["info-start-index"] or 1)
        local stop_index = (session["info-stop-index"] or 0)
        local out_of_range = ((selected1 < start_index) or (selected1 > stop_index))
        local range_changed = ((wanted_start ~= start_index) or (wanted_stop ~= stop_index))
        if (force_refresh_3f or refresh_lines or out_of_range or range_changed) then
          local idxs = (meta.buf.indices or {})
          local sig = join_str("|", {idxs, #idxs, wanted_start, wanted_stop, info_max_width_now(session), info_height(session), vim.o.columns})
          if (force_refresh_3f or out_of_range or range_changed or (session["info-render-sig"] ~= sig)) then
            session["info-render-sig"] = sig
            session["info-showing-project-loading?"] = false
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
  end
  local function _112_(session, refresh_lines)
    local refresh_lines0
    if (refresh_lines == nil) then
      refresh_lines0 = true
    else
      refresh_lines0 = refresh_lines
    end
    if session["project-mode"] then
      update_regular_21(session)
      return update_project_21(session, refresh_lines0)
    else
      return update_regular_21(session)
    end
  end
  update_21 = _112_
  return {["close-window!"] = close_info_window_21, ["update!"] = update_21}
end
return M
