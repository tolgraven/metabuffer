-- [nfnl] fnl/metabuffer/window/metawindow.fnl
local base = require("metabuffer.window.base")
local M = {}
M["default-opts"] = {scrolloff = 0, sidescrolloff = 0, signcolumn = "yes:1", cursorcolumn = false, foldenable = false, spell = false}
M["opts-to-stash"] = {"foldcolumn", "number", "relativenumber", "wrap", "conceallevel", "signcolumn"}
M.statusline = "%%#MetaStatuslineMode%s# %s%%#MetaStatuslineIndicator# %d/%d%s%%#MetaStatuslineMiddle#%%=%%#MetaStatuslineFile# %s %%#MetaStatuslineMatcher%s# %s %%#MetaStatuslineKey#%s%%#MetaStatuslineCase%s# %s %%#MetaStatuslineKey#%s%%#MetaStatuslineSyntax%s# %s %%#MetaStatuslineKey#%s "
local function title_case(s)
  if ((type(s) == "string") and (#s > 0)) then
    return (string.upper(string.sub(s, 1, 1)) .. string.lower(string.sub(s, 2)))
  else
    return ""
  end
end
M.new = function(nvim, win)
  local self = base.new(nvim, (win or vim.api.nvim_get_current_win()), M["opts-to-stash"], M["default-opts"])
  self["set-statusline-state"] = function(mode_group, mode_label, name, num_hits, num_lines, line_nr, debug_out, preview_file, matcher, case_mode, hl_prefix, syntax)
    local matcher_suffix = title_case(matcher)
    local case_suffix = title_case(case_mode)
    local text = string.format(M.statusline, mode_group, mode_label, num_hits, num_lines, (debug_out or ""), (preview_file or ""), matcher_suffix, matcher, "C^", case_suffix, case_mode, "C-o", hl_prefix, syntax, "Cs")
    return self["set-statusline"](text)
  end
  return self
end
return M
