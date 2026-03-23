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

T['collapsed displayed segments keep original segment bucket colors'] = function()
  local ranges = ph['ranges-for-dir']('f/m/', 0, 'fnl/metabuffer')
  eq(type(ranges), 'table')
  eq(ranges[1].hl, ph['group-for-segment']('fnl'))
  eq(ranges[3].hl, ph['group-for-segment']('metabuffer'))
end

T['collapsed first and last displayed segments map to first and last originals'] = function()
  local ranges = ph['ranges-for-dir']('f/router/', 0, 'fnl/metabuffer/router')
  eq(type(ranges), 'table')
  eq(ranges[1].hl, ph['group-for-segment']('fnl'))
  eq(ranges[3].hl, ph['group-for-segment']('router'))
end

return T
