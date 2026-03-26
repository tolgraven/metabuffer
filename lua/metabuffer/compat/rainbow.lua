-- [nfnl] fnl/metabuffer/compat/rainbow.fnl
local function buf_valid_3f(buf)
  return (buf and vim.api.nvim_buf_is_valid(buf))
end
local function deactivate_21(_1_)
  local buf = _1_.buf
  if (buf_valid_3f(buf) and (1 == vim.fn.exists("*rainbow_parentheses#deactivate"))) then
    pcall(vim.api.nvim_buf_set_var, buf, "metabuffer_rainbow_parentheses_disabled", true)
    local run_21
    local function _2_()
      return vim.cmd("silent! call rainbow_parentheses#deactivate()")
    end
    run_21 = _2_
    return pcall(vim.api.nvim_buf_call, buf, run_21)
  else
    return nil
  end
end
local function activate_21(_4_)
  local buf = _4_.buf
  if buf_valid_3f(buf) then
    local ok,disabled_3f = pcall(vim.api.nvim_buf_get_var, buf, "metabuffer_rainbow_parentheses_disabled")
    if (ok and disabled_3f and (1 == vim.fn.exists("*rainbow_parentheses#activate"))) then
      do
        local run_21
        local function _5_()
          return vim.cmd("silent! call rainbow_parentheses#activate()")
        end
        run_21 = _5_
        pcall(vim.api.nvim_buf_call, buf, run_21)
      end
      return pcall(vim.api.nvim_buf_del_var, buf, "metabuffer_rainbow_parentheses_disabled")
    else
      return nil
    end
  else
    return nil
  end
end
return {name = "rainbow", domain = "compat", events = {["on-buf-create!"] = {handler = deactivate_21, priority = 30}, ["on-buf-teardown!"] = {handler = activate_21, priority = 70}}}
