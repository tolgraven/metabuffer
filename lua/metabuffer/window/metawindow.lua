-- [nfnl] fnl/metabuffer/window/metawindow.fnl
local base = require("metabuffer.window.base")
local metabuffer_winhighlight = base["metabuffer-winhighlight"]
local M = {}
local function main_winhighlight(middle_group)
  return (metabuffer_winhighlight() .. ",StatusLine:" .. (middle_group or "MetaStatuslineMiddle") .. ",StatusLineNC:" .. (middle_group or "MetaStatuslineMiddle"))
end
M["default-opts"] = {number = true, cursorline = true, scrolloff = 0, sidescrolloff = 0, signcolumn = "yes:1", winhighlight = main_winhighlight(nil), cursorcolumn = false, foldenable = false, relativenumber = false, spell = false}
M["opts-to-stash"] = {"foldcolumn", "number", "numberwidth", "relativenumber", "statuscolumn", "wrap", "conceallevel", "signcolumn", "scrolloff", "sidescrolloff", "statusline", "cursorline", "winhighlight"}
M.statusline = "%s%%#%s#%%=%s "
M.new = function(nvim, win)
  local self = base.new(nvim, (win or vim.api.nvim_get_current_win()), M["opts-to-stash"], M["default-opts"])
  self["set-statusline-state"] = function(_mode_group, _mode_label, _name, _num_hits, _num_lines, _line_nr, left_extra, right_extra, _matcher, _case_mode, _hl_prefix, _syntax, middle_group)
    local middle = (middle_group or "MetaStatuslineMiddle")
    local winhl = main_winhighlight(middle)
    local text = string.format(M.statusline, (left_extra or ""), middle, (right_extra or ""))
    if (self.window and vim.api.nvim_win_is_valid(self.window)) then
      pcall(vim.api.nvim_set_option_value, "winhighlight", winhl, {win = self.window})
    else
    end
    return self["set-statusline"](text)
  end
  return self
end
return M
