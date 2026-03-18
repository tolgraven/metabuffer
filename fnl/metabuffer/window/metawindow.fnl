(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local base (require :metabuffer.window.base))
(local statusline-mod (require :metabuffer.window.statusline))
(local metabuffer-winhighlight (. base :metabuffer-winhighlight))

(local M {})

(fn main-winhighlight
  []
  (.. (metabuffer-winhighlight)
      ",StatusLine:MetaStatuslineMiddle,StatusLineNC:MetaStatuslineMiddle"))

(set M.default-opts {:spell false
                     :foldenable false
                     :cursorcolumn false
                     :cursorline true
                     :scrolloff 0
                     :sidescrolloff 0
                     :signcolumn "yes:1"
                     :winhighlight (main-winhighlight)})
(set M.opts-to-stash ["foldcolumn" "number" "relativenumber" "wrap" "conceallevel" "signcolumn" "scrolloff" "sidescrolloff" "statusline" "cursorline" "winhighlight"])

(set M.statusline
  "%%#MetaStatuslineMode%s# %s%%#MetaStatuslineIndicator# %d/%d%s%%#MetaStatuslineMiddle#%%=%%#MetaStatuslineFile# %s %%#MetaStatuslineMatcher%s# %s %%#MetaStatuslineKey#%s%%#MetaStatuslineCase%s# %s %%#MetaStatuslineKey#%s%%#MetaStatuslineSyntax%s# %s %%#MetaStatuslineKey#%s ")

(fn M.new
  [nvim win]
  "Create the main Meta results window wrapper and statusline renderer."
  (let [self (base.new nvim (or win (vim.api.nvim_get_current_win)) M.opts-to-stash M.default-opts)]

    (fn self.set-statusline-state
      [mode-group mode-label _name num-hits num-lines _line-nr debug-out preview-file matcher case-mode hl-prefix syntax]
      (let [matcher-suffix (statusline-mod.title-case matcher)
            case-suffix (statusline-mod.title-case case-mode)
            text (string.format M.statusline
                   mode-group mode-label
                   num-hits num-lines (or debug-out "")
                   (or preview-file "")
                   matcher-suffix matcher "C^"
                   case-suffix case-mode "C-o"
                   hl-prefix syntax "Cs")]
        (self.set-statusline text)))

    self))

M
