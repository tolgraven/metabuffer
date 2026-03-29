-- [nfnl] fnl/metabuffer/prompt/hooks.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local M = {}
local animation_mod = require("metabuffer.window.animation")
local prompt_view_mod = require("metabuffer.buffer.prompt_view")
local events = require("metabuffer.events")
local hooks_directive_mod = require("metabuffer.prompt.hooks_directive")
local hooks_keymaps_mod = require("metabuffer.prompt.hooks_keymaps")
local loading_state_mod = require("metabuffer.widgets.loading_state")
local hooks_window_mod = require("metabuffer.prompt.hooks_window")
M.new = function(opts)
  local default_prompt_keymaps = opts["default-prompt-keymaps"]
  local active_by_prompt = opts["active-by-prompt"]
  local default_main_keymaps = opts["default-main-keymaps"]
  local on_prompt_changed = opts["on-prompt-changed"]
  local maybe_sync_from_main_21 = opts["maybe-sync-from-main!"]
  local schedule_scroll_sync_21 = opts["schedule-scroll-sync!"]
  local maybe_restore_hidden_ui_21 = opts["maybe-restore-hidden-ui!"]
  local hide_visible_ui_21 = opts["hide-visible-ui!"]
  local rebuild_source_set_21 = opts["rebuild-source-set!"]
  local sign_mod = opts["sign-mod"]
  local animation_enabled_3f = animation_mod["enabled?"]
  local animation_duration_ms = animation_mod["duration-ms"]
  local function prompt_animation_delay_ms(session)
    if (animation_mod and animation_enabled_3f and animation_enabled_3f(session, "prompt")) then
      return animation_duration_ms(session, "prompt", 140)
    else
      return 0
    end
  end
  local function switch_mode(session, which)
    local meta = session.meta
    local function mode_label(value)
      if (type(value) == "table") then
        return (value.name or tostring(value))
      else
        return tostring(value)
      end
    end
    local old = mode_label(meta.mode[which].current())
    meta.switch_mode(which)
    return events.post("on-mode-switch!", {session = session, kind = which, old = old, new = mode_label(meta.mode[which].current())}, {["supersede?"] = true, ["dedupe-key"] = ("on-mode-switch:" .. tostring(session["prompt-buf"]) .. ":" .. which)})
  end
  local function nvim_exiting_3f()
    local v = (vim.v and vim.v.exiting)
    return ((v ~= nil) and (v ~= vim.NIL) and (v ~= 0) and (v ~= ""))
  end
  local function session_prompt_valid_3f(session)
    return (not nvim_exiting_3f() and session and not session["ui-hidden"] and not session.closing and session.meta and session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and (active_by_prompt[session["prompt-buf"]] == session))
  end
  local function schedule_when_valid(session, f)
    local function _3_()
      if session_prompt_valid_3f(session) then
        return f()
      else
        return nil
      end
    end
    return vim.schedule(_3_)
  end
  local function option_prefix()
    local p = vim.g["meta#prefix"]
    if ((type(p) == "string") and (p ~= "")) then
      return p
    else
      return "#"
    end
  end
  local window_hooks = hooks_window_mod.new(session_prompt_valid_3f)
  local covered_by_new_window_3f = window_hooks["covered-by-new-window?"]
  local transient_overlay_buffer_3f = window_hooks["transient-overlay-buffer?"]
  local first_window_for_buffer = window_hooks["first-window-for-buffer"]
  local capture_expected_layout_21 = window_hooks["capture-expected-layout!"]
  local note_editor_size_21 = window_hooks["note-editor-size!"]
  local note_global_editor_resize_21 = window_hooks["note-global-editor-resize!"]
  local manual_prompt_resize_3f = window_hooks["manual-prompt-resize?"]
  local schedule_restore_expected_layout_21 = window_hooks["schedule-restore-expected-layout!"]
  local hidden_session_reachable_3f = window_hooks["hidden-session-reachable?"]
  local refresh_prompt_highlights_21 = nil
  local schedule_loading_indicator_21 = nil
  local prompt_view
  local function _6_(session)
    if schedule_loading_indicator_21 then
      return schedule_loading_indicator_21(session)
    else
      return nil
    end
  end
  prompt_view = prompt_view_mod.new({["option-prefix"] = option_prefix, ["session-prompt-valid?"] = session_prompt_valid_3f, ["schedule-loading-indicator!"] = _6_})
  local directive_hooks = hooks_directive_mod.new({["option-prefix"] = option_prefix, ["highlight-prompt-like-line!"] = prompt_view["highlight-like-line!"]})
  local keymap_hooks = hooks_keymaps_mod.new({["default-prompt-keymaps"] = default_prompt_keymaps, ["default-main-keymaps"] = default_main_keymaps, ["schedule-when-valid"] = schedule_when_valid, ["switch-mode"] = switch_mode, ["sign-mod"] = sign_mod})
  local hide_directive_help_21 = directive_hooks["hide-directive-help!"]
  local maybe_show_directive_help_21 = directive_hooks["maybe-show-directive-help!"]
  local maybe_trigger_directive_complete_21 = directive_hooks["maybe-trigger-directive-complete!"]
  local apply_keymaps = keymap_hooks["apply-keymaps"]
  local apply_emacs_insert_fallbacks = keymap_hooks["apply-emacs-insert-fallbacks"]
  local apply_main_keymaps = keymap_hooks["apply-main-keymaps"]
  local apply_results_edit_keymaps = keymap_hooks["apply-results-edit-keymaps"]
  local begin_direct_results_edit_21 = keymap_hooks["begin-direct-results-edit!"]
  local loading_hooks
  local function _8_(session)
    return refresh_prompt_highlights_21(session)
  end
  loading_hooks = loading_state_mod.new({["session-prompt-valid?"] = session_prompt_valid_3f, ["animation-enabled?"] = animation_enabled_3f, ["animation-duration-ms"] = animation_duration_ms, ["refresh-prompt-highlights!"] = _8_})
  local loading_scheduler = loading_hooks["schedule-loading-indicator!"]
  refresh_prompt_highlights_21 = prompt_view["refresh-highlights!"]
  schedule_loading_indicator_21 = loading_scheduler
  local function maybe_expand_history_shorthand_21(router, session)
    if session["_expanding-history-shorthand"] then
      return false
    else
      if (session and session["prompt-buf"] and session["prompt-win"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and vim.api.nvim_win_is_valid(session["prompt-win"])) then
        local _let_9_ = vim.api.nvim_win_get_cursor(session["prompt-win"])
        local row = _let_9_[1]
        local col = _let_9_[2]
        local row0 = math.max(0, (row - 1))
        local line = (vim.api.nvim_buf_get_lines(session["prompt-buf"], row0, (row0 + 1), false)[1] or "")
        local left
        if (col > 0) then
          left = string.sub(line, 1, col)
        else
          left = ""
        end
        local saved_tag = string.match(left, "##([%w_%-]+)$")
        local saved_replacement
        if saved_tag then
          saved_replacement = router["saved-prompt-entry"](saved_tag)
        else
          saved_replacement = ""
        end
        local trigger
        if ((col >= 3) and vim.endswith(left, "!^!")) then
          trigger = "!^!"
        elseif ((col >= 2) and vim.endswith(left, "!!")) then
          trigger = "!!"
        elseif ((col >= 2) and vim.endswith(left, "!$")) then
          trigger = "!$"
        else
          trigger = nil
        end
        local replacement
        if (trigger == "!!") then
          replacement = router["last-prompt-entry"](session["prompt-buf"])
        elseif (trigger == "!$") then
          replacement = router["last-prompt-token"](session["prompt-buf"])
        elseif (trigger == "!^!") then
          replacement = router["last-prompt-tail"](session["prompt-buf"])
        else
          replacement = ""
        end
        if (trigger and (type(replacement) == "string") and (replacement ~= "")) then
          session["_expanding-history-shorthand"] = true
          do
            local start_col
            local _14_
            if (trigger == "!^!") then
              _14_ = 3
            else
              _14_ = 2
            end
            start_col = (col - _14_)
            vim.api.nvim_buf_set_text(session["prompt-buf"], row0, start_col, row0, col, {""})
            pcall(vim.api.nvim_win_set_cursor, session["prompt-win"], {row, start_col})
          end
          if (trigger == "!!") then
            router["insert-last-prompt"](session["prompt-buf"])
          elseif (trigger == "!$") then
            router["insert-last-token"](session["prompt-buf"])
          else
            router["insert-last-tail"](session["prompt-buf"])
          end
          session["_expanding-history-shorthand"] = false
          return true
        else
          if (saved_tag and (type(saved_replacement) == "string") and (saved_replacement ~= "")) then
            session["_expanding-history-shorthand"] = true
            do
              local tag_len = (2 + #saved_tag)
              local start_col = (col - tag_len)
              vim.api.nvim_buf_set_text(session["prompt-buf"], row0, start_col, row0, col, {""})
              pcall(vim.api.nvim_win_set_cursor, session["prompt-win"], {row, start_col})
            end
            router["prompt-insert-text"](session["prompt-buf"], saved_replacement)
            session["_expanding-history-shorthand"] = false
            return true
          else
            return false
          end
        end
      else
        return false
      end
    end
  end
  local function register_21(router, session)
    local aug = vim.api.nvim_create_augroup(("MetaPrompt" .. session["prompt-buf"]), {clear = true})
    session.augroup = aug
    capture_expected_layout_21(session)
    local function au_21(events0, buf, body)
      local function _21_(_)
        return schedule_when_valid(session, body)
      end
      return vim.api.nvim_create_autocmd(events0, {group = aug, buffer = buf, callback = _21_})
    end
    local function au_buf_21(events0, buf, callback)
      return vim.api.nvim_create_autocmd(events0, {group = aug, buffer = buf, callback = callback})
    end
    local function au_global_21(events0, callback, _3fopts)
      local base = {group = aug, callback = callback}
      for k, v in pairs((_3fopts or {})) do
        base[k] = v
      end
      return vim.api.nvim_create_autocmd(events0, base)
    end
    local function _22_(_, _0, changedtick, _1, _2, _3, _4, _5)
      local function _23_()
        if (session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
          if maybe_expand_history_shorthand_21(router, session) then
            return nil
          else
            refresh_prompt_highlights_21(session)
            return on_prompt_changed(session["prompt-buf"], false, changedtick)
          end
        else
          return nil
        end
      end
      return vim.schedule(_23_)
    end
    local function _26_()
      if session["prompt-buf"] then
        active_by_prompt[session["prompt-buf"]] = nil
        return nil
      else
        return nil
      end
    end
    vim.api.nvim_buf_attach(session["prompt-buf"], false, {on_lines = _22_, on_detach = _26_})
    local function _28_(_)
      if maybe_expand_history_shorthand_21(router, session) then
        return nil
      else
        refresh_prompt_highlights_21(session)
        maybe_show_directive_help_21(session)
        maybe_trigger_directive_complete_21(session)
        return on_prompt_changed(session["prompt-buf"], false, vim.api.nvim_buf_get_changedtick(session["prompt-buf"]))
      end
    end
    au_buf_21({"TextChanged", "TextChangedI"}, session["prompt-buf"], _28_)
    local function _30_(ev)
      local item = (ev and (type(ev) == "table") and ev.completed_item)
      return maybe_show_directive_help_21(session, item)
    end
    au_21("CompleteChanged", session["prompt-buf"], _30_)
    local function _31_()
      return maybe_show_directive_help_21(session)
    end
    au_21("CompleteDone", session["prompt-buf"], _31_)
    local function _32_()
      events.send("on-insert-enter!", {session = session})
      apply_keymaps(router, session)
      return apply_emacs_insert_fallbacks(router, session)
    end
    au_21("InsertEnter", session["prompt-buf"], _32_)
    local function _33_()
      return events.post("on-prompt-focus!", {session = session}, {["supersede?"] = true, ["dedupe-key"] = ("on-prompt-focus:" .. tostring(session["prompt-buf"]))})
    end
    au_21({"BufEnter", "WinEnter", "FocusGained"}, session["prompt-buf"], _33_)
    local function _34_()
      events.post("on-prompt-focus!", {session = session}, {["supersede?"] = true, ["dedupe-key"] = ("on-prompt-focus:" .. tostring(session["prompt-buf"]))})
      return maybe_show_directive_help_21(session)
    end
    au_21({"ModeChanged", "InsertEnter", "InsertLeave"}, session["prompt-buf"], _34_)
    local function _35_()
      return maybe_show_directive_help_21(session)
    end
    au_21({"CursorMoved", "CursorMovedI"}, session["prompt-buf"], _35_)
    local function _36_()
      return hide_directive_help_21(session)
    end
    au_21({"BufLeave", "WinLeave"}, session["prompt-buf"], _36_)
    local function _37_(ev)
      if not session["handling-layout-change?"] then
        do
          local is_vim_resized_3f = (ev.event == "VimResized")
          local wins
          local _39_
          do
            local t_38_ = vim.v
            if (nil ~= t_38_) then
              t_38_ = t_38_.event
            else
            end
            if (nil ~= t_38_) then
              t_38_ = t_38_.windows
            else
            end
            _39_ = t_38_
          end
          wins = (_39_ or {})
          local manual_prompt_resize = (not is_vim_resized_3f and manual_prompt_resize_3f(session, wins))
          if is_vim_resized_3f then
            session["preview-user-resized?"] = false
          else
          end
          do
            local editor_size_changed_3f = (((session["last-editor-columns"] or vim.o.columns) ~= vim.o.columns) or ((session["last-editor-lines"] or vim.o.lines) ~= vim.o.lines))
            note_editor_size_21(session)
            if (is_vim_resized_3f or editor_size_changed_3f) then
              note_global_editor_resize_21(session)
            else
            end
            if (not is_vim_resized_3f and not editor_size_changed_3f and not session["preview-global-resize-token"] and session["preview-win"] and vim.api.nvim_win_is_valid(session["preview-win"])) then
              for _, wid in ipairs(wins) do
                if (wid == session["preview-win"]) then
                  session["preview-user-resized?"] = true
                else
                end
              end
            else
            end
          end
          if manual_prompt_resize then
            session["prompt-target-height"] = vim.api.nvim_win_get_height(session["prompt-win"])
            capture_expected_layout_21(session)
          else
            schedule_restore_expected_layout_21(session)
          end
        end
        session["handling-layout-change?"] = true
        local function _47_()
          if session_prompt_valid_3f(session) then
            do
              local results_wrap_3f = (session.meta and session.meta.win and vim.api.nvim_win_is_valid(session.meta.win.window) and vim.api.nvim_get_option_value("wrap", {win = session.meta.win.window}))
              if (results_wrap_3f and rebuild_source_set_21 and not session["project-mode"]) then
                pcall(rebuild_source_set_21, session)
                pcall(session.meta["on-update"], 0)
              else
              end
            end
            if not session["prompt-animating?"] then
              pcall(refresh_prompt_highlights_21, session)
              events.send("on-query-update!", {session = session, query = (session["prompt-last-applied-text"] or ""), ["refresh-lines"] = true})
            else
            end
            if (ev.event == "VimResized") then
              capture_expected_layout_21(session)
            else
            end
          else
          end
          session["handling-layout-change?"] = false
          return nil
        end
        return vim.schedule(_47_)
      else
        return nil
      end
    end
    au_global_21({"VimResized", "WinResized"}, _37_)
    local function _53_(_)
      if not session["handling-layout-change?"] then
        session["handling-layout-change?"] = true
        local function _54_()
          if session_prompt_valid_3f(session) then
            if (session.meta and session.meta.win and vim.api.nvim_win_is_valid(session.meta.win.window) and (vim.api.nvim_get_current_win() == session.meta.win.window)) then
              local wrap_3f = clj.boolean(vim.api.nvim_get_option_value("wrap", {win = session.meta.win.window}))
              pcall(vim.api.nvim_set_option_value, "linebreak", wrap_3f, {win = session.meta.win.window})
              if (rebuild_source_set_21 and not session["project-mode"]) then
                pcall(rebuild_source_set_21, session)
                pcall(session.meta["on-update"], 0)
                events.send("on-query-update!", {session = session, query = (session["prompt-last-applied-text"] or ""), ["refresh-lines"] = true})
              else
              end
            else
            end
          else
          end
          session["handling-layout-change?"] = false
          return nil
        end
        return vim.schedule(_54_)
      else
        return nil
      end
    end
    au_global_21("OptionSet", _53_, {pattern = "wrap"})
    local function _59_()
      return maybe_sync_from_main_21(session)
    end
    au_21({"CursorMoved", "CursorMovedI"}, session.meta.buf.buffer, _59_)
    local function _60_(_)
      return begin_direct_results_edit_21(session)
    end
    au_buf_21({"BufEnter", "WinEnter", "FocusGained"}, session.meta.buf.buffer, _60_)
    local function _61_(_)
      if (sign_mod and session.meta and session.meta.buf) then
        local buf = session.meta.buf.buffer
        local internal_3f
        do
          local ok,v = pcall(vim.api.nvim_buf_get_var, buf, "meta_internal_render")
          internal_3f = (ok and v)
        end
        if not internal_3f then
          begin_direct_results_edit_21(session)
        else
        end
        local function _63_()
          if (session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
            pcall(router["sync-live-edits"], session["prompt-buf"])
            pcall(maybe_sync_from_main_21, session, true)
            return events.send("on-query-update!", {session = session, query = (session["prompt-last-applied-text"] or ""), ["refresh-lines"] = true, ["refresh-signs?"] = true})
          else
            return nil
          end
        end
        return vim.schedule(_63_)
      else
        return nil
      end
    end
    au_buf_21({"TextChanged", "TextChangedI"}, session.meta.buf.buffer, _61_)
    local function _66_(_)
      if (not session.closing and session.meta and session.meta.buf and vim.api.nvim_buf_is_valid(session.meta.buf.buffer)) then
        local bo = vim.bo[session.meta.buf.buffer]
        bo["buftype"] = "acwrite"
        bo["modifiable"] = true
        bo["readonly"] = false
        bo["bufhidden"] = "hide"
      else
      end
      if maybe_restore_hidden_ui_21 then
        local function _68_()
          if (not session.closing and session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
            return pcall(maybe_restore_hidden_ui_21, session)
          else
            return nil
          end
        end
        return vim.schedule(_68_)
      else
        return nil
      end
    end
    au_buf_21({"BufEnter", "WinEnter", "FocusGained"}, session.meta.buf.buffer, _66_)
    local function _71_(_)
      local function _72_()
        if (hide_visible_ui_21 and not session["ui-hidden"] and session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
          local win = vim.api.nvim_get_current_win()
          if covered_by_new_window_3f(session, win) then
            return pcall(hide_visible_ui_21, session)
          else
            return nil
          end
        else
          return nil
        end
      end
      return vim.defer_fn(_72_, 20)
    end
    au_global_21("WinNew", _71_)
    local function _75_(ev)
      local function _76_()
        if (hide_visible_ui_21 and not session["ui-hidden"] and session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
          local buf = (ev.buf or vim.api.nvim_get_current_buf())
          local win = (first_window_for_buffer(buf) or vim.api.nvim_get_current_win())
          if (transient_overlay_buffer_3f(buf) or covered_by_new_window_3f(session, win)) then
            return pcall(hide_visible_ui_21, session)
          else
            return nil
          end
        else
          return nil
        end
      end
      return vim.defer_fn(_76_, 20)
    end
    au_global_21("BufWinEnter", _75_)
    local function _79_()
      return events.send("on-selection-change!", {session = session, ["line-nr"] = (1 + (session.meta.selected_index or 0)), ["refresh-lines"] = false})
    end
    au_21({"BufEnter", "WinEnter", "FocusGained"}, session.meta.buf.buffer, _79_)
    local function _80_(_)
      local function _81_()
        if (session["ui-hidden"] and session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session) and not hidden_session_reachable_3f(session)) then
          return pcall(router["remove-session"], session)
        else
          return nil
        end
      end
      return vim.schedule(_81_)
    end
    au_global_21({"BufEnter", "WinEnter", "FocusGained"}, _80_)
    local function _83_(_)
      local function _84_()
        if (not session["ui-hidden"] and session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and (active_by_prompt[session["prompt-buf"]] == session)) then
          local win = session.meta.win.window
          if not vim.api.nvim_win_is_valid(win) then
            return router.cancel(session["prompt-buf"])
          else
            local buf = vim.api.nvim_win_get_buf(win)
            if (buf ~= session.meta.buf.buffer) then
              if (session["project-mode"] and hide_visible_ui_21) then
                return hide_visible_ui_21(session["prompt-buf"])
              else
                return router.cancel(session["prompt-buf"])
              end
            else
              return nil
            end
          end
        else
          return nil
        end
      end
      return vim.schedule(_84_)
    end
    au_buf_21("BufLeave", session.meta.buf.buffer, _83_)
    apply_main_keymaps(router, session)
    apply_results_edit_keymaps(session)
    local function _89_(ev)
      local function _90_()
        if (session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session) and not session.closing) then
          local buf = (ev.buf or vim.api.nvim_get_current_buf())
          if (vim.api.nvim_buf_is_valid(buf) and (buf ~= session.meta.buf.buffer)) then
            local raw = vim.api.nvim_buf_get_name(buf)
            local path
            if (raw and (raw ~= "")) then
              path = vim.fn.fnamemodify(raw, ":p")
            else
              path = nil
            end
            if path then
              if session["preview-file-cache"] then
                session["preview-file-cache"][path] = nil
              else
              end
              if session["info-file-head-cache"] then
                session["info-file-head-cache"][path] = nil
              else
              end
              if session["info-file-meta-cache"] then
                session["info-file-meta-cache"][path] = nil
              else
              end
              if router["project-file-cache"] then
                router["project-file-cache"][path] = nil
              else
              end
              if rebuild_source_set_21 then
                pcall(rebuild_source_set_21, session)
              else
              end
              return events.send("on-query-update!", {session = session, query = (session["prompt-last-applied-text"] or ""), ["refresh-lines"] = true})
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
      return vim.schedule(_90_)
    end
    au_global_21("BufWritePost", _89_)
    local function _100_(_)
      return schedule_scroll_sync_21(session)
    end
    au_global_21("WinScrolled", _100_)
    local function _101_(_)
      return router["write-results"](session["prompt-buf"])
    end
    au_buf_21("BufWriteCmd", session.meta.buf.buffer, _101_)
    local function _102_(_)
      local function _103_()
        return router["results-buffer-wiped"](session.meta.buf.buffer)
      end
      return vim.schedule(_103_)
    end
    au_buf_21("BufWipeout", session.meta.buf.buffer, _102_)
    refresh_prompt_highlights_21(session)
    maybe_show_directive_help_21(session)
    local function _104_()
      if (session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
        pcall(refresh_prompt_highlights_21, session)
        return capture_expected_layout_21(session)
      else
        return nil
      end
    end
    vim.defer_fn(_104_, prompt_animation_delay_ms(session))
    apply_keymaps(router, session)
    return apply_emacs_insert_fallbacks(router, session)
  end
  return {["register!"] = register_21, ["refresh!"] = refresh_prompt_highlights_21, ["loading!"] = schedule_loading_indicator_21}
end
return M
