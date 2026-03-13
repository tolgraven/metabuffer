local expand = require('metabuffer.context.expand')
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['normalized-mode maps aliases to canonical expansion names'] = function()
  eq(expand['normalized-mode'](''), 'none')
  eq(expand['normalized-mode']('off'), 'none')
  eq(expand['normalized-mode']('context'), 'around')
  eq(expand['normalized-mode']('function'), 'fn')
  eq(expand['normalized-mode']('type'), 'class')
  eq(expand['normalized-mode']('block'), 'scope')
  eq(expand['normalized-mode']('buffer'), 'file')
  eq(expand['normalized-mode']('references'), 'usage')
end

T['context-blocks returns line-scoped block for line mode'] = function()
  local session = {}
  local path = vim.fn.tempname() .. '.lua'
  local refs = {
    {
      path = path,
      lnum = 2,
      kind = 'text',
    },
  }
  local lines = {
    'local alpha = 1',
    'local beta = alpha + 1',
    'return alpha + beta',
  }
  vim.fn.writefile(lines, path)

  local blocks = expand['context-blocks'](session, refs, {
    mode = 'line',
    ['around-lines'] = 3,
    ['max-blocks'] = 10,
    ['read-file-lines-cached'] = function(path)
      eq(path, refs[1].path)
      return lines
    end,
  })

  eq(#blocks, 1)
  eq(blocks[1].start_lnum or blocks[1]['start-lnum'], 2)
  eq(blocks[1].end_lnum or blocks[1]['end-lnum'], 2)
  eq(blocks[1].lines, { 'local beta = alpha + 1' })

  vim.fn.delete(path)
end

return T
