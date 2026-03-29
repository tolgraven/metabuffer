-- [nfnl] fnl/metabuffer/buffer/prompt.fnl
local base_buffer_mod = require("metabuffer.buffer.base")
local directive_mod = require("metabuffer.query.directive")
local M = {}
local function set_prompt_completefunc_21()
  _G.__meta_directive_completefunc = directive_mod.completefunc
  return nil
end
local function apply_prompt_buffer_opts_21(buf)
  if (buf and vim.api.nvim_buf_is_valid(buf)) then
    set_prompt_completefunc_21()
    base_buffer_mod["apply-buffer-opts!"](buf, {buftype = "nofile", bufhidden = "hide", modifiable = true, completefunc = "v:lua.__meta_directive_completefunc", filetype = "metabufferprompt", swapfile = false})
  else
  end
  return buf
end
M["prepare-buffer!"] = function(buf)
  return apply_prompt_buffer_opts_21(buf)
end
M.new = function(buf)
  set_prompt_completefunc_21()
  return base_buffer_mod["register-managed-buffer!"](buf, "prompt", "[Metabuffer Prompt]", {buftype = "nofile", bufhidden = "hide", modifiable = true, completefunc = "v:lua.__meta_directive_completefunc", filetype = "metabufferprompt", swapfile = false}, nil)
end
M["sync-name!"] = function(session)
  if (session and session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and session.meta and session.meta.buf and (type(session.meta.buf.name) == "string") and (session.meta.buf.name ~= "")) then
    local name = (session.meta.buf.name .. " [Prompt]")
    pcall(vim.api.nvim_buf_set_name, session["prompt-buf"], name)
    return name
  else
    return nil
  end
end
M["clear-modified!"] = function(buf)
  return base_buffer_mod["clear-modified!"](buf)
end
return M
