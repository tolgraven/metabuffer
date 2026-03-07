-- [nfnl] fnl/metabuffer/core/state.fnl
local M = {}
M.cases = {"smart", "ignore", "normal"}
M["syntax-types"] = {"buffer", "meta"}
M["default-condition"] = function(query)
  local c = vim.api.nvim_win_get_cursor(0)
  return {text = (query or ""), ["caret-locus"] = #(query or ""), ["selected-index"] = (c[1] - 1), ["matcher-index"] = 1, ["case-index"] = 1, ["syntax-index"] = 1, restored = false}
end
M.ignorecase = function(case_mode, query)
  if (case_mode == "ignore") then
    return true
  else
    if (case_mode == "normal") then
      return false
    else
      return (query == string.lower(query))
    end
  end
end
return M
