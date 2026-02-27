local M = {}
local function _change_line(offset)
  local c = vim.api.nvim_win_get_cursor(0)
  return vim.api.nvim_win_set_cursor(0, {(c[1] + offset), c[2]})
end
local function _select_next(meta, _)
  _change_line(1)
  return meta["refresh-statusline"]()
end
local function _select_prev(meta, _)
  _change_line(-1)
  return meta["refresh-statusline"]()
end
local function _switch_matcher(meta, _)
  return meta["switch-mode"]("matcher")
end
local function _switch_case(meta, _)
  return meta["switch-mode"]("case")
end
local function _switch_highlight(meta, _)
  return meta["switch-mode"]("syntax")
end
local function _pause(_, _0)
  return 4
end
M["DEFAULT-ACTION-RULES"] = {{"meta:select_next_candidate", _select_next}, {"meta:select_previous_candidate", _select_prev}, {"meta:switch_matcher", _switch_matcher}, {"meta:switch_case", _switch_case}, {"meta:switch_highlight", _switch_highlight}, {"meta:pause_prompt", _pause}}
M["DEFAULT-ACTION-KEYMAP"] = {{"<PageUp>", "<meta:select_previous_candidate>", "noremap"}, {"<PageDown>", "<meta:select_next_candidate>", "noremap"}, {"<C-A>", "<meta:move_caret_to_head>", "noremap"}, {"<C-E>", "<meta:move_caret_to_tail>", "noremap"}, {"<C-P>", "<meta:select_previous_candidate>", "noremap"}, {"<C-N>", "<meta:select_next_candidate>", "noremap"}, {"<C-K>", "<meta:select_previous_candidate>", "noremap"}, {"<C-J>", "<meta:select_next_candidate>", "noremap"}, {"<Left>", "<meta:move_caret_to_left>", "noremap"}, {"<Right>", "<meta:move_caret_to_right>", "noremap"}, {"<C-I>", "<meta:toggle_insert_mode>", "noremap"}, {"<S-Tab>", "<meta:select_previous_candidate>", "noremap"}, {"<Tab>", "<meta:select_next_candidate>", "noremap"}, {"<C-^>", "<meta:switch_matcher>", "noremap"}, {"<C-6>", "<meta:switch_matcher>", "noremap"}, {"<C-_>", "<meta:switch_case>", "noremap"}, {"<C-O>", "<meta:switch_case>", "noremap"}, {"<C-S>", "<meta:switch_highlight>", "noremap"}, {"<C-z>", "<meta:pause_prompt>", "noremap"}}
return M
