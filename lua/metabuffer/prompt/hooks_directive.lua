-- [nfnl] fnl/metabuffer/prompt/hooks_directive.fnl
local directive_mod = require("metabuffer.query.directive")
local M = {}
M.new = function(opts)
  local option_prefix = opts["option-prefix"]
  local highlight_prompt_like_line_21 = opts["highlight-prompt-like-line!"]
  local function current_prompt_token(session)
    if (session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"]) and session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"])) then
      local function _1_()
        local row_col = vim.api.nvim_win_get_cursor(0)
        local row = (row_col[1] or 1)
        local col1 = ((row_col[2] or 0) + 1)
        local line = (vim.api.nvim_buf_get_lines(session["prompt-buf"], (row - 1), row, false)[1] or "")
        local span = directive_mod["token-under-cursor"](line, col1)
        if span then
          return vim.tbl_extend("force", span, {row = row})
        else
          return nil
        end
      end
      return vim.api.nvim_win_call(session["prompt-win"], _1_)
    else
      return nil
    end
  end
  local function directive_help_token(tok)
    local token = (tok or "")
    local prefix = option_prefix()
    local colon = string.find(token, ":", 1, true)
    if colon then
      local stem = string.sub(token, 1, (colon - 1))
      if directive_mod["parse-token"](prefix, stem) then
        return stem
      else
        return token
      end
    else
      return token
    end
  end
  local function directive_help_spec_for_token(token)
    local needle = (token or "")
    local prefix = option_prefix()
    local matches = directive_mod["matching-catalog"](prefix, needle)
    local exact = nil
    for _, spec in ipairs(matches) do
      if (not exact and (((spec.display or "") == needle) or ((spec.literal or "") == needle) or ((spec.prefix or "") == needle))) then
        exact = spec
      else
      end
    end
    return (exact or matches[1])
  end
  local function hide_directive_help_21(session)
    if (session["directive-help-win"] and vim.api.nvim_win_is_valid(session["directive-help-win"])) then
      pcall(vim.api.nvim_win_close, session["directive-help-win"], true)
    else
    end
    session["directive-help-win"] = nil
    if (session["directive-help-buf"] and not vim.api.nvim_buf_is_valid(session["directive-help-buf"])) then
      session["directive-help-buf"] = nil
      return nil
    else
      return nil
    end
  end
  local function show_directive_help_21(session, spec, span)
    if (session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"]) and spec) then
      local buf0 = (session["directive-help-buf"] and vim.api.nvim_buf_is_valid(session["directive-help-buf"]) and session["directive-help-buf"])
      local buf = (buf0 or vim.api.nvim_create_buf(false, true))
      local _
      session["directive-help-buf"] = buf
      _ = nil
      local help = (spec.help or "")
      local display
      if ((spec["token-key"] or "") == "include-files") then
        display = (option_prefix() .. "file:{filter}")
      else
        display = (spec.display or "")
      end
      local lines = {display, help}
      local width = math.max(#display, #help, 12)
      local row1 = ((span and span.row) or 1)
      local col1 = ((span and span.start) or 1)
      local screenpos = vim.fn.screenpos(session["prompt-win"], row1, col1)
      local screen_row = math.max(1, (screenpos.row or 1))
      local screen_col = math.max(1, (screenpos.col or 1))
      local cfg = {relative = "editor", row = math.max(0, (screen_row - (#lines + 3))), col = math.max(0, (screen_col - 1)), width = width, height = #lines, style = "minimal", border = "rounded", noautocmd = true, focusable = false}
      do
        local bo = vim.bo[buf]
        bo["buftype"] = "nofile"
        bo["bufhidden"] = "wipe"
        bo["swapfile"] = false
        bo["modifiable"] = true
      end
      pcall(vim.api.nvim_buf_set_name, buf, "[Metabuffer Directive Help]")
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      do
        local ns = (session["directive-help-hl-ns"] or vim.api.nvim_create_namespace("metabuffer.directive-help"))
        session["directive-help-hl-ns"] = ns
        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
        highlight_prompt_like_line_21(buf, ns, 0, display, "MetaPromptText1")
        vim.api.nvim_buf_add_highlight(buf, ns, "Comment", 1, 0, -1)
      end
      do
        local bo = vim.bo[buf]
        bo["modifiable"] = false
      end
      if (session["directive-help-win"] and vim.api.nvim_win_is_valid(session["directive-help-win"])) then
        pcall(vim.api.nvim_win_set_buf, session["directive-help-win"], buf)
        return pcall(vim.api.nvim_win_set_config, session["directive-help-win"], cfg)
      else
        session["directive-help-win"] = vim.api.nvim_open_win(buf, false, cfg)
        return nil
      end
    else
      return nil
    end
  end
  local function maybe_show_directive_help_21(session, selected_item)
    if (not session["prompt-win"] or not vim.api.nvim_win_is_valid(session["prompt-win"]) or (vim.api.nvim_get_current_win() ~= session["prompt-win"])) then
      return hide_directive_help_21(session)
    else
      local span = current_prompt_token(session)
      if span then
        local selected_word = ((selected_item and selected_item.word) or (selected_item and selected_item.abbr) or "")
        local token = directive_help_token((span.token or ""))
        local prefix = option_prefix()
        local spec
        if ((selected_word ~= "") and vim.startswith(selected_word, prefix)) then
          spec = directive_help_spec_for_token(selected_word)
        else
          spec = (vim.startswith(token, prefix) and directive_help_spec_for_token(token))
        end
        if spec then
          return show_directive_help_21(session, spec, span)
        else
          return hide_directive_help_21(session)
        end
      else
        return hide_directive_help_21(session)
      end
    end
  end
  local function maybe_trigger_directive_complete_21(session)
    if (session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"]) and (vim.api.nvim_get_current_win() == session["prompt-win"]) and vim.startswith((vim.api.nvim_get_mode().mode or ""), "i")) then
      local span = current_prompt_token(session)
      if span then
        local token = (span.token or "")
        local prefix = option_prefix()
        local matches
        if vim.startswith(token, prefix) then
          matches = directive_mod["complete-items"](prefix, token)
        else
          matches = {}
        end
        local start = (span.start or 1)
        if ((#matches > 0) and (0 == vim.fn.pumvisible()) and (token ~= (session["directive-last-complete-token"] or ""))) then
          session["directive-last-complete-token"] = token
          return vim.fn.complete(start, matches)
        else
          return nil
        end
      else
        session["directive-last-complete-token"] = nil
        return nil
      end
    else
      return nil
    end
  end
  return {["current-prompt-token"] = current_prompt_token, ["hide-directive-help!"] = hide_directive_help_21, ["maybe-show-directive-help!"] = maybe_show_directive_help_21, ["maybe-trigger-directive-complete!"] = maybe_trigger_directive_complete_21}
end
return M
