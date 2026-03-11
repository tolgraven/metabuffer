local all = require('metabuffer.matcher.all').new()
local fuzzy = require('metabuffer.matcher.fuzzy').new()
local regex = require('metabuffer.matcher.regex').new()
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

local function idxs(n)
  local out = {}
  for i = 1, n do
    out[i] = i
  end
  return out
end

T['all matcher filters literal tokens'] = function()
  local candidates = { 'alpha beta', 'beta gamma', 'alpha gamma' }
  local out = all.filter(all, 'alpha', idxs(#candidates), candidates, false)
  eq(out, { 1, 3 })
end

T['all matcher handles negation token'] = function()
  local candidates = { 'vim api', 'vim pcall', 'api pcall' }
  local out = all.filter(all, 'vim !pcall', idxs(#candidates), candidates, false)
  eq(out, { 1 })
end

T['all matcher supports anchors and escaped bang'] = function()
  local candidates = { 'meta', 'metabuffer', '!meta literal' }
  eq(all.filter(all, '^meta$', idxs(#candidates), candidates, false), { 1 })
  eq(all.filter(all, '\\!meta', idxs(#candidates), candidates, false), { 3 })
end

T['all matcher treats unclosed regex-like token as literal'] = function()
  local candidates = { '(let [x 1])', 'let keyword', '(if x)' }
  local out = all.filter(all, '(let', idxs(#candidates), candidates, false)
  eq(out, { 1 })
end

T['all matcher allows regex token inside all mode'] = function()
  local candidates = { 'valid abc', 'valid xyz', 'valid 123' }
  local out = all.filter(all, 'valid \\w.*', idxs(#candidates), candidates, false)
  eq(out, { 1, 2, 3 })
end

T['all matcher highlight excludes negated terms'] = function()
  local pats = all['get-highlight-pattern'](all, 'vim !pcall')
  eq(type(pats), 'table')
  eq(#pats, 1)
  eq(type(pats[1].pattern), 'string')
end

T['fuzzy matcher matches non contiguous query'] = function()
  local candidates = { 'metabuffer', 'meta', 'router' }
  local out = fuzzy.filter(fuzzy, 'mbr', idxs(#candidates), candidates, false)
  eq(out, { 1 })
end

T['regex matcher ANDs multiple tokens'] = function()
  local candidates = { 'valid abc', 'valid xyz', 'other xyz' }
  local out = regex.filter(regex, 'valid xyz', idxs(#candidates), candidates, false)
  eq(out, { 2 })
end

T['regex matcher returns empty on invalid regex token'] = function()
  local candidates = { 'alpha', 'beta' }
  local out = regex.filter(regex, '(', idxs(#candidates), candidates, false)
  eq(out, {})
end

return T
