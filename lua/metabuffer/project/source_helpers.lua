-- [nfnl] fnl/metabuffer/project/source_helpers.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local M = {}
local events = require("metabuffer.events")
local source_mod = require("metabuffer.source")
local transform_mod = require("metabuffer.transform")
local function parse_prefilter_terms(query_lines, ignorecase)
  local function unclosed_pattern_delims_3f(token)
    local s = (token or "")
    local n = #s
    local i = 1
    local paren = 0
    local bracket = 0
    while (i <= n) do
      local ch = string.sub(s, i, i)
      if (ch == "%") then
        i = (i + 2)
      else
        if (ch == "(") then
          paren = (paren + 1)
        elseif (ch == ")") then
          paren = math.max(0, (paren - 1))
        else
        end
        if (ch == "[") then
          bracket = (bracket + 1)
        elseif (ch == "]") then
          bracket = math.max(0, (bracket - 1))
        else
        end
        i = (i + 1)
      end
    end
    return ((paren > 0) or (bracket > 0))
  end
  local function regex_token_3f(token)
    local and_4_ = (type(token) == "string") and (token ~= "") and not string.match(token, "^[%?%*%+%|%.]$") and not unclosed_pattern_delims_3f(token) and (nil ~= string.find(token, "[\\%[%]%(%)%+%*%?%|%.]"))
    if and_4_ then
      local ok = pcall(vim.regex, ("\\C" .. token))
      and_4_ = ok
    end
    return and_4_
  end
  local function prefilter_safe_token(tok)
    local raw = (tok or "")
    local escaped_neg_3f = vim.startswith(raw, "\\!")
    local negated_3f = ((string.sub(raw, 1, 1) == "!") and not escaped_neg_3f)
    local body0
    if escaped_neg_3f then
      body0 = string.sub(raw, 2)
    elseif negated_3f then
      body0 = string.sub(raw, 2)
    else
      body0 = raw
    end
    local anchor_start = ((#body0 > 0) and not vim.startswith(body0, "\\^") and (string.sub(body0, 1, 1) == "^"))
    local body1
    if anchor_start then
      body1 = string.sub(body0, 2)
    else
      body1 = body0
    end
    local anchor_end = ((#body1 > 0) and not vim.endswith(body1, "\\$") and (string.sub(body1, #body1) == "$"))
    local body2
    if anchor_end then
      body2 = string.sub(body1, 1, (#body1 - 1))
    else
      body2 = body1
    end
    local unescaped = string.gsub(string.gsub(string.gsub(body2, "\\\\!", "!"), "\\%^", "^"), "\\%$", "$")
    if negated_3f then
      return nil
    else
      if regex_token_3f(unescaped) then
        return nil
      else
        if (unescaped ~= "") then
          return unescaped
        else
          return nil
        end
      end
    end
  end
  local groups = {}
  for _, line in ipairs((query_lines or {})) do
    local trimmed = vim.trim((line or ""))
    if (trimmed ~= "") then
      local toks = {}
      for _0, tok in ipairs(vim.split(trimmed, "%s+")) do
        local val_110_auto = prefilter_safe_token(tok)
        if val_110_auto then
          local needle = val_110_auto
          local function _12_()
            if ignorecase then
              return string.lower(needle)
            else
              return needle
            end
          end
          table.insert(toks, _12_())
        else
        end
      end
      if (#toks > 0) then
        table.insert(groups, toks)
      else
      end
    else
    end
  end
  return groups
end
local function line_matches_prefilter_3f(line, spec)
  if (not spec or not spec.groups or (#spec.groups == 0)) then
    return true
  else
    local probe0 = (line or "")
    local probe
    if spec.ignorecase then
      probe = string.lower(probe0)
    else
      probe = probe0
    end
    local all_groups = true
    for _, grp in ipairs(spec.groups) do
      local grp_ok = true
      for _0, tok in ipairs(grp) do
        if (grp_ok and not string.find(probe, tok, 1, true)) then
          grp_ok = false
        else
        end
      end
      if (all_groups and not grp_ok) then
        all_groups = false
      else
      end
    end
    return all_groups
  end
end
local function reset_meta_indices_21(meta)
  local all_indices = {}
  for i = 1, #meta.buf.content do
    table.insert(all_indices, i)
  end
  meta.buf["all-indices"] = all_indices
  meta.buf.indices = vim.deepcopy(all_indices)
  return nil
end
local function bump_content_version_21(meta)
  meta.buf["content-version"] = (1 + (meta.buf["content-version"] or 0))
  return nil
end
local function file_query_matches_3f(path, q, ignorecase)
  local probe0 = (path or "")
  local probe
  if ignorecase then
    probe = string.lower(probe0)
  else
    probe = probe0
  end
  local query0 = vim.trim((q or ""))
  local query
  if ignorecase then
    query = string.lower(query0)
  else
    query = query0
  end
  if (query == "") then
    return true
  else
    return (nil ~= string.find(probe, query, 1, true))
  end
end
local function path_matches_file_queries_3f(path, queries, ignorecase)
  if (#(queries or {}) == 0) then
    return true
  else
    local path0 = (path or "")
    local rel
    if (path0 ~= "") then
      rel = vim.fn.fnamemodify(path0, ":.")
    else
      rel = ""
    end
    local probe
    if (rel ~= "") then
      probe = (rel .. " " .. path0)
    else
      probe = path0
    end
    local ok0 = true
    local ok = ok0
    for _, q in ipairs((queries or {})) do
      if (ok and not file_query_matches_3f(probe, q, ignorecase)) then
        ok = false
      else
      end
    end
    return ok
  end
end
local function active_file_query_lines(session)
  local out = {}
  for _, q in ipairs((session["file-query-lines"] or {})) do
    local trimmed = vim.trim((q or ""))
    if (trimmed ~= "") then
      table.insert(out, trimmed)
    else
    end
  end
  return out
end
local function current_file_filter(session)
  local queries = active_file_query_lines(session)
  local active_3f = (session["effective-include-files"] and (#queries > 0))
  return {["active?"] = active_3f, queries = queries, ignorecase = clj.boolean((session.meta and session.meta.ignorecase and session.meta.ignorecase()))}
end
local function file_only_mode_3f(session, normal_query_active_3f)
  return (session["project-mode"] and session["effective-include-files"] and not normal_query_active_3f(session))
end
M.new = function(opts)
  local settings = opts.settings
  local truthy_3f = opts["truthy?"]
  local canonical_path = opts["canonical-path"]
  local current_buffer_path = opts["current-buffer-path"]
  local path_under_root_3f = opts["path-under-root?"]
  local allow_project_path_3f = opts["allow-project-path?"]
  local project_file_list = opts["project-file-list"]
  local binary_file_3f = opts["binary-file?"]
  local read_file_view_cached = opts["read-file-view-cached"]
  local prompt_has_active_query_3f = opts["prompt-has-active-query?"]
  local function push_file_entry_into_pool_21(session, path)
    local meta = session.meta
    local content = meta.buf.content
    local refs = meta.buf["source-refs"]
    local rel = vim.fn.fnamemodify(path, ":.")
    local line = ""
    table.insert(content, line)
    local _28_
    if ((type(rel) == "string") and (rel ~= "")) then
      _28_ = rel
    else
      _28_ = path
    end
    return table.insert(refs, {path = path, lnum = 1, line = _28_, kind = "file-entry", ["open-lnum"] = 1, ["preview-lnum"] = 1})
  end
  local function include_file_path_3f(path, file_filter)
    return (not (file_filter and file_filter["active?"]) or path_matches_file_queries_3f(path, ((file_filter and file_filter.queries) or {}), clj.boolean((file_filter and file_filter.ignorecase))))
  end
  local function all_project_file_paths(_session, include_hidden, include_ignored, include_deps, include_binary, file_filter)
    local root = vim.fn.getcwd()
    local seen = {}
    local out = {}
    for _, p in ipairs(project_file_list(root, include_hidden, include_ignored, include_deps)) do
      local path = canonical_path(p)
      if (path and (1 == vim.fn.filereadable(path)) and (include_binary or not binary_file_3f(path)) and path_under_root_3f(path, root) and include_file_path_3f(path, file_filter) and not seen[path]) then
        seen[path] = true
        table.insert(out, path)
      else
      end
    end
    return out
  end
  local function results_wrap_width(session)
    local win = (session and session.meta and session.meta.win and session.meta.win.window)
    if (win and vim.api.nvim_win_is_valid(win)) then
      local wrap_3f = clj.boolean(vim.api.nvim_get_option_value("wrap", {win = win}))
      if wrap_3f then
        local wininfo = vim.fn.getwininfo(win)[1]
        local textoff = ((wininfo and wininfo.textoff) or 0)
        local info_width
        if (session["info-win"] and vim.api.nvim_win_is_valid(session["info-win"])) then
          info_width = vim.api.nvim_win_get_width(session["info-win"])
        else
          info_width = 0
        end
        return math.max(12, (vim.api.nvim_win_get_width(win) - textoff - info_width))
      else
        return nil
      end
    else
      return nil
    end
  end
  local function single_source_view(session)
    local path = current_buffer_path(session["source-buf"])
    local transforms = (session["effective-transforms"] or session["transform-flags"] or {})
    local binary_3f = (path and (1 == vim.fn.filereadable(path)) and binary_file_3f(path))
    local wrap_width = results_wrap_width(session)
    if binary_3f then
      if session["effective-include-binary"] then
        return (read_file_view_cached(path, {["include-binary"] = true, transforms = transforms, ["wrap-width"] = wrap_width, linebreak = true}) or {lines = {}, ["line-map"] = {}})
      else
        return {lines = {}, ["line-map"] = {}, ["row-meta"] = {}}
      end
    else
      local raw_lines
      if (session["source-buf"] and vim.api.nvim_buf_is_valid(session["source-buf"])) then
        raw_lines = vim.api.nvim_buf_get_lines(session["source-buf"], 0, -1, false)
      else
        raw_lines = (session["single-content"] or {})
      end
      return transform_mod["apply-view"](path, raw_lines, {path = path, transforms = transforms, ["wrap-width"] = wrap_width, linebreak = true, binary = false})
    end
  end
  local function set_single_source_content_21(session, show_separators)
    local meta = session.meta
    local path = (current_buffer_path(session["source-buf"]) or ((#(session["single-refs"] or {}) > 0) and session["single-refs"][1].path) or "[Current Buffer]")
    local view = single_source_view(session)
    local content = {}
    local refs = {}
    for idx, line in ipairs((view.lines or {})) do
      local lnum = ((view["line-map"] or {})[idx] or idx)
      local meta0 = ((view["row-meta"] or {})[idx] or {})
      table.insert(content, (line or ""))
      table.insert(refs, vim.tbl_extend("force", {path = path, lnum = lnum, line = line}, meta0))
    end
    meta.buf.content = content
    meta.buf["source-refs"] = refs
    bump_content_version_21(meta)
    meta.buf["show-source-prefix"] = false
    meta.buf["show-source-separators"] = show_separators
    return reset_meta_indices_21(meta)
  end
  local function normal_query_active_3f(session)
    local lines = ((session["last-parsed-query"] and session["last-parsed-query"].lines) or {})
    local active_3f = false
    local on_3f = active_3f
    for _, line in ipairs(lines) do
      if (not on_3f and (vim.trim((line or "")) ~= "")) then
        on_3f = true
      else
      end
    end
    return on_3f
  end
  local function set_query_source_content_21(session)
    local meta = session.meta
    local pool = (source_mod["collect-query-source-set"](settings, session["last-parsed-query"], canonical_path) or {content = {}, refs = {}})
    meta.buf.content = pool.content
    meta.buf["source-refs"] = pool.refs
    bump_content_version_21(meta)
    meta.buf["show-source-prefix"] = false
    meta.buf["show-source-separators"] = true
    return reset_meta_indices_21(meta)
  end
  local function set_file_entry_source_content_21(session, include_hidden, include_ignored, include_deps, include_binary, file_filter)
    local meta = session.meta
    meta.buf.content = {}
    meta.buf["source-refs"] = {}
    for _, path in ipairs(all_project_file_paths(session, include_hidden, include_ignored, include_deps, include_binary, file_filter)) do
      push_file_entry_into_pool_21(session, path)
    end
    bump_content_version_21(meta)
    meta.buf["show-source-prefix"] = true
    meta.buf["show-source-separators"] = true
    return reset_meta_indices_21(meta)
  end
  local function best_project_selection_index(session, old_ref, old_line)
    local meta = session.meta
    local refs = (meta.buf["source-refs"] or {})
    local old_ref_path = canonical_path((old_ref and old_ref.path))
    local target_path = (old_ref_path or canonical_path(current_buffer_path(session["source-buf"])))
    local target_lnum = ((old_ref and old_ref.lnum) or old_line)
    local fallback_idx = math.max(0, (meta.buf["closest-index"](old_line) - 1))
    local match_idx = nil
    if (old_ref and old_ref.path and old_ref.lnum and refs) then
      for i = 1, #refs do
        local r = refs[i]
        if (not match_idx and r and ((canonical_path(r.path) or "") == (old_ref_path or "")) and ((r.lnum or 0) == (old_ref.lnum or 0))) then
          match_idx = i
        else
        end
      end
    else
    end
    if (not match_idx and target_path and refs) then
      local best_idx = nil
      local best_dist = math.huge
      for i = 1, #refs do
        local r = refs[i]
        local r_path = (r and canonical_path(r.path))
        if (r_path and (r_path == target_path)) then
          local dist = math.abs(((r.lnum or 1) - (target_lnum or 1)))
          if (dist < best_dist) then
            best_dist = dist
            best_idx = i
          else
          end
        else
        end
      end
      match_idx = best_idx
    else
    end
    local _43_
    if match_idx then
      _43_ = (match_idx - 1)
    else
      _43_ = fallback_idx
    end
    return math.max(0, math.min(_43_, math.max(0, (#meta.buf.indices - 1))))
  end
  local function push_file_into_pool_21(session, path, view, prefilter)
    local lines = (view and view.lines)
    local line_map = ((view and view["line-map"]) or {})
    local row_meta = ((view and view["row-meta"]) or {})
    if (not lines or (type(lines) == "nil")) then
      return 0
    else
      local meta = session.meta
      local content = meta.buf.content
      local refs = meta.buf["source-refs"]
      local start_n = #content
      local take = math.max(0, (settings["project-max-total-lines"] - start_n))
      local has_prefilter = (prefilter and prefilter.groups and (#prefilter.groups > 0))
      if (take <= 0) then
        return 0
      else
        local added = 0
        if has_prefilter then
          for lnum, line in ipairs(lines) do
            if ((added < take) and line_matches_prefilter_3f(line, prefilter)) then
              table.insert(content, line)
              table.insert(refs, vim.tbl_extend("force", {path = path, lnum = (line_map[lnum] or lnum), line = line}, (row_meta[lnum] or {})))
              added = (added + 1)
            else
            end
          end
        else
          for lnum, line in ipairs(lines) do
            if (added < take) then
              table.insert(content, line)
              table.insert(refs, vim.tbl_extend("force", {path = path, lnum = (line_map[lnum] or lnum), line = line}, (row_meta[lnum] or {})))
              added = (added + 1)
            else
            end
          end
        end
        if (added > 0) then
          for i = (start_n + 1), #content do
            table.insert(meta.buf["all-indices"], i)
          end
        else
        end
        return added
      end
    end
  end
  local function current_project_prefilter(session)
    if (session and session["project-mode"] and session["prefilter-mode"] and session.meta and session.meta.ignorecase) then
      local query_lines = ((session["last-parsed-query"] and session["last-parsed-query"].lines) or (session.meta and session.meta["query-lines"]) or {})
      local ignorecase = clj.boolean(session.meta.ignorecase())
      local groups = parse_prefilter_terms(query_lines, ignorecase)
      if (#groups > 0) then
        return {groups = groups, ignorecase = ignorecase}
      else
        return nil
      end
    else
      return nil
    end
  end
  local function open_project_buffer_paths(session, root, include_hidden, include_deps)
    local out = {}
    local seen = {}
    local current = canonical_path(current_buffer_path(session["source-buf"]))
    local include_binary = session["effective-include-binary"]
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if (vim.api.nvim_buf_is_valid(buf) and (vim.bo[buf].buftype == "") and truthy_3f(vim.bo[buf].buflisted)) then
        local name = canonical_path(vim.api.nvim_buf_get_name(buf))
        if (name and (not current or (name ~= current)) and not seen[name] and (1 == vim.fn.filereadable(name)) and (include_binary or not binary_file_3f(name)) and path_under_root_3f(name, root)) then
          local rel = vim.fn.fnamemodify(name, ":.")
          if allow_project_path_3f(rel, include_hidden, include_deps) then
            seen[name] = true
            table.insert(out, name)
          else
          end
        else
        end
      else
      end
    end
    return out
  end
  local function estimate_lines_from_files(paths)
    local bytes = 0
    for _, path in ipairs((paths or {})) do
      local size = vim.fn.getfsize(path)
      if (size > 0) then
        bytes = (bytes + size)
      else
      end
    end
    return math.floor((bytes / 80))
  end
  local function project_view_opts(session, wrap_width)
    return {["include-binary"] = session["effective-include-binary"], transforms = (session["effective-transforms"] or {}), ["wrap-width"] = wrap_width, linebreak = true}
  end
  local function cached_project_view(session, path, wrap_width)
    return (path and read_file_view_cached(path, project_view_opts(session, wrap_width)))
  end
  local function set_project_pool_21(session, pool)
    local meta = session.meta
    meta.buf.content = pool.content
    meta.buf["source-refs"] = pool.refs
    return bump_content_version_21(meta)
  end
  local function enable_full_source_syntax_21(session)
    if (session.meta and session.meta.buf and not session["prompt-animating?"] and not session["startup-initializing"]) then
      session.meta.buf["visible-source-syntax-only"] = false
      return events.send("on-source-syntax-refresh!", {session = session, ["immediate?"] = true})
    else
      return nil
    end
  end
  local function emit_source_pool_change_21(session, opts0)
    return events.send("on-source-pool-change!", vim.tbl_extend("force", {session = session}, (opts0 or {})))
  end
  local function finish_project_stream_21(session, sent_complete_3f)
    session["lazy-stream-done"] = true
    enable_full_source_syntax_21(session)
    if not sent_complete_3f then
      return emit_source_pool_change_21(session, {phase = "complete", ["phase-only?"] = true, ["force?"] = true, ["refresh-lines"] = true})
    else
      return nil
    end
  end
  local function maybe_finish_project_stream_21(session)
    if (session["lazy-stream-done"] and session.meta and session.meta.buf and not session["prompt-animating?"] and not session["startup-initializing"]) then
      local has_query_3f = prompt_has_active_query_3f(session)
      local sent_complete_3f = false
      local sent_complete = sent_complete_3f
      if not has_query_3f then
        emit_source_pool_change_21(session, {phase = "complete", ["force?"] = true, ["refresh-lines"] = true, ["restore-view?"] = true})
        sent_complete = true
      else
      end
      return finish_project_stream_21(session, sent_complete)
    else
      return nil
    end
  end
  local function _61_(session)
    return file_only_mode_3f(session, normal_query_active_3f)
  end
  return {["parse-prefilter-terms"] = parse_prefilter_terms, ["line-matches-prefilter?"] = line_matches_prefilter_3f, ["reset-meta-indices!"] = reset_meta_indices_21, ["bump-content-version!"] = bump_content_version_21, ["push-file-entry-into-pool!"] = push_file_entry_into_pool_21, ["include-file-path?"] = include_file_path_3f, ["all-project-file-paths"] = all_project_file_paths, ["results-wrap-width"] = results_wrap_width, ["single-source-view"] = single_source_view, ["set-single-source-content!"] = set_single_source_content_21, ["normal-query-active?"] = normal_query_active_3f, ["current-file-filter"] = current_file_filter, ["file-only-mode?"] = _61_, ["set-query-source-content!"] = set_query_source_content_21, ["set-file-entry-source-content!"] = set_file_entry_source_content_21, ["best-project-selection-index"] = best_project_selection_index, ["push-file-into-pool!"] = push_file_into_pool_21, ["current-project-prefilter"] = current_project_prefilter, ["open-project-buffer-paths"] = open_project_buffer_paths, ["estimate-lines-from-files"] = estimate_lines_from_files, ["project-view-opts"] = project_view_opts, ["cached-project-view"] = cached_project_view, ["set-project-pool!"] = set_project_pool_21, ["enable-full-source-syntax!"] = enable_full_source_syntax_21, ["emit-source-pool-change!"] = emit_source_pool_change_21, ["finish-project-stream!"] = finish_project_stream_21, ["maybe-finish-project-stream!"] = maybe_finish_project_stream_21}
end
return M
