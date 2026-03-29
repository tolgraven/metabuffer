-- [nfnl] fnl/metabuffer/router/actions_edit.fnl
local M = {}
local source_mod = require("metabuffer.source")
local transform_mod = require("metabuffer.transform")
local events = require("metabuffer.events")
local debug_mod = require("metabuffer.debug")
M.new = function(opts)
  local _let_1_ = (opts or {})
  local session_by_prompt = _let_1_["session-by-prompt"]
  local clear_map_entry_21 = _let_1_["clear-map-entry!"]
  local restore_main_window_opts_21 = _let_1_["restore-main-window-opts!"]
  local hide_session_ui_21 = _let_1_["hide-session-ui!"]
  local restore_session_ui_21 = _let_1_["restore-session-ui!"]
  local function ensure_session_for_results_buf_21(deps, session)
    local router = deps.router
    local active_by_source = router["active-by-source"]
    local buf = session.meta.buf.buffer
    active_by_source[buf] = session
    return nil
  end
  local function diff_hunks(old_lines, new_lines)
    local old_text = table.concat((old_lines or {}), "\n")
    local new_text = table.concat((new_lines or {}), "\n")
    local ok,out = pcall(vim.diff, old_text, new_text, {result_type = "indices", algorithm = "histogram"})
    if (ok and (type(out) == "table")) then
      return out
    else
      return {}
    end
  end
  local function hunk_indices(h)
    return {(h[1] or 1), (h[2] or 0), (h[3] or 1), (h[4] or 0)}
  end
  local function slice_lines(lines, start, count)
    local out = {}
    for i = start, (start + count + -1) do
      if ((i >= 1) and (i <= #lines)) then
        table.insert(out, lines[i])
      else
      end
    end
    return out
  end
  local function clone_row_with_text(row, text)
    local r = vim.deepcopy((row or {}))
    r["text"] = (text or "")
    r["line"] = (text or "")
    return r
  end
  local function consecutive_same_source_3f(prev_row, next_row)
    return (prev_row and next_row and (type(prev_row.path) == "string") and (type(next_row.path) == "string") and (prev_row.path ~= "") and (next_row.path ~= "") and (type(prev_row.lnum) == "number") and (type(next_row.lnum) == "number") and (prev_row.path == next_row.path) and ((prev_row.lnum + 1) == next_row.lnum))
  end
  local function inserted_row(session, prev_row, next_row, text, rel_index)
    local base = (prev_row or next_row or {})
    local out = vim.deepcopy(base)
    local prev_lnum = ((prev_row and prev_row.lnum) or base.lnum or 1)
    local next_lnum = ((next_row and next_row.lnum) or base.lnum or (prev_lnum + 1))
    local pending = (session["pending-structural-edit"] or {})
    local pending_side = pending.side
    local pending_path = pending.path
    local pending_lnum = pending.lnum
    local lnum
    if consecutive_same_source_3f(prev_row, next_row) then
      lnum = (prev_lnum + rel_index)
    else
      if ((pending_side == "after") and prev_row and (pending_path == prev_row.path) and (pending_lnum == prev_row.lnum)) then
        lnum = (pending_lnum + rel_index)
      else
        if ((pending_side == "before") and next_row and (pending_path == next_row.path) and (pending_lnum == next_row.lnum)) then
          lnum = (pending_lnum + rel_index + -1)
        else
          if prev_row then
            lnum = (prev_lnum + rel_index)
          else
            lnum = math.max(1, (next_lnum - 1))
          end
        end
      end
    end
    out["lnum"] = math.max(1, (lnum or 1))
    out["text"] = (text or "")
    out["line"] = (text or "")
    if consecutive_same_source_3f(prev_row, next_row) then
      out["insert-path"] = prev_row.path
      out["insert-lnum"] = prev_row.lnum
      out["insert-side"] = "after"
    else
      if ((pending_side == "after") and prev_row and (type(prev_row.path) == "string") and (prev_row.path ~= "") and (type(prev_row.lnum) == "number") and (pending_path == prev_row.path) and (pending_lnum == prev_row.lnum)) then
        out["insert-path"] = prev_row.path
        out["insert-lnum"] = prev_row.lnum
        out["insert-side"] = "after"
      else
      end
      if ((pending_side == "before") and next_row and (type(next_row.path) == "string") and (next_row.path ~= "") and (type(next_row.lnum) == "number") and (pending_path == next_row.path) and (pending_lnum == next_row.lnum)) then
        out["insert-path"] = next_row.path
        out["insert-lnum"] = next_row.lnum
        out["insert-side"] = "before"
      else
      end
    end
    return out
  end
  local function projected_rows_from_edits(session, baseline_rows, baseline_lines, current_lines)
    local hunks = diff_hunks(baseline_lines, current_lines)
    local out = {}
    local idx = {old = 1, new = 1}
    for _, h in ipairs(hunks) do
      local _let_11_ = hunk_indices(h)
      local a_start = _let_11_[1]
      local a_count = _let_11_[2]
      local b_start = _let_11_[3]
      local b_count = _let_11_[4]
      local common = math.min(a_count, b_count)
      while (idx.old < a_start) do
        local txt = (current_lines[idx.new] or "")
        table.insert(out, clone_row_with_text(baseline_rows[idx.old], txt))
        idx["old"] = (idx.old + 1)
        idx["new"] = (idx.new + 1)
      end
      for k = 1, common do
        local txt = (current_lines[(b_start + k + -1)] or "")
        table.insert(out, clone_row_with_text(baseline_rows[(a_start + k + -1)], txt))
      end
      if (b_count > a_count) then
        local extra = (b_count - common)
        local prev_row
        if ((a_start + common + -1) > 0) then
          prev_row = baseline_rows[(a_start + common + -1)]
        else
          prev_row = nil
        end
        local next_row = baseline_rows[(a_start + common)]
        for k = 1, extra do
          local txt = (current_lines[(b_start + common + k + -1)] or "")
          table.insert(out, inserted_row(session, prev_row, next_row, txt, k))
        end
      else
      end
      idx["old"] = (a_start + a_count)
      idx["new"] = (b_start + b_count)
    end
    while (idx.old <= #baseline_rows) do
      local txt = (current_lines[idx.new] or "")
      table.insert(out, clone_row_with_text(baseline_rows[idx.old], txt))
      idx["old"] = (idx.old + 1)
      idx["new"] = (idx.new + 1)
    end
    return out
  end
  local function apply_live_edits_to_meta_21(session, current_lines)
    local meta = session.meta
    local baseline_lines = (session["edit-baseline-lines"] or {})
    local baseline_rows = (session["edit-baseline-rows"] or {})
    local rows = projected_rows_from_edits(session, baseline_rows, baseline_lines, current_lines)
    local refs = {}
    local content = {}
    local idxs = {}
    session["live-edit-rows"] = rows
    for i = 1, #rows do
      local row = (rows[i] or {})
      refs[i] = {kind = (row.kind or ""), path = (row.path or ""), lnum = (row.lnum or 1), ["open-lnum"] = (row["open-lnum"] or row.lnum or 1), line = (row.text or row.line or "")}
      content[i] = (row.text or row.line or "")
      idxs[i] = i
    end
    meta.buf["source-refs"] = refs
    meta.buf.content = content
    meta.buf.indices = idxs
    local max = math.max(1, #idxs)
    meta.selected_index = math.max(0, math.min((meta.selected_index or 0), (max - 1)))
    return nil
  end
  local function valid_row_3f(row)
    return (row and (type(row.path) == "string") and (row.path ~= "") and (type(row.lnum) == "number") and (row.lnum > 0))
  end
  local function special_projected_row_3f(row)
    return (row and row["source-group-id"] and ((#(row["transform-chain"] or {}) > 0) or ((row["source-group-kind"] or "") == "file")))
  end
  local function append_op_21(ops, path, op)
    local per_file = (ops[path] or {})
    table.insert(per_file, op)
    ops[path] = per_file
    return nil
  end
  local function append_group_op_21(ops, row, current_rows, processed)
    local group_id = row["source-group-id"]
    local path = row.path
    local key = (path .. "|" .. tostring(group_id))
    local group_lines = {}
    if (processed or {})[key] then
      return nil
    else
      processed[key] = true
      for _, r in ipairs((current_rows or {})) do
        if ((r.path == path) and (r["source-group-id"] == group_id)) then
          table.insert(group_lines, (r.text or r.line or ""))
        else
        end
      end
      local reversed = transform_mod["reverse-group"](row, group_lines, {path = path, lnum = row.lnum})
      if reversed.error then
        return {error = reversed.error}
      else
        if (reversed.kind == "rewrite-bytes") then
          append_op_21(ops, path, {kind = "rewrite-bytes", bytes = reversed.bytes, ["ref-kind"] = (row.kind or "")})
        else
          append_op_21(ops, path, {kind = "replace", lnum = row.lnum, text = reversed.text, ["old-text"] = (row["source-text"] or ""), ["ref-kind"] = (row.kind or "")})
        end
        return nil
      end
    end
  end
  local function structural_op_from_current_rows(current_rows, start, count)
    local rows = slice_lines(current_rows, start, count)
    local first_row = rows[1]
    if (first_row and first_row["insert-path"] and first_row["insert-lnum"] and first_row["insert-side"]) then
      local path = first_row["insert-path"]
      local lnum = first_row["insert-lnum"]
      local side = first_row["insert-side"]
      local ref_kind = (first_row.kind or "")
      local lines = {}
      local state = {["consistent?"] = true}
      for _, row in ipairs(rows) do
        if ((row["insert-path"] ~= path) or (row["insert-lnum"] ~= lnum) or (row["insert-side"] ~= side)) then
          state["consistent?"] = false
        else
        end
        table.insert(lines, (row.text or row.line or ""))
      end
      if state["consistent?"] then
        return {path = path, lnum = lnum, side = side, lines = lines, ["ref-kind"] = ref_kind}
      else
        return nil
      end
    else
      return nil
    end
  end
  local function pending_structural_op(session, start, count, current_lines, fallback_kind)
    local pending = (session["pending-structural-edit"] or {})
    local path = pending.path
    local lnum = pending.lnum
    local side = pending.side
    local ref_kind = (pending.kind or fallback_kind or "")
    if ((type(path) == "string") and (path ~= "") and (type(lnum) == "number") and (lnum > 0) and ((side == "before") or (side == "after")) and (count > 0) and (ref_kind ~= "file-entry")) then
      return {path = path, lnum = lnum, side = side, lines = slice_lines(current_lines, start, count), ["ref-kind"] = ref_kind}
    else
      return nil
    end
  end
  local function append_replace_ops_21(ops, old_rows, new_lines, common, current_rows, state)
    for i = 1, common do
      local row = old_rows[i]
      local text = (new_lines[i] or "")
      if (valid_row_3f(row) and ((row.text or "") ~= text)) then
        if special_projected_row_3f(row) then
          local err = append_group_op_21(ops, row, current_rows, state["processed-special-groups"])
          if err then
            state["unsafe-structural?"] = true
          else
          end
        else
          append_op_21(ops, row.path, {kind = "replace", lnum = row.lnum, text = text, ["old-text"] = (row.text or ""), ["ref-kind"] = (row.kind or "")})
        end
      else
      end
    end
    return nil
  end
  local function append_delete_ops_21(ops, old_rows, common, a_count, state)
    if (a_count > common) then
      for i = (common + 1), a_count do
        local row = old_rows[i]
        if (valid_row_3f(row) and not special_projected_row_3f(row)) then
          append_op_21(ops, row.path, {kind = "delete", lnum = row.lnum, ["ref-kind"] = (row.kind or "")})
        else
          state["unsafe-structural?"] = true
        end
      end
      return nil
    else
      return nil
    end
  end
  local function insertion_op(session, current_rows, current_lines, b_start, common, b_count, old_rows)
    return (structural_op_from_current_rows(current_rows, (b_start + common), (b_count - common)) or pending_structural_op(session, (b_start + common), (b_count - common), current_lines, ((old_rows[common] and old_rows[common].kind) or (old_rows[(common + 1)] and old_rows[(common + 1)].kind) or "")))
  end
  local function append_insert_ops_21(ops, insert_op, state)
    if insert_op then
      local _27_
      if (insert_op.side == "before") then
        _27_ = "insert-before"
      else
        _27_ = "insert-after"
      end
      return append_op_21(ops, insert_op.path, {kind = _27_, lnum = insert_op.lnum, lines = insert_op.lines, ["ref-kind"] = (insert_op["ref-kind"] or "")})
    else
      state["unsafe-structural?"] = true
      return nil
    end
  end
  local function handle_modified_hunk_21(session, ops, current_rows, current_lines, state, h, baseline_rows)
    local _let_30_ = hunk_indices(h)
    local a_start = _let_30_[1]
    local a_count = _let_30_[2]
    local b_start = _let_30_[3]
    local b_count = _let_30_[4]
    local common = math.min(a_count, b_count)
    local old_rows = slice_lines(baseline_rows, a_start, a_count)
    local new_lines = slice_lines(current_lines, b_start, b_count)
    append_replace_ops_21(ops, old_rows, new_lines, common, current_rows, state)
    append_delete_ops_21(ops, old_rows, common, a_count, state)
    if (b_count > a_count) then
      return append_insert_ops_21(ops, insertion_op(session, current_rows, current_lines, b_start, common, b_count, old_rows), state)
    else
      return nil
    end
  end
  local function handle_insert_only_hunk_21(session, ops, current_rows, current_lines, state, h)
    local _let_32_ = hunk_indices(h)
    local _ = _let_32_[1]
    local _0 = _let_32_[2]
    local b_start = _let_32_[3]
    local b_count = _let_32_[4]
    if (b_count > 0) then
      return append_insert_ops_21(ops, (structural_op_from_current_rows(current_rows, b_start, b_count) or pending_structural_op(session, b_start, b_count, current_lines, "")), state)
    else
      return nil
    end
  end
  local function apply_hunk_file_ops_21(session, ops, current_rows, current_lines, state, h, baseline_rows)
    local _let_34_ = hunk_indices(h)
    local _ = _let_34_[1]
    local a_count = _let_34_[2]
    local _0 = _let_34_[3]
    local _1 = _let_34_[4]
    if (a_count > 0) then
      return handle_modified_hunk_21(session, ops, current_rows, current_lines, state, h, baseline_rows)
    else
      return handle_insert_only_hunk_21(session, ops, current_rows, current_lines, state, h)
    end
  end
  local function collect_file_ops(session)
    local meta = session.meta
    local buf = meta.buf.buffer
    local baseline_lines = (session["edit-baseline-lines"] or vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    local baseline_rows = (session["edit-baseline-rows"] or {})
    local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local current_rows = projected_rows_from_edits(session, baseline_rows, baseline_lines, current_lines)
    local hunks = diff_hunks(baseline_lines, current_lines)
    local ops = {}
    local state = {["processed-special-groups"] = {}, ["unsafe-structural?"] = false}
    session["live-edit-rows"] = current_rows
    for _, h in ipairs(hunks) do
      apply_hunk_file_ops_21(session, ops, current_rows, current_lines, state, h, baseline_rows)
    end
    return {ops = ops, ["current-lines"] = current_lines, ["current-rows"] = current_rows, ["unsafe-structural?"] = state["unsafe-structural?"]}
  end
  local function grouped_path_ops__3eflat_ops(ops)
    local out = {}
    for path, per_file in pairs((ops or {})) do
      for _, op in ipairs((per_file or {})) do
        local item = vim.deepcopy((op or {}))
        item["path"] = path
        table.insert(out, item)
      end
    end
    return out
  end
  local function apply_file_ops_21(ops)
    return source_mod["apply-write-ops!"](grouped_path_ops__3eflat_ops(ops))
  end
  local function update_row_after_ops(row, ops, post_lines, renames)
    local ref = vim.deepcopy((row or {}))
    local path0 = (ref.path or "")
    local path = ((renames or {})[path0] or path0)
    local lnum0
    if ((type(ref.lnum) == "number") and (ref.lnum > 0)) then
      lnum0 = ref.lnum
    else
      lnum0 = 1
    end
    local generated_path = ref["insert-path"]
    local generated_lnum = ref["insert-lnum"]
    local generated_side = ref["insert-side"]
    ref["path"] = path
    local lnum = lnum0
    for _, op in ipairs((ops[path] or {})) do
      local same_generated_3f = ((generated_path == path) and (generated_lnum == op.lnum) and (((generated_side == "before") and (op.kind == "insert-before")) or ((generated_side == "after") and (op.kind == "insert-after"))))
      if not same_generated_3f then
        if (op.kind == "insert-before") then
          if (lnum >= op.lnum) then
            lnum = (lnum + #(op.lines or {}))
          else
          end
        elseif (op.kind == "insert-after") then
          if (lnum > op.lnum) then
            lnum = (lnum + #(op.lines or {}))
          else
          end
        elseif (op.kind == "delete") then
          if (lnum > op.lnum) then
            lnum = (lnum - 1)
          else
          end
        else
        end
      else
      end
    end
    if (lnum < 1) then
      lnum = 1
    else
    end
    ref["lnum"] = lnum
    do
      local lines = post_lines[path]
      local line = ((lines and (lnum >= 1) and (lnum <= #lines) and lines[lnum]) or ref.text or ref.line or "")
      ref["line"] = line
      ref["text"] = line
    end
    return ref
  end
  local function update_session_refs_after_ops_21(session, current_rows, ops, post_lines, renames)
    local meta = session.meta
    local refs = {}
    local content = {}
    local idxs = {}
    for _, row in ipairs((current_rows or {})) do
      local ref = update_row_after_ops(row, ops, post_lines, renames)
      local idx = (#refs + 1)
      if ((ref.kind or "") == "file-entry") then
        local rel = vim.fn.fnamemodify((ref.path or ""), ":.")
        if ((type(rel) == "string") and (rel ~= "")) then
          ref["line"] = rel
        else
          ref["line"] = (ref.path or "")
        end
        ref["text"] = ref.line
      else
      end
      table.insert(refs, {kind = (ref.kind or ""), path = (ref.path or ""), lnum = (ref.lnum or 1), ["open-lnum"] = (ref["open-lnum"] or ref.lnum or 1), ["source-lnum"] = ref["source-lnum"], ["source-text"] = ref["source-text"], ["source-group-id"] = ref["source-group-id"], ["source-group-kind"] = ref["source-group-kind"], ["transform-chain"] = vim.deepcopy((ref["transform-chain"] or {})), line = (ref.line or "")})
      table.insert(content, (ref.line or ""))
      table.insert(idxs, idx)
    end
    meta.buf["source-refs"] = refs
    meta.buf.content = content
    meta.buf.indices = idxs
    return nil
  end
  local function invalidate_caches_for_paths_21(deps, session, updates)
    local router = deps.router
    local project_file_cache = (router and router["project-file-cache"])
    local preview_file_cache = (session["preview-file-cache"] or {})
    local info_file_head_cache = (session["info-file-head-cache"] or {})
    local info_file_meta_cache = (session["info-file-meta-cache"] or {})
    session["preview-file-cache"] = preview_file_cache
    session["info-file-head-cache"] = info_file_head_cache
    session["info-file-meta-cache"] = info_file_meta_cache
    for path, _ in pairs((updates or {})) do
      if project_file_cache then
        project_file_cache[path] = nil
      else
      end
      preview_file_cache[path] = nil
      info_file_head_cache[path] = nil
      info_file_meta_cache[path] = nil
    end
    return nil
  end
  local function write_results_21(deps, prompt_buf)
    local router = deps.router
    local mods = deps.mods
    local session = session_by_prompt(router["active-by-prompt"], prompt_buf)
    local sign_mod = mods.sign
    if session then
      local collected = collect_file_ops(session)
      local ops = collected.ops
      local buf = session.meta.buf.buffer
      if collected["unsafe-structural?"] then
        vim.notify("metabuffer: only in-place line replacements are writable from results; open the real file for insert/delete edits", vim.log.levels.ERROR)
        return events.send("on-query-update!", {session = session, query = (session["prompt-last-applied-text"] or ""), ["refresh-signs?"] = true, ["refresh-lines"] = false})
      else
        local result = apply_file_ops_21(ops)
        session["pending-structural-edit"] = nil
        update_session_refs_after_ops_21(session, collected["current-rows"], ops, result["post-lines"], result.renames)
        invalidate_caches_for_paths_21(deps, session, result.paths)
        if (result.changed > 0) then
          pcall(session.meta["on-update"], 0)
        else
        end
        pcall(vim.api.nvim_set_option_value, "modified", false, {buf = buf})
        pcall(vim.api.nvim_buf_set_var, buf, "meta_manual_edit_active", false)
        events.send("on-query-update!", {session = session, query = (session["prompt-last-applied-text"] or ""), ["refresh-lines"] = true, ["capture-sign-baseline?"] = not not sign_mod, ["refresh-signs?"] = not not sign_mod})
        local _47_
        if (result.changed > 0) then
          _47_ = ("metabuffer: wrote " .. tostring(result.changed) .. " change(s)")
        else
          _47_ = "metabuffer: no changes"
        end
        return vim.notify(_47_, vim.log.levels.INFO)
      end
    else
      return nil
    end
  end
  local function enter_edit_mode_21(deps, prompt_buf)
    local router = deps.router
    local mods = deps.mods
    local history = deps.history
    local refresh = deps.refresh
    local session = session_by_prompt(router["active-by-prompt"], prompt_buf)
    local router_util_mod = mods["router-util"]
    local sign_mod = mods.sign
    local history_api = history.api
    local apply_prompt_lines = refresh["apply-prompt-lines!"]
    if session then
      session["last-prompt-text"] = router_util_mod["prompt-text"](session)
      history_api["push-history-entry!"](session, session["last-prompt-text"])
      apply_prompt_lines(session)
      session["results-edit-mode"] = true
      hide_session_ui_21(deps, session)
      ensure_session_for_results_buf_21(deps, session)
      if (session.meta and session.meta.buf and session.meta.buf["prepare-visible-edit!"]) then
        pcall(session.meta.buf["prepare-visible-edit!"], session.meta.buf)
      else
      end
      if (session.meta and session.meta.win and vim.api.nvim_win_is_valid(session.meta.win.window)) then
        pcall(vim.api.nvim_set_current_win, session.meta.win.window)
        pcall(vim.api.nvim_win_set_buf, session.meta.win.window, session.meta.buf.buffer)
      else
      end
      if sign_mod then
        pcall(sign_mod["capture-baseline!"], session)
      else
      end
      return pcall(vim.cmd, "stopinsert")
    else
      return nil
    end
  end
  local function hide_visible_ui_21(deps, prompt_buf)
    local router = deps.router
    local session = session_by_prompt(router["active-by-prompt"], prompt_buf)
    if (session and not session["ui-hidden"] and not session.closing) then
      session["results-edit-mode"] = false
      hide_session_ui_21(deps, session)
      return pcall(vim.cmd, "stopinsert")
    else
      return nil
    end
  end
  local function sync_live_edits_21(deps, prompt_buf)
    local router = deps.router
    local session = session_by_prompt(router["active-by-prompt"], prompt_buf)
    if (session and session.meta and session.meta.buf) then
      local buf = session.meta.buf.buffer
      local manual_3f
      do
        local ok,v = pcall(vim.api.nvim_buf_get_var, buf, "meta_manual_edit_active")
        manual_3f = (ok and v)
      end
      if (manual_3f and vim.api.nvim_buf_is_valid(buf)) then
        local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        return apply_live_edits_to_meta_21(session, current_lines)
      else
        return nil
      end
    else
      return nil
    end
  end
  local function maybe_restore_ui_21(deps, prompt_buf, force)
    local router = deps.router
    local session = session_by_prompt(router["active-by-prompt"], prompt_buf)
    if (session and session["ui-hidden"] and not session["restoring-ui?"] and session.meta and session.meta.buf) then
      local current_buf = vim.api.nvim_get_current_buf()
      local results_buf = session.meta.buf.buffer
      if (force or (current_buf == results_buf)) then
        debug_mod.log("router-actions", ("maybe-restore-ui" .. " force=" .. tostring(not not force) .. " current=" .. tostring(current_buf) .. " results=" .. tostring(results_buf) .. " hidden=" .. tostring(not not session["ui-hidden"]) .. " restoring=" .. tostring(not not session["restoring-ui?"]) .. " bootstrapped=" .. tostring(not not session["project-bootstrapped"]) .. " stream-done=" .. tostring(not not session["lazy-stream-done"])))
        session.meta.win.window = vim.api.nvim_get_current_win()
        return restore_session_ui_21(deps, session, {["preserve-focus"] = not force})
      else
        return nil
      end
    else
      return nil
    end
  end
  local function on_results_buffer_wipe_21(deps, results_buf)
    local router = deps.router
    local history = deps.history
    local mods = deps.mods
    local windows = deps.windows
    local active_by_source = router["active-by-source"]
    local history_api = history.api
    local router_util_mod = mods["router-util"]
    local info_window = windows.info
    local preview_window = windows.preview
    local instances = router.instances
    local active_by_prompt = router["active-by-prompt"]
    local session = active_by_source[results_buf]
    if (session and not session._results_wiped) then
      session._results_wiped = true
      session.closing = true
      restore_main_window_opts_21(session)
      local or_60_ = session["last-prompt-text"]
      if not or_60_ then
        if (session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"])) then
          or_60_ = router_util_mod["prompt-text"](session)
        else
          or_60_ = ""
        end
      end
      history_api["push-history-entry!"](session, or_60_)
      router_util_mod["persist-prompt-height!"](session)
      if (session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"])) then
        pcall(vim.api.nvim_win_close, session["prompt-win"], true)
      else
      end
      if (session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"])) then
        pcall(vim.api.nvim_buf_delete, session["prompt-buf"], {force = true})
      else
      end
      info_window["close-window!"](session)
      preview_window["close-window!"](session)
      history_api["close-history-browser!"](session)
      clear_map_entry_21(active_by_source, session["source-buf"], session)
      clear_map_entry_21(active_by_source, results_buf, session)
      clear_map_entry_21(active_by_prompt, session["prompt-buf"], session)
      if session["instance-id"] then
        return clear_map_entry_21(instances, session["instance-id"], session)
      else
        return nil
      end
    else
      return nil
    end
  end
  return {["write-results!"] = write_results_21, ["enter-edit-mode!"] = enter_edit_mode_21, ["hide-visible-ui!"] = hide_visible_ui_21, ["sync-live-edits!"] = sync_live_edits_21, ["maybe-restore-ui!"] = maybe_restore_ui_21, ["on-results-buffer-wipe!"] = on_results_buffer_wipe_21}
end
return M
