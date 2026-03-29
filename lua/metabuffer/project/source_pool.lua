-- [nfnl] fnl/metabuffer/project/source_pool.fnl
local M = {}
local events = require("metabuffer.events")
M.new = function(opts)
  local _let_1_ = (opts or {})
  local settings = _let_1_.settings
  local prompt_has_active_query_3f = _let_1_["prompt-has-active-query?"]
  local function push_file_entry_into_pool_21(session, path)
    local meta = session.meta
    local content = meta.buf.content
    local refs = meta.buf["source-refs"]
    local rel = vim.fn.fnamemodify(path, ":.")
    local line = ""
    table.insert(content, line)
    local _2_
    if ((type(rel) == "string") and (rel ~= "")) then
      _2_ = rel
    else
      _2_ = path
    end
    return table.insert(refs, {path = path, lnum = 1, line = _2_, kind = "file-entry", ["open-lnum"] = 1, ["preview-lnum"] = 1})
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
            if ((added < take) and opts["line-matches-prefilter?"](line, prefilter)) then
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
  local function set_project_pool_21(session, pool)
    local meta = session.meta
    meta.buf.content = pool.content
    meta.buf["source-refs"] = pool.refs
    return opts["bump-content-version!"](meta)
  end
  local function enable_full_source_syntax_21(session)
    if (session.meta and session.meta.buf and not session["prompt-animating?"] and not session["startup-initializing"]) then
      session.meta.buf["visible-source-syntax-only"] = false
      return events.send("on-source-syntax-refresh!", {session = session, ["immediate?"] = true})
    else
      return nil
    end
  end
  local function emit_source_pool_change_21(session, extra)
    return events.send("on-source-pool-change!", vim.tbl_extend("force", {session = session}, (extra or {})))
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
  return {["push-file-entry-into-pool!"] = push_file_entry_into_pool_21, ["push-file-into-pool!"] = push_file_into_pool_21, ["set-project-pool!"] = set_project_pool_21, ["enable-full-source-syntax!"] = enable_full_source_syntax_21, ["emit-source-pool-change!"] = emit_source_pool_change_21, ["finish-project-stream!"] = finish_project_stream_21, ["maybe-finish-project-stream!"] = maybe_finish_project_stream_21}
end
return M
