(local base (require :metabuffer.window.base))

(local M {})

(set M.default-opts {:spell false :foldenable false :cursorcolumn false :scrolloff 0 :sidescrolloff 0})
(set M.opts-to-stash ["foldcolumn" "number" "relativenumber" "wrap" "conceallevel"])

(set M.statusline
  "%%#MetaStatuslineMode%s#%s%%#MetaStatuslineQuery#%s%%#MetaStatuslineFile# %s%%#MetaStatuslineIndicator# %d/%d %%#Normal# %d%s%%#MetaStatuslineMiddle#%%=%%#MetaStatuslineMatcher%s# %s %%#MetaStatuslineKey#%s%%#MetaStatuslineCase%s# %s %%#MetaStatuslineKey#%s%%#MetaStatuslineSyntax%s# %s %%#MetaStatuslineKey#%s ")

(fn title-case [s]
  (if (and (= (type s) "string") (> (# s) 0))
      (.. (string.upper (string.sub s 1 1)) (string.lower (string.sub s 2)))
      ""))

(fn M.new [nvim win]
  (local self (base.new nvim (or win (vim.api.nvim_get_current_win)) M.opts-to-stash M.default-opts))

  (fn self.set-statusline-state [mode prefix query name num-hits num-lines line-nr debug-out matcher case-mode hl-prefix syntax]
    (local matcher-suffix (title-case matcher))
    (local case-suffix (title-case case-mode))
    (local text (string.format M.statusline
                  mode prefix query name
                  num-hits num-lines line-nr (or debug-out "")
                  matcher-suffix matcher "C^"
                  case-suffix case-mode "C-o"
                  hl-prefix syntax "Cs"))
    (self.set-statusline text))

  self)

M
