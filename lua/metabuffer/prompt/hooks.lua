-- [nfnl] fnl/metabuffer/prompt/hooks.fnl
local M = {}
M.new = function(opts)
  local mark_prompt_buffer_21 = opts["mark-prompt-buffer!"]
  local default_prompt_keymaps = opts["default-prompt-keymaps"]
  local active_by_prompt = opts["active-by-prompt"]
  local on_prompt_changed = opts["on-prompt-changed"]
  local update_info_window = opts["update-info-window"]
  local maybe_sync_from_main_21 = opts["maybe-sync-from-main!"]
  local schedule_scroll_sync_21 = opts["schedule-scroll-sync!"]
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
            local escaped_neg_3f = vim.startswith(token, "\\!")
            local negated_3f = ((#token > 1) and (string.sub(token, 1, 1) == "!") and not escaped_neg_3f)
            local body
            if negated_3f then
              body = string.sub(token, 2)
            elseif escaped_neg_3f then
              body = string.sub(token, 2)
            else
              body = token
            end
            local body_start
            if (negated_3f or escaped_neg_3f) then
              body_start = (s0 + 1)
            else
              body_start = s0
            end
            vim.api.nvim_buf_add_highlight(session["prompt-buf"], ns, "MetaPromptText", r, s0, e0)
            if negated_3f then
              vim.api.nvim_buf_add_highlight(session["prompt-buf"], ns, "MetaPromptNeg", r, s0, e0)
            else
            end
            if ((#body > 0) and not string.match(body, "^[%?%*%+%|%.]$") and not not string.find(body, "[\\%[%]%(%)%+%*%?%|]")) then
              vim.api.nvim_buf_add_highlight(session["prompt-buf"], ns, "MetaPromptRegex", r, s0, e0)
            else
            end
            if ((#body > 0) and not vim.startswith(body, "\\^") and (string.sub(body, 1, 1) == "^")) then
              vim.api.nvim_buf_add_highlight(session["prompt-buf"], ns, "MetaPromptAnchor", r, body_start, (body_start + 1))
            else
            end
            if ((#body > 0) and not vim.endswith(body, "\\$") and (string.sub(body, #body) == "$")) then
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
  local function escaped_inline_shorthand_3f(left, token)
    local n = #(left or "")
    local m = #(token or "")
    local and_12_ = (n >= m)
    if and_12_ then
      local before = (n - m)
      and_12_ = ((before >= 1) and (string.sub(left, before, before) == "\\"))
    end
    return and_12_
  end
  local function maybe_expand_history_shorthand_21(router, session)
    if session["_expanding-history-shorthand"] then
      return false
    else
      if (session and session["prompt-buf"] and session["prompt-win"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and vim.api.nvim_win_is_valid(session["prompt-win"])) then
        local _let_14_ = vim.api.nvim_win_get_cursor(session["prompt-win"])
        local row = _let_14_[1]
        local col = _let_14_[2]
        local row0 = math.max(0, (row - 1))
        local line = (vim.api.nvim_buf_get_lines(session["prompt-buf"], row0, (row0 + 1), false)[1] or "")
        local left
        if (col > 0) then
          left = string.sub(line, 1, col)
        else
          left = ""
        end
        local saved_tag = string.match(left, "##([%w_%-]+)$")
        local saved_token = (saved_tag and ("##" .. saved_tag))
        local saved_replacement
        if saved_tag then
          saved_replacement = router["saved-prompt-entry"](saved_tag)
        else
          saved_replacement = ""
        end
        local trigger0
        if ((col >= 3) and vim.endswith(left, "!^!")) then
          trigger0 = "!^!"
        elseif ((col >= 2) and vim.endswith(left, "!!")) then
          trigger0 = "!!"
        elseif ((col >= 2) and vim.endswith(left, "!$")) then
          trigger0 = "!$"
        else
          trigger0 = nil
        end
        local trigger
        if (trigger0 and escaped_inline_shorthand_3f(left, trigger0)) then
          trigger = nil
        else
          trigger = trigger0
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
            local _20_
            if (trigger == "!^!") then
              _20_ = 3
            else
              _20_ = 2
            end
            start_col = (col - _20_)
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
          if (saved_tag and not escaped_inline_shorthand_3f(left, saved_token) and (type(saved_replacement) == "string") and (saved_replacement ~= "")) then
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
      local function _27_()
        return router.accept(session["prompt-buf"])
      end
      return _27_
    elseif (action == "cancel") then
      local function _28_()
        return router.cancel(session["prompt-buf"])
      end
      return _28_
    elseif (action == "move-selection") then
      local function _29_()
        return router["move-selection"](session["prompt-buf"], arg)
      end
      return _29_
    elseif (action == "history-or-move") then
      local function _30_()
        return router["history-or-move"](session["prompt-buf"], arg)
      end
      return _30_
    elseif (action == "prompt-home") then
      local function _31_()
        local function _32_()
          return router["prompt-home"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _32_)
      end
      return _31_
    elseif (action == "prompt-end") then
      local function _33_()
        local function _34_()
          return router["prompt-end"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _34_)
      end
      return _33_
    elseif (action == "prompt-kill-backward") then
      local function _35_()
        local function _36_()
          return router["prompt-kill-backward"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _36_)
      end
      return _35_
    elseif (action == "prompt-kill-forward") then
      local function _37_()
        local function _38_()
          return router["prompt-kill-forward"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _38_)
      end
      return _37_
    elseif (action == "prompt-yank") then
      local function _39_()
        local function _40_()
          return router["prompt-yank"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _40_)
      end
      return _39_
    elseif (action == "insert-last-prompt") then
      local function _41_()
        local function _42_()
          return router["insert-last-prompt"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _42_)
      end
      return _41_
    elseif (action == "insert-last-token") then
      local function _43_()
        local function _44_()
          return router["insert-last-token"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _44_)
      end
      return _43_
    elseif (action == "insert-last-tail") then
      local function _45_()
        local function _46_()
          return router["insert-last-tail"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _46_)
      end
      return _45_
    elseif (action == "negate-current-token") then
      local function _47_()
        local function _48_()
          return router["negate-current-token"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _48_)
      end
      return _47_
    elseif (action == "history-searchback") then
      local function _49_()
        local function _50_()
          return router["open-history-searchback"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _50_)
      end
      return _49_
    elseif (action == "merge-history") then
      local function _51_()
        local function _52_()
          return router["merge-history-cache"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _52_)
      end
      return _51_
    elseif (action == "switch-mode") then
      local function _53_()
        return switch_mode(session, arg)
      end
      return _53_
    elseif (action == "toggle-scan-option") then
      local function _54_()
        return router["toggle-scan-option"](session["prompt-buf"], arg)
      end
      return _54_
    elseif (action == "scroll-main") then
      local function _55_()
        return router["scroll-main"](session["prompt-buf"], arg)
      end
      return _55_
    elseif (action == "toggle-project-mode") then
      local function _56_()
        return router["toggle-project-mode"](session["prompt-buf"])
      end
      return _56_
    else
      return nil
    end
  end
  local function apply_keymaps(router, session)
    local base_opts = {buffer = session["prompt-buf"], silent = true, noremap = true, nowait = true}
    local rules
    if (type(vim.g.meta_prompt_keymaps) == "table") then
      rules = vim.g.meta_prompt_keymaps
    else
      rules = default_prompt_keymaps
    end
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
    local opts0 = {buffer = session["prompt-buf"], silent = true, noremap = true, nowait = true}
    local function _61_()
      local function _62_()
        return router["prompt-home"](session["prompt-buf"])
      end
      return schedule_when_valid(session, _62_)
    end
    vim.keymap.set("i", "<C-a>", _61_, opts0)
    local function _63_()
      local function _64_()
        return router["prompt-end"](session["prompt-buf"])
      end
      return schedule_when_valid(session, _64_)
    end
    vim.keymap.set("i", "<C-e>", _63_, opts0)
    local function _65_()
      local function _66_()
        return router["prompt-kill-backward"](session["prompt-buf"])
      end
      return schedule_when_valid(session, _66_)
    end
    vim.keymap.set("i", "<C-u>", _65_, opts0)
    local function _67_()
      local function _68_()
        return router["prompt-kill-forward"](session["prompt-buf"])
      end
      return schedule_when_valid(session, _68_)
    end
    vim.keymap.set("i", "<C-k>", _67_, opts0)
    local function _69_()
      local function _70_()
        return router["prompt-yank"](session["prompt-buf"])
      end
      return schedule_when_valid(session, _70_)
    end
    return vim.keymap.set("i", "<C-y>", _69_, opts0)
  end
  local function register_21(router, session)
    local aug = vim.api.nvim_create_augroup(("MetaPrompt" .. session["prompt-buf"]), {clear = true})
    session.augroup = aug
    local function _71_(_, _0, changedtick, _1, _2, _3, _4, _5)
      local function _72_()
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
      return vim.schedule(_72_)
    end
    local function _75_()
      if session["prompt-buf"] then
        active_by_prompt[session["prompt-buf"]] = nil
        return nil
      else
        return nil
      end
    end
    vim.api.nvim_buf_attach(session["prompt-buf"], false, {on_lines = _71_, on_detach = _75_})
    local function _77_(_)
      if maybe_expand_history_shorthand_21(router, session) then
        return nil
      else
        refresh_prompt_highlights_21(session)
        return on_prompt_changed(session["prompt-buf"], false, vim.api.nvim_buf_get_changedtick(session["prompt-buf"]))
      end
    end
    vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI"}, {group = aug, buffer = session["prompt-buf"], callback = _77_})
    local function _79_(_)
      local function _80_()
        disable_cmp(session)
        apply_keymaps(router, session)
        return apply_emacs_insert_fallbacks(router, session)
      end
      return schedule_when_valid(session, _80_)
    end
    vim.api.nvim_create_autocmd("InsertEnter", {group = aug, buffer = session["prompt-buf"], callback = _79_})
    local function _81_(_)
      local function _82_()
        return pcall(session.meta.refresh_statusline)
      end
      return schedule_when_valid(session, _82_)
    end
    vim.api.nvim_create_autocmd({"BufEnter", "WinEnter", "FocusGained"}, {group = aug, buffer = session["prompt-buf"], callback = _81_})
    local function _83_(_)
      local function _84_()
        return pcall(session.meta.refresh_statusline)
      end
      return schedule_when_valid(session, _84_)
    end
    vim.api.nvim_create_autocmd({"ModeChanged", "InsertEnter", "InsertLeave"}, {group = aug, buffer = session["prompt-buf"], callback = _83_})
    local function _85_(_)
      local function _86_()
        return pcall(update_info_window, session)
      end
      return schedule_when_valid(session, _86_)
    end
    vim.api.nvim_create_autocmd({"VimResized", "WinResized"}, {group = aug, callback = _85_})
    local function _87_(_)
      local function _88_()
        return maybe_sync_from_main_21(session)
      end
      return schedule_when_valid(session, _88_)
    end
    vim.api.nvim_create_autocmd({"CursorMoved", "CursorMovedI"}, {group = aug, buffer = session.meta.buf.buffer, callback = _87_})
    local function _89_()
      return router["exclude-symbol-under-cursor"](session["prompt-buf"])
    end
    vim.keymap.set("n", "!", _89_, {buffer = session.meta.buf.buffer, silent = true, noremap = true})
    local function _90_()
      local function _91_()
        return router["accept-main"](session["prompt-buf"])
      end
      return schedule_when_valid(session, _91_)
    end
    vim.keymap.set("n", "<CR>", _90_, {buffer = session.meta.buf.buffer, silent = true, noremap = true, nowait = true})
    local function _92_(_)
      return schedule_scroll_sync_21(session)
    end
    vim.api.nvim_create_autocmd("WinScrolled", {group = aug, callback = _92_})
    disable_cmp(session)
    mark_prompt_buffer_21(session["prompt-buf"])
    refresh_prompt_highlights_21(session)
    apply_keymaps(router, session)
    return apply_emacs_insert_fallbacks(router, session)
  end
  return {["register!"] = register_21}
end
return M
