-- [nfnl] fnl/metabuffer/action.fnl
local M = {}
local function _sync_selected_from_cursor(meta)
  local max = #meta.buf.indices
  if (max <= 0) then
    meta.selected_index = 0
    return nil
  else
    local c = vim.api.nvim_win_get_cursor(0)
    local row = c[1]
    local clamped = math.max(1, math.min(row, max))
    if (row ~= clamped) then
      vim.api.nvim_win_set_cursor(0, {clamped, 0})
    else
    end
    meta.selected_index = (clamped - 1)
    return nil
  end
end
local function _change_line(meta, offset)
  local c = vim.api.nvim_win_get_cursor(0)
  local max = math.max(1, #meta.buf.indices)
  local row = math.max(1, math.min((c[1] + offset), max))
  vim.api.nvim_win_set_cursor(0, {row, c[2]})
  return _sync_selected_from_cursor(meta)
end
local function _select_next(meta, _)
  _change_line(meta, 1)
  return meta.refresh_statusline()
end
local function _select_prev(meta, _)
  _change_line(meta, -1)
  return meta.refresh_statusline()
end
local function _select_clicked(meta, _)
  do
    local mp = vim.fn.getmousepos()
    local winid = mp.winid
    local lnum = mp.line
    local curwin = vim.api.nvim_get_current_win()
    local max = math.max(1, #meta.buf.indices)
    if ((winid == curwin) and (lnum > 0)) then
      local row = math.max(1, math.min(lnum, max))
      vim.api.nvim_win_set_cursor(0, {row, 0})
    else
    end
  end
  _sync_selected_from_cursor(meta)
  return meta.refresh_statusline()
end
local function _ignore(meta, _)
  return meta.refresh_statusline()
end
local function _switch_matcher(meta, _)
  return meta.switch_mode("matcher")
end
local function _switch_case(meta, _)
  return meta.switch_mode("case")
end
local function _switch_highlight(meta, _)
  return meta.switch_mode("syntax")
end
local function _prompt_newline(_, _0)
  return vim.api.nvim_put({""}, "c", true, true)
end
local function _pause(_, _0)
  return 4
end
local default_action_rules = {{"meta:select_next_candidate", _select_next}, {"meta:select_previous_candidate", _select_prev}, {"meta:select_clicked_candidate", _select_clicked}, {"meta:ignore", _ignore}, {"meta:switch_matcher", _switch_matcher}, {"meta:switch_case", _switch_case}, {"meta:switch_highlight", _switch_highlight}, {"meta:prompt_newline", _prompt_newline}, {"meta:pause_prompt", _pause}}
local default_action_keymap = {{"<PageUp>", "<meta:select_previous_candidate>", "noremap"}, {"<PageDown>", "<meta:select_next_candidate>", "noremap"}, {"<C-A>", "<meta:move_caret_to_head>", "noremap"}, {"<C-E>", "<meta:move_caret_to_tail>", "noremap"}, {"<C-P>", "<meta:select_previous_candidate>", "noremap"}, {"<C-N>", "<meta:select_next_candidate>", "noremap"}, {"<C-K>", "<meta:select_previous_candidate>", "noremap"}, {"<C-J>", "<meta:select_next_candidate>", "noremap"}, {"<Left>", "<meta:move_caret_to_left>", "noremap"}, {"<Right>", "<meta:move_caret_to_right>", "noremap"}, {"<S-CR>", "<meta:prompt_newline>", "noremap"}, {"<C-I>", "<meta:toggle_insert_mode>", "noremap"}, {"<S-Tab>", "<meta:select_previous_candidate>", "noremap"}, {"<Tab>", "<meta:select_next_candidate>", "noremap"}, {"<C-^>", "<meta:switch_matcher>", "noremap"}, {"<C-6>", "<meta:switch_matcher>", "noremap"}, {"<C-_>", "<meta:switch_case>", "noremap"}, {"<C-O>", "<meta:switch_case>", "noremap"}, {"<C-S>", "<meta:switch_highlight>", "noremap"}, {"<LeftMouse>", "<meta:select_clicked_candidate>", "noremap"}, {"<LeftRelease>", "<meta:select_clicked_candidate>", "noremap"}, {"<C-z>", "<meta:pause_prompt>", "noremap"}}
M.DEFAULT_ACTION_RULES = default_action_rules
M.DEFAULT_ACTION_KEYMAP = default_action_keymap
return M
