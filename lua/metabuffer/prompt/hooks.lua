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
      return nil
    else
      return nil
    end
  end
  local function maybe_expand_history_shorthand_21(router, session)
    if session["_expanding-history-shorthand"] then
      return false
    else
      if (session and session["prompt-buf"] and session["prompt-win"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and vim.api.nvim_win_is_valid(session["prompt-win"])) then
        local _let_11_ = vim.api.nvim_win_get_cursor(session["prompt-win"])
        local row = _let_11_[1]
        local col = _let_11_[2]
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
            local _16_
            if (trigger == "!^!") then
              _16_ = 3
            else
              _16_ = 2
            end
            start_col = (col - _16_)
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
      local function _23_()
        return router.accept(session["prompt-buf"])
      end
      return _23_
    elseif (action == "enter-edit-mode") then
      local function _24_()
        return router["enter-edit-mode"](session["prompt-buf"])
      end
      return _24_
    elseif (action == "cancel") then
      local function _25_()
        return router.cancel(session["prompt-buf"])
      end
      return _25_
    elseif (action == "move-selection") then
      local function _26_()
        return router["move-selection"](session["prompt-buf"], arg)
      end
      return _26_
    elseif (action == "history-or-move") then
      local function _27_()
        return router["history-or-move"](session["prompt-buf"], arg)
      end
      return _27_
    elseif (action == "prompt-home") then
      local function _28_()
        local function _29_()
          return router["prompt-home"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _29_)
      end
      return _28_
    elseif (action == "prompt-end") then
      local function _30_()
        local function _31_()
          return router["prompt-end"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _31_)
      end
      return _30_
    elseif (action == "prompt-kill-backward") then
      local function _32_()
        local function _33_()
          return router["prompt-kill-backward"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _33_)
      end
      return _32_
    elseif (action == "prompt-kill-forward") then
      local function _34_()
        local function _35_()
          return router["prompt-kill-forward"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _35_)
      end
      return _34_
    elseif (action == "prompt-yank") then
      local function _36_()
        local function _37_()
          return router["prompt-yank"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _37_)
      end
      return _36_
    elseif (action == "insert-last-prompt") then
      local function _38_()
        local function _39_()
          return router["insert-last-prompt"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _39_)
      end
      return _38_
    elseif (action == "insert-last-token") then
      local function _40_()
        local function _41_()
          return router["insert-last-token"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _41_)
      end
      return _40_
    elseif (action == "insert-last-tail") then
      local function _42_()
        local function _43_()
          return router["insert-last-tail"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _43_)
      end
      return _42_
    elseif (action == "negate-current-token") then
      local function _44_()
        local function _45_()
          return router["negate-current-token"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _45_)
      end
      return _44_
    elseif (action == "history-searchback") then
      local function _46_()
        local function _47_()
          return router["open-history-searchback"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _47_)
      end
      return _46_
    elseif (action == "merge-history") then
      local function _48_()
        local function _49_()
          return router["merge-history-cache"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _49_)
      end
      return _48_
    elseif (action == "switch-mode") then
      local function _50_()
        return switch_mode(session, arg)
      end
      return _50_
    elseif (action == "toggle-scan-option") then
      local function _51_()
        return router["toggle-scan-option"](session["prompt-buf"], arg)
      end
      return _51_
    elseif (action == "scroll-main") then
      local function _52_()
        return router["scroll-main"](session["prompt-buf"], arg)
      end
      return _52_
    elseif (action == "toggle-project-mode") then
      local function _53_()
        return router["toggle-project-mode"](session["prompt-buf"])
      end
      return _53_
    elseif (action == "toggle-info-file-entry-view") then
      local function _54_()
        return router["toggle-info-file-entry-view"](session["prompt-buf"])
      end
      return _54_
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
      local function _59_()
        return router["accept-main"](session["prompt-buf"])
      end
      return _59_
    elseif (action == "enter-edit-mode") then
      local function _60_()
        return router["enter-edit-mode"](session["prompt-buf"])
      end
      return _60_
    elseif (action == "exclude-symbol-under-cursor") then
      local function _61_()
        return router["exclude-symbol-under-cursor"](session["prompt-buf"])
      end
      return _61_
    elseif (action == "insert-symbol-under-cursor") then
      local function _62_()
        return router["insert-symbol-under-cursor"](session["prompt-buf"])
      end
      return _62_
    elseif (action == "scroll-main") then
      local function _63_()
        return router["scroll-main"](session["prompt-buf"], arg)
      end
      return _63_
    elseif (action == "toggle-info-file-entry-view") then
      local function _64_()
        return router["toggle-info-file-entry-view"](session["prompt-buf"])
      end
      return _64_
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
    local function _67_(_, _0, changedtick, _1, _2, _3, _4, _5)
      local function _68_()
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
      return vim.schedule(_68_)
    end
    local function _71_()
      if session["prompt-buf"] then
        active_by_prompt[session["prompt-buf"]] = nil
        return nil
      else
        return nil
      end
    end
    vim.api.nvim_buf_attach(session["prompt-buf"], false, {on_lines = _67_, on_detach = _71_})
    local function _73_(_)
      if maybe_expand_history_shorthand_21(router, session) then
        return nil
      else
        refresh_prompt_highlights_21(session)
        return on_prompt_changed(session["prompt-buf"], false, vim.api.nvim_buf_get_changedtick(session["prompt-buf"]))
      end
    end
    vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI"}, {group = aug, buffer = session["prompt-buf"], callback = _73_})
    local function _75_(_)
      local function _76_()
        disable_cmp(session)
        apply_keymaps(router, session)
        return apply_emacs_insert_fallbacks(router, session)
      end
      return schedule_when_valid(session, _76_)
    end
    vim.api.nvim_create_autocmd("InsertEnter", {group = aug, buffer = session["prompt-buf"], callback = _75_})
    local function _77_(_)
      local function _78_()
        return pcall(session.meta.refresh_statusline)
      end
      return schedule_when_valid(session, _78_)
    end
    vim.api.nvim_create_autocmd({"BufEnter", "WinEnter", "FocusGained"}, {group = aug, buffer = session["prompt-buf"], callback = _77_})
    local function _79_(_)
      local function _80_()
        return pcall(session.meta.refresh_statusline)
      end
      return schedule_when_valid(session, _80_)
    end
    vim.api.nvim_create_autocmd({"ModeChanged", "InsertEnter", "InsertLeave"}, {group = aug, buffer = session["prompt-buf"], callback = _79_})
    local function _81_(_)
      local function _82_()
        return pcall(update_info_window, session)
      end
      return schedule_when_valid(session, _82_)
    end
    vim.api.nvim_create_autocmd({"VimResized", "WinResized"}, {group = aug, callback = _81_})
    local function _83_(_)
      local function _84_()
        return maybe_sync_from_main_21(session)
      end
      return schedule_when_valid(session, _84_)
    end
    vim.api.nvim_create_autocmd({"CursorMoved", "CursorMovedI"}, {group = aug, buffer = session.meta.buf.buffer, callback = _83_})
    local function _85_(_)
      if (session.meta and session.meta.buf and vim.api.nvim_buf_is_valid(session.meta.buf.buffer)) then
        local bo = vim.bo[session.meta.buf.buffer]
        bo["buftype"] = "acwrite"
        bo["modifiable"] = true
        bo["readonly"] = false
        bo["bufhidden"] = "hide"
      else
      end
      if maybe_restore_hidden_ui_21 then
        local function _87_()
          if (session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
            return pcall(maybe_restore_hidden_ui_21, session)
          else
            return nil
          end
        end
        return vim.schedule(_87_)
      else
        return nil
      end
    end
    vim.api.nvim_create_autocmd("BufEnter", {group = aug, buffer = session.meta.buf.buffer, callback = _85_})
    apply_main_keymaps(router, session)
    local function _90_(_)
      return schedule_scroll_sync_21(session)
    end
    vim.api.nvim_create_autocmd("WinScrolled", {group = aug, callback = _90_})
    local function _91_(_)
      return router["write-results"](session["prompt-buf"])
    end
    vim.api.nvim_create_autocmd("BufWriteCmd", {group = aug, buffer = session.meta.buf.buffer, callback = _91_})
    disable_cmp(session)
    mark_prompt_buffer_21(session["prompt-buf"])
    refresh_prompt_highlights_21(session)
    apply_keymaps(router, session)
    return apply_emacs_insert_fallbacks(router, session)
  end
  return {["register!"] = register_21}
end
return M
