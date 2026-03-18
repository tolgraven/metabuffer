local H = require('tests.screen.support.screen_helpers')
local eq = H.eq
local json = vim.json or require('vim.json')

local T = MiniTest.new_set({ hooks = H.case_hooks() })

local function hidden_meta_buffers()
  local raw = H.child.lua_get([[
    (function()
      local out = {}
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.fn.buflisted(buf) == 0 then
          local name = vim.api.nvim_buf_get_name(buf)
          local ok_prompt, is_prompt = pcall(vim.api.nvim_buf_get_var, buf, 'meta_prompt')
          local ok_preview, is_preview = pcall(vim.api.nvim_buf_get_var, buf, 'meta_preview')
          if (ok_prompt and is_prompt) or (ok_preview and is_preview) or string.find(name, 'Metabuffer', 1, true) then
            out[#out + 1] = { buf = buf, name = name, prompt = not not is_prompt, preview = not not is_preview }
          end
        end
      end
      return vim.json.encode(out)
    end)()
  ]])
  return json.decode(raw)
end

T['cancel wipes hidden prompt and preview buffers'] = H.timed_case(function()
  H.open_meta_with_lines({ 'alpha one', 'alpha two', 'beta three' })
  H.child.lua([[
    local router = require('metabuffer.router')
    local session = router['active-by-source'][_G.__meta_source_buf]
    assert(session and session['prompt-buf'], 'missing session prompt buf')
    router.cancel(session['prompt-buf'])
  ]])
  H.wait_for(function()
    return H.child.lua_get("next(require('metabuffer.router')['active-by-source']) == nil")
  end, 3000)

  local leaked = hidden_meta_buffers()
  eq(#leaked, 0)
end)

T['accept preserves only named metabuffer result state'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)
  H.child.lua([[
    local router = require('metabuffer.router')
    local session = router['active-by-source'][_G.__meta_source_buf]
    assert(session and session['prompt-buf'], 'missing session prompt buf')
    router.accept(session['prompt-buf'])
  ]])
  vim.loop.sleep(300)

  local leaked = hidden_meta_buffers()
  eq(#leaked >= 1, true)
  for _, item in ipairs(leaked) do
    eq(item.preview, false)
    eq(item.name ~= '', true)
    eq(string.find(item.name, 'Prompt', 1, true) ~= nil or string.find(item.name, 'Metabuffer', 1, true) ~= nil, true)
  end
end)

return T
