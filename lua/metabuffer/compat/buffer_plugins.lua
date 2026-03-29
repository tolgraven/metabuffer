-- [nfnl] fnl/metabuffer/compat/buffer_plugins.fnl
local function buf_valid_3f(buf)
  return (buf and vim.api.nvim_buf_is_valid(buf))
end
local function disable_common_21(_1_)
  local buf = _1_.buf
  if buf_valid_3f(buf) then
    pcall(vim.api.nvim_buf_set_var, buf, "conjure_disable", true)
    pcall(vim.api.nvim_buf_set_var, buf, "lsp_disabled", 1)
    pcall(vim.api.nvim_buf_set_var, buf, "gitgutter_enabled", 0)
    pcall(vim.api.nvim_buf_set_var, buf, "gitsigns_disable", true)
    return pcall(vim.diagnostic.enable, false, {bufnr = buf})
  else
    return nil
  end
end
local function disable_prompt_pairs_21(_3_)
  local buf = _3_.buf
  if buf_valid_3f(buf) then
    pcall(vim.api.nvim_buf_set_var, buf, "autopairs_enabled", false)
    pcall(vim.api.nvim_buf_set_var, buf, "AutoPairsDisabled", 1)
    pcall(vim.api.nvim_buf_set_var, buf, "delimitMate_enabled", 0)
    pcall(vim.api.nvim_buf_set_var, buf, "pear_tree_disable", 1)
    pcall(vim.api.nvim_buf_set_var, buf, "endwise_disable", 1)
    pcall(vim.api.nvim_buf_set_var, buf, "cmp_enabled", false)
    return pcall(vim.api.nvim_buf_set_var, buf, "meta_prompt", true)
  else
    return nil
  end
end
local function mark_preview_21(_5_)
  local buf = _5_.buf
  local transient_3f = _5_["transient?"]
  local and_6_ = buf_valid_3f(buf)
  if and_6_ then
    if (transient_3f == nil) then
      and_6_ = true
    else
      and_6_ = transient_3f
    end
  end
  if and_6_ then
    return pcall(vim.api.nvim_buf_set_var, buf, "meta_preview", true)
  else
    return nil
  end
end
return {name = "buffer-plugins", domain = "compat", events = {["on-buf-create!"] = {{handler = disable_common_21, priority = 10}, {handler = disable_prompt_pairs_21, priority = 20, ["role-filter"] = "prompt"}, {handler = mark_preview_21, priority = 20, ["role-filter"] = "preview"}}}}
