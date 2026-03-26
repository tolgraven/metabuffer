-- [nfnl] fnl/metabuffer/project/source.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local M = {}
local source_mod = require("metabuffer.source")
local transform_mod = require("metabuffer.transform")
M.new = function(opts)
  local settings = opts.settings
  local truthy_3f = opts["truthy?"]
  local selected_ref = opts["selected-ref"]
  local canonical_path = opts["canonical-path"]
  local current_buffer_path = opts["current-buffer-path"]
  local path_under_root_3f = opts["path-under-root?"]
  local allow_project_path_3f = opts["allow-project-path?"]
  local project_file_list = opts["project-file-list"]
  local binary_file_3f = opts["binary-file?"]
  local read_file_view_cached = opts["read-file-view-cached"]
  local session_active_3f = opts["session-active?"]
  local lazy_streaming_allowed_3f = opts["lazy-streaming-allowed?"]
  local on_prompt_changed = opts["on-prompt-changed"]
  local apply_prompt_lines_now_21 = opts["apply-prompt-lines-now!"]
  local prompt_has_active_query_3f = opts["prompt-has-active-query?"]
  local now_ms = opts["now-ms"]
  local prompt_update_delay_ms = opts["prompt-update-delay-ms"]
  local schedule_prompt_update_21 = opts["schedule-prompt-update!"]
  local restore_meta_view_21 = opts["restore-meta-view!"]
  local update_info_window = opts["update-info-window"]
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
  local function push_file_entry_into_pool_21(session, path)
    local meta = session.meta
    local content = meta.buf.content
    local refs = meta.buf["source-refs"]
    local rel = vim.fn.fnamemodify(path, ":.")
    local line = ""
    table.insert(content, line)
    local _20_
    if ((type(rel) == "string") and (rel ~= "")) then
      _20_ = rel
    else
      _20_ = path
    end
    return table.insert(refs, {path = path, lnum = 1, line = _20_, kind = "file-entry", ["open-lnum"] = 1, ["preview-lnum"] = 1})
  end
  local function all_project_file_paths(_session, include_hidden, include_ignored, include_deps, include_binary)
    local root = vim.fn.getcwd()
    local seen = {}
    local out = {}
    for _, p in ipairs(project_file_list(root, include_hidden, include_ignored, include_deps)) do
      local path = canonical_path(p)
      if (path and (1 == vim.fn.filereadable(path)) and (include_binary or not binary_file_3f(path)) and path_under_root_3f(path, root) and not seen[path]) then
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
    return prompt_has_active_query_3f({["last-parsed-query"] = {lines = lines}})
  end
  local function file_only_mode_3f(session)
    return (session["project-mode"] and session["effective-include-files"] and not normal_query_active_3f(session))
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
  local function set_file_entry_source_content_21(session, include_hidden, include_ignored, include_deps, include_binary)
    local meta = session.meta
    meta.buf.content = {}
    meta.buf["source-refs"] = {}
    for _, path in ipairs(all_project_file_paths(session, include_hidden, include_ignored, include_deps, include_binary)) do
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
    local _34_
    if match_idx then
      _34_ = (match_idx - 1)
    else
      _34_ = fallback_idx
    end
    return math.max(0, math.min(_34_, math.max(0, (#meta.buf.indices - 1))))
  end
  local function schedule_lazy_refresh_21(session)
    if (session and session_active_3f(session) and not session.closing) then
      session["lazy-refresh-dirty"] = true
      if not session["lazy-refresh-pending"] then
        session["lazy-refresh-pending"] = true
        local function _36_()
          session["lazy-refresh-pending"] = false
          if (session and session_active_3f(session) and session["lazy-refresh-dirty"]) then
            session["lazy-refresh-dirty"] = false
            if (session.meta and session.meta.buf and vim.api.nvim_buf_is_valid(session.meta.buf.buffer)) then
              if (not session["lazy-stream-done"] and not prompt_has_active_query_3f(session)) then
                pcall(session.meta.refresh_statusline)
                pcall(update_info_window, session)
              else
                local ok,err = pcall(session.meta["on-update"], 0)
                if ok then
                  pcall(session.meta.refresh_statusline)
                  pcall(update_info_window, session)
                else
                  if (err and string.find(tostring(err), "E565")) then
                    local function _37_()
                      if (session and session_active_3f(session) and session.meta and session.meta.buf and vim.api.nvim_buf_is_valid(session.meta.buf.buffer)) then
                        pcall(session.meta["on-update"], 0)
                        pcall(session.meta.refresh_statusline)
                        return pcall(update_info_window, session)
                      else
                        return nil
                      end
                    end
                    vim.defer_fn(_37_, 1)
                  else
                  end
                end
              end
            else
            end
          else
          end
          if (session and session_active_3f(session) and session["lazy-refresh-dirty"]) then
            return schedule_lazy_refresh_21(session)
          else
            return nil
          end
        end
        return vim.defer_fn(_36_, math.max((settings["project-lazy-refresh-min-ms"] or 0), settings["project-lazy-refresh-debounce-ms"]))
      else
        return nil
      end
    else
      return nil
    end
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
  local function collect_project_sources(session, include_hidden, include_ignored, include_deps, include_binary, include_files, prefilter)
    local root = vim.fn.getcwd()
    local current_path = current_buffer_path(session["source-buf"])
    local wrap_width = results_wrap_width(session)
    local file_cache = (session["preview-file-cache"] or {})
    local _
    session["preview-file-cache"] = file_cache
    _ = nil
    local content = {}
    local refs = {}
    if file_only_mode_3f(session) then
      for _0, path in ipairs(all_project_file_paths(session, include_hidden, include_ignored, include_deps, include_binary)) do
        table.insert(content, "")
        local _59_
        do
          local rel = vim.fn.fnamemodify(path, ":.")
          if ((type(rel) == "string") and (rel ~= "")) then
            _59_ = rel
          else
            _59_ = path
          end
        end
        table.insert(refs, {path = path, lnum = 1, line = _59_, kind = "file-entry", ["open-lnum"] = 1, ["preview-lnum"] = 1})
      end
      return {content = content, refs = refs}
    else
      local pool_session = {meta = {buf = {content = content, ["source-refs"] = refs, ["all-indices"] = {}}}}
      push_file_into_pool_21(pool_session, (current_path or "[Current Buffer]"), single_source_view(session), prefilter)
      if current_path then
        file_cache[current_path] = single_source_view(session)
      else
      end
      if include_files then
        for _0, path in ipairs(all_project_file_paths(session, include_hidden, include_ignored, include_deps, include_binary)) do
          push_file_entry_into_pool_21(session, path)
        end
      else
      end
      for _0, path in ipairs(project_file_list(root, include_hidden, include_ignored, include_deps)) do
        local rel = vim.fn.fnamemodify(path, ":.")
        if ((#content < settings["project-max-total-lines"]) and allow_project_path_3f(rel, include_hidden, include_deps) and (include_binary or not binary_file_3f(path)) and (not current_path or (vim.fn.fnamemodify(path, ":p") ~= vim.fn.fnamemodify(current_path, ":p"))) and (1 == vim.fn.filereadable(path))) then
          local size = vim.fn.getfsize(path)
          if ((size >= 0) and (size <= settings["project-max-file-bytes"])) then
            local view = read_file_view_cached(path, {["include-binary"] = include_binary, transforms = (session["effective-transforms"] or {}), ["wrap-width"] = wrap_width, linebreak = true})
            if (type(view) == "table") then
              file_cache[path] = view
              push_file_into_pool_21(pool_session, path, view, prefilter)
            else
            end
          else
          end
        else
        end
      end
      return {content = content, refs = refs}
    end
  end
  local function init_project_pool_21(session, prefilter)
    local root = vim.fn.getcwd()
    local include_hidden = session["effective-include-hidden"]
    local include_ignored = session["effective-include-ignored"]
    local include_deps = session["effective-include-deps"]
    local include_binary = session["effective-include-binary"]
    local wrap_width = results_wrap_width(session)
    local include_files = session["effective-include-files"]
    local current = canonical_path(current_buffer_path(session["source-buf"]))
    local open_paths = open_project_buffer_paths(session, root, include_hidden, include_deps)
    local all_paths = project_file_list(root, include_hidden, include_ignored, include_deps)
    local file_entry_paths
    if include_files then
      file_entry_paths = all_project_file_paths(session, include_hidden, include_ignored, include_deps, include_binary)
    else
      file_entry_paths = {}
    end
    local deferred = {}
    local deferred_seen = {}
    if file_only_mode_3f(session) then
      set_file_entry_source_content_21(session, include_hidden, include_ignored, include_deps, include_binary)
      return {["deferred-paths"] = {}, ["estimated-lines"] = 0}
    else
      set_single_source_content_21(session, session["project-mode"])
      for _, path in ipairs(file_entry_paths) do
        push_file_entry_into_pool_21(session, path)
      end
      for _, path in ipairs(open_paths) do
        local p = canonical_path(path)
        if (p and (1 == vim.fn.filereadable(p))) then
          deferred_seen[p] = true
          push_file_into_pool_21(session, p, read_file_view_cached(p, {["include-binary"] = include_binary, transforms = (session["effective-transforms"] or {}), ["wrap-width"] = wrap_width, linebreak = true}), prefilter)
        else
        end
      end
      for _, path in ipairs(all_paths) do
        local p = canonical_path(path)
        if (p and not deferred_seen[p] and (include_binary or not binary_file_3f(p)) and (not current or (p ~= current))) then
          deferred_seen[p] = true
          table.insert(deferred, p)
        else
        end
      end
      return {["deferred-paths"] = deferred, ["estimated-lines"] = estimate_lines_from_files(deferred)}
    end
  end
  local function lazy_preferred_3f(session, estimated_lines)
    return (lazy_streaming_allowed_3f(session) and truthy_3f(session["lazy-mode"]) and ((session["project-mode"] and not session["project-bootstrapped"] and not prompt_has_active_query_3f(session)) or (settings["project-lazy-min-estimated-lines"] <= 0) or (estimated_lines >= settings["project-lazy-min-estimated-lines"])))
  end
  local function start_project_stream_21(session, prefilter, init)
    session["lazy-stream-id"] = (1 + (session["lazy-stream-id"] or 0))
    session["lazy-stream-done"] = false
    session["lazy-stream-next"] = 1
    session["lazy-stream-paths"] = (init["deferred-paths"] or {})
    session["lazy-stream-total"] = #session["lazy-stream-paths"]
    session["lazy-prefilter"] = prefilter
    local stream_id = session["lazy-stream-id"]
    local function run_batch()
      if (session_active_3f(session) and (stream_id == session["lazy-stream-id"]) and not session["lazy-stream-done"]) then
        local paths = session["lazy-stream-paths"]
        local total = #paths
        local chunk = math.max(1, settings["project-lazy-chunk-size"])
        local frame_budget = math.max(1, (settings["project-lazy-frame-budget-ms"] or 6))
        local batch_start = now_ms()
        local consumed = 0
        local touched = false
        while ((consumed < chunk) and ((now_ms() - batch_start) < frame_budget) and (session["lazy-stream-next"] <= total) and (#session.meta.buf.content < settings["project-max-total-lines"])) do
          local path = paths[session["lazy-stream-next"]]
          local view = (path and read_file_view_cached(path, {["include-binary"] = session["effective-include-binary"], transforms = (session["effective-transforms"] or {}), ["wrap-width"] = results_wrap_width(session), linebreak = true}))
          local before = #session.meta.buf.content
          if view then
            push_file_into_pool_21(session, path, view, prefilter)
            if (#session.meta.buf.content > before) then
              touched = true
            else
            end
          else
          end
          consumed = (consumed + 1)
          session["lazy-stream-next"] = (session["lazy-stream-next"] + 1)
        end
        if ((session["lazy-stream-next"] > total) or (#session.meta.buf.content >= settings["project-max-total-lines"])) then
          session["lazy-stream-done"] = true
        else
        end
        if (session["lazy-stream-done"] and session.meta and session.meta.buf and not session["prompt-animating?"] and not session["startup-initializing"]) then
          session.meta.buf["visible-source-syntax-only"] = false
          pcall(session.meta.buf["apply-source-syntax-regions"])
          if not prompt_has_active_query_3f(session) then
            reset_meta_indices_21(session.meta)
            pcall(session.meta.buf.render)
            restore_meta_view_21(session.meta, session["source-view"], session, update_info_window)
          else
          end
          pcall(session.meta.refresh_statusline)
          pcall(update_info_window, session, true)
        else
        end
        if touched then
          schedule_lazy_refresh_21(session)
        else
        end
        if (not session["lazy-stream-done"] and (stream_id == session["lazy-stream-id"]) and session_active_3f(session)) then
          return vim.defer_fn(run_batch, 17)
        else
          return nil
        end
      else
        return nil
      end
    end
    return vim.defer_fn(run_batch, 0)
  end
  local function apply_source_set_21(session)
    local meta = session.meta
    local query_source_key = source_mod["query-source-key"](session["last-parsed-query"])
    local query_source_3f = clj.boolean(query_source_key)
    local old_ref = (session["project-mode"] and selected_ref(meta))
    local prefilter = current_project_prefilter(session)
    local old_line
    if (meta.selected_index and (meta.selected_index >= 0) and ((meta.selected_index + 1) <= #meta.buf.indices)) then
      old_line = math.max(1, meta.selected_line())
    else
      old_line = math.max(1, (session["initial-source-line"] or 1))
    end
    if query_source_3f then
      session["lazy-stream-id"] = (1 + (session["lazy-stream-id"] or 0))
      session["lazy-stream-done"] = true
      set_query_source_content_21(session)
    elseif session["project-mode"] then
      local init = init_project_pool_21(session, prefilter)
      if lazy_preferred_3f(session, (init["estimated-lines"] or 0)) then
        start_project_stream_21(session, prefilter, init)
      else
        local pool = collect_project_sources(session, session["effective-include-hidden"], session["effective-include-ignored"], session["effective-include-deps"], session["effective-include-binary"], session["effective-include-files"], prefilter)
        meta.buf.content = pool.content
        meta.buf["source-refs"] = pool.refs
        bump_content_version_21(meta)
        session["lazy-stream-done"] = true
        if (session.meta and session.meta.buf and not session["prompt-animating?"] and not session["startup-initializing"]) then
          session.meta.buf["visible-source-syntax-only"] = false
          pcall(session.meta.buf["apply-source-syntax-regions"])
        else
        end
      end
    else
      session["lazy-stream-id"] = (1 + (session["lazy-stream-id"] or 0))
      session["lazy-stream-done"] = true
      set_single_source_content_21(session, false)
    end
    if not query_source_3f then
      meta.buf["show-source-prefix"] = (session["project-mode"] and session["effective-include-files"])
      meta.buf["show-source-separators"] = session["project-mode"]
    else
    end
    session["active-source-key"] = query_source_key
    meta.buf["visible-source-syntax-only"] = clj.boolean((session["project-mode"] or query_source_3f))
    reset_meta_indices_21(meta)
    if query_source_3f then
      if (#meta.buf.indices > 0) then
        meta.selected_index = 0
      else
        meta.selected_index = 0
      end
    elseif session["project-mode"] then
      meta.selected_index = best_project_selection_index(session, old_ref, old_line)
    else
      meta.selected_index = math.max(0, (meta.buf["closest-index"](old_line) - 1))
    end
    meta._prev_text = ""
    meta["_filter-cache"] = {}
    meta["_filter-cache-line-count"] = #meta.buf.content
    return nil
  end
  local function schedule_source_set_rebuild_21(session, wait_ms)
    if (session and not session.closing) then
      session["source-set-rebuild-token"] = (1 + (session["source-set-rebuild-token"] or 0))
      local token = session["source-set-rebuild-token"]
      session["source-set-rebuild-pending"] = true
      local function _86_()
        if (session and (token == session["source-set-rebuild-token"])) then
          session["source-set-rebuild-pending"] = false
        else
        end
        if (session and (token == session["source-set-rebuild-token"]) and session["prompt-buf"] and session_active_3f(session) and not session.closing) then
          apply_source_set_21(session)
          if apply_prompt_lines_now_21 then
            return apply_prompt_lines_now_21(session)
          else
            return on_prompt_changed(session["prompt-buf"], true)
          end
        else
          return nil
        end
      end
      return vim.defer_fn(_86_, math.max(0, (wait_ms or 0)))
    else
      return nil
    end
  end
  local function apply_minimal_source_set_21(session)
    local meta = session.meta
    local old_line
    if (meta.selected_index and (meta.selected_index >= 0) and ((meta.selected_index + 1) <= #meta.buf.indices)) then
      old_line = math.max(1, meta.selected_line())
    else
      old_line = math.max(1, (session["initial-source-line"] or 1))
    end
    session["lazy-stream-id"] = (1 + (session["lazy-stream-id"] or 0))
    session["lazy-stream-done"] = true
    set_single_source_content_21(session, false)
    meta.selected_index = math.max(0, (meta.buf["closest-index"](old_line) - 1))
    meta._prev_text = ""
    meta["_filter-cache"] = {}
    meta["_filter-cache-line-count"] = #meta.buf.content
    return nil
  end
  local function schedule_project_bootstrap_21(session, wait_ms)
    if (session and session["project-mode"] and not session["project-bootstrapped"]) then
      session["project-bootstrap-token"] = (1 + (session["project-bootstrap-token"] or 0))
      local token = session["project-bootstrap-token"]
      local delay = math.max(0, (wait_ms or session["project-bootstrap-delay-ms"] or settings["project-bootstrap-delay-ms"] or 0))
      session["project-bootstrap-pending"] = true
      local run_bootstrap_21
      local function _92_()
        if (session and (token == session["project-bootstrap-token"])) then
          session["project-bootstrap-pending"] = false
        else
        end
        if (session and (token == session["project-bootstrap-token"]) and session["project-mode"] and session["prompt-buf"] and session_active_3f(session) and not session["project-bootstrapped"]) then
          local has_query = prompt_has_active_query_3f(session)
          apply_source_set_21(session)
          session["project-bootstrapped"] = true
          if has_query then
            session["prompt-update-dirty"] = true
            local now = now_ms()
            local quiet_for = (now - (session["prompt-last-change-ms"] or 0))
            local need_quiet = math.max(0, prompt_update_delay_ms(session))
            if (quiet_for < need_quiet) then
              schedule_prompt_update_21(session, math.max(1, (need_quiet - quiet_for)))
            else
              schedule_prompt_update_21(session, 0)
            end
          else
          end
          if not has_query then
            pcall(session.meta.buf.render)
            restore_meta_view_21(session.meta, session["source-view"], session, update_info_window)
            pcall(session.meta.refresh_statusline)
            pcall(update_info_window, session, true)
            local function _96_()
              if (session and session_active_3f(session) and not session.closing) then
                return pcall(update_info_window, session, true)
              else
                return nil
              end
            end
            vim.defer_fn(_96_, 17)
          else
          end
          session["project-mode-starting?"] = false
          return nil
        else
          return nil
        end
      end
      run_bootstrap_21 = _92_
      return vim.defer_fn(run_bootstrap_21, delay)
    else
      return nil
    end
  end
  local api = {["schedule-lazy-refresh!"] = schedule_lazy_refresh_21, ["apply-source-set!"] = apply_source_set_21, ["schedule-source-set-rebuild!"] = schedule_source_set_rebuild_21, ["apply-minimal-source-set!"] = apply_minimal_source_set_21, ["schedule-project-bootstrap!"] = schedule_project_bootstrap_21}
  return api
end
return M
