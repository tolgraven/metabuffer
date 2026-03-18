local session_mod = require('metabuffer.router.session')
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['project-start-selected-index uses current source line for project start'] = function()
  eq(session_mod['project-start-selected-index'](true, 'start', { lnum = 37 }, { ['selected-index'] = 0 }), 36)
end

T['project-start-selected-index falls back to condition selection when source line is missing'] = function()
  eq(session_mod['project-start-selected-index'](true, 'start', {}, { ['selected-index'] = 4 }), 4)
end

T['project-start-selected-index leaves non-project starts unchanged'] = function()
  eq(session_mod['project-start-selected-index'](false, 'start', { lnum = 37 }, { ['selected-index'] = 2 }), 2)
  eq(session_mod['project-start-selected-index'](true, 'resume', { lnum = 37 }, { ['selected-index'] = 2 }), 2)
end

return T
