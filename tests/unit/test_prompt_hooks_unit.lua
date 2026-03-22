local hooks_mod = require('metabuffer.prompt.hooks')
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['prompt hooks constructor returns hook table'] = function()
  local hooks = hooks_mod.new({
    ['mark-prompt-buffer!'] = function() end,
    ['default-prompt-keymaps'] = {},
    ['default-main-keymaps'] = {},
    ['active-by-prompt'] = {},
    ['on-prompt-changed'] = function() end,
    ['update-info-window'] = function() end,
    ['maybe-sync-from-main!'] = function() end,
    ['schedule-scroll-sync!'] = function() end,
    ['maybe-restore-hidden-ui!'] = function() end,
    ['hide-visible-ui!'] = function() end,
    ['maybe-refresh-preview-statusline!'] = function() end,
    ['sign-mod'] = nil,
  })

  eq(type(hooks), 'table')
  eq(type(hooks['register!']), 'function')
  eq(type(hooks['refresh!']), 'function')
end

return T
