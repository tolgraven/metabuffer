(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(fn _sync-selected-from-cursor
  [meta]
  (let [max (# meta.buf.indices)]
    (if (<= max 0)
        (set meta.selected_index 0)
        (let [c (vim.api.nvim_win_get_cursor 0)
              row (. c 1)
              col (. c 2)
              clamped (math.max 1 (math.min row max))]
          (when (~= row clamped)
            (vim.api.nvim_win_set_cursor 0 [clamped col]))
          (set meta.selected_index (- clamped 1))))))

(fn _change-line
  [meta offset]
  (let [c (vim.api.nvim_win_get_cursor 0)
        max (math.max 1 (# meta.buf.indices))
        row (math.max 1 (math.min (+ (. c 1) offset) max))]
    (vim.api.nvim_win_set_cursor 0 [row (. c 2)])
    (_sync-selected-from-cursor meta)))

(fn _select-next
  [meta _]
  (_change-line meta 1)
  (meta.refresh_statusline))

(fn _select-prev
  [meta _]
  (_change-line meta -1)
  (meta.refresh_statusline))

(fn _select-clicked
  [meta _]
  (let [mp (vim.fn.getmousepos)
        winid (. mp :winid)
        lnum (. mp :line)
        col (. mp :column)
        curwin (vim.api.nvim_get_current_win)
        max (math.max 1 (# meta.buf.indices))]
    (when (and (= winid curwin) (> lnum 0))
      (let [row (math.max 1 (math.min lnum max))
            zero-col (math.max 0 (- (or col 1) 1))]
        (vim.api.nvim_win_set_cursor 0 [row zero-col]))))
  (_sync-selected-from-cursor meta)
  (meta.refresh_statusline))

(fn _ignore
  [meta _]
  (meta.refresh_statusline))

(fn _switch-matcher
  [meta _]
  (meta.switch_mode "matcher"))

(fn _switch-case
  [meta _]
  (meta.switch_mode "case"))

(fn _switch-highlight
  [meta _]
  (meta.switch_mode "syntax"))

(fn _pause
  [_ _]
  4)

(local default-action-rules
  [ ["meta:select_next_candidate" _select-next]
    ["meta:select_previous_candidate" _select-prev]
    ["meta:select_clicked_candidate" _select-clicked]
    ["meta:ignore" _ignore]
    ["meta:switch_matcher" _switch-matcher]
    ["meta:switch_case" _switch-case]
    ["meta:switch_highlight" _switch-highlight]
    ["meta:pause_prompt" _pause]])

(local default-action-keymap
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
    ["<LeftMouse>" "<meta:select_clicked_candidate>" "noremap"]
    ["<LeftRelease>" "<meta:select_clicked_candidate>" "noremap"]
    ["<C-z>" "<meta:pause_prompt>" "noremap"]])

(set M.DEFAULT_ACTION_RULES
  (if (= (type vim.g.meta_legacy_action_rules) "table")
      vim.g.meta_legacy_action_rules
      default-action-rules))

(set M.DEFAULT_ACTION_KEYMAP
  (if (= (type vim.g.meta_legacy_action_keymap) "table")
      vim.g.meta_legacy_action_keymap
      default-action-keymap))

;; Backward compatibility aliases.
(set M.DEFAULT-ACTION-RULES M.DEFAULT_ACTION_RULES)
(set M.DEFAULT-ACTION-KEYMAP M.DEFAULT_ACTION_KEYMAP)

M
