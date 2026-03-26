(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local M {})
(local util (require :metabuffer.util))

(fn ensure-window!
  [floating-window-mod session]
  (when-not (and session.history-browser-win
                 (vim.api.nvim_win_is_valid session.history-browser-win))
    (let [buf (vim.api.nvim_create_buf false true)
          p-row-col (vim.api.nvim_win_get_position session.prompt-win)
          p-row (. p-row-col 1)
          p-col (. p-row-col 2)
          p-width (vim.api.nvim_win_get_width session.prompt-win)
          p-height (vim.api.nvim_win_get_height session.prompt-win)
          width (math.max 42 (math.min 120 p-width))
          height (math.max 4 (math.min 12 p-height))
          cfg (if session.window-local-layout
                  {:relative "win"
                   :win session.prompt-win
                   :anchor "SW"
                   :row 0
                   :col 0
                   :width width
                   :height height}
                  (let [row (math.max 0 (- p-row height))
                        col p-col]
                    {:relative "editor"
                     :anchor "NE"
                     :row row
                     :col col
                     :width width
                     :height height}))
          win (floating-window-mod.new vim buf cfg)]
      (util.disable-heavy-buffer-features! buf)
      (util.set-buffer-name! buf "[Metabuffer History]")
      (set session.history-browser-buf buf)
      (set session.history-browser-win win.window)
      (let [bo (. vim.bo buf)]
        (set (. bo :buftype) "nofile")
        (set (. bo :bufhidden) "wipe")
        (set (. bo :swapfile) false)
        (set (. bo :modifiable) false)
        (set (. bo :filetype) "metabuffer")))))

(fn close-window!
  [session]
  (when (and session.history-browser-win
             (vim.api.nvim_win_is_valid session.history-browser-win))
    (pcall vim.api.nvim_win_close session.history-browser-win true))
  (set session.history-browser-win nil)
  (set session.history-browser-buf nil)
  (set session.history-browser-active false)
  (set session.history-browser-items [])
  (set session.history-browser-index 1)
  (set session.history-browser-mode nil))

(fn clamp-index
  [idx n]
  (if (<= n 0)
      1
      (math.max 1 (math.min idx n))))

(fn render!
  [session]
  (when (and session.history-browser-buf
             (vim.api.nvim_buf_is_valid session.history-browser-buf))
    (let [items (or session.history-browser-items [])
          lines []
          hl []
          filter (or session.history-browser-filter "")
          idx (clamp-index (or session.history-browser-index 1) (# items))]
      (set session.history-browser-index idx)
      (if (= (# items) 0)
          (table.insert lines "")
          (each [i item (ipairs items)]
            (let [label (or (. item :label) "")
                  mark (if (= i idx) "> " "  ")]
              (table.insert lines (.. mark label))
              (when (and (~= filter "") (not= nil (string.find (string.lower label) (string.lower filter) 1 true)))
                (var pos 1)
                (while (<= pos (# label))
                  (let [[s e] [(string.find (string.lower label) (string.lower filter) pos true)]]
                    (if (and s e)
                        (do
                          (table.insert hl [(- i 1) (+ 2 (- s 1)) (+ 2 e)])
                          (set pos (+ e 1)))
                        (set pos (+ (# label) 1)))))))))
      (let [bo (. vim.bo session.history-browser-buf)]
        (set (. bo :modifiable) true))
      (vim.api.nvim_buf_set_lines session.history-browser-buf 0 -1 false lines)
      (let [bo (. vim.bo session.history-browser-buf)]
        (set (. bo :modifiable) false))
      (let [ns (or session.history-browser-hl-ns
                   (vim.api.nvim_create_namespace "metabuffer.history-browser"))]
        (set session.history-browser-hl-ns ns)
        (vim.api.nvim_buf_clear_namespace session.history-browser-buf ns 0 -1)
        (each [_ item (ipairs hl)]
          (vim.api.nvim_buf_add_highlight
            session.history-browser-buf
            ns
            "MetaSearchHitAll"
            (. item 1)
            (. item 2)
            (. item 3))))
      (when (and session.history-browser-win
                 (vim.api.nvim_win_is_valid session.history-browser-win))
        (pcall vim.api.nvim_win_set_cursor session.history-browser-win [idx 0])))))

(fn M.new
  [opts]
  "Create floating history browser window."
  (let [{: floating-window-mod} opts]
    (fn open!
      [session mode]
      (ensure-window! floating-window-mod session)
      (set session.history-browser-active true)
      (set session.history-browser-mode mode)
      (set session.history-browser-items [])
      (set session.history-browser-index 1)
      (render! session))

    (fn refresh!
      [session items]
      (when session.history-browser-active
        (set session.history-browser-items (or items []))
        (set session.history-browser-index
             (clamp-index (or session.history-browser-index 1)
                          (# (or session.history-browser-items []))))
        (render! session)))

    (fn move!
      [session delta]
      (when session.history-browser-active
        (let [n (# (or session.history-browser-items []))]
          (set session.history-browser-index
               (clamp-index (+ (or session.history-browser-index 1) delta) n))
          (render! session))))

    (fn selected!
      [session]
      (when (and session.history-browser-active
                 (> (# (or session.history-browser-items [])) 0))
        (. session.history-browser-items (or session.history-browser-index 1))))

    {:open! open!
     :refresh! refresh!
     :move! move!
     :selected! selected!
     :close! close-window!}))

M
