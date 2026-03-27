-- [nfnl] fnl/metabuffer/compat/cmp.fnl
local function buf_valid_3f(buf)
  return (buf and vim.api.nvim_buf_is_valid(buf))
end
local function close_completion_ui_21()
  return pcall(vim.cmd, "silent! pclose")
end
local function disable_native_completion_for_buf_21(buf)
  if buf_valid_3f(buf) then
    local bo = vim.bo[buf]
    local completefunc = (bo.completefunc or "")
    if (completefunc ~= "v:lua.__meta_directive_completefunc") then
      bo["completefunc"] = ""
    else
    end
    bo["omnifunc"] = ""
    bo["complete"] = ""
    bo["completeopt"] = "menuone,noselect,noinsert"
    return nil
  else
    return nil
  end
end
local function disable_completion_for_buf_21(buf)
  if buf_valid_3f(buf) then
    disable_native_completion_for_buf_21(buf)
    close_completion_ui_21()
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
local function disable_cmp_for_buf_21(_5_)
  local buf = _5_.buf
  disable_completion_for_buf_21(buf)
  local function _6_()
    return disable_completion_for_buf_21(buf)
  end
  return vim.schedule(_6_)
end
local function disable_cmp_on_insert_21(_7_)
  local session = _7_.session
  if (session and session["prompt-buf"] and buf_valid_3f(session["prompt-buf"])) then
    return disable_completion_for_buf_21(session["prompt-buf"])
  else
    return nil
  end
end
return {name = "cmp", domain = "compat", events = {["on-buf-create!"] = {handler = disable_cmp_for_buf_21, priority = 30, ["role-filter"] = "prompt"}, ["on-insert-enter!"] = {handler = disable_cmp_on_insert_21, priority = 30}}}
