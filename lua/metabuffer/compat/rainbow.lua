-- [nfnl] fnl/metabuffer/compat/rainbow.fnl
local function buf_valid_3f(buf)
  return (buf and vim.api.nvim_buf_is_valid(buf))
end
local function origin_buf(_1_)
  local session = _1_.session
  local buf = (session and session["origin-buf"])
  if buf_valid_3f(buf) then
    return buf
  else
    return nil
  end
end
local function deactivate_21(_3_)
  local session = _3_.session
  local buf = origin_buf({session = session})
  if buf then
    pcall(vim.api.nvim_buf_set_var, buf, "metabuffer_rainbow_parentheses_disabled", true)
    if (1 == vim.fn.exists("*rainbow_parentheses#deactivate")) then
      local run_21
      local function _4_()
        return vim.cmd("silent! call rainbow_parentheses#deactivate()")
      end
      run_21 = _4_
      return pcall(vim.api.nvim_buf_call, buf, run_21)
    else
      return nil
    end
  else
    return nil
  end
end
local function activate_21(_7_)
  local session = _7_.session
  local buf = origin_buf({session = session})
  if buf then
    local ok,disabled_3f = pcall(vim.api.nvim_buf_get_var, buf, "metabuffer_rainbow_parentheses_disabled")
    if (ok and disabled_3f and (1 == vim.fn.exists("*rainbow_parentheses#activate"))) then
      do
        local run_21
        local function _8_()
          return vim.cmd("silent! call rainbow_parentheses#activate()")
        end
        run_21 = _8_
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
return {name = "rainbow", domain = "compat", events = {["on-session-start!"] = {handler = deactivate_21, priority = 30}, ["on-session-stop!"] = {handler = activate_21, priority = 70}}}
