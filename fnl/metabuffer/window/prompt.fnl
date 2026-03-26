(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local base (require :metabuffer.window.base))
(local animation-mod (require :metabuffer.window.animation))
(local directive-mod (require :metabuffer.query.directive))
(local util (require :metabuffer.util))
(local M {})
(local disable-airline-statusline! (. base :disable-airline-statusline!))
(local apply-metabuffer-window-highlights! (. base :apply-metabuffer-window-highlights!))
(local metabuffer-winhighlight (. base :metabuffer-winhighlight))
(local with-split-mins (. animation-mod :with-split-mins))

(fn prompt-winhighlight
  []
  (.. (metabuffer-winhighlight)
      ",StatusLine:MetaStatuslineMiddle,StatusLineNC:MetaStatuslineMiddle"))

(fn prompt-buffer!
  [win]
  (let [buf (vim.api.nvim_win_get_buf win)]
    (util.disable-heavy-buffer-features! buf)
    (util.set-buffer-name! buf "[Metabuffer Prompt]")
    (let [bo (. vim.bo buf)]
      (set (. bo :buftype) "nofile")
      (set (. bo :bufhidden) "wipe")
      (set (. bo :swapfile) false)
      (set (. bo :modifiable) true)
      (set _G.__meta_directive_completefunc (. directive-mod :completefunc))
      (set (. bo :completefunc) "v:lua.__meta_directive_completefunc")
      (set (. bo :filetype) "metabufferprompt"))
    buf))

(fn prompt-window-opts!
  [win]
  (disable-airline-statusline! win)
  (apply-metabuffer-window-highlights! win)
  (let [wo (. vim.wo win)]
    (set (. wo :winfixheight) true)
    (set (. wo :number) false)
    (set (. wo :relativenumber) false)
    (set (. wo :signcolumn) "no")
    (set (. wo :foldcolumn) "0")
    (set (. wo :statusline) " ")
    (set (. wo :winbar) "")
    (set (. wo :spell) false)
    (set (. wo :cursorline) false)
    (set (. wo :wrap) true)
    (set (. wo :linebreak) true)
    (set (. wo :winhighlight) (prompt-winhighlight))
    (set (. wo :winblend) 0)))

(fn open-split-win!
  [origin-win local-layout? start-height]
  (let [open! (fn []
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
                      (vim.api.nvim_get_current_win))))]
    (let [win (with-split-mins open!)]
      (when (and win (vim.api.nvim_win_is_valid win))
        (util.mark-transient-unnamed-buffer! (vim.api.nvim_win_get_buf win)))
      win)))

(fn wipe-replaced-split-buffer!
  [old-buf]
  "Delete the temporary [No Name] split buffer once a real prompt buffer is attached."
  (when (and old-buf (vim.api.nvim_buf_is_valid old-buf))
    (util.delete-transient-unnamed-buffer! old-buf)))

(fn float-config
  [origin-win start-height]
  (let [host (if (and origin-win (vim.api.nvim_win_is_valid origin-win))
                 origin-win
                 (vim.api.nvim_get_current_win))
        host-width (vim.api.nvim_win_get_width host)
        host-height (vim.api.nvim_win_get_height host)]
    {:relative "win"
     :win host
     :anchor "SW"
     :row host-height
     :col 0
     :width host-width
     :height (math.max 1 start-height)
     :style "minimal"}))

(fn M.new
  [nvim opts]
  "Create the bottom prompt window used by Meta interactive input."
  (let [cfg (or opts {})
        height (or cfg.height 3)
        start-height (math.max 1 (or cfg.start-height height))
        local-layout? (if (= cfg.window-local-layout nil) true cfg.window-local-layout)
        origin-win cfg.origin-win
        floating? (clj.boolean cfg.floating?)
        win (if floating?
                (vim.api.nvim_open_win (vim.api.nvim_create_buf false true) false (float-config origin-win start-height))
                (open-split-win! origin-win local-layout? start-height))
        self (base.new nvim win [] {})]
      (if floating?
          (pcall vim.api.nvim_win_set_config win (float-config origin-win start-height))
          (pcall vim.api.nvim_win_set_height win start-height))
      (let [buf (prompt-buffer! win)]
      ;; Common nvim-cmp convention: buffer-local opt-out.
        (let [b (. vim.b buf)]
          (set (. b :cmp_enabled) false)
          (prompt-window-opts! win))
        (set self.buffer buf)
        (set self.floating? floating?)
        self)))

(fn M.handoff-to-split!
  [nvim prompt-win opts]
  (let [cfg (or opts {})
        origin-win cfg.origin-win
        local-layout? (if (= cfg.window-local-layout nil) true cfg.window-local-layout)
        height (math.max 1 (or cfg.height 1))
        old-win (. prompt-win :window)
        buf (. prompt-win :buffer)
        saved-view (and origin-win
                        (vim.api.nvim_win_is_valid origin-win)
                        (vim.api.nvim_win_call origin-win (fn [] (vim.fn.winsaveview))))
        split-win (open-split-win! origin-win local-layout? height)
        old-buf (and split-win
                     (vim.api.nvim_win_is_valid split-win)
                     (vim.api.nvim_win_get_buf split-win))]
    (pcall vim.api.nvim_win_set_buf split-win buf)
    (wipe-replaced-split-buffer! old-buf)
    (pcall vim.api.nvim_win_set_height split-win height)
    (prompt-window-opts! split-win)
    (when (and origin-win
               saved-view
               (vim.api.nvim_win_is_valid origin-win))
      (vim.api.nvim_win_call
        origin-win
        (fn []
          (pcall vim.fn.winrestview saved-view))))
    (when (and old-win (vim.api.nvim_win_is_valid old-win))
      (pcall vim.api.nvim_win_close old-win true))
    (let [self (base.new nvim split-win [] {})]
      (set self.buffer buf)
      (set self.floating? false)
      self)))

M
