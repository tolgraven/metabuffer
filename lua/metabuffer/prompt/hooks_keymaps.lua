-- [nfnl] fnl/metabuffer/prompt/hooks_keymaps.fnl
local M = {}
M.new = function(opts)
  local default_prompt_keymaps = opts["default-prompt-keymaps"]
  local default_main_keymaps = opts["default-main-keymaps"]
  local schedule_when_valid = opts["schedule-when-valid"]
  local switch_mode = opts["switch-mode"]
  local sign_mod = opts["sign-mod"]
  local function resolve_map_action(router, session, action, arg)
    if (action == "accept") then
      local function _1_()
        return router.accept(session["prompt-buf"])
      end
      return _1_
    elseif (action == "enter-edit-mode") then
      local function _2_()
        return router["enter-edit-mode"](session["prompt-buf"])
      end
      return _2_
    elseif (action == "cancel") then
      local function _3_()
        return router.cancel(session["prompt-buf"])
      end
      return _3_
    elseif (action == "move-selection") then
      local function _4_()
        return router["move-selection"](session["prompt-buf"], arg)
      end
      return _4_
    elseif (action == "history-or-move") then
      local function _5_()
        return router["history-or-move"](session["prompt-buf"], arg)
      end
      return _5_
    elseif (action == "prompt-home") then
      local function _6_()
        local function _7_()
          return router["prompt-home"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _7_)
      end
      return _6_
    elseif (action == "prompt-end") then
      local function _8_()
        local function _9_()
          return router["prompt-end"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _9_)
      end
      return _8_
    elseif (action == "prompt-kill-backward") then
      local function _10_()
        local function _11_()
          return router["prompt-kill-backward"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _11_)
      end
      return _10_
    elseif (action == "prompt-kill-forward") then
      local function _12_()
        local function _13_()
          return router["prompt-kill-forward"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _13_)
      end
      return _12_
    elseif (action == "prompt-yank") then
      local function _14_()
        local function _15_()
          return router["prompt-yank"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _15_)
      end
      return _14_
    elseif (action == "prompt-newline") then
      local function _16_()
        local function _17_()
          return router["prompt-newline"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _17_)
      end
      return _16_
    elseif (action == "insert-last-prompt") then
      local function _18_()
        local function _19_()
          return router["insert-last-prompt"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _19_)
      end
      return _18_
    elseif (action == "insert-last-token") then
      local function _20_()
        local function _21_()
          return router["insert-last-token"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _21_)
      end
      return _20_
    elseif (action == "insert-last-tail") then
      local function _22_()
        local function _23_()
          return router["insert-last-tail"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _23_)
      end
      return _22_
    elseif (action == "toggle-prompt-results-focus") then
      local function _24_()
        local function _25_()
          return router["toggle-prompt-results-focus"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _25_)
      end
      return _24_
    elseif (action == "negate-current-token") then
      local function _26_()
        local function _27_()
          return router["negate-current-token"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _27_)
      end
      return _26_
    elseif (action == "history-searchback") then
      local function _28_()
        local function _29_()
          return router["open-history-searchback"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _29_)
      end
      return _28_
    elseif (action == "merge-history") then
      local function _30_()
        local function _31_()
          return router["merge-history-cache"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _31_)
      end
      return _30_
    elseif (action == "switch-mode") then
      local function _32_()
        return switch_mode(session, arg)
      end
      return _32_
    elseif (action == "toggle-scan-option") then
      local function _33_()
        return router["toggle-scan-option"](session["prompt-buf"], arg)
      end
      return _33_
    elseif (action == "scroll-main") then
      local function _34_()
        return router["scroll-main"](session["prompt-buf"], arg)
      end
      return _34_
    elseif (action == "toggle-project-mode") then
      local function _35_()
        return router["toggle-project-mode"](session["prompt-buf"])
      end
      return _35_
    elseif (action == "toggle-info-file-entry-view") then
      local function _36_()
        return router["toggle-info-file-entry-view"](session["prompt-buf"])
      end
      return _36_
    elseif (action == "refresh-files") then
      local function _37_()
        return router["refresh-files"](session["prompt-buf"])
      end
      return _37_
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
    if (action == "cancel") then
      local function _42_()
        return router.cancel(session["prompt-buf"])
      end
      return _42_
    elseif (action == "accept-main") then
      local function _43_()
        return router["accept-main"](session["prompt-buf"])
      end
      return _43_
    elseif (action == "enter-edit-mode") then
      local function _44_()
        return router["enter-edit-mode"](session["prompt-buf"])
      end
      return _44_
    elseif (action == "exclude-symbol-under-cursor") then
      local function _45_()
        return router["exclude-symbol-under-cursor"](session["prompt-buf"])
      end
      return _45_
    elseif (action == "insert-symbol-under-cursor") then
      local function _46_()
        return router["insert-symbol-under-cursor"](session["prompt-buf"])
      end
      return _46_
    elseif (action == "insert-symbol-under-cursor-newline") then
      local function _47_()
        return router["insert-symbol-under-cursor-newline"](session["prompt-buf"])
      end
      return _47_
    elseif (action == "toggle-prompt-results-focus") then
      local function _48_()
        return router["toggle-prompt-results-focus"](session["prompt-buf"])
      end
      return _48_
    elseif (action == "scroll-main") then
      local function _49_()
        return router["scroll-main"](session["prompt-buf"], arg)
      end
      return _49_
    elseif (action == "toggle-info-file-entry-view") then
      local function _50_()
        return router["toggle-info-file-entry-view"](session["prompt-buf"])
      end
      return _50_
    elseif (action == "refresh-files") then
      local function _51_()
        return router["refresh-files"](session["prompt-buf"])
      end
      return _51_
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
  local function feed_results_normal_key_21(key)
    return vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), "n", false)
  end
  local function set_pending_structural_edit_21(session, side)
    if (session["results-edit-mode"] and session.meta and session.meta.win and vim.api.nvim_win_is_valid(session.meta.win.window)) then
      local row = vim.api.nvim_win_get_cursor(session.meta.win.window)[1]
      local idx = (session.meta.buf.indices or {})[row]
      local ref = (idx and (session.meta.buf["source-refs"] or {})[idx])
      if (ref and ref.path and ref.lnum) then
        session["pending-structural-edit"] = {path = ref.path, lnum = ref.lnum, side = side, kind = (ref.kind or "")}
        return nil
      else
        return nil
      end
    else
      return nil
    end
  end
  local function apply_results_edit_keymaps(session)
    local opts0 = {buffer = session.meta.buf.buffer, silent = true, noremap = true, nowait = true}
    local function _56_()
      set_pending_structural_edit_21(session, "after")
      return feed_results_normal_key_21("o")
    end
    vim.keymap.set("n", "o", _56_, opts0)
    local function _57_()
      set_pending_structural_edit_21(session, "before")
      return feed_results_normal_key_21("O")
    end
    vim.keymap.set("n", "O", _57_, opts0)
    local function _58_()
      set_pending_structural_edit_21(session, "after")
      return feed_results_normal_key_21("p")
    end
    vim.keymap.set("n", "p", _58_, opts0)
    local function _59_()
      set_pending_structural_edit_21(session, "before")
      return feed_results_normal_key_21("P")
    end
    return vim.keymap.set("n", "P", _59_, opts0)
  end
  local function begin_direct_results_edit_21(session)
    if (sign_mod and session.meta and session.meta.buf and vim.api.nvim_buf_is_valid(session.meta.buf.buffer)) then
      local buf = session.meta.buf.buffer
      local internal_3f
      do
        local ok,v = pcall(vim.api.nvim_buf_get_var, buf, "meta_internal_render")
        internal_3f = (ok and v)
      end
      local manual_3f
      do
        local ok,v = pcall(vim.api.nvim_buf_get_var, buf, "meta_manual_edit_active")
        manual_3f = (ok and v)
      end
      if not (internal_3f or manual_3f) then
        session["results-edit-mode"] = true
        pcall(sign_mod["capture-baseline!"], session)
        return pcall(vim.api.nvim_buf_set_var, buf, "meta_manual_edit_active", true)
      else
        return nil
      end
    else
      return nil
    end
  end
  return {["apply-keymaps"] = apply_keymaps, ["apply-emacs-insert-fallbacks"] = apply_emacs_insert_fallbacks, ["apply-main-keymaps"] = apply_main_keymaps, ["apply-results-edit-keymaps"] = apply_results_edit_keymaps, ["begin-direct-results-edit!"] = begin_direct_results_edit_21}
end
return M
