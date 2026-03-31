-- [nfnl] fnl/metabuffer/project/source.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local M = {}
local debug = require("metabuffer.debug")
local source_mod = require("metabuffer.source")
local source_helper_mod = require("metabuffer.project.source_helpers")
local source_stream_mod = require("metabuffer.project.source_stream")
M.new = function(opts)
  local settings = opts.settings
  local truthy_3f = opts["truthy?"]
  local selected_ref = opts["selected-ref"]
  local canonical_path = opts["canonical-path"]
  local current_buffer_path = opts["current-buffer-path"]
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
  local helpers = source_helper_mod.new(opts)
  local reset_meta_indices_21 = helpers["reset-meta-indices!"]
  local push_file_entry_into_pool_21 = helpers["push-file-entry-into-pool!"]
  local include_file_path_3f = helpers["include-file-path?"]
  local all_project_file_paths = helpers["all-project-file-paths"]
  local results_wrap_width = helpers["results-wrap-width"]
  local single_source_view = helpers["single-source-view"]
  local set_single_source_content_21 = helpers["set-single-source-content!"]
  local normal_query_active_3f = helpers["normal-query-active?"]
  local current_file_filter = helpers["current-file-filter"]
  local file_only_mode_3f = helpers["file-only-mode?"]
  local set_query_source_content_21 = helpers["set-query-source-content!"]
  local set_file_entry_source_content_21 = helpers["set-file-entry-source-content!"]
  local best_project_selection_index = helpers["best-project-selection-index"]
  local push_file_into_pool_21 = helpers["push-file-into-pool!"]
  local current_project_prefilter = helpers["current-project-prefilter"]
  local open_project_buffer_paths = helpers["open-project-buffer-paths"]
  local estimate_lines_from_files = helpers["estimate-lines-from-files"]
  local project_view_opts = helpers["project-view-opts"]
  local cached_project_view = helpers["cached-project-view"]
  local set_project_pool_21 = helpers["set-project-pool!"]
  local enable_full_source_syntax_21 = helpers["enable-full-source-syntax!"]
  local emit_source_pool_change_21 = helpers["emit-source-pool-change!"]
  local maybe_finish_project_stream_21 = helpers["maybe-finish-project-stream!"]
  local lazy_preferred_3f = nil
  local start_project_stream_21 = nil
  local schedule_source_set_rebuild_21 = nil
  local apply_minimal_source_set_21 = nil
  local schedule_project_bootstrap_21 = nil
  local function stream_next_path_21(session, path, prefilter)
    local before = #session.meta.buf.content
    local view = cached_project_view(session, path, results_wrap_width(session))
    if view then
      push_file_into_pool_21(session, path, view, prefilter)
      return (#session.meta.buf.content > before)
    else
      return nil
    end
  end
  local function collect_project_sources(_2_)
    local session = _2_.session
    local include_hidden = _2_["include-hidden"]
    local include_ignored = _2_["include-ignored"]
    local include_deps = _2_["include-deps"]
    local include_binary = _2_["include-binary"]
    local include_files = _2_["include-files"]
    local prefilter = _2_.prefilter
    local root = vim.fn.getcwd()
    local current_path = current_buffer_path(session["source-buf"])
    local wrap_width = results_wrap_width(session)
    local file_filter = current_file_filter(session)
    local file_cache = (session["preview-file-cache"] or {})
    local _
    session["preview-file-cache"] = file_cache
    _ = nil
    local content = {}
    local refs = {}
    if file_only_mode_3f(session) then
      for _0, path in ipairs(all_project_file_paths({["include-hidden"] = include_hidden, ["include-ignored"] = include_ignored, ["include-deps"] = include_deps, ["include-binary"] = include_binary, ["file-filter"] = file_filter})) do
        table.insert(content, "")
        local _3_
        do
          local rel = vim.fn.fnamemodify(path, ":.")
          if ((type(rel) == "string") and (rel ~= "")) then
            _3_ = rel
          else
            _3_ = path
          end
        end
        table.insert(refs, {path = path, lnum = 1, line = _3_, kind = "file-entry", ["open-lnum"] = 1, ["preview-lnum"] = 1})
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
        if not normal_query_active_3f(session) then
          for _0, path in ipairs(all_project_file_paths({["include-hidden"] = include_hidden, ["include-ignored"] = include_ignored, ["include-deps"] = include_deps, ["include-binary"] = include_binary, ["file-filter"] = file_filter})) do
            push_file_entry_into_pool_21(session, path)
          end
        else
        end
      else
      end
      for _0, path in ipairs(project_file_list(root, include_hidden, include_ignored, include_deps)) do
        local rel = vim.fn.fnamemodify(path, ":.")
        if ((#content < settings["project-max-total-lines"]) and allow_project_path_3f(rel, include_hidden, include_deps) and include_file_path_3f(path, file_filter) and (include_binary or not binary_file_3f(path)) and (not current_path or (vim.fn.fnamemodify(path, ":p") ~= vim.fn.fnamemodify(current_path, ":p"))) and (1 == vim.fn.filereadable(path))) then
          local size = vim.fn.getfsize(path)
          if ((size >= 0) and (size <= settings["project-max-file-bytes"])) then
            local view = read_file_view_cached(path, project_view_opts(session, wrap_width))
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
    local file_filter = current_file_filter(session)
    local current = canonical_path(current_buffer_path(session["source-buf"]))
    local open_paths = open_project_buffer_paths(session, root, include_hidden, include_deps)
    local all_paths = project_file_list(root, include_hidden, include_ignored, include_deps)
    local file_entry_paths
    if (include_files and not normal_query_active_3f(session)) then
      file_entry_paths = all_project_file_paths({["include-hidden"] = include_hidden, ["include-ignored"] = include_ignored, ["include-deps"] = include_deps, ["include-binary"] = include_binary, ["file-filter"] = file_filter})
    else
      file_entry_paths = {}
    end
    local deferred = {}
    local deferred_seen = {}
    if file_only_mode_3f(session) then
      set_file_entry_source_content_21({session = session, ["include-hidden"] = include_hidden, ["include-ignored"] = include_ignored, ["include-deps"] = include_deps, ["include-binary"] = include_binary, ["file-filter"] = file_filter})
      return {["deferred-paths"] = {}, ["estimated-lines"] = 0}
    else
      set_single_source_content_21(session, session["project-mode"])
      for _, path in ipairs(file_entry_paths) do
        push_file_entry_into_pool_21(session, path)
      end
      for _, path in ipairs(open_paths) do
        local p = canonical_path(path)
        if (p and (1 == vim.fn.filereadable(p)) and include_file_path_3f(p, file_filter)) then
          deferred_seen[p] = true
          push_file_into_pool_21(session, p, cached_project_view(session, p, wrap_width), prefilter)
        else
        end
      end
      for _, path in ipairs(all_paths) do
        local p = canonical_path(path)
        if (p and not deferred_seen[p] and include_file_path_3f(p, file_filter) and (include_binary or not binary_file_3f(p)) and (not current or (p ~= current))) then
          deferred_seen[p] = true
          table.insert(deferred, p)
        else
        end
      end
      return {["deferred-paths"] = deferred, ["estimated-lines"] = estimate_lines_from_files(deferred)}
    end
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
    debug.log("project-source", ("apply-source-set" .. " project=" .. tostring(clj.boolean(session["project-mode"])) .. " source=" .. tostring(query_source_key) .. " bootstrapped=" .. tostring(clj.boolean(session["project-bootstrapped"])) .. " pending=" .. tostring(clj.boolean(session["project-bootstrap-pending"])) .. " stream-done=" .. tostring(clj.boolean(session["lazy-stream-done"])) .. " prompt=" .. tostring((session["prompt-last-applied-text"] or ""))))
    if query_source_3f then
      session["lazy-stream-id"] = (1 + (session["lazy-stream-id"] or 0))
      session["lazy-stream-done"] = true
      set_query_source_content_21(session)
    elseif session["project-mode"] then
      local init = init_project_pool_21(session, prefilter)
      if lazy_preferred_3f(session, (init["estimated-lines"] or 0)) then
        start_project_stream_21(session, prefilter, init)
      else
        local pool = collect_project_sources({session = session, ["include-hidden"] = session["effective-include-hidden"], ["include-ignored"] = session["effective-include-ignored"], ["include-deps"] = session["effective-include-deps"], ["include-binary"] = session["effective-include-binary"], ["include-files"] = session["effective-include-files"], prefilter = prefilter})
        set_project_pool_21(session, pool)
        session["lazy-stream-done"] = true
        enable_full_source_syntax_21(session)
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
  do
    local stream_helpers = source_stream_mod.new({settings = settings, ["truthy?"] = truthy_3f, ["session-active?"] = session_active_3f, ["lazy-streaming-allowed?"] = lazy_streaming_allowed_3f, ["prompt-has-active-query?"] = prompt_has_active_query_3f, ["now-ms"] = now_ms, ["prompt-update-delay-ms"] = prompt_update_delay_ms, ["schedule-prompt-update!"] = schedule_prompt_update_21, ["on-prompt-changed"] = on_prompt_changed, ["apply-prompt-lines-now!"] = apply_prompt_lines_now_21, ["stream-next-path!"] = stream_next_path_21, ["emit-source-pool-change!"] = emit_source_pool_change_21, ["maybe-finish-project-stream!"] = maybe_finish_project_stream_21, ["apply-source-set!"] = apply_source_set_21, ["set-single-source-content!"] = set_single_source_content_21})
    lazy_preferred_3f = stream_helpers["lazy-preferred?"]
    start_project_stream_21 = stream_helpers["start-project-stream!"]
    schedule_source_set_rebuild_21 = stream_helpers["schedule-source-set-rebuild!"]
    apply_minimal_source_set_21 = stream_helpers["apply-minimal-source-set!"]
    schedule_project_bootstrap_21 = stream_helpers["schedule-project-bootstrap!"]
  end
  local api = {["apply-source-set!"] = apply_source_set_21, ["schedule-source-set-rebuild!"] = schedule_source_set_rebuild_21, ["apply-minimal-source-set!"] = apply_minimal_source_set_21, ["schedule-project-bootstrap!"] = schedule_project_bootstrap_21}
  return api
end
return M
