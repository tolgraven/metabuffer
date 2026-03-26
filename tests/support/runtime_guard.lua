local M = {}

local BAD_PATTERNS = {
  'stack traceback',
  'vim.schedule callback:',
  'Lua :command callback:',
  'torn down after error',
  '_core/editor.lua',
  'E5108:',
  'Error in function ',
}

local function trim(s)
  if type(s) ~= 'string' then
    return ''
  end
  return s:gsub('^%s+', ''):gsub('%s+$', '')
end

function M.clear()
  vim.v.errmsg = ''
  pcall(vim.cmd, 'messages clear')
end

function M.drain(ms)
  pcall(vim.wait, ms or 20, function() return false end, 5)
end

function M.messages_output()
  local ok, out = pcall(function()
    return vim.api.nvim_exec2('silent messages', { output = true }).output or ''
  end)
  return ok and out or ''
end

function M.bad_message(messages)
  local text = trim(messages)
  if text == '' then
    return nil, text
  end
  for _, pat in ipairs(BAD_PATTERNS) do
    if text:find(pat, 1, true) ~= nil then
      return pat, text
    end
  end
  return nil, text
end

function M.assert_clean(eq_fn)
  local eq = eq_fn or function(a, b)
    assert(a == b, string.format('expected %s, got %s', vim.inspect(b), vim.inspect(a)))
  end

  M.drain()

  local errmsg = trim(vim.v.errmsg or '')
  eq(errmsg, '')

  local bad, text = M.bad_message(M.messages_output())
  if bad ~= nil then
    io.stdout:write('[runtime-guard] unexpected :messages output follows\n')
    io.stdout:write(text .. '\n')
  end
  eq(bad == nil, true)
end

return M
