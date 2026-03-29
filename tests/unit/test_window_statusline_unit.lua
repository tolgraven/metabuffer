local statusline = require('metabuffer.window.statusline')
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['render-path uses separate icon and extension highlight groups'] = function()
  local prev = _G.MiniIcons
  _G.MiniIcons = {
    get = function(category, name)
      if category == 'file' and name == '/tmp/demo.lua' then
        return 'F', 'MiniIconsBlue', false
      end
      if category == 'extension' and name == 'lua' then
        return 'E', 'MiniIconsGreen', false
      end
      return '', '', false
    end,
  }

  local rendered = statusline['render-path']('/tmp/demo.lua', {
    default_text = 'Preview',
    base_group = 'MetaPreviewStatusline',
    file_group = 'MetaPreviewStatuslinePathFile',
  })

  _G.MiniIcons = prev

  eq(rendered:find('%%#MiniIconsBlue#F ', 1) ~= nil, true)
  eq(rendered:find('%%#MetaPreviewStatuslinePathFile#demo', 1) ~= nil, true)
  eq(rendered:find('%%#MiniIconsGreen#.lua', 1) ~= nil, true)
end

return T
