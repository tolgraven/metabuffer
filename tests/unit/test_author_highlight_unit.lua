local ah = require('metabuffer.author_highlight')
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['author highlight buckets are stable and normalized'] = function()
  local a1 = ah['group-for-author']('Alice Example')
  local a2 = ah['group-for-author']('alice example')
  local a3 = ah['group-for-author']('  Alice Example  ')
  eq(a1, a2)
  eq(a1, a3)
end

T['author highlight buckets do not depend on call order'] = function()
  local target_before = ah['group-for-author']('Target Author')
  ah['group-for-author']('Other One')
  ah['group-for-author']('Other Two')
  ah['group-for-author']('Other Three')
  local target_after = ah['group-for-author']('Target Author')
  eq(target_before, target_after)
end

return T
