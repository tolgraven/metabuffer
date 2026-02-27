(local base (require :metabuffer.window.base))

(local M {})

(set M.default-opts {:spell false :foldenable false :cursorcolumn false})
(set M.opts-to-stash ["foldcolumn" "number" "relativenumber" "wrap" "conceallevel"])

(set M.statusline
  "%%#MetaStatuslineMode%s#%s%%#MetaStatuslineQuery#%s%%#MetaStatuslineFile# %s%%#MetaStatuslineIndicator# %d/%d %%#Normal# %d%s%%#MetaStatuslineMiddle#%%=%%#MetaStatuslineMatcher%s# %s %%#MetaStatuslineKey#%s%%#MetaStatuslineCase%s# %s %%#MetaStatuslineKey#%s%%#MetaStatuslineSyntax%s# %s %%#MetaStatuslineKey#%s ")

(fn M.new [nvim win]
  (local self (base.new nvim (or win (vim.api.nvim_get_current_win)) M.opts-to-stash M.default-opts))

  (fn self.set-statusline-state [mode prefix query name num-hits num-lines line-nr debug-out matcher case-mode hl-prefix syntax]
    (local text (string.format M.statusline
                  mode prefix query name
                  num-hits num-lines line-nr (or debug-out "")
                  (string.upper (string.sub matcher 1 1)) matcher "C^"
                  (string.upper (string.sub case-mode 1 1)) case-mode "C_"
                  hl-prefix syntax "Cs"))
    (self.set-statusline text))

  self)

M
