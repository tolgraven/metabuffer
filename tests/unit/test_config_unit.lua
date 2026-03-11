local config = require('metabuffer.config')
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['defaults expose prompt and main keymaps'] = function()
  local d = config.defaults
  eq(type(d), 'table')
  eq(type(d.keymaps), 'table')
  eq(type(d.keymaps.prompt), 'table')
  eq(type(d.keymaps.main), 'table')
  eq(#d.keymaps.prompt > 0, true)
  eq(#d.keymaps.main > 0, true)
end

T['resolve reads nested keymaps overrides'] = function()
  local resolved = config.resolve({
    keymaps = {
      prompt = { { 'i', '<C-a>', 'prompt-home' } },
      main = { { 'n', '<CR>', 'accept-main' } },
      prompt_fallback = { { 'i', '<C-e>', 'prompt-end' } },
    },
  })

  eq(type(resolved.keymaps.prompt), 'table')
  eq(type(resolved.keymaps.main), 'table')
  eq(type(resolved.keymaps.prompt_fallback), 'table')
  eq(#resolved.keymaps.prompt, 1)
  eq(#resolved.keymaps.main, 1)
end

T['resolve preserves debounce defaults when options absent'] = function()
  local resolved = config.resolve({})
  eq(type(resolved.options.prompt_update_debounce_ms), 'number')
  eq(resolved.options.prompt_update_debounce_ms >= 0, true)
end

return T
