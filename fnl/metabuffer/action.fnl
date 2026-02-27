(local M {})

(fn _change-line [offset]
  (let [c (vim.api.nvim_win_get_cursor 0)]
    (vim.api.nvim_win_set_cursor 0 [(+ (. c 1) offset) (. c 2)])))

(fn _select-next [meta _]
  (_change-line 1)
  (meta.refresh-statusline))

(fn _select-prev [meta _]
  (_change-line -1)
  (meta.refresh-statusline))

(fn _switch-matcher [meta _]
  (meta.switch-mode "matcher"))

(fn _switch-case [meta _]
  (meta.switch-mode "case"))

(fn _switch-highlight [meta _]
  (meta.switch-mode "syntax"))

(fn _pause [_ _]
  4)

(set M.DEFAULT-ACTION-RULES
  [ ["meta:select_next_candidate" _select-next]
    ["meta:select_previous_candidate" _select-prev]
    ["meta:switch_matcher" _switch-matcher]
    ["meta:switch_case" _switch-case]
    ["meta:switch_highlight" _switch-highlight]
    ["meta:pause_prompt" _pause]])

(set M.DEFAULT-ACTION-KEYMAP
  [ ["<PageUp>" "<meta:select_previous_candidate>" "noremap"]
    ["<PageDown>" "<meta:select_next_candidate>" "noremap"]
    ["<C-A>" "<meta:move_caret_to_head>" "noremap"]
    ["<C-E>" "<meta:move_caret_to_tail>" "noremap"]
    ["<C-P>" "<meta:select_previous_candidate>" "noremap"]
    ["<C-N>" "<meta:select_next_candidate>" "noremap"]
    ["<C-K>" "<meta:select_previous_candidate>" "noremap"]
    ["<C-J>" "<meta:select_next_candidate>" "noremap"]
    ["<Left>" "<meta:move_caret_to_left>" "noremap"]
    ["<Right>" "<meta:move_caret_to_right>" "noremap"]
    ["<C-I>" "<meta:toggle_insert_mode>" "noremap"]
    ["<S-Tab>" "<meta:select_previous_candidate>" "noremap"]
    ["<Tab>" "<meta:select_next_candidate>" "noremap"]
    ["<C-^>" "<meta:switch_matcher>" "noremap"]
    ["<C-6>" "<meta:switch_matcher>" "noremap"]
    ["<C-_>" "<meta:switch_case>" "noremap"]
    ["<C-O>" "<meta:switch_case>" "noremap"]
    ["<C-S>" "<meta:switch_highlight>" "noremap"]
    ["<C-z>" "<meta:pause_prompt>" "noremap"]])

M
