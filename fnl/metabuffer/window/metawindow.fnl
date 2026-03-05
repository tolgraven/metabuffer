(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local base (require :metabuffer.window.base))

(local M {})

(set M.default-opts {:spell false :foldenable false :cursorcolumn false :scrolloff 0 :sidescrolloff 0})
(set M.opts-to-stash ["foldcolumn" "number" "relativenumber" "wrap" "conceallevel"])

(set M.statusline
  "%%#MetaStatuslineMode%s# %s%%#MetaStatuslineIndicator# %d/%d%s%%#MetaStatuslineMiddle#%%=%%#MetaStatuslineMatcher%s# %s %%#MetaStatuslineKey#%s%%#MetaStatuslineCase%s# %s %%#MetaStatuslineKey#%s%%#MetaStatuslineSyntax%s# %s %%#MetaStatuslineKey#%s ")

(fn title-case
  [s]
  (if (and (= (type s) "string") (> (# s) 0))
      (.. (string.upper (string.sub s 1 1)) (string.lower (string.sub s 2)))
      ""))

(fn M.new
  [nvim win]
  "Create the main Meta results window wrapper and statusline renderer."
  (let [self (base.new nvim (or win (vim.api.nvim_get_current_win)) M.opts-to-stash M.default-opts)]

    (fn self.set-statusline-state
      [mode-group mode-label name num-hits num-lines line-nr debug-out matcher case-mode hl-prefix syntax]
      (let [matcher-suffix (title-case matcher)
            case-suffix (title-case case-mode)
            text (string.format M.statusline
                   mode-group mode-label
                   num-hits num-lines (or debug-out "")
                   matcher-suffix matcher "C^"
                   case-suffix case-mode "C-o"
                   hl-prefix syntax "Cs")]
        (self.set-statusline text)))

    self))

M
