-- [nfnl] fnl/metabuffer/prompt/hooks.fnl
local M = {}
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
  local sign_mod = opts["sign-mod"]
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
    local function _2_()
      if session_prompt_valid_3f(session) then
        return f()
      else
        return nil
      end
    end
    return vim.schedule(_2_)
  end
  local function option_prefix()
    local p = vim.g["meta#prefix"]
    if ((type(p) == "string") and (p ~= "")) then
      return p
    else
      return "#"
    end
  end
  local function control_token_hl(tok)
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
    local toggle_off_3f = ((base == "nohidden") or (base == "noignored") or (base == "nodeps") or (base == "nobinary") or (base == "nohex") or (base == "nofile") or (base == "noprefilter") or (base == "nolazy") or (base == "escape"))
    local toggle_on_3f = ((base == "hidden") or (base == "ignored") or (base == "deps") or (base == "binary") or (base == "hex") or (base == "file") or (base == "prefilter") or (base == "lazy"))
    if (escaped_prefix_3f or (base == "")) then
      return nil
    else
      if ((sign == "-") or toggle_off_3f) then
        return "MetaPromptFlagOff"
      else
        if ((sign == "+") or toggle_on_3f) then
          return "MetaPromptFlagOn"
        else
          return nil
        end
      end
    end
  end
  local function project_flag_token(name, on_3f)
    local _11_
    if on_3f then
      _11_ = ("#" .. name)
    else
      _11_ = ("#-" .. name)
    end
    local function _13_()
      if on_3f then
        return "MetaPromptFlagOn"
      else
        return "MetaPromptFlagOff"
      end
    end
    return {_11_, _13_()}
  end
  local function wrap_flag_pieces(pieces, max_cols)
    local width = math.max(12, (max_cols or 12))
    local lines = {}
    local current0 = {}
    local line_w0 = 0
    local current = current0
    local line_w = line_w0
    local function flush_line_21()
      if (#current > 0) then
        table.insert(lines, current)
        current = {}
        line_w = 0
        return nil
      else
        return nil
      end
    end
    for _, p in ipairs(pieces) do
      local txt = (p.text or "")
      local hl = (p.hl or "MetaPromptText")
      local w = vim.fn.strdisplaywidth(txt)
      if ((line_w > 0) and ((line_w + w) > width)) then
        flush_line_21()
      else
      end
      table.insert(current, {txt, hl})
      line_w = (line_w + w)
    end
    flush_line_21()
    if (#lines > 0) then
      return lines
    else
      return {{{"", "MetaPromptText"}}}
    end
  end
  local function render_project_flags_footer_21(session)
    if (session["prompt-buf"] and session_prompt_valid_3f(session)) then
      local ns = (session["prompt-footer-ns"] or vim.api.nvim_create_namespace("metabuffer.prompt.footer"))
      local row = math.max(0, (vim.api.nvim_buf_line_count(session["prompt-buf"]) - 1))
      local _let_17_ = project_flag_token("hidden", not not session["effective-include-hidden"])
      local hidden_token = _let_17_[1]
      local hidden_hl = _let_17_[2]
      local _let_18_ = project_flag_token("ignored", not not session["effective-include-ignored"])
      local ignored_token = _let_18_[1]
      local ignored_hl = _let_18_[2]
      local _let_19_ = project_flag_token("deps", not not session["effective-include-deps"])
      local deps_token = _let_19_[1]
      local deps_hl = _let_19_[2]
      local _let_20_ = project_flag_token("file", not not session["effective-include-files"])
      local file_token = _let_20_[1]
      local file_hl = _let_20_[2]
      local _let_21_ = project_flag_token("binary", not not session["effective-include-binary"])
      local binary_token = _let_21_[1]
      local binary_hl = _let_21_[2]
      local _let_22_ = project_flag_token("hex", not not session["effective-include-hex"])
      local hex_token = _let_22_[1]
      local hex_hl = _let_22_[2]
      local _let_23_ = project_flag_token("prefilter", not not session["prefilter-mode"])
      local prefilter_token = _let_23_[1]
      local prefilter_hl = _let_23_[2]
      local _let_24_ = project_flag_token("lazy", not not session["lazy-mode"])
      local lazy_token = _let_24_[1]
      local lazy_hl = _let_24_[2]
      local pieces = {{text = "flags: ", hl = "MetaPromptText"}, {text = hidden_token, hl = hidden_hl}, {text = " ", hl = "MetaPromptText"}, {text = ignored_token, hl = ignored_hl}, {text = " ", hl = "MetaPromptText"}, {text = deps_token, hl = deps_hl}, {text = " ", hl = "MetaPromptText"}, {text = file_token, hl = file_hl}, {text = " ", hl = "MetaPromptText"}, {text = binary_token, hl = binary_hl}, {text = " ", hl = "MetaPromptText"}, {text = hex_token, hl = hex_hl}, {text = " ", hl = "MetaPromptText"}, {text = prefilter_token, hl = prefilter_hl}, {text = " ", hl = "MetaPromptText"}, {text = lazy_token, hl = lazy_hl}}
      local max_cols
      if (session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"])) then
        max_cols = vim.api.nvim_win_get_width(session["prompt-win"])
      else
        max_cols = 80
      end
      local virt_lines = wrap_flag_pieces(pieces, max_cols)
      session["prompt-footer-ns"] = ns
      vim.api.nvim_buf_clear_namespace(session["prompt-buf"], ns, 0, -1)
      if session["project-mode"] then
        return vim.api.nvim_buf_set_extmark(session["prompt-buf"], ns, row, 0, {virt_lines = virt_lines, hl_mode = "combine", virt_lines_above = false})
      else
        return nil
      end
    else
      return nil
    end
  end
  local function refresh_prompt_highlights_21(session)
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
              local val_110_auto = control_token_hl(token)
              if val_110_auto then
                local flag_hl = val_110_auto
                vim.api.nvim_buf_add_highlight(session["prompt-buf"], ns, flag_hl, r, s0, e0)
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
  local function maybe_expand_history_shorthand_21(router, session)
    if session["_expanding-history-shorthand"] then
      return false
    else
      if (session and session["prompt-buf"] and session["prompt-win"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and vim.api.nvim_win_is_valid(session["prompt-win"])) then
        local _let_36_ = vim.api.nvim_win_get_cursor(session["prompt-win"])
        local row = _let_36_[1]
        local col = _let_36_[2]
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
            local _41_
            if (trigger == "!^!") then
              _41_ = 3
            else
              _41_ = 2
            end
            start_col = (col - _41_)
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
      local function _48_()
        return router.accept(session["prompt-buf"])
      end
      return _48_
    elseif (action == "enter-edit-mode") then
      local function _49_()
        return router["enter-edit-mode"](session["prompt-buf"])
      end
      return _49_
    elseif (action == "cancel") then
      local function _50_()
        return router.cancel(session["prompt-buf"])
      end
      return _50_
    elseif (action == "move-selection") then
      local function _51_()
        return router["move-selection"](session["prompt-buf"], arg)
      end
      return _51_
    elseif (action == "history-or-move") then
      local function _52_()
        return router["history-or-move"](session["prompt-buf"], arg)
      end
      return _52_
    elseif (action == "prompt-home") then
      local function _53_()
        local function _54_()
          return router["prompt-home"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _54_)
      end
      return _53_
    elseif (action == "prompt-end") then
      local function _55_()
        local function _56_()
          return router["prompt-end"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _56_)
      end
      return _55_
    elseif (action == "prompt-kill-backward") then
      local function _57_()
        local function _58_()
          return router["prompt-kill-backward"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _58_)
      end
      return _57_
    elseif (action == "prompt-kill-forward") then
      local function _59_()
        local function _60_()
          return router["prompt-kill-forward"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _60_)
      end
      return _59_
    elseif (action == "prompt-yank") then
      local function _61_()
        local function _62_()
          return router["prompt-yank"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _62_)
      end
      return _61_
    elseif (action == "insert-last-prompt") then
      local function _63_()
        local function _64_()
          return router["insert-last-prompt"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _64_)
      end
      return _63_
    elseif (action == "insert-last-token") then
      local function _65_()
        local function _66_()
          return router["insert-last-token"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _66_)
      end
      return _65_
    elseif (action == "insert-last-tail") then
      local function _67_()
        local function _68_()
          return router["insert-last-tail"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _68_)
      end
      return _67_
    elseif (action == "toggle-prompt-results-focus") then
      local function _69_()
        local function _70_()
          return router["toggle-prompt-results-focus"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _70_)
      end
      return _69_
    elseif (action == "negate-current-token") then
      local function _71_()
        local function _72_()
          return router["negate-current-token"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _72_)
      end
      return _71_
    elseif (action == "history-searchback") then
      local function _73_()
        local function _74_()
          return router["open-history-searchback"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _74_)
      end
      return _73_
    elseif (action == "merge-history") then
      local function _75_()
        local function _76_()
          return router["merge-history-cache"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _76_)
      end
      return _75_
    elseif (action == "switch-mode") then
      local function _77_()
        return switch_mode(session, arg)
      end
      return _77_
    elseif (action == "toggle-scan-option") then
      local function _78_()
        return router["toggle-scan-option"](session["prompt-buf"], arg)
      end
      return _78_
    elseif (action == "scroll-main") then
      local function _79_()
        return router["scroll-main"](session["prompt-buf"], arg)
      end
      return _79_
    elseif (action == "toggle-project-mode") then
      local function _80_()
        return router["toggle-project-mode"](session["prompt-buf"])
      end
      return _80_
    elseif (action == "toggle-info-file-entry-view") then
      local function _81_()
        return router["toggle-info-file-entry-view"](session["prompt-buf"])
      end
      return _81_
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
      local function _86_()
        return router["accept-main"](session["prompt-buf"])
      end
      return _86_
    elseif (action == "enter-edit-mode") then
      local function _87_()
        return router["enter-edit-mode"](session["prompt-buf"])
      end
      return _87_
    elseif (action == "exclude-symbol-under-cursor") then
      local function _88_()
        return router["exclude-symbol-under-cursor"](session["prompt-buf"])
      end
      return _88_
    elseif (action == "insert-symbol-under-cursor") then
      local function _89_()
        return router["insert-symbol-under-cursor"](session["prompt-buf"])
      end
      return _89_
    elseif (action == "insert-symbol-under-cursor-newline") then
      local function _90_()
        return router["insert-symbol-under-cursor-newline"](session["prompt-buf"])
      end
      return _90_
    elseif (action == "toggle-prompt-results-focus") then
      local function _91_()
        return router["toggle-prompt-results-focus"](session["prompt-buf"])
      end
      return _91_
    elseif (action == "scroll-main") then
      local function _92_()
        return router["scroll-main"](session["prompt-buf"], arg)
      end
      return _92_
    elseif (action == "toggle-info-file-entry-view") then
      local function _93_()
        return router["toggle-info-file-entry-view"](session["prompt-buf"])
      end
      return _93_
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
    local function _96_(_, _0, changedtick, _1, _2, _3, _4, _5)
      local function _97_()
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
      return vim.schedule(_97_)
    end
    local function _100_()
      if session["prompt-buf"] then
        active_by_prompt[session["prompt-buf"]] = nil
        return nil
      else
        return nil
      end
    end
    vim.api.nvim_buf_attach(session["prompt-buf"], false, {on_lines = _96_, on_detach = _100_})
    local function _102_(_)
      if maybe_expand_history_shorthand_21(router, session) then
        return nil
      else
        refresh_prompt_highlights_21(session)
        return on_prompt_changed(session["prompt-buf"], false, vim.api.nvim_buf_get_changedtick(session["prompt-buf"]))
      end
    end
    vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI"}, {group = aug, buffer = session["prompt-buf"], callback = _102_})
    local function _104_(_)
      local function _105_()
        disable_cmp(session)
        apply_keymaps(router, session)
        return apply_emacs_insert_fallbacks(router, session)
      end
      return schedule_when_valid(session, _105_)
    end
    vim.api.nvim_create_autocmd("InsertEnter", {group = aug, buffer = session["prompt-buf"], callback = _104_})
    local function _106_(_)
      local function _107_()
        return pcall(session.meta.refresh_statusline)
      end
      return schedule_when_valid(session, _107_)
    end
    vim.api.nvim_create_autocmd({"BufEnter", "WinEnter", "FocusGained"}, {group = aug, buffer = session["prompt-buf"], callback = _106_})
    local function _108_(_)
      local function _109_()
        return pcall(session.meta.refresh_statusline)
      end
      return schedule_when_valid(session, _109_)
    end
    vim.api.nvim_create_autocmd({"ModeChanged", "InsertEnter", "InsertLeave"}, {group = aug, buffer = session["prompt-buf"], callback = _108_})
    local function _110_(_)
      local function _111_()
        return pcall(update_info_window, session)
      end
      return schedule_when_valid(session, _111_)
    end
    vim.api.nvim_create_autocmd({"VimResized", "WinResized"}, {group = aug, callback = _110_})
    local function _112_(_)
      local function _113_()
        return maybe_sync_from_main_21(session)
      end
      return schedule_when_valid(session, _113_)
    end
    vim.api.nvim_create_autocmd({"CursorMoved", "CursorMovedI"}, {group = aug, buffer = session.meta.buf.buffer, callback = _112_})
    local function _114_(_)
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
        local function _116_()
          if (session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
            pcall(router["sync-live-edits"], session["prompt-buf"])
            pcall(maybe_sync_from_main_21, session, true)
            pcall(update_info_window, session, true)
            return pcall(sign_mod["refresh-change-signs!"], session)
          else
            return nil
          end
        end
        return vim.schedule(_116_)
      else
        return nil
      end
    end
    vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI"}, {group = aug, buffer = session.meta.buf.buffer, callback = _114_})
    local function _119_(_)
      if (session.meta and session.meta.buf and vim.api.nvim_buf_is_valid(session.meta.buf.buffer)) then
        local bo = vim.bo[session.meta.buf.buffer]
        bo["buftype"] = "acwrite"
        bo["modifiable"] = true
        bo["readonly"] = false
        bo["bufhidden"] = "hide"
      else
      end
      if maybe_restore_hidden_ui_21 then
        local function _121_()
          if (session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
            return pcall(maybe_restore_hidden_ui_21, session)
          else
            return nil
          end
        end
        return vim.schedule(_121_)
      else
        return nil
      end
    end
    vim.api.nvim_create_autocmd("BufEnter", {group = aug, buffer = session.meta.buf.buffer, callback = _119_})
    apply_main_keymaps(router, session)
    local function _124_(_)
      return schedule_scroll_sync_21(session)
    end
    vim.api.nvim_create_autocmd("WinScrolled", {group = aug, callback = _124_})
    local function _125_(_)
      return router["write-results"](session["prompt-buf"])
    end
    vim.api.nvim_create_autocmd("BufWriteCmd", {group = aug, buffer = session.meta.buf.buffer, callback = _125_})
    local function _126_(_)
      local function _127_()
        return router["results-buffer-wiped"](session.meta.buf.buffer)
      end
      return vim.schedule(_127_)
    end
    vim.api.nvim_create_autocmd("BufWipeout", {group = aug, buffer = session.meta.buf.buffer, callback = _126_})
    disable_cmp(session)
    mark_prompt_buffer_21(session["prompt-buf"])
    refresh_prompt_highlights_21(session)
    apply_keymaps(router, session)
    return apply_emacs_insert_fallbacks(router, session)
  end
  return {["register!"] = register_21}
end
return M
