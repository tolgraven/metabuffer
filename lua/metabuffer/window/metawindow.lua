local base = require("metabuffer.window.base")
local M = {}
M["default-opts"] = {cursorcolumn = false, foldenable = false, spell = false}
M["opts-to-stash"] = {"foldcolumn", "number", "relativenumber", "wrap", "conceallevel"}
M.statusline = "%%#MetaStatuslineMode%s#%s%%#MetaStatuslineQuery#%s%%#MetaStatuslineFile# %s%%#MetaStatuslineIndicator# %d/%d %%#Normal# %d%s%%#MetaStatuslineMiddle#%%=%%#MetaStatuslineMatcher%s# %s %%#MetaStatuslineKey#%s%%#MetaStatuslineCase%s# %s %%#MetaStatuslineKey#%s%%#MetaStatuslineSyntax%s# %s %%#MetaStatuslineKey#%s "
M.new = function(nvim, win)
  local self = base.new(nvim, (win or vim.api.nvim_get_current_win()), M["opts-to-stash"], M["default-opts"])
  self["set-statusline-state"] = function(mode, prefix, query, name, num_hits, num_lines, line_nr, debug_out, matcher, case_mode, hl_prefix, syntax)
    local text = string.format(M.statusline, mode, prefix, query, name, num_hits, num_lines, line_nr, (debug_out or ""), string.upper(string.sub(matcher, 1, 1)), matcher, "C^", string.upper(string.sub(case_mode, 1, 1)), case_mode, "C_", hl_prefix, syntax, "Cs")
    return self["set-statusline"](text)
  end
  return self
end
return M
