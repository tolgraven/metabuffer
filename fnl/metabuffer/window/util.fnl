(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(fn M.window-rect
  [win]
  "Return screen rect for WIN or nil."
  (when (and win (= (type win) "number") (vim.api.nvim_win_is_valid win))
    (let [pos (vim.api.nvim_win_get_position win)
          row (or (. pos 1) 0)
          col (or (. pos 2) 0)
          height (vim.api.nvim_win_get_height win)
          width (vim.api.nvim_win_get_width win)]
      {:top row
       :left col
       :bottom (+ row height -1)
       :right (+ col width -1)})))

(fn M.rect-overlap?
  [a b]
  "True when rects A and B overlap."
  (and a b
       (<= (. a :top) (. b :bottom))
       (<= (. b :top) (. a :bottom))
       (<= (. a :left) (. b :right))
       (<= (. b :left) (. a :right))))

(fn M.first-window-for-buffer
  [buf]
  "Return first valid window currently showing BUF, or nil."
  (when (and buf (= (type buf) "number") (vim.api.nvim_buf_is_valid buf))
    (let [wins (vim.fn.win_findbuf buf)]
      (var found nil)
      (each [_ win (ipairs (or wins []))]
        (when (and (not found) (vim.api.nvim_win_is_valid win))
          (set found win)))
      found)))

(fn M.tab-window-count
  [win]
  "Return count of windows in WIN tab, or nil."
  (when (and win (= (type win) "number") (vim.api.nvim_win_is_valid win))
    (let [[ok tab] [(pcall vim.api.nvim_win_get_tabpage win)]]
      (when (and ok tab)
        (let [[ok2 wins] [(pcall vim.api.nvim_tabpage_list_wins tab)]]
          (when (and ok2 (= (type wins) "table"))
            (# wins)))))))

M
