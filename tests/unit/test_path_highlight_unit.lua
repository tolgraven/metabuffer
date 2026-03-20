local ph = require('metabuffer.path_highlight')
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['path highlight buckets are stable and normalized'] = function()
  local a1 = ph['group-for-segment']('src')
  local a2 = ph['group-for-segment']('SRC')
  local a3 = ph['group-for-segment']('  src  ')
  eq(a1, a2)
  eq(a1, a3)
end

T['path highlight buckets do not depend on call order'] = function()
  local target_before = ph['group-for-segment']('preview')
  ph['group-for-segment']('alpha')
  ph['group-for-segment']('beta')
  ph['group-for-segment']('gamma')
  local target_after = ph['group-for-segment']('preview')
  eq(target_before, target_after)
end

return T
