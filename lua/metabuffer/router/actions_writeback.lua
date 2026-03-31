-- [nfnl] fnl/metabuffer/router/actions_writeback.fnl
local source_mod = require("metabuffer.source")
local transform_mod = require("metabuffer.transform")
local events = require("metabuffer.events")
local M = {}
M.new = function(opts)
  local _ = (opts or {})
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
    for _0, h in ipairs(hunks) do
      local _let_10_ = hunk_indices(h)
      local a_start = _let_10_[1]
      local a_count = _let_10_[2]
      local b_start = _let_10_[3]
      local b_count = _let_10_[4]
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
      for _0, r in ipairs((current_rows or {})) do
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
      for _0, row in ipairs(rows) do
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
      local _26_
      if (insert_op.side == "before") then
        _26_ = "insert-before"
      else
        _26_ = "insert-after"
      end
      return append_op_21(ops, insert_op.path, {kind = _26_, lnum = insert_op.lnum, lines = insert_op.lines, ["ref-kind"] = (insert_op["ref-kind"] or "")})
    else
      state["unsafe-structural?"] = true
      return nil
    end
  end
  local function handle_modified_hunk_21(session, ops, current_rows, current_lines, state, h, baseline_rows)
    local _let_29_ = hunk_indices(h)
    local a_start = _let_29_[1]
    local a_count = _let_29_[2]
    local b_start = _let_29_[3]
    local b_count = _let_29_[4]
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
    local _let_31_ = hunk_indices(h)
    local _0 = _let_31_[1]
    local _1 = _let_31_[2]
    local b_start = _let_31_[3]
    local b_count = _let_31_[4]
    if (b_count > 0) then
      return append_insert_ops_21(ops, (structural_op_from_current_rows(current_rows, b_start, b_count) or pending_structural_op(session, b_start, b_count, current_lines, "")), state)
    else
      return nil
    end
  end
  local function apply_hunk_file_ops_21(session, ops, current_rows, current_lines, state, h, baseline_rows)
    local _let_33_ = hunk_indices(h)
    local _0 = _let_33_[1]
    local a_count = _let_33_[2]
    local _1 = _let_33_[3]
    local _2 = _let_33_[4]
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
    for _0, h in ipairs(hunks) do
      apply_hunk_file_ops_21(session, ops, current_rows, current_lines, state, h, baseline_rows)
    end
    return {ops = ops, ["current-lines"] = current_lines, ["current-rows"] = current_rows, ["unsafe-structural?"] = state["unsafe-structural?"]}
  end
  local function grouped_path_ops__3eflat_ops(ops)
    local out = {}
    for path, per_file in pairs((ops or {})) do
      for _0, op in ipairs((per_file or {})) do
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
    for _0, op in ipairs((ops[path] or {})) do
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
    for _0, row in ipairs((current_rows or {})) do
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
    for path, _0 in pairs((updates or {})) do
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
  local function write_results_21(deps, session, sign_mod)
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
      local _46_
      if (result.changed > 0) then
        _46_ = ("metabuffer: wrote " .. tostring(result.changed) .. " change(s)")
      else
        _46_ = "metabuffer: no changes"
      end
      return vim.notify(_46_, vim.log.levels.INFO)
    end
  end
  return {["apply-live-edits-to-meta!"] = apply_live_edits_to_meta_21, ["write-results!"] = write_results_21}
end
return M
