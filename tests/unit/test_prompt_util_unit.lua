local prompt_util = require('metabuffer.prompt.util')
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['build_echon_expr escapes slashes and quotes'] = function()
  eq(
    prompt_util.build_echon_expr('say "hi" \\ there', 'Special'),
    'echohl Special|echon "say \\"hi\\" \\\\ there"'
  )
end

return T
