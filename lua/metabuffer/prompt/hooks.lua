-- [nfnl] fnl/metabuffer/prompt/hooks.fnl
local M = {}
local animation_mod = require("metabuffer.window.animation")
M.new = function(opts)
  local mark_prompt_buffer_21 = opts["mark-prompt-buffer!"]
  local default_prompt_keymaps = opts["default-prompt-keymaps"]
  local active_by_prompt = opts["active-by-prompt"]
  local default_main_keymaps = opts["default-main-keymaps"]
  local on_prompt_changed = opts["on-prompt-changed"]
  local update_info_window = opts["update-info-window"]
  local maybe_sync_from_main_21 = opts["maybe-sync-from-main!"]
  local schedule_scroll_sync_21 = opts["schedule-scroll-sync!"]
  local maybe_restore_hidden_ui_21 = opts["maybe-restore-hidden-ui!"]
  local hide_visible_ui_21 = opts["hide-visible-ui!"]
  local maybe_refresh_preview_statusline_21 = opts["maybe-refresh-preview-statusline!"]
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
  local function disable_cmp(session)
    mark_prompt_buffer_21(session["prompt-buf"])
    local ok,cmp = pcall(require, "cmp")
    if ok then
      pcall(cmp.setup.buffer, {enabled = false})
      return pcall(cmp.abort)
    else
      return nil
    end
  end
  local function switch_mode(session, which)
    local meta = session.meta
    meta.switch_mode(which)
    return pcall(meta.refresh_statusline)
  end
  local function session_prompt_valid_3f(session)
    return (session.meta and session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]))
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
  local function some_3d(needle, coll)
    local hit0 = false
    local hit = hit0
    for _, item in ipairs((coll or {})) do
      if (needle == item) then
        hit = true
      else
      end
    end
    return hit
  end
  local function window_rect(win)
    if (win and (type(win) == "number") and vim.api.nvim_win_is_valid(win)) then
      local pos = vim.api.nvim_win_get_position(win)
      local row = (pos[1] or 0)
      local col = (pos[2] or 0)
      local height = vim.api.nvim_win_get_height(win)
      local width = vim.api.nvim_win_get_width(win)
      return {top = row, left = col, bottom = (row + height + -1), right = (col + width + -1)}
    else
      return nil
    end
  end
  local function rect_overlap_3f(a, b)
    return (a and b and (a.top <= b.bottom) and (b.top <= a.bottom) and (a.left <= b.right) and (b.left <= a.right))
  end
  local function meta_owned_window_3f(session, win)
    local meta_win = (session.meta and session.meta.win and session.meta.win.window)
    local prompt_win = session["prompt-win"]
    local info_win = session["info-win"]
    local preview_win = session["preview-win"]
    local history_win = session["history-browser-win"]
    return ((win == meta_win) or (win == prompt_win) or (win == info_win) or (win == preview_win) or (win == history_win))
  end
  local function covered_by_new_window_3f(session, win)
    local target = window_rect(win)
    local prompt_win = session["prompt-win"]
    local info_win = session["info-win"]
    local preview_win = session["preview-win"]
    local history_win = session["history-browser-win"]
    return (target and not meta_owned_window_3f(session, win) and (rect_overlap_3f(target, window_rect(info_win)) or rect_overlap_3f(target, window_rect(preview_win)) or rect_overlap_3f(target, window_rect(history_win)) or (session["prompt-floating?"] and rect_overlap_3f(target, window_rect(prompt_win)))))
  end
  local function transient_overlay_buffer_3f(buf)
    if (buf and (type(buf) == "number") and vim.api.nvim_buf_is_valid(buf)) then
      local bo = vim.bo[buf]
      local ft = (bo.filetype or "")
      local bt = (bo.buftype or "")
      return ((ft == "help") or (ft == "man") or (bt == "help"))
    else
      return nil
    end
  end
  local function first_window_for_buffer(buf)
    if (buf and (type(buf) == "number") and vim.api.nvim_buf_is_valid(buf)) then
      local wins = vim.fn.win_findbuf(buf)
      local found = nil
      for _, win in ipairs((wins or {})) do
        if (not found and vim.api.nvim_win_is_valid(win)) then
          found = win
        else
        end
      end
      return found
    else
      return nil
    end
  end
  local function control_token_style(tok)
    local token = (tok or "")
    local prefix = option_prefix()
    local escaped_prefix_3f = (vim.startswith(token, "\\") and vim.startswith(string.sub(token, 2), prefix))
    local sign = string.match(token, "^#([%+%-])")
    local base
    if sign then
      base = string.sub(token, 3)
    else
      if vim.startswith(token, "#") then
        base = string.sub(token, 2)
      else
        if ((prefix ~= "#") and vim.startswith(token, prefix)) then
          base = string.sub(token, (#prefix + 1))
        else
          base = ""
        end
      end
    end
    local toggle_off_3f = some_3d(base, {"nohidden", "noignored", "nodeps", "nobinary", "nohex", "nofile", "noprefilter", "nolazy", "escape"})
    local toggle_on_3f = some_3d(base, {"hidden", "ignored", "deps", "binary", "hex", "file", "prefilter", "lazy"})
    local functional_3f = some_3d(base, {"hex", "nohex", "prefilter", "noprefilter", "lazy", "nolazy", "escape"})
    local off_3f = ((sign == "-") or toggle_off_3f)
    if (escaped_prefix_3f or (base == "")) then
      return nil
    else
      if ((sign == "+") or (sign == "-") or toggle_on_3f or toggle_off_3f) then
        local _14_
        if off_3f then
          _14_ = "MetaPromptFlagHashOff"
        else
          _14_ = "MetaPromptFlagHashOn"
        end
        local _16_
        if functional_3f then
          if off_3f then
            _16_ = "MetaPromptFlagTextFuncOff"
          else
            _16_ = "MetaPromptFlagTextFuncOn"
          end
        else
          if off_3f then
            _16_ = "MetaPromptFlagTextOff"
          else
            _16_ = "MetaPromptFlagTextOn"
          end
        end
        return {["hash-hl"] = _14_, ["text-hl"] = _16_}
      else
        return nil
      end
    end
  end
  local function session_busy_3f(session)
    return (session and (session["prompt-update-pending"] or session["prompt-update-dirty"] or session["lazy-refresh-pending"] or session["lazy-refresh-dirty"] or session["project-bootstrap-pending"] or (session["project-mode"] and not session["project-bootstrapped"])))
  end
  local refresh_prompt_highlights_21 = nil
  local function schedule_loading_indicator_21(session)
    if (session and not session["loading-anim-pending"] and session["prompt-buf"] and session_prompt_valid_3f(session) and session["loading-indicator?"] and session_busy_3f(session)) then
      session["loading-anim-pending"] = true
      local function _22_()
        session["loading-anim-pending"] = false
        if session_prompt_valid_3f(session) then
          if (session_busy_3f(session) and animation_enabled_3f and animation_enabled_3f(session, "loading")) then
            session["loading-anim-phase"] = (1 + (session["loading-anim-phase"] or 0))
            pcall(session.meta.refresh_statusline)
            return refresh_prompt_highlights_21(session)
          else
            if (session["loading-anim-phase"] ~= nil) then
              session["loading-anim-phase"] = nil
              return pcall(session.meta.refresh_statusline)
            else
              return nil
            end
          end
        else
          return nil
        end
      end
      return vim.defer_fn(_22_, animation_duration_ms(session, "loading", 90))
    else
      return nil
    end
  end
  local function render_project_flags_footer_21(session)
    if (session["prompt-buf"] and session_prompt_valid_3f(session)) then
      local ns = (session["prompt-footer-ns"] or vim.api.nvim_create_namespace("metabuffer.prompt.footer"))
      local _
      session["prompt-footer-ns"] = ns
      _ = nil
      session["prompt-footer-ns"] = ns
      vim.api.nvim_buf_clear_namespace(session["prompt-buf"], ns, 0, -1)
      return schedule_loading_indicator_21(session)
    else
      return nil
    end
  end
  local function _28_(session)
    if (session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"])) then
      local ns = (session["prompt-hl-ns"] or vim.api.nvim_create_namespace("metabuffer.prompt"))
      local lines = vim.api.nvim_buf_get_lines(session["prompt-buf"], 0, -1, false)
      session["prompt-hl-ns"] = ns
      vim.api.nvim_buf_clear_namespace(session["prompt-buf"], ns, 0, -1)
      for row, line in ipairs((lines or {})) do
        local r = (row - 1)
        local txt = (line or "")
        local pos = 1
        while (pos <= #txt) do
          local s,e = string.find(txt, "%S+", pos)
          if (s and e) then
            local token = string.sub(txt, s, e)
            local s0 = (s - 1)
            local e0 = e
            vim.api.nvim_buf_add_highlight(session["prompt-buf"], ns, "MetaPromptText", r, s0, e0)
            do
              local val_110_auto = control_token_style(token)
              if val_110_auto then
                local style = val_110_auto
                vim.api.nvim_buf_add_highlight(session["prompt-buf"], ns, (style["hash-hl"] or "MetaPromptText"), r, s0, (s0 + 1))
                if (e0 > (s0 + 1)) then
                  vim.api.nvim_buf_add_highlight(session["prompt-buf"], ns, (style["text-hl"] or "MetaPromptText"), r, (s0 + 1), e0)
                else
                end
              else
              end
            end
            if ((#token > 1) and (string.sub(token, 1, 1) == "!")) then
              vim.api.nvim_buf_add_highlight(session["prompt-buf"], ns, "MetaPromptNeg", r, s0, e0)
            else
            end
            do
              local core
              if ((#token > 1) and (string.sub(token, 1, 1) == "!")) then
                core = string.sub(token, 2)
              else
                core = token
              end
              if ((#core > 0) and not not string.find(core, "[\\%[%]%(%)%+%*%?%|]")) then
                vim.api.nvim_buf_add_highlight(session["prompt-buf"], ns, "MetaPromptRegex", r, s0, e0)
              else
              end
            end
            if ((#token > 0) and (string.sub(token, 1, 1) == "^")) then
              vim.api.nvim_buf_add_highlight(session["prompt-buf"], ns, "MetaPromptAnchor", r, s0, (s0 + 1))
            else
            end
            if ((#token > 0) and (string.sub(token, #token) == "$")) then
              vim.api.nvim_buf_add_highlight(session["prompt-buf"], ns, "MetaPromptAnchor", r, (e0 - 1), e0)
            else
            end
            pos = (e + 1)
          else
            pos = (#txt + 1)
          end
        end
      end
      return render_project_flags_footer_21(session)
    else
      return nil
    end
  end
  refresh_prompt_highlights_21 = _28_
  local function maybe_expand_history_shorthand_21(router, session)
    if session["_expanding-history-shorthand"] then
      return false
    else
      if (session and session["prompt-buf"] and session["prompt-win"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and vim.api.nvim_win_is_valid(session["prompt-win"])) then
        local _let_38_ = vim.api.nvim_win_get_cursor(session["prompt-win"])
        local row = _let_38_[1]
        local col = _let_38_[2]
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
            local _43_
            if (trigger == "!^!") then
              _43_ = 3
            else
              _43_ = 2
            end
            start_col = (col - _43_)
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
  local function resolve_map_action(router, session, action, arg)
    if (action == "accept") then
      local function _50_()
        return router.accept(session["prompt-buf"])
      end
      return _50_
    elseif (action == "enter-edit-mode") then
      local function _51_()
        return router["enter-edit-mode"](session["prompt-buf"])
      end
      return _51_
    elseif (action == "cancel") then
      local function _52_()
        return router.cancel(session["prompt-buf"])
      end
      return _52_
    elseif (action == "move-selection") then
      local function _53_()
        return router["move-selection"](session["prompt-buf"], arg)
      end
      return _53_
    elseif (action == "history-or-move") then
      local function _54_()
        return router["history-or-move"](session["prompt-buf"], arg)
      end
      return _54_
    elseif (action == "prompt-home") then
      local function _55_()
        local function _56_()
          return router["prompt-home"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _56_)
      end
      return _55_
    elseif (action == "prompt-end") then
      local function _57_()
        local function _58_()
          return router["prompt-end"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _58_)
      end
      return _57_
    elseif (action == "prompt-kill-backward") then
      local function _59_()
        local function _60_()
          return router["prompt-kill-backward"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _60_)
      end
      return _59_
    elseif (action == "prompt-kill-forward") then
      local function _61_()
        local function _62_()
          return router["prompt-kill-forward"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _62_)
      end
      return _61_
    elseif (action == "prompt-yank") then
      local function _63_()
        local function _64_()
          return router["prompt-yank"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _64_)
      end
      return _63_
    elseif (action == "insert-last-prompt") then
      local function _65_()
        local function _66_()
          return router["insert-last-prompt"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _66_)
      end
      return _65_
    elseif (action == "insert-last-token") then
      local function _67_()
        local function _68_()
          return router["insert-last-token"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _68_)
      end
      return _67_
    elseif (action == "insert-last-tail") then
      local function _69_()
        local function _70_()
          return router["insert-last-tail"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _70_)
      end
      return _69_
    elseif (action == "toggle-prompt-results-focus") then
      local function _71_()
        local function _72_()
          return router["toggle-prompt-results-focus"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _72_)
      end
      return _71_
    elseif (action == "negate-current-token") then
      local function _73_()
        local function _74_()
          return router["negate-current-token"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _74_)
      end
      return _73_
    elseif (action == "history-searchback") then
      local function _75_()
        local function _76_()
          return router["open-history-searchback"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _76_)
      end
      return _75_
    elseif (action == "merge-history") then
      local function _77_()
        local function _78_()
          return router["merge-history-cache"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _78_)
      end
      return _77_
    elseif (action == "switch-mode") then
      local function _79_()
        return switch_mode(session, arg)
      end
      return _79_
    elseif (action == "toggle-scan-option") then
      local function _80_()
        return router["toggle-scan-option"](session["prompt-buf"], arg)
      end
      return _80_
    elseif (action == "scroll-main") then
      local function _81_()
        return router["scroll-main"](session["prompt-buf"], arg)
      end
      return _81_
    elseif (action == "toggle-project-mode") then
      local function _82_()
        return router["toggle-project-mode"](session["prompt-buf"])
      end
      return _82_
    elseif (action == "toggle-info-file-entry-view") then
      local function _83_()
        return router["toggle-info-file-entry-view"](session["prompt-buf"])
      end
      return _83_
    else
      return nil
    end
  end
  local function apply_keymaps(router, session)
    local base_opts = {buffer = session["prompt-buf"], silent = true, noremap = true, nowait = true}
    local rules = (session["prompt-keymaps"] or default_prompt_keymaps)
    for _, r in ipairs(rules) do
      local mode = r[1]
      local lhs = r[2]
      local action = r[3]
      local arg = r[4]
      local opts0
      if ((action == "insert-last-prompt") or (action == "insert-last-token") or (action == "insert-last-tail")) then
        opts0 = vim.tbl_extend("force", base_opts, {nowait = false})
      else
        opts0 = base_opts
      end
      local rhs = resolve_map_action(router, session, action, arg)
      if rhs then
        vim.keymap.set(mode, lhs, rhs, opts0)
      else
        vim.notify(("metabuffer: unknown prompt keymap action '" .. tostring(action) .. "' for " .. tostring(lhs)), vim.log.levels.WARN)
      end
    end
    return nil
  end
  local function apply_emacs_insert_fallbacks(router, session)
    local base_opts = {buffer = session["prompt-buf"], silent = true, noremap = true, nowait = true}
    local rules = (session["prompt-fallback-keymaps"] or {})
    for _, r in ipairs(rules) do
      local mode = r[1]
      local lhs = r[2]
      local action = r[3]
      local arg = r[4]
      local rhs = resolve_map_action(router, session, action, arg)
      if rhs then
        vim.keymap.set(mode, lhs, rhs, base_opts)
      else
      end
    end
    return nil
  end
  local function resolve_main_map_action(router, session, action, arg)
    if (action == "accept-main") then
      local function _88_()
        return router["accept-main"](session["prompt-buf"])
      end
      return _88_
    elseif (action == "enter-edit-mode") then
      local function _89_()
        return router["enter-edit-mode"](session["prompt-buf"])
      end
      return _89_
    elseif (action == "exclude-symbol-under-cursor") then
      local function _90_()
        return router["exclude-symbol-under-cursor"](session["prompt-buf"])
      end
      return _90_
    elseif (action == "insert-symbol-under-cursor") then
      local function _91_()
        return router["insert-symbol-under-cursor"](session["prompt-buf"])
      end
      return _91_
    elseif (action == "insert-symbol-under-cursor-newline") then
      local function _92_()
        return router["insert-symbol-under-cursor-newline"](session["prompt-buf"])
      end
      return _92_
    elseif (action == "toggle-prompt-results-focus") then
      local function _93_()
        return router["toggle-prompt-results-focus"](session["prompt-buf"])
      end
      return _93_
    elseif (action == "scroll-main") then
      local function _94_()
        return router["scroll-main"](session["prompt-buf"], arg)
      end
      return _94_
    elseif (action == "toggle-info-file-entry-view") then
      local function _95_()
        return router["toggle-info-file-entry-view"](session["prompt-buf"])
      end
      return _95_
    else
      return nil
    end
  end
  local function apply_main_keymaps(router, session)
    local base_opts = {buffer = session.meta.buf.buffer, silent = true, noremap = true, nowait = true}
    local rules = (session["main-keymaps"] or default_main_keymaps)
    for _, r in ipairs(rules) do
      local mode = r[1]
      local lhs = r[2]
      local action = r[3]
      local arg = r[4]
      local rhs = resolve_main_map_action(router, session, action, arg)
      if rhs then
        vim.keymap.set(mode, lhs, rhs, base_opts)
      else
        vim.notify(("metabuffer: unknown main keymap action '" .. tostring(action) .. "' for " .. tostring(lhs)), vim.log.levels.WARN)
      end
    end
    return nil
  end
  local function register_21(router, session)
    local aug = vim.api.nvim_create_augroup(("MetaPrompt" .. session["prompt-buf"]), {clear = true})
    session.augroup = aug
    local function _98_(_, _0, changedtick, _1, _2, _3, _4, _5)
      local function _99_()
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
      return vim.schedule(_99_)
    end
    local function _102_()
      if session["prompt-buf"] then
        active_by_prompt[session["prompt-buf"]] = nil
        return nil
      else
        return nil
      end
    end
    vim.api.nvim_buf_attach(session["prompt-buf"], false, {on_lines = _98_, on_detach = _102_})
    local function _104_(_)
      if maybe_expand_history_shorthand_21(router, session) then
        return nil
      else
        refresh_prompt_highlights_21(session)
        return on_prompt_changed(session["prompt-buf"], false, vim.api.nvim_buf_get_changedtick(session["prompt-buf"]))
      end
    end
    vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI"}, {group = aug, buffer = session["prompt-buf"], callback = _104_})
    local function _106_(_)
      local function _107_()
        disable_cmp(session)
        apply_keymaps(router, session)
        return apply_emacs_insert_fallbacks(router, session)
      end
      return schedule_when_valid(session, _107_)
    end
    vim.api.nvim_create_autocmd("InsertEnter", {group = aug, buffer = session["prompt-buf"], callback = _106_})
    local function _108_(_)
      local function _109_()
        return pcall(session.meta.refresh_statusline)
      end
      return schedule_when_valid(session, _109_)
    end
    vim.api.nvim_create_autocmd({"BufEnter", "WinEnter", "FocusGained"}, {group = aug, buffer = session["prompt-buf"], callback = _108_})
    local function _110_(_)
      local function _111_()
        return pcall(session.meta.refresh_statusline)
      end
      return schedule_when_valid(session, _111_)
    end
    vim.api.nvim_create_autocmd({"ModeChanged", "InsertEnter", "InsertLeave"}, {group = aug, buffer = session["prompt-buf"], callback = _110_})
    local function _112_(_)
      local function _113_()
        if maybe_refresh_preview_statusline_21 then
          return pcall(maybe_refresh_preview_statusline_21, session)
        else
          return nil
        end
      end
      return schedule_when_valid(session, _113_)
    end
    vim.api.nvim_create_autocmd({"BufEnter", "WinEnter", "FocusGained"}, {group = aug, buffer = session["prompt-buf"], callback = _112_})
    local function _115_(_)
      local function _116_()
        if not session["prompt-animating?"] then
          pcall(refresh_prompt_highlights_21, session)
          return pcall(update_info_window, session)
        else
          return nil
        end
      end
      return schedule_when_valid(session, _116_)
    end
    vim.api.nvim_create_autocmd({"VimResized", "WinResized"}, {group = aug, callback = _115_})
    local function _118_(_)
      local function _119_()
        return maybe_sync_from_main_21(session)
      end
      return schedule_when_valid(session, _119_)
    end
    vim.api.nvim_create_autocmd({"CursorMoved", "CursorMovedI"}, {group = aug, buffer = session.meta.buf.buffer, callback = _118_})
    local function _120_(_)
      if (sign_mod and session.meta and session.meta.buf) then
        local buf = session.meta.buf.buffer
        local internal_3f
        do
          local ok,v = pcall(vim.api.nvim_buf_get_var, buf, "meta_internal_render")
          internal_3f = (ok and v)
        end
        if not internal_3f then
          pcall(vim.api.nvim_buf_set_var, buf, "meta_manual_edit_active", true)
        else
        end
        local function _122_()
          if (session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
            pcall(router["sync-live-edits"], session["prompt-buf"])
            pcall(maybe_sync_from_main_21, session, true)
            pcall(update_info_window, session, true)
            return pcall(sign_mod["refresh-change-signs!"], session)
          else
            return nil
          end
        end
        return vim.schedule(_122_)
      else
        return nil
      end
    end
    vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI"}, {group = aug, buffer = session.meta.buf.buffer, callback = _120_})
    local function _125_(_)
      if (session.meta and session.meta.buf and vim.api.nvim_buf_is_valid(session.meta.buf.buffer)) then
        local bo = vim.bo[session.meta.buf.buffer]
        bo["buftype"] = "acwrite"
        bo["modifiable"] = true
        bo["readonly"] = false
        bo["bufhidden"] = "hide"
      else
      end
      if maybe_restore_hidden_ui_21 then
        local function _127_()
          if (session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
            return pcall(maybe_restore_hidden_ui_21, session)
          else
            return nil
          end
        end
        return vim.schedule(_127_)
      else
        return nil
      end
    end
    vim.api.nvim_create_autocmd("BufEnter", {group = aug, buffer = session.meta.buf.buffer, callback = _125_})
    local function _130_(_)
      local function _131_()
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
      return vim.defer_fn(_131_, 20)
    end
    vim.api.nvim_create_autocmd("WinNew", {group = aug, callback = _130_})
    local function _134_(ev)
      local function _135_()
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
      return vim.defer_fn(_135_, 20)
    end
    vim.api.nvim_create_autocmd("BufWinEnter", {group = aug, callback = _134_})
    local function _138_(_)
      local function _139_()
        return pcall(session.meta.refresh_statusline)
      end
      return schedule_when_valid(session, _139_)
    end
    vim.api.nvim_create_autocmd({"BufEnter", "WinEnter", "FocusGained"}, {group = aug, buffer = session.meta.buf.buffer, callback = _138_})
    local function _140_(_)
      local function _141_()
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
      return vim.schedule(_141_)
    end
    vim.api.nvim_create_autocmd("BufLeave", {group = aug, buffer = session.meta.buf.buffer, callback = _140_})
    apply_main_keymaps(router, session)
    local function _146_(_)
      return schedule_scroll_sync_21(session)
    end
    vim.api.nvim_create_autocmd("WinScrolled", {group = aug, callback = _146_})
    local function _147_(_)
      return router["write-results"](session["prompt-buf"])
    end
    vim.api.nvim_create_autocmd("BufWriteCmd", {group = aug, buffer = session.meta.buf.buffer, callback = _147_})
    local function _148_(_)
      local function _149_()
        return router["results-buffer-wiped"](session.meta.buf.buffer)
      end
      return vim.schedule(_149_)
    end
    vim.api.nvim_create_autocmd("BufWipeout", {group = aug, buffer = session.meta.buf.buffer, callback = _148_})
    disable_cmp(session)
    mark_prompt_buffer_21(session["prompt-buf"])
    refresh_prompt_highlights_21(session)
    local function _150_()
      if (session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
        return pcall(refresh_prompt_highlights_21, session)
      else
        return nil
      end
    end
    vim.defer_fn(_150_, prompt_animation_delay_ms(session))
    apply_keymaps(router, session)
    return apply_emacs_insert_fallbacks(router, session)
  end
  return {["register!"] = register_21, ["refresh!"] = refresh_prompt_highlights_21}
end
return M
