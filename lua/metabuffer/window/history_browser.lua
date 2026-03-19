-- [nfnl] fnl/metabuffer/window/history_browser.fnl
local M = {}
local util = require("metabuffer.util")
local function ensure_window_21(floating_window_mod, session)
  if not (session["history-browser-win"] and vim.api.nvim_win_is_valid(session["history-browser-win"])) then
    local buf = vim.api.nvim_create_buf(false, true)
    local p_row_col = vim.api.nvim_win_get_position(session["prompt-win"])
    local p_row = p_row_col[1]
    local p_col = p_row_col[2]
    local p_width = vim.api.nvim_win_get_width(session["prompt-win"])
    local p_height = vim.api.nvim_win_get_height(session["prompt-win"])
    local width = math.max(42, math.min(120, p_width))
    local height = math.max(4, math.min(12, p_height))
    local cfg
    if session["window-local-layout"] then
      cfg = {relative = "win", win = session["prompt-win"], anchor = "SW", row = 0, col = 0, width = width, height = height}
    else
      local row = math.max(0, (p_row - height))
      local col = p_col
      cfg = {relative = "editor", anchor = "NE", row = row, col = col, width = width, height = height}
    end
    local win = floating_window_mod.new(vim, buf, cfg)
    util["disable-heavy-buffer-features!"](buf)
    session["history-browser-buf"] = buf
    session["history-browser-win"] = win.window
    local bo = vim.bo[buf]
    bo["buftype"] = "nofile"
    bo["bufhidden"] = "wipe"
    bo["swapfile"] = false
    bo["modifiable"] = false
    bo["filetype"] = "metabuffer"
    return nil
  else
    return nil
  end
end
local function close_window_21(session)
  if (session["history-browser-win"] and vim.api.nvim_win_is_valid(session["history-browser-win"])) then
    pcall(vim.api.nvim_win_close, session["history-browser-win"], true)
  else
  end
  session["history-browser-win"] = nil
  session["history-browser-buf"] = nil
  session["history-browser-active"] = false
  session["history-browser-items"] = {}
  session["history-browser-index"] = 1
  session["history-browser-mode"] = nil
  return nil
end
local function clamp_index(idx, n)
  if (n <= 0) then
    return 1
  else
    return math.max(1, math.min(idx, n))
  end
end
local function render_21(session)
  if (session["history-browser-buf"] and vim.api.nvim_buf_is_valid(session["history-browser-buf"])) then
    local items = (session["history-browser-items"] or {})
    local lines = {}
    local hl = {}
    local filter = (session["history-browser-filter"] or "")
    local idx = clamp_index((session["history-browser-index"] or 1), #items)
    session["history-browser-index"] = idx
    if (#items == 0) then
      table.insert(lines, "")
    else
      for i, item in ipairs(items) do
        local label = (item.label or "")
        local mark
        if (i == idx) then
          mark = "> "
        else
          mark = "  "
        end
        table.insert(lines, (mark .. label))
        if ((filter ~= "") and not not string.find(string.lower(label), string.lower(filter), 1, true)) then
          local pos = 1
          while (pos <= #label) do
            local s,e = string.find(string.lower(label), string.lower(filter), pos, true)
            if (s and e) then
              table.insert(hl, {(i - 1), (2 + (s - 1)), (2 + e)})
              pos = (e + 1)
            else
              pos = (#label + 1)
            end
          end
        else
        end
      end
    end
    do
      local bo = vim.bo[session["history-browser-buf"]]
      bo["modifiable"] = true
    end
    vim.api.nvim_buf_set_lines(session["history-browser-buf"], 0, -1, false, lines)
    do
      local bo = vim.bo[session["history-browser-buf"]]
      bo["modifiable"] = false
    end
    do
      local ns = (session["history-browser-hl-ns"] or vim.api.nvim_create_namespace("metabuffer.history-browser"))
      session["history-browser-hl-ns"] = ns
      vim.api.nvim_buf_clear_namespace(session["history-browser-buf"], ns, 0, -1)
      for _, item in ipairs(hl) do
        vim.api.nvim_buf_add_highlight(session["history-browser-buf"], ns, "MetaSearchHitAll", item[1], item[2], item[3])
      end
    end
    if (session["history-browser-win"] and vim.api.nvim_win_is_valid(session["history-browser-win"])) then
      return pcall(vim.api.nvim_win_set_cursor, session["history-browser-win"], {idx, 0})
    else
      return nil
    end
  else
    return nil
  end
end
M.new = function(opts)
  local floating_window_mod = opts["floating-window-mod"]
  local function open_21(session, mode)
    ensure_window_21(floating_window_mod, session)
    session["history-browser-active"] = true
    session["history-browser-mode"] = mode
    session["history-browser-items"] = {}
    session["history-browser-index"] = 1
    return render_21(session)
  end
  local function refresh_21(session, items)
    if session["history-browser-active"] then
      session["history-browser-items"] = (items or {})
      session["history-browser-index"] = clamp_index((session["history-browser-index"] or 1), #(session["history-browser-items"] or {}))
      return render_21(session)
    else
      return nil
    end
  end
  local function move_21(session, delta)
    if session["history-browser-active"] then
      local n = #(session["history-browser-items"] or {})
      session["history-browser-index"] = clamp_index(((session["history-browser-index"] or 1) + delta), n)
      return render_21(session)
    else
      return nil
    end
  end
  local function selected_21(session)
    if (session["history-browser-active"] and (#(session["history-browser-items"] or {}) > 0)) then
      return session["history-browser-items"][(session["history-browser-index"] or 1)]
    else
      return nil
    end
  end
  return {["open!"] = open_21, ["refresh!"] = refresh_21, ["move!"] = move_21, ["selected!"] = selected_21, ["close!"] = close_window_21}
end
return M
