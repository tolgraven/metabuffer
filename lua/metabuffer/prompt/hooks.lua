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
  local function covered_by_new_window_3f(session, win)
    local target = window_rect(win)
    local meta_win = (session.meta and session.meta.win and session.meta.win.window)
    local prompt_win = session["prompt-win"]
    local info_win = session["info-win"]
    local preview_win = session["preview-win"]
    local history_win = session["history-browser-win"]
    return (target and not (win == meta_win) and not (win == prompt_win) and (rect_overlap_3f(target, window_rect(info_win)) or rect_overlap_3f(target, window_rect(preview_win)) or rect_overlap_3f(target, window_rect(history_win)) or (session["prompt-floating?"] and rect_overlap_3f(target, window_rect(prompt_win)))))
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
        local _12_
        if off_3f then
          _12_ = "MetaPromptFlagHashOff"
        else
          _12_ = "MetaPromptFlagHashOn"
        end
        local _14_
        if functional_3f then
          if off_3f then
            _14_ = "MetaPromptFlagTextFuncOff"
          else
            _14_ = "MetaPromptFlagTextFuncOn"
          end
        else
          if off_3f then
            _14_ = "MetaPromptFlagTextOff"
          else
            _14_ = "MetaPromptFlagTextOn"
          end
        end
        return {["hash-hl"] = _12_, ["text-hl"] = _14_}
      else
        return nil
      end
    end
  end
  local function project_flag_token(name, on_3f)
    local _20_
    if on_3f then
      _20_ = ("#" .. name)
    else
      _20_ = ("#-" .. name)
    end
    local function _22_()
      if on_3f then
        return ("#" .. name)
      else
        return ("#-" .. name)
      end
    end
    return {_20_, control_token_style(_22_())}
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
      local chunks = (p.chunks or {{(p.text or ""), (p.hl or "MetaPromptText")}})
      local w
      local or_24_ = p.width
      if not or_24_ then
        local sum0 = 0
        local sum = sum0
        for _0, c in ipairs(chunks) do
          sum = (sum + vim.fn.strdisplaywidth((c[1] or "")))
        end
        or_24_ = sum
      end
      w = or_24_
      if ((line_w > 0) and ((line_w + w) > width)) then
        flush_line_21()
      else
      end
      for _0, c in ipairs(chunks) do
        table.insert(current, {(c[1] or ""), (c[2] or "MetaPromptText")})
      end
      line_w = (line_w + w)
    end
    flush_line_21()
    if (#lines > 0) then
      return lines
    else
      return {{{"", "MetaPromptText"}}}
    end
  end
  local function line_display_rows(line, width)
    local w = math.max(1, (width or 1))
    local n = vim.fn.strdisplaywidth((line or ""))
    return math.max(1, math.ceil((n / w)))
  end
  local function session_busy_3f(session)
    return (session and (session["prompt-update-pending"] or session["prompt-update-dirty"] or session["lazy-refresh-pending"] or session["lazy-refresh-dirty"] or session["project-bootstrap-pending"] or (session["project-mode"] and not session["project-bootstrapped"])))
  end
  local refresh_prompt_highlights_21 = nil
  local function loading_pieces(session)
    local word = "Working"
    local phase = (session["loading-anim-phase"] or 0)
    local pieces = {}
    local center = (1 + (phase % #word))
    for i = 1, #word do
      local dist = math.abs((i - center))
      local hl
      if (dist == 0) then
        hl = "MetaLoading6"
      elseif (dist == 1) then
        hl = "MetaLoading5"
      elseif (dist == 2) then
        hl = "MetaLoading4"
      elseif (dist == 3) then
        hl = "MetaLoading3"
      elseif (dist == 4) then
        hl = "MetaLoading2"
      else
        hl = "MetaLoading1"
      end
      table.insert(pieces, {string.sub(word, i, i), hl})
    end
    return {{chunks = pieces, width = #word}}
  end
  local function schedule_loading_indicator_21(session)
    if (session and not session["loading-anim-pending"] and session["prompt-buf"] and session_prompt_valid_3f(session) and session["loading-indicator?"] and session_busy_3f(session)) then
      session["loading-anim-pending"] = true
      local function _29_()
        session["loading-anim-pending"] = false
        if (session_prompt_valid_3f(session) and session_busy_3f(session) and animation_enabled_3f and animation_enabled_3f(session, "loading")) then
          session["loading-anim-phase"] = (1 + (session["loading-anim-phase"] or 0))
          return refresh_prompt_highlights_21(session)
        else
          return nil
        end
      end
      return vim.defer_fn(_29_, animation_duration_ms(session, "loading", 90))
    else
      return nil
    end
  end
  local function prompt_content_display_rows(session, width)
    local rows0 = 0
    local rows = rows0
    for _, line in ipairs((vim.api.nvim_buf_get_lines(session["prompt-buf"], 0, -1, false) or {})) do
      rows = (rows + line_display_rows(line, width))
    end
    return math.max(1, rows)
  end
  local function render_project_flags_footer_21(session)
    if (session["prompt-buf"] and session_prompt_valid_3f(session)) then
      local ns = (session["prompt-footer-ns"] or vim.api.nvim_create_namespace("metabuffer.prompt.footer"))
      local row = math.max(0, (vim.api.nvim_buf_line_count(session["prompt-buf"]) - 1))
      local last_line = (vim.api.nvim_buf_get_lines(session["prompt-buf"], row, (row + 1), false)[1] or "")
      local _let_32_ = project_flag_token("hidden", not not session["effective-include-hidden"])
      local hidden_token = _let_32_[1]
      local hidden_style = _let_32_[2]
      local _let_33_ = project_flag_token("ignored", not not session["effective-include-ignored"])
      local ignored_token = _let_33_[1]
      local ignored_style = _let_33_[2]
      local _let_34_ = project_flag_token("deps", not not session["effective-include-deps"])
      local deps_token = _let_34_[1]
      local deps_style = _let_34_[2]
      local _let_35_ = project_flag_token("file", not not session["effective-include-files"])
      local file_token = _let_35_[1]
      local file_style = _let_35_[2]
      local _let_36_ = project_flag_token("binary", not not session["effective-include-binary"])
      local binary_token = _let_36_[1]
      local binary_style = _let_36_[2]
      local _let_37_ = project_flag_token("hex", not not session["effective-include-hex"])
      local hex_token = _let_37_[1]
      local hex_style = _let_37_[2]
      local _let_38_ = project_flag_token("prefilter", not not session["prefilter-mode"])
      local prefilter_token = _let_38_[1]
      local prefilter_style = _let_38_[2]
      local _let_39_ = project_flag_token("lazy", not not session["lazy-mode"])
      local lazy_token = _let_39_[1]
      local lazy_style = _let_39_[2]
      local tokens = {{hidden_token, hidden_style}, {ignored_token, ignored_style}, {deps_token, deps_style}, {file_token, file_style}, {binary_token, binary_style}, {hex_token, hex_style}, {prefilter_token, prefilter_style}, {lazy_token, lazy_style}}
      local loading0
      if session_busy_3f(session) then
        loading0 = loading_pieces(session)
      else
        loading0 = {}
      end
      local pieces0 = {}
      local _
      for _0, p in ipairs(loading0) do
        table.insert(pieces0, p)
      end
      _ = nil
      local _0
      if (#loading0 > 0) then
        _0 = table.insert(pieces0, {chunks = {{"  ", "MetaPromptText"}}, width = 2})
      else
        _0 = nil
      end
      local _1
      for i, pair in ipairs(tokens) do
        local tok = (pair[1] or "")
        local style = pair[2]
        local sign_hl = ((style and style["hash-hl"]) or "MetaPromptText")
        local text_hl = ((style and style["text-hl"]) or "MetaPromptText")
        if (#tok > 0) then
          if vim.startswith(tok, "#-") then
            local suffix
            if (#tok > 2) then
              suffix = string.sub(tok, 3)
            else
              suffix = ""
            end
            local chunks = {{"-", sign_hl}, {suffix, text_hl}}
            local w = (1 + vim.fn.strdisplaywidth(suffix))
            table.insert(pieces0, {chunks = chunks, width = w})
          else
            if vim.startswith(tok, "#") then
              local suffix
              if (#tok > 1) then
                suffix = string.sub(tok, 2)
              else
                suffix = ""
              end
              local chunks = {{"+", sign_hl}, {suffix, text_hl}}
              local w = (1 + vim.fn.strdisplaywidth(suffix))
              table.insert(pieces0, {chunks = chunks, width = w})
            else
              table.insert(pieces0, {chunks = {{tok, text_hl}}, width = vim.fn.strdisplaywidth(tok)})
            end
          end
        else
        end
        if (i < #tokens) then
          table.insert(pieces0, {chunks = {{" ", "MetaPromptText"}}, width = 1})
        else
        end
      end
      _1 = nil
      local pieces = pieces0
      local max_cols
      if (session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"])) then
        max_cols = vim.api.nvim_win_get_width(session["prompt-win"])
      else
        max_cols = 80
      end
      local win_height
      if (session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"])) then
        win_height = vim.api.nvim_win_get_height(session["prompt-win"])
      else
        win_height = 1
      end
      local last_line_rows = line_display_rows(last_line, max_cols)
      local anchor_row = math.max(0, (row - math.max(0, (last_line_rows - 1))))
      local flag_lines = wrap_flag_pieces(pieces, max_cols)
      local content_rows = prompt_content_display_rows(session, max_cols)
      local spacer_count = math.max(0, (win_height - content_rows - #flag_lines))
      local virt_lines0 = {}
      local _2
      for _3, _i in ipairs(vim.fn.range(1, spacer_count)) do
        table.insert(virt_lines0, {{"", "MetaPromptText"}})
      end
      _2 = nil
      local _3
      for _4, vl in ipairs(flag_lines) do
        table.insert(virt_lines0, vl)
      end
      _3 = nil
      local virt_lines = virt_lines0
      session["prompt-footer-ns"] = ns
      vim.api.nvim_buf_clear_namespace(session["prompt-buf"], ns, 0, -1)
      if session["project-mode"] then
        vim.api.nvim_buf_set_extmark(session["prompt-buf"], ns, anchor_row, 0, {virt_lines = virt_lines, hl_mode = "combine", virt_lines_above = false})
      else
      end
      return schedule_loading_indicator_21(session)
    else
      return nil
    end
  end
  local function _52_(session)
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
  refresh_prompt_highlights_21 = _52_
  local function maybe_expand_history_shorthand_21(router, session)
    if session["_expanding-history-shorthand"] then
      return false
    else
      if (session and session["prompt-buf"] and session["prompt-win"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and vim.api.nvim_win_is_valid(session["prompt-win"])) then
        local _let_62_ = vim.api.nvim_win_get_cursor(session["prompt-win"])
        local row = _let_62_[1]
        local col = _let_62_[2]
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
            local _67_
            if (trigger == "!^!") then
              _67_ = 3
            else
              _67_ = 2
            end
            start_col = (col - _67_)
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
      local function _74_()
        return router.accept(session["prompt-buf"])
      end
      return _74_
    elseif (action == "enter-edit-mode") then
      local function _75_()
        return router["enter-edit-mode"](session["prompt-buf"])
      end
      return _75_
    elseif (action == "cancel") then
      local function _76_()
        return router.cancel(session["prompt-buf"])
      end
      return _76_
    elseif (action == "move-selection") then
      local function _77_()
        return router["move-selection"](session["prompt-buf"], arg)
      end
      return _77_
    elseif (action == "history-or-move") then
      local function _78_()
        return router["history-or-move"](session["prompt-buf"], arg)
      end
      return _78_
    elseif (action == "prompt-home") then
      local function _79_()
        local function _80_()
          return router["prompt-home"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _80_)
      end
      return _79_
    elseif (action == "prompt-end") then
      local function _81_()
        local function _82_()
          return router["prompt-end"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _82_)
      end
      return _81_
    elseif (action == "prompt-kill-backward") then
      local function _83_()
        local function _84_()
          return router["prompt-kill-backward"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _84_)
      end
      return _83_
    elseif (action == "prompt-kill-forward") then
      local function _85_()
        local function _86_()
          return router["prompt-kill-forward"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _86_)
      end
      return _85_
    elseif (action == "prompt-yank") then
      local function _87_()
        local function _88_()
          return router["prompt-yank"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _88_)
      end
      return _87_
    elseif (action == "insert-last-prompt") then
      local function _89_()
        local function _90_()
          return router["insert-last-prompt"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _90_)
      end
      return _89_
    elseif (action == "insert-last-token") then
      local function _91_()
        local function _92_()
          return router["insert-last-token"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _92_)
      end
      return _91_
    elseif (action == "insert-last-tail") then
      local function _93_()
        local function _94_()
          return router["insert-last-tail"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _94_)
      end
      return _93_
    elseif (action == "toggle-prompt-results-focus") then
      local function _95_()
        local function _96_()
          return router["toggle-prompt-results-focus"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _96_)
      end
      return _95_
    elseif (action == "negate-current-token") then
      local function _97_()
        local function _98_()
          return router["negate-current-token"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _98_)
      end
      return _97_
    elseif (action == "history-searchback") then
      local function _99_()
        local function _100_()
          return router["open-history-searchback"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _100_)
      end
      return _99_
    elseif (action == "merge-history") then
      local function _101_()
        local function _102_()
          return router["merge-history-cache"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _102_)
      end
      return _101_
    elseif (action == "switch-mode") then
      local function _103_()
        return switch_mode(session, arg)
      end
      return _103_
    elseif (action == "toggle-scan-option") then
      local function _104_()
        return router["toggle-scan-option"](session["prompt-buf"], arg)
      end
      return _104_
    elseif (action == "scroll-main") then
      local function _105_()
        return router["scroll-main"](session["prompt-buf"], arg)
      end
      return _105_
    elseif (action == "toggle-project-mode") then
      local function _106_()
        return router["toggle-project-mode"](session["prompt-buf"])
      end
      return _106_
    elseif (action == "toggle-info-file-entry-view") then
      local function _107_()
        return router["toggle-info-file-entry-view"](session["prompt-buf"])
      end
      return _107_
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
      local function _112_()
        return router["accept-main"](session["prompt-buf"])
      end
      return _112_
    elseif (action == "enter-edit-mode") then
      local function _113_()
        return router["enter-edit-mode"](session["prompt-buf"])
      end
      return _113_
    elseif (action == "exclude-symbol-under-cursor") then
      local function _114_()
        return router["exclude-symbol-under-cursor"](session["prompt-buf"])
      end
      return _114_
    elseif (action == "insert-symbol-under-cursor") then
      local function _115_()
        return router["insert-symbol-under-cursor"](session["prompt-buf"])
      end
      return _115_
    elseif (action == "insert-symbol-under-cursor-newline") then
      local function _116_()
        return router["insert-symbol-under-cursor-newline"](session["prompt-buf"])
      end
      return _116_
    elseif (action == "toggle-prompt-results-focus") then
      local function _117_()
        return router["toggle-prompt-results-focus"](session["prompt-buf"])
      end
      return _117_
    elseif (action == "scroll-main") then
      local function _118_()
        return router["scroll-main"](session["prompt-buf"], arg)
      end
      return _118_
    elseif (action == "toggle-info-file-entry-view") then
      local function _119_()
        return router["toggle-info-file-entry-view"](session["prompt-buf"])
      end
      return _119_
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
    local function _122_(_, _0, changedtick, _1, _2, _3, _4, _5)
      local function _123_()
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
      return vim.schedule(_123_)
    end
    local function _126_()
      if session["prompt-buf"] then
        active_by_prompt[session["prompt-buf"]] = nil
        return nil
      else
        return nil
      end
    end
    vim.api.nvim_buf_attach(session["prompt-buf"], false, {on_lines = _122_, on_detach = _126_})
    local function _128_(_)
      if maybe_expand_history_shorthand_21(router, session) then
        return nil
      else
        refresh_prompt_highlights_21(session)
        return on_prompt_changed(session["prompt-buf"], false, vim.api.nvim_buf_get_changedtick(session["prompt-buf"]))
      end
    end
    vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI"}, {group = aug, buffer = session["prompt-buf"], callback = _128_})
    local function _130_(_)
      local function _131_()
        disable_cmp(session)
        apply_keymaps(router, session)
        return apply_emacs_insert_fallbacks(router, session)
      end
      return schedule_when_valid(session, _131_)
    end
    vim.api.nvim_create_autocmd("InsertEnter", {group = aug, buffer = session["prompt-buf"], callback = _130_})
    local function _132_(_)
      local function _133_()
        return pcall(session.meta.refresh_statusline)
      end
      return schedule_when_valid(session, _133_)
    end
    vim.api.nvim_create_autocmd({"BufEnter", "WinEnter", "FocusGained"}, {group = aug, buffer = session["prompt-buf"], callback = _132_})
    local function _134_(_)
      local function _135_()
        return pcall(session.meta.refresh_statusline)
      end
      return schedule_when_valid(session, _135_)
    end
    vim.api.nvim_create_autocmd({"ModeChanged", "InsertEnter", "InsertLeave"}, {group = aug, buffer = session["prompt-buf"], callback = _134_})
    local function _136_(_)
      local function _137_()
        if maybe_refresh_preview_statusline_21 then
          return pcall(maybe_refresh_preview_statusline_21, session)
        else
          return nil
        end
      end
      return schedule_when_valid(session, _137_)
    end
    vim.api.nvim_create_autocmd({"BufEnter", "WinEnter", "FocusGained"}, {group = aug, buffer = session["prompt-buf"], callback = _136_})
    local function _139_(_)
      local function _140_()
        if not session["prompt-animating?"] then
          pcall(refresh_prompt_highlights_21, session)
          return pcall(update_info_window, session)
        else
          return nil
        end
      end
      return schedule_when_valid(session, _140_)
    end
    vim.api.nvim_create_autocmd({"VimResized", "WinResized"}, {group = aug, callback = _139_})
    local function _142_(_)
      local function _143_()
        return maybe_sync_from_main_21(session)
      end
      return schedule_when_valid(session, _143_)
    end
    vim.api.nvim_create_autocmd({"CursorMoved", "CursorMovedI"}, {group = aug, buffer = session.meta.buf.buffer, callback = _142_})
    local function _144_(_)
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
        local function _146_()
          if (session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
            pcall(router["sync-live-edits"], session["prompt-buf"])
            pcall(maybe_sync_from_main_21, session, true)
            pcall(update_info_window, session, true)
            return pcall(sign_mod["refresh-change-signs!"], session)
          else
            return nil
          end
        end
        return vim.schedule(_146_)
      else
        return nil
      end
    end
    vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI"}, {group = aug, buffer = session.meta.buf.buffer, callback = _144_})
    local function _149_(_)
      if (session.meta and session.meta.buf and vim.api.nvim_buf_is_valid(session.meta.buf.buffer)) then
        local bo = vim.bo[session.meta.buf.buffer]
        bo["buftype"] = "acwrite"
        bo["modifiable"] = true
        bo["readonly"] = false
        bo["bufhidden"] = "hide"
      else
      end
      if maybe_restore_hidden_ui_21 then
        local function _151_()
          if (session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
            return pcall(maybe_restore_hidden_ui_21, session)
          else
            return nil
          end
        end
        return vim.schedule(_151_)
      else
        return nil
      end
    end
    vim.api.nvim_create_autocmd("BufEnter", {group = aug, buffer = session.meta.buf.buffer, callback = _149_})
    local function _154_(_)
      local function _155_()
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
      return vim.defer_fn(_155_, 20)
    end
    vim.api.nvim_create_autocmd("WinNew", {group = aug, callback = _154_})
    local function _158_(_)
      local function _159_()
        if (hide_visible_ui_21 and not session["ui-hidden"] and session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
          local buf = vim.api.nvim_get_current_buf()
          if transient_overlay_buffer_3f(buf) then
            return pcall(hide_visible_ui_21, session)
          else
            return nil
          end
        else
          return nil
        end
      end
      return vim.defer_fn(_159_, 20)
    end
    vim.api.nvim_create_autocmd("BufWinEnter", {group = aug, callback = _158_})
    local function _162_(_)
      local function _163_()
        if (session.meta and session.meta.win and session.meta.win["set-statusline"]) then
          return pcall(session.meta.win["set-statusline"], " ")
        else
          return nil
        end
      end
      return schedule_when_valid(session, _163_)
    end
    vim.api.nvim_create_autocmd({"BufEnter", "WinEnter", "FocusGained"}, {group = aug, buffer = session.meta.buf.buffer, callback = _162_})
    local function _165_(_)
      local function _166_()
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
      return vim.schedule(_166_)
    end
    vim.api.nvim_create_autocmd("BufLeave", {group = aug, buffer = session.meta.buf.buffer, callback = _165_})
    apply_main_keymaps(router, session)
    local function _171_(_)
      return schedule_scroll_sync_21(session)
    end
    vim.api.nvim_create_autocmd("WinScrolled", {group = aug, callback = _171_})
    local function _172_(_)
      return router["write-results"](session["prompt-buf"])
    end
    vim.api.nvim_create_autocmd("BufWriteCmd", {group = aug, buffer = session.meta.buf.buffer, callback = _172_})
    local function _173_(_)
      local function _174_()
        return router["results-buffer-wiped"](session.meta.buf.buffer)
      end
      return vim.schedule(_174_)
    end
    vim.api.nvim_create_autocmd("BufWipeout", {group = aug, buffer = session.meta.buf.buffer, callback = _173_})
    disable_cmp(session)
    mark_prompt_buffer_21(session["prompt-buf"])
    refresh_prompt_highlights_21(session)
    local function _175_()
      if (session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
        return pcall(refresh_prompt_highlights_21, session)
      else
        return nil
      end
    end
    vim.defer_fn(_175_, prompt_animation_delay_ms(session))
    apply_keymaps(router, session)
    return apply_emacs_insert_fallbacks(router, session)
  end
  return {["register!"] = register_21, ["refresh!"] = refresh_prompt_highlights_21}
end
return M
