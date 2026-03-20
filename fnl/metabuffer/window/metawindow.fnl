(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local base (require :metabuffer.window.base))
(local metabuffer-winhighlight (. base :metabuffer-winhighlight))

(local M {})

(fn main-winhighlight
  []
  (.. (metabuffer-winhighlight)
      ",StatusLine:MetaStatuslineMiddle,StatusLineNC:MetaStatuslineMiddle"))

(set M.default-opts {:spell false
                     :foldenable false
                     :number true
                     :relativenumber false
                     :cursorcolumn false
                     :cursorline true
                     :scrolloff 0
                     :sidescrolloff 0
                     :signcolumn "yes:1"
                     :winhighlight (main-winhighlight)})
(set M.opts-to-stash ["foldcolumn" "number" "numberwidth" "relativenumber" "statuscolumn" "wrap" "conceallevel" "signcolumn" "scrolloff" "sidescrolloff" "statusline" "cursorline" "winhighlight"])

(set M.statusline
  "%s%%#%s#%%=%s ")

(fn M.new
  [nvim win]
  "Create the main Meta results window wrapper and statusline renderer."
  (let [self (base.new nvim (or win (vim.api.nvim_get_current_win)) M.opts-to-stash M.default-opts)]

    (fn self.set-statusline-state
      [_mode-group _mode-label _name _num-hits _num-lines _line-nr left-extra right-extra _matcher _case-mode _hl-prefix _syntax middle-group]
      (let [text (string.format M.statusline (or left-extra "") (or middle-group "MetaStatuslineMiddle") (or right-extra ""))]
        (self.set-statusline text)))

    self))

M
