-- [nfnl] fnl/metabuffer/window/info_regular.fnl
local M = {}
local file_info = require("metabuffer.source.file_info")
local helper_mod = require("metabuffer.window.info_helpers")
local join_str = helper_mod["join-str"]
local indices_slice_sig = helper_mod["indices-slice-sig"]
local ref_path = helper_mod["ref-path"]
local refs_slice_sig = helper_mod["refs-slice-sig"]
M.new = function(opts)
  local _let_1_ = (opts or {})
  local info_height = _let_1_["info-height"]
  local info_max_lines = _let_1_["info-max-lines"]
  local refresh_info_statusline_21 = _let_1_["refresh-info-statusline!"]
  local render_info_lines_21 = _let_1_["render-info-lines!"]
  local set_info_topline_21 = _let_1_["set-info-topline!"]
  local sync_info_selection_21 = _let_1_["sync-info-selection!"]
  local info_visible_range = _let_1_["info-visible-range"]
  local info_max_width_now = _let_1_["info-max-width-now"]
  local function render_current_range_21(session, meta)
    local total = #(meta.buf.indices or {})
    local _let_2_ = info_visible_range(session, meta, total, info_max_lines)
    local start_index = _let_2_[1]
    local stop_index = _let_2_[2]
    local overscan = math.max(1, info_height(session))
    local render_start = math.max(1, (start_index - overscan))
    local render_stop = math.min(total, (stop_index + overscan))
    render_info_lines_21({session = session, meta = meta, ["render-start"] = render_start, ["render-stop"] = render_stop, ["visible-start"] = start_index, ["visible-stop"] = stop_index})
    sync_info_selection_21(session, meta)
    return {start_index, stop_index}
  end
  local function schedule_regular_line_meta_refresh_21(session, meta, start_index, stop_index)
    local refs = (meta.buf["source-refs"] or {})
    local idxs = (meta.buf.indices or {})
    local first_row = ((#idxs > 0) and idxs[start_index])
    local first_ref = (first_row and refs[first_row])
    local path = ref_path(session, first_ref)
    local rerender_21 = nil
    local function _3_()
      if (session and session["info-buf"] and vim.api.nvim_buf_is_valid(session["info-buf"]) and not session["project-mode"] and session["single-file-info-ready"]) then
        if (session["scroll-animating?"] or session["scroll-command-view"] or session["scroll-sync-pending"] or session["selection-refresh-pending"]) then
          if not session["info-line-meta-refresh-pending"] then
            session["info-line-meta-refresh-pending"] = true
            local function _4_()
              session["info-line-meta-refresh-pending"] = false
              return rerender_21()
            end
            return vim.defer_fn(_4_, 90)
          else
            return nil
          end
        else
          local _let_6_ = render_current_range_21(session, meta)
          local start1 = _let_6_[1]
          local stop1 = _let_6_[2]
          session["info-start-index"] = start1
          session["info-stop-index"] = stop1
          return nil
        end
      else
        return nil
      end
    end
    rerender_21 = _3_
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
          local function _10_()
            if (range_key == session["info-line-meta-range-key"]) then
              return rerender_21()
            else
              return nil
            end
          end
          file_info["ensure-file-status-async!"](session, path, _10_)
          local function _12_()
            if (range_key == session["info-line-meta-range-key"]) then
              return rerender_21()
            else
              return nil
            end
          end
          return file_info["ensure-line-meta-range-async!"](session, path, lnums, _12_)
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
  local function update_regular_21(session, refresh_lines)
    if (session["info-render-suspended?"] and not session["prompt-animating?"] and not session["startup-initializing"]) then
      session["info-post-fade-refresh?"] = nil
      session["info-render-suspended?"] = false
    else
    end
    if (not session["info-render-suspended?"] and session["info-buf"] and vim.api.nvim_buf_is_valid(session["info-buf"])) then
      local meta = session.meta
      local _ = refresh_info_statusline_21(session)
      local force_refresh_3f = ((session["info-render-sig"] == nil) or (session["info-start-index"] == nil) or (session["info-stop-index"] == nil))
      local selected1 = (meta.selected_index + 1)
      local idxs = (meta.buf.indices or {})
      local overscan = math.max(1, info_height(session))
      local _let_18_ = info_visible_range(session, meta, #idxs, info_max_lines)
      local wanted_start = _let_18_[1]
      local wanted_stop = _let_18_[2]
      local render_start
      if (#idxs > 0) then
        render_start = math.max(1, (wanted_start - overscan))
      else
        render_start = 1
      end
      local render_stop
      if (#idxs > 0) then
        render_stop = math.min(#idxs, (wanted_stop + overscan))
      else
        render_stop = 0
      end
      local start_index = (session["info-start-index"] or 1)
      local stop_index = (session["info-stop-index"] or 0)
      local rendered_start = (session["info-render-start"] or 1)
      local rendered_stop = (session["info-render-stop"] or 0)
      local out_of_range = ((selected1 < start_index) or (selected1 > stop_index))
      local range_changed = ((wanted_start ~= start_index) or (wanted_stop ~= stop_index))
      local rendered_range_changed = ((wanted_start < rendered_start) or (wanted_stop > rendered_stop) or (render_start ~= rendered_start) or (render_stop ~= rendered_stop))
      local sig = join_str("|", {#idxs, indices_slice_sig(idxs, render_start, render_stop), refs_slice_sig(session, meta.buf["source-refs"], idxs, render_start, render_stop), render_start, render_stop, (session["active-source-key"] or ""), (session["info-file-entry-view"] or ""), info_max_width_now(session), info_height(session), vim.o.columns, tostring(not not session["single-file-info-ready"]), tostring(not not session["single-file-info-fetch-ready"])})
      if (force_refresh_3f or refresh_lines or out_of_range or range_changed or rendered_range_changed or (session["info-render-sig"] ~= sig)) then
        if refresh_lines then
          session["info-line-meta-range-key"] = nil
        else
        end
        session["info-render-sig"] = sig
        render_info_lines_21({session = session, meta = meta, ["render-start"] = render_start, ["render-stop"] = render_stop, ["visible-start"] = wanted_start, ["visible-stop"] = wanted_stop})
        session["info-start-index"] = wanted_start
        session["info-stop-index"] = wanted_stop
        sync_info_selection_21(session, meta)
        return schedule_regular_line_meta_refresh_21(session, meta, wanted_start, wanted_stop)
      else
        set_info_topline_21(session, wanted_start)
        return sync_info_selection_21(session, meta)
      end
    else
      return nil
    end
  end
  return {["update-regular!"] = update_regular_21}
end
return M
