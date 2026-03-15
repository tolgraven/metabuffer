local util = require('metabuffer.util')
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['split-input trims and splits on spaces'] = function()
  eq(util['split-input']('  alpha   beta  '), { 'alpha', 'beta' })
  eq(util['split-input'](''), {})
end

T['convert2regex-pattern joins by alternation'] = function()
  eq(util['convert2regex-pattern']('alpha beta gamma'), 'alpha\\|beta\\|gamma')
end

T['ext-from-path keeps last segment extension semantics'] = function()
  eq(util['ext-from-path']('lua/metabuffer/util.lua'), 'lua')
  eq(util['ext-from-path']('.gitignore'), 'gitignore')
  eq(util['ext-from-path']('README'), '')
end

T['escape-vim-pattern escapes special chars'] = function()
  eq(util['escape-vim-pattern']('a.b[c]$'), 'a\\.b\\[c\\]\\$')
end

T['query-is-lower identifies lowercase-only queries'] = function()
  eq(util['query-is-lower']('meta'), true)
  eq(util['query-is-lower']('Meta'), false)
end

T['clamp bounds values'] = function()
  eq(util.clamp(5, 1, 10), 5)
  eq(util.clamp(0, 1, 10), 1)
  eq(util.clamp(11, 1, 10), 10)
end

return T
