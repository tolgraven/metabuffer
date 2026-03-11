local query = require('metabuffer.query')
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['truthy? handles canonical truthy values'] = function()
  eq(query['truthy?'](true), true)
  eq(query['truthy?'](1), true)
  eq(query['truthy?']('1'), true)
  eq(query['truthy?']('true'), true)
  eq(query['truthy?']('yes'), false)
  eq(query['truthy?'](0), false)
end

T['parse-query-lines consumes project flags and keeps search text'] = function()
  local parsed = query['parse-query-lines']({ '#hidden #deps #nolazy alpha beta' })
  eq(parsed.hidden, true)
  eq(parsed.deps, true)
  eq(parsed.lazy, false)
  eq(parsed.lines, { 'alpha beta' })
end

T['parse-query-lines supports saved tag tokens and history token'] = function()
  local parsed = query['parse-query-lines']({ '#history #save:quick ##foo body' })
  eq(parsed.history, true)
  eq(parsed['save-tag'], 'quick')
  eq(parsed['saved-tag'], 'foo')
  eq(parsed.lines, { 'body' })
end

T['parse-query-lines keeps escaped control tokens literal'] = function()
  local parsed = query['parse-query-lines']({ '\\#deps token' })
  eq(parsed.deps, nil)
  eq(parsed.lines, { '\\#deps token' })
end

T['parse-query-text merges multiline settings and returns stripped query'] = function()
  local parsed = query['parse-query-text']('alpha\n#deps\n#nohidden beta')
  eq(parsed.query, 'alpha\n\nbeta')
  eq(parsed['include-deps'], true)
  eq(parsed['include-hidden'], false)
end

T['parse-query-lines honors custom prefix for options'] = function()
  local prev = vim.g['meta#prefix']
  vim.g['meta#prefix'] = '@'
  local parsed = query['parse-query-lines']({ '@deps @hidden token' })
  vim.g['meta#prefix'] = prev

  eq(parsed.deps, true)
  eq(parsed.hidden, true)
  eq(parsed.lines, { 'token' })
end

T['query-lines-has-active? ignores blank lines'] = function()
  eq(query['query-lines-has-active?']({ '', '   ', '\t' }), false)
  eq(query['query-lines-has-active?']({ '', ' x ' }), true)
end

return T
