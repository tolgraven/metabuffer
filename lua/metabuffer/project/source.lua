-- [nfnl] fnl/metabuffer/project/source.fnl
local M = {}
M.new = function(opts)
  local settings = opts.settings
  local truthy_3f = opts["truthy?"]
  local selected_ref = opts["selected-ref"]
  local canonical_path = opts["canonical-path"]
  local current_buffer_path = opts["current-buffer-path"]
  local path_under_root_3f = opts["path-under-root?"]
  local allow_project_path_3f = opts["allow-project-path?"]
  local project_file_list = opts["project-file-list"]
  local read_file_lines_cached = opts["read-file-lines-cached"]
  local session_active_3f = opts["session-active?"]
  local lazy_streaming_allowed_3f = opts["lazy-streaming-allowed?"]
  local on_prompt_changed = opts["on-prompt-changed"]
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
      local and_4_ = (type(token) == "string") and (token ~= "") and not string.match(token, "^[%?%*%+%|%.]$") and not unclosed_pattern_delims_3f(token) and not not string.find(token, "[\\%[%]%(%)%+%*%?%|%.]")
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
  local function push_file_entry_into_pool_21(session, path, lines)
    local meta = session.meta
    local content = meta.buf.content
    local refs = meta.buf["source-refs"]
    local rel = vim.fn.fnamemodify(path, ":.")
    local line = ""
    local total_lines
    if (type(lines) == "table") then
      total_lines = #lines
    else
      total_lines = 0
    end
    table.insert(content, line)
    local _21_
    if ((type(rel) == "string") and (rel ~= "")) then
      _21_ = rel
    else
      _21_ = path
    end
    return table.insert(refs, {path = path, lnum = total_lines, line = _21_, kind = "file-entry", ["open-lnum"] = 1, ["preview-lnum"] = 1})
  end
  local function all_project_file_paths(session, include_hidden, include_ignored, include_deps)
    local root = vim.fn.getcwd()
    local seen = {}
    local out = {}
    for _, p in ipairs(project_file_list(root, include_hidden, include_ignored, include_deps)) do
      local path = canonical_path(p)
      if (path and (1 == vim.fn.filereadable(path)) and path_under_root_3f(path, root) and not seen[path]) then
        seen[path] = true
        table.insert(out, path)
      else
      end
    end
    return out
  end
  local function set_single_source_content_21(session, show_separators)
    local meta = session.meta
    meta.buf.content = vim.deepcopy(session["single-content"])
    meta.buf["source-refs"] = vim.deepcopy(session["single-refs"])
    meta.buf["show-source-prefix"] = false
    meta.buf["show-source-separators"] = show_separators
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
    local _29_
    if match_idx then
      _29_ = (match_idx - 1)
    else
      _29_ = fallback_idx
    end
    return math.max(0, math.min(_29_, math.max(0, (#meta.buf.indices - 1))))
  end
  local function schedule_lazy_refresh_21(session)
    if (session and session_active_3f(session) and not session.closing) then
      session["lazy-refresh-dirty"] = true
      if not session["lazy-refresh-pending"] then
        session["lazy-refresh-pending"] = true
        local function _31_()
          session["lazy-refresh-pending"] = false
          if (session and session_active_3f(session) and session["lazy-refresh-dirty"]) then
            session["lazy-refresh-dirty"] = false
            if (session.meta and session.meta.buf and vim.api.nvim_buf_is_valid(session.meta.buf.buffer)) then
              local ok,err = pcall(session.meta["on-update"], 0)
              if ok then
                pcall(session.meta.refresh_statusline)
                pcall(update_info_window, session)
              else
                if (err and string.find(tostring(err), "E565")) then
                  local function _32_()
                    if (session and session_active_3f(session) and session.meta and session.meta.buf and vim.api.nvim_buf_is_valid(session.meta.buf.buffer)) then
                      pcall(session.meta["on-update"], 0)
                      pcall(session.meta.refresh_statusline)
                      return pcall(update_info_window, session)
                    else
                      return nil
                    end
                  end
                  vim.defer_fn(_32_, 1)
                else
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
        return vim.defer_fn(_31_, math.max((settings["project-lazy-refresh-min-ms"] or 0), settings["project-lazy-refresh-debounce-ms"]))
      else
        return nil
      end
    else
      return nil
    end
  end
  local function push_file_into_pool_21(session, path, lines, prefilter)
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
              table.insert(refs, {path = path, lnum = lnum, line = line})
              added = (added + 1)
            else
            end
          end
        else
          for lnum, line in ipairs(lines) do
            if (added < take) then
              table.insert(content, line)
              table.insert(refs, {path = path, lnum = lnum, line = line})
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
  local function open_project_buffer_paths(session, root, include_hidden, include_deps)
    local out = {}
    local seen = {}
    local current = canonical_path(current_buffer_path(session["source-buf"]))
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if (vim.api.nvim_buf_is_valid(buf) and (vim.bo[buf].buftype == "") and truthy_3f(vim.bo[buf].buflisted)) then
        local name = canonical_path(vim.api.nvim_buf_get_name(buf))
        if (name and (not current or (name ~= current)) and not seen[name] and (1 == vim.fn.filereadable(name)) and path_under_root_3f(name, root)) then
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
  local function collect_project_sources(session, include_hidden, include_ignored, include_deps, include_binary, include_hex, include_files)
    local root = vim.fn.getcwd()
    local current_path = current_buffer_path(session["source-buf"])
    local file_cache = (session["preview-file-cache"] or {})
    local _
    session["preview-file-cache"] = file_cache
    _ = nil
    local content = {}
    local refs = {}
    local total_lines = 0
    local push_line_21
    local function _51_(path, lnum, line)
      table.insert(content, line)
      table.insert(refs, {path = path, lnum = lnum, line = line})
      total_lines = (total_lines + 1)
      return nil
    end
    push_line_21 = _51_
    for i, line in ipairs((session["single-content"] or {})) do
      push_line_21((current_path or "[Current Buffer]"), i, line)
    end
    if (current_path and (type(session["single-content"]) == "table")) then
      file_cache[current_path] = vim.deepcopy(session["single-content"])
    else
    end
    if include_files then
      for _0, path in ipairs(all_project_file_paths(session, include_hidden, include_ignored, include_deps)) do
        push_file_entry_into_pool_21(session, path, read_file_lines_cached(path, {["include-binary"] = include_binary, ["hex-view"] = include_hex}))
      end
    else
    end
    for _0, path in ipairs(project_file_list(root, include_hidden, include_ignored, include_deps)) do
      local rel = vim.fn.fnamemodify(path, ":.")
      if ((total_lines < settings["project-max-total-lines"]) and allow_project_path_3f(rel, include_hidden, include_deps) and (not current_path or (vim.fn.fnamemodify(path, ":p") ~= vim.fn.fnamemodify(current_path, ":p"))) and (1 == vim.fn.filereadable(path))) then
        local size = vim.fn.getfsize(path)
        if ((size >= 0) and (size <= settings["project-max-file-bytes"])) then
          local lines = read_file_lines_cached(path, {["include-binary"] = include_binary, ["hex-view"] = include_hex})
          if (type(lines) == "table") then
            file_cache[path] = lines
            for lnum, line in ipairs(lines) do
              if (total_lines < settings["project-max-total-lines"]) then
                push_line_21(path, lnum, line)
              else
              end
            end
          else
          end
        else
        end
      else
      end
    end
    return {content = content, refs = refs}
  end
  local function init_project_pool_21(session, prefilter)
    set_single_source_content_21(session, session["project-mode"])
    local root = vim.fn.getcwd()
    local include_hidden = session["effective-include-hidden"]
    local include_ignored = session["effective-include-ignored"]
    local include_deps = session["effective-include-deps"]
    local include_binary = session["effective-include-binary"]
    local include_hex = session["effective-include-hex"]
    local include_files = session["effective-include-files"]
    local current = canonical_path(current_buffer_path(session["source-buf"]))
    local open_paths = open_project_buffer_paths(session, root, include_hidden, include_deps)
    local all_paths = project_file_list(root, include_hidden, include_ignored, include_deps)
    local file_entry_paths
    if include_files then
      file_entry_paths = all_project_file_paths(session, include_hidden, include_ignored, include_deps)
    else
      file_entry_paths = {}
    end
    local deferred = {}
    local deferred_seen = {}
    for _, path in ipairs(file_entry_paths) do
      push_file_entry_into_pool_21(session, path, read_file_lines_cached(path, {["include-binary"] = include_binary, ["hex-view"] = include_hex}))
    end
    for _, path in ipairs(open_paths) do
      local p = canonical_path(path)
      if (p and (1 == vim.fn.filereadable(p))) then
        deferred_seen[p] = true
        push_file_into_pool_21(session, p, read_file_lines_cached(p, {["include-binary"] = include_binary, ["hex-view"] = include_hex}), prefilter)
      else
      end
    end
    for _, path in ipairs(all_paths) do
      local p = canonical_path(path)
      if (p and not deferred_seen[p] and (not current or (p ~= current))) then
        deferred_seen[p] = true
        table.insert(deferred, p)
      else
      end
    end
    return {["deferred-paths"] = deferred, ["estimated-lines"] = estimate_lines_from_files(deferred)}
  end
  local function lazy_preferred_3f(session, estimated_lines)
    return (lazy_streaming_allowed_3f(session) and truthy_3f(session["lazy-mode"]) and ((settings["project-lazy-min-estimated-lines"] <= 0) or (estimated_lines >= settings["project-lazy-min-estimated-lines"])))
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
        local consumed = 0
        local touched = false
        while ((consumed < chunk) and (session["lazy-stream-next"] <= total) and (#session.meta.buf.content < settings["project-max-total-lines"])) do
          local path = paths[session["lazy-stream-next"]]
          local lines = (path and read_file_lines_cached(path, {["include-binary"] = session["effective-include-binary"], ["hex-view"] = session["effective-include-hex"]}))
          local before = #session.meta.buf.content
          if lines then
            push_file_into_pool_21(session, path, lines, prefilter)
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
        if touched then
          schedule_lazy_refresh_21(session)
        else
        end
        if (not session["lazy-stream-done"] and (stream_id == session["lazy-stream-id"]) and session_active_3f(session)) then
          return vim.defer_fn(run_batch, 0)
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
    local old_ref = (session["project-mode"] and selected_ref(meta))
    local old_line
    if (meta.selected_index and (meta.selected_index >= 0) and ((meta.selected_index + 1) <= #meta.buf.indices)) then
      old_line = math.max(1, meta.selected_line())
    else
      old_line = math.max(1, (session["initial-source-line"] or 1))
    end
    if session["project-mode"] then
      local init = init_project_pool_21(session, nil)
      if lazy_preferred_3f(session, (init["estimated-lines"] or 0)) then
        start_project_stream_21(session, nil, init)
      else
        local pool = collect_project_sources(session, session["effective-include-hidden"], session["effective-include-ignored"], session["effective-include-deps"], session["effective-include-binary"], session["effective-include-hex"], session["effective-include-files"])
        meta.buf.content = pool.content
        meta.buf["source-refs"] = pool.refs
        session["lazy-stream-done"] = true
      end
    else
      session["lazy-stream-id"] = (1 + (session["lazy-stream-id"] or 0))
      session["lazy-stream-done"] = true
      set_single_source_content_21(session, false)
    end
    meta.buf["show-source-prefix"] = (session["project-mode"] and session["effective-include-files"])
    meta.buf["show-source-separators"] = session["project-mode"]
    reset_meta_indices_21(meta)
    if session["project-mode"] then
      meta.selected_index = best_project_selection_index(session, old_ref, old_line)
    else
      meta.selected_index = math.max(0, (meta.buf["closest-index"](old_line) - 1))
    end
    meta._prev_text = ""
    meta["_filter-cache"] = {}
    meta["_filter-cache-line-count"] = #meta.buf.content
    return nil
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
      session["project-bootstrap-pending"] = true
      local function _72_()
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
            restore_meta_view_21(session.meta, session["source-view"])
            pcall(session.meta.refresh_statusline)
            return pcall(update_info_window, session)
          else
            return nil
          end
        else
          return nil
        end
      end
      return vim.defer_fn(_72_, math.max(0, (wait_ms or session["project-bootstrap-delay-ms"] or settings["project-bootstrap-delay-ms"])))
    else
      return nil
    end
  end
  return {["schedule-lazy-refresh!"] = schedule_lazy_refresh_21, ["apply-source-set!"] = apply_source_set_21, ["apply-minimal-source-set!"] = apply_minimal_source_set_21, ["schedule-project-bootstrap!"] = schedule_project_bootstrap_21}
end
return M
