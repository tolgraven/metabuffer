-- [nfnl] fnl/metabuffer/compat/cmp.fnl
local function buf_valid_3f(buf)
  return (buf and vim.api.nvim_buf_is_valid(buf))
end
local function disable_cmp_for_buf_21(_1_)
  local buf = _1_.buf
  if buf_valid_3f(buf) then
    local ok,cmp = pcall(require, "cmp")
    if ok then
      pcall(cmp.setup.buffer, {enabled = false})
      return pcall(cmp.abort)
    else
      return nil
    end
  else
    return nil
  end
end
local function disable_cmp_on_insert_21(_4_)
  local session = _4_.session
  if (session and session["prompt-buf"] and buf_valid_3f(session["prompt-buf"])) then
    local ok,cmp = pcall(require, "cmp")
    if ok then
      pcall(cmp.setup.buffer, {enabled = false})
      return pcall(cmp.abort)
    else
      return nil
    end
  else
    return nil
  end
end
return {name = "cmp", domain = "compat", events = {["on-buf-create!"] = {handler = disable_cmp_for_buf_21, priority = 30, ["role-filter"] = "prompt"}, ["on-insert-enter!"] = {handler = disable_cmp_on_insert_21, priority = 30}}}
