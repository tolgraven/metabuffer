(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local base (require :metabuffer.window.base))
(local animation-mod (require :metabuffer.window.animation))
(local M {})

(fn M.new
  [nvim opts]
  "Create the bottom prompt window used by Meta interactive input."
  (let [cfg (or opts {})
        height (or cfg.height 3)
        start-height (math.max 1 (or cfg.start-height height))
        local-layout? (if (= cfg.window-local-layout nil) true cfg.window-local-layout)
        origin-win cfg.origin-win
        open-prompt-win! (fn []
                           (if (and local-layout?
                                    origin-win
                                    (vim.api.nvim_win_is_valid origin-win))
                               (vim.api.nvim_win_call
                                 origin-win
                                 (fn []
                                   (vim.cmd (.. "belowright " (tostring start-height) "new"))
                                   (vim.api.nvim_get_current_win)))
                               (do
                                 (vim.cmd (.. "botright " (tostring start-height) "new"))
                                 (vim.api.nvim_get_current_win))))
        win (animation-mod.with-split-mins open-prompt-win!)
        buf (vim.api.nvim_win_get_buf win)
          self (base.new nvim win [] {})]
      (pcall vim.api.nvim_win_set_height win start-height)
      (let [bo (. vim.bo buf)]
        (set (. bo :buftype) "nofile")
        (set (. bo :bufhidden) "wipe")
        (set (. bo :swapfile) false)
        (set (. bo :modifiable) true)
        (set (. bo :filetype) "metabufferprompt"))
      ;; Common nvim-cmp convention: buffer-local opt-out.
      (let [b (. vim.b buf)
            wo (. vim.wo win)]
        (set (. b :cmp_enabled) false)
        (set (. wo :winfixheight) true)
        (set (. wo :number) false)
        (set (. wo :relativenumber) false)
        (set (. wo :signcolumn) "no")
        (set (. wo :foldcolumn) "0")
        (set (. wo :spell) false)
        (set (. wo :wrap) true)
        (set (. wo :linebreak) true))
      (set self.buffer buf)
      self))

M
