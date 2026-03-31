-- [nfnl] fnl/metabuffer/buffer/prompt_view.fnl
local directive_mod = require("metabuffer.query.directive")
local query_mod = require("metabuffer.query")
local M = {}
M.new = function(opts)
  local option_prefix = opts["option-prefix"]
  local session_prompt_valid_3f = opts["session-prompt-valid?"]
  local schedule_loading_indicator_21 = opts["schedule-loading-indicator!"]
  local function control_token_style(tok)
    local token = (tok or "")
    local prefix = option_prefix()
    local escaped_prefix_3f = (vim.startswith(token, "\\") and vim.startswith(string.sub(token, 2), prefix))
    local parsed = (not escaped_prefix_3f and directive_mod["parse-token"](prefix, token))
    local off_3f = (parsed and (parsed.value == false))
    local provider_type = ((parsed and parsed["provider-type"]) or "")
    local functional_3f = ((provider_type == "transform") or (((parsed and parsed["token-key"]) or "") == "prefilter") or (((parsed and parsed["token-key"]) or "") == "lazy") or (((parsed and parsed["token-key"]) or "") == "escape"))
    local matches_3f = not (parsed == nil)
    if (escaped_prefix_3f or not matches_3f) then
      return nil
    else
      local _1_
      if off_3f then
        _1_ = "MetaPromptFlagHashOff"
      else
        _1_ = "MetaPromptFlagHashOn"
      end
      local _3_
      if functional_3f then
        if off_3f then
          _3_ = "MetaPromptFlagTextFuncOff"
        else
          _3_ = "MetaPromptFlagTextFuncOn"
        end
      else
        if off_3f then
          _3_ = "MetaPromptFlagTextOff"
        else
          _3_ = "MetaPromptFlagTextOn"
        end
      end
      return {["hash-hl"] = _1_, ["text-hl"] = _3_}
    end
  end
  local function prompt_line_primary_group(row)
    return ("MetaPromptText" .. tostring(((math.max(0, (row - 1)) % 6) + 1)))
  end
  local function prompt_tokens(txt)
    local or_8_ = query_mod["tokenize-line"]
    if not or_8_ then
      local function _9_(s)
        return vim.split(s, "%s+", {trimempty = true})
      end
      or_8_ = _9_
    end
    return or_8_(txt)
  end
  local function directive_arg_style(tok)
    local token = (tok or "")
    local prefix = option_prefix()
    local parsed = directive_mod["parse-token"](prefix, token)
    local await = (parsed and parsed.await)
    if (((await and await.kind) or "") == "query-source") then
      return {["text-hl"] = "MetaPromptLgrep"}
    else
      return nil
    end
  end
  local function inline_file_filter_style(tok)
    local token = (tok or "")
    local colon = string.find(token, ":", 1, true)
    local prefix = option_prefix()
    if colon then
      local flag_token = string.sub(token, 1, (colon - 1))
      local parsed = directive_mod["parse-token"](prefix, flag_token)
      local style = (parsed and control_token_style(flag_token))
      if (((parsed and parsed["token-key"]) or "") == "include-files") then
        return {["flag-style"] = style, ["arg-start"] = colon, ["arg-hl"] = "MetaPromptFileArg"}
      else
        return nil
      end
    else
      return nil
    end
  end
  local function highlight_like_line_21(buf, ns, row, txt, primary_hl)
    local tokens = prompt_tokens(txt)
    local pos = 1
    local await_style = nil
    for _, token in ipairs(tokens) do
      local s,e = string.find(txt, token, pos, true)
      if (s and e) then
        local s0 = (s - 1)
        local e0 = e
        vim.api.nvim_buf_add_highlight(buf, ns, primary_hl, row, s0, e0)
        if await_style then
          vim.api.nvim_buf_add_highlight(buf, ns, (await_style["text-hl"] or "MetaPromptLgrep"), row, s0, e0)
        else
        end
        do
          local val_111_auto = inline_file_filter_style(token)
          if val_111_auto then
            local inline_style = val_111_auto
            local flag_style = inline_style["flag-style"]
            local arg_start = (s0 + (inline_style["arg-start"] or 0))
            if flag_style then
              vim.api.nvim_buf_add_highlight(buf, ns, (flag_style["hash-hl"] or primary_hl), row, s0, (s0 + 1))
              if (arg_start > (s0 + 1)) then
                vim.api.nvim_buf_add_highlight(buf, ns, (flag_style["text-hl"] or primary_hl), row, (s0 + 1), arg_start)
              else
              end
            else
            end
            if (e0 > arg_start) then
              vim.api.nvim_buf_add_highlight(buf, ns, (inline_style["arg-hl"] or "MetaPromptFileArg"), row, arg_start, e0)
            else
            end
          else
            local val_110_auto = control_token_style(token)
            if val_110_auto then
              local style = val_110_auto
              vim.api.nvim_buf_add_highlight(buf, ns, (style["hash-hl"] or primary_hl), row, s0, (s0 + 1))
              if (e0 > (s0 + 1)) then
                vim.api.nvim_buf_add_highlight(buf, ns, (style["text-hl"] or primary_hl), row, (s0 + 1), e0)
              else
              end
            else
            end
          end
        end
        await_style = directive_arg_style(token)
        if ((#token > 1) and (string.sub(token, 1, 1) == "!")) then
          vim.api.nvim_buf_add_highlight(buf, ns, "MetaPromptNeg", row, s0, e0)
        else
        end
        do
          local core
          if ((#token > 1) and (string.sub(token, 1, 1) == "!")) then
            core = string.sub(token, 2)
          else
            core = token
          end
          if ((#core > 0) and (nil ~= string.find(core, "[\\%[%]%(%)%+%*%?%|]"))) then
            vim.api.nvim_buf_add_highlight(buf, ns, "MetaPromptRegex", row, s0, e0)
          else
          end
        end
        if ((#token > 0) and (string.sub(token, 1, 1) == "^")) then
          vim.api.nvim_buf_add_highlight(buf, ns, "MetaPromptAnchor", row, s0, (s0 + 1))
        else
        end
        if ((#token > 0) and (string.sub(token, #token) == "$")) then
          vim.api.nvim_buf_add_highlight(buf, ns, "MetaPromptAnchor", row, (e0 - 1), e0)
        else
        end
        pos = (e + 1)
      else
      end
    end
    return nil
  end
  local function render_project_flags_footer_21(session)
    if (session["prompt-buf"] and session_prompt_valid_3f(session)) then
      local ns = (session["prompt-footer-ns"] or vim.api.nvim_create_namespace("metabuffer.prompt.footer"))
      session["prompt-footer-ns"] = ns
      vim.api.nvim_buf_clear_namespace(session["prompt-buf"], ns, 0, -1)
      return schedule_loading_indicator_21(session)
    else
      return nil
    end
  end
  local function refresh_highlights_21(session)
    if (session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"])) then
      local ns = (session["prompt-hl-ns"] or vim.api.nvim_create_namespace("metabuffer.prompt"))
      local lines = vim.api.nvim_buf_get_lines(session["prompt-buf"], 0, -1, false)
      session["prompt-hl-ns"] = ns
      vim.api.nvim_buf_clear_namespace(session["prompt-buf"], ns, 0, -1)
      for row, line in ipairs((lines or {})) do
        local r = (row - 1)
        local txt = (line or "")
        local primary_hl = prompt_line_primary_group(row)
        highlight_like_line_21(session["prompt-buf"], ns, r, txt, primary_hl)
      end
      return render_project_flags_footer_21(session)
    else
      return nil
    end
  end
  return {["highlight-like-line!"] = highlight_like_line_21, ["refresh-highlights!"] = refresh_highlights_21}
end
return M
