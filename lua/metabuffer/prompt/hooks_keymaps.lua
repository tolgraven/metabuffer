-- [nfnl] fnl/metabuffer/prompt/hooks_keymaps.fnl
local M = {}
M.new = function(opts)
  local default_prompt_keymaps = opts["default-prompt-keymaps"]
  local default_main_keymaps = opts["default-main-keymaps"]
  local schedule_when_valid = opts["schedule-when-valid"]
  local switch_mode = opts["switch-mode"]
  local sign_mod = opts["sign-mod"]
  local function resolve_map_action(router, session, action, arg)
    local defer_router
    local function _1_(method)
      local function _2_()
        local function _3_()
          return method(router, session["prompt-buf"])
        end
        return schedule_when_valid(session, _3_)
      end
      return _2_
    end
    defer_router = _1_
    local dispatch
    local function _4_()
      return router.accept(session["prompt-buf"])
    end
    local function _5_()
      return router["enter-edit-mode"](session["prompt-buf"])
    end
    local function _6_()
      return router.cancel(session["prompt-buf"])
    end
    local function _7_()
      return router["move-selection"](session["prompt-buf"], arg)
    end
    local function _8_()
      return router["history-or-move"](session["prompt-buf"], arg)
    end
    local function _9_()
      return switch_mode(session, arg)
    end
    local function _10_()
      return router["toggle-scan-option"](session["prompt-buf"], arg)
    end
    local function _11_()
      return router["scroll-main"](session["prompt-buf"], arg)
    end
    local function _12_()
      return router["toggle-project-mode"](session["prompt-buf"])
    end
    local function _13_()
      return router["toggle-info-file-entry-view"](session["prompt-buf"])
    end
    local function _14_()
      return router["refresh-files"](session["prompt-buf"])
    end
    dispatch = {accept = _4_, ["enter-edit-mode"] = _5_, cancel = _6_, ["move-selection"] = _7_, ["history-or-move"] = _8_, ["prompt-home"] = defer_router(router["prompt-home"]), ["prompt-end"] = defer_router(router["prompt-end"]), ["prompt-kill-backward"] = defer_router(router["prompt-kill-backward"]), ["prompt-kill-forward"] = defer_router(router["prompt-kill-forward"]), ["prompt-yank"] = defer_router(router["prompt-yank"]), ["prompt-newline"] = defer_router(router["prompt-newline"]), ["insert-last-prompt"] = defer_router(router["insert-last-prompt"]), ["insert-last-token"] = defer_router(router["insert-last-token"]), ["insert-last-tail"] = defer_router(router["insert-last-tail"]), ["toggle-prompt-results-focus"] = defer_router(router["toggle-prompt-results-focus"]), ["negate-current-token"] = defer_router(router["negate-current-token"]), ["history-searchback"] = defer_router(router["open-history-searchback"]), ["merge-history"] = defer_router(router["merge-history-cache"]), ["switch-mode"] = _9_, ["toggle-scan-option"] = _10_, ["scroll-main"] = _11_, ["toggle-project-mode"] = _12_, ["toggle-info-file-entry-view"] = _13_, ["refresh-files"] = _14_}
    return dispatch[action]
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
    local dispatch
    local function _18_()
      return router.cancel(session["prompt-buf"])
    end
    local function _19_()
      return router["accept-main"](session["prompt-buf"])
    end
    local function _20_()
      return router["enter-edit-mode"](session["prompt-buf"])
    end
    local function _21_()
      return router["exclude-symbol-under-cursor"](session["prompt-buf"])
    end
    local function _22_()
      return router["insert-symbol-under-cursor"](session["prompt-buf"])
    end
    local function _23_()
      return router["insert-symbol-under-cursor-newline"](session["prompt-buf"])
    end
    local function _24_()
      return router["toggle-prompt-results-focus"](session["prompt-buf"])
    end
    local function _25_()
      return router["scroll-main"](session["prompt-buf"], arg)
    end
    local function _26_()
      return router["toggle-info-file-entry-view"](session["prompt-buf"])
    end
    local function _27_()
      return router["refresh-files"](session["prompt-buf"])
    end
    dispatch = {cancel = _18_, ["accept-main"] = _19_, ["enter-edit-mode"] = _20_, ["exclude-symbol-under-cursor"] = _21_, ["insert-symbol-under-cursor"] = _22_, ["insert-symbol-under-cursor-newline"] = _23_, ["toggle-prompt-results-focus"] = _24_, ["scroll-main"] = _25_, ["toggle-info-file-entry-view"] = _26_, ["refresh-files"] = _27_}
    return dispatch[action]
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
    local function _31_()
      set_pending_structural_edit_21(session, "after")
      return feed_results_normal_key_21("o")
    end
    vim.keymap.set("n", "o", _31_, opts0)
    local function _32_()
      set_pending_structural_edit_21(session, "before")
      return feed_results_normal_key_21("O")
    end
    vim.keymap.set("n", "O", _32_, opts0)
    local function _33_()
      set_pending_structural_edit_21(session, "after")
      return feed_results_normal_key_21("p")
    end
    vim.keymap.set("n", "p", _33_, opts0)
    local function _34_()
      set_pending_structural_edit_21(session, "before")
      return feed_results_normal_key_21("P")
    end
    return vim.keymap.set("n", "P", _34_, opts0)
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
