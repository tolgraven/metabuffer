local query = require('metabuffer.query')
local directive = require('metabuffer.query.directive')
local custom = require('metabuffer.custom')
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

T['parse-query-lines supports short project flags'] = function()
  local parsed = query['parse-query-lines']({ '#hi #i #-d #b token' })
  eq(parsed['include-hidden'], true)
  eq(parsed['include-ignored'], true)
  eq(parsed['include-deps'], false)
  eq(parsed['include-binary'], true)
  eq(parsed.lines, { 'token' })
end

T['parse-query-lines consumes expansion directives and keeps search text'] = function()
  local parsed = query['parse-query-lines']({ '#exp:fn alpha beta' })
  eq(parsed.expansion, 'fn')
  eq(parsed.lines, { 'alpha beta' })
end

T['parse-query-lines supports prompt control short forms'] = function()
  local parsed = query['parse-query-lines']({ '#p #-lazy #e token' })
  eq(parsed.prefilter, false)
  eq(parsed.lazy, false)
  eq(parsed.lines, { 'token' })
end

T['parse-query-lines consumes inline file filter and keeps other line text'] = function()
  local parsed = query['parse-query-lines']({ 'alpha #file:README.md', 'beta' })
  eq(parsed.files, true)
  eq(parsed['include-files'], true)
  eq(parsed['file-lines'], { 'README.md' })
  eq(parsed.lines, { 'alpha', 'beta' })
end

T['parse-query-lines captures lgrep token and leaves remaining filters in normal query'] = function()
  local parsed = query['parse-query-lines']({ '#lg setup alpha beta' })
  eq(parsed['lgrep-lines'], { { kind = 'search', query = 'setup' } })
  eq(parsed.lines, { 'alpha beta' })
end

T['parse-query-lines supports quoted lgrep query and command variants'] = function()
  local parsed = query['parse-query-lines']({ '#lg:u "setup paths" alpha', "#lg:d build beta" })
  eq(parsed['lgrep-lines'], {
    { kind = 'usages', query = 'setup paths' },
    { kind = 'definition', query = 'build' },
  })
  eq(parsed.lines, { 'alpha', 'beta' })
end

T['parse-query-lines supports full lgrep directive aliases'] = function()
  local parsed = query['parse-query-lines']({ '#lgrep:u "setup paths" alpha', '#lgrep search beta' })
  eq(parsed['lgrep-lines'], {
    { kind = 'usages', query = 'setup paths' },
    { kind = 'search', query = 'search' },
  })
  eq(parsed.lines, { 'alpha', 'beta' })
end

T['parse-query-lines keeps additional tokens after inline file filter in normal query'] = function()
  local parsed = query['parse-query-lines']({ '#file:query lua', 'meta #file:src now' })
  eq(parsed['file-lines'], { 'query', 'src' })
  eq(parsed.lines, { 'lua', 'meta now' })
end

T['parse-query-lines keeps bare #file as mode toggle without consuming next token'] = function()
  local prev = vim.g['meta#prefix']
  vim.g['meta#prefix'] = '#'
  local parsed = query['parse-query-lines']({ '#file lua' })
  vim.g['meta#prefix'] = prev
  eq(parsed['include-files'], true)
  eq(parsed['file-lines'], {})
  eq(parsed.lines, { 'lua' })
end

T['parse-query-lines supports short inline file alias with quoted filters'] = function()
  local parsed = query['parse-query-lines']({ '#f:\"lua core\" meta' })
  eq(parsed['file-lines'], { 'lua core' })
  eq(parsed.lines, { 'meta' })
end

T['parse-query-lines no longer consumes legacy spaced file argument syntax'] = function()
  local parsed = query['parse-query-lines']({ '#f lua meta' })
  eq(parsed['include-files'], true)
  eq(parsed['file-lines'], {})
  eq(parsed.lines, { 'lua meta' })
end

T['parse-query-lines supports explicit file disable after inline file filter'] = function()
  local parsed = query['parse-query-lines']({ '#file:lua #-f meta' })
  eq(parsed['file-lines'], { 'lua' })
  eq(parsed['include-files'], false)
  eq(parsed.lines, { 'meta' })
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
  eq(parsed.lines, { '#deps token' })
end

T['parse-query-lines consumes binary and hex flags into settings'] = function()
  local parsed = query['parse-query-lines']({ '#binary #hex token' })
  eq(parsed['include-binary'], true)
  eq(parsed['include-hex'], true)
  eq(parsed.lines, { 'token' })
end

T['parse-query-lines supports short hex alias'] = function()
  local parsed = query['parse-query-lines']({ '#he token' })
  eq(parsed['include-hex'], true)
  eq(parsed.lines, { 'token' })
end

T['parse-query-lines supports explicit binary and hex disable flags'] = function()
  local parsed = query['parse-query-lines']({ '#binary #hex #-binary #-hex token' })
  eq(parsed['include-binary'], false)
  eq(parsed['include-hex'], false)
  eq(parsed.lines, { 'token' })
end

T['parse-query-lines consumes additional transform flags into settings'] = function()
  local parsed = query['parse-query-lines']({ '#b64 #json #xml #css #bplist #strings token' })
  eq(parsed['include-b64'], true)
  eq(parsed['include-json'], true)
  eq(parsed['include-xml'], true)
  eq(parsed['include-css'], true)
  eq(parsed['include-bplist'], true)
  eq(parsed['include-strings'], true)
  eq(parsed.lines, { 'token' })
end

T['parse-query-text merges multiline settings and returns stripped query'] = function()
  local parsed = query['parse-query-text']('alpha\n#deps\n#nohidden beta')
  eq(parsed.query, 'alpha\n\nbeta')
  eq(parsed.lines, { 'alpha', '', 'beta' })
  eq(parsed['include-deps'], true)
  eq(parsed['include-hidden'], false)
end

T['parse-query-text includes file directives'] = function()
  local parsed = query['parse-query-text']('#file:README.md\nmeta')
  eq(parsed['include-files'], true)
  eq(parsed['file-lines'], { 'README.md' })
  eq(parsed.query, '\nmeta')
end

T['apply-default-source promotes first token into default source query when enabled'] = function()
  local parsed = query['apply-default-source'](query['parse-query-text']('setup alpha beta'), true)
  eq(parsed['lgrep-lines'], { { kind = 'search', query = 'setup' } })
  eq(parsed.lines, { 'alpha beta' })
  eq(parsed.query, 'alpha beta')
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

T['directive catalog derives short forms by domain priority'] = function()
  local items = directive['catalog']('#')
  local by_long = {}
  for _, item in ipairs(items) do
    by_long[item.long] = item
  end

  eq(by_long.history.short, 'h')
  eq(by_long.hidden.short, 'hi')
  eq(by_long.hex.short, 'he')
  eq(by_long.b64.short, 'b6')
  eq(by_long.bplist.short, 'bp')
  eq(by_long.json.short, 'j')
  eq(by_long.strings.short, 'st')
  eq(by_long.xml.short, 'x')
  eq(by_long.css.short, 'c')
  eq(by_long.file.short, 'f')
  eq(by_long.lgrep.short, 'lg')
end

T['directive completion exposes registry-driven help'] = function()
  local items = directive['complete-items']('#', '#lg')
  eq(#items > 0, true)
  eq(items[1].info:match('lgrep') ~= nil, true)
end

T['custom transform directives are registry-driven and parse without query hardcoding'] = function()
  local prev = custom.config()
  custom['configure!']({
    transforms = {
      upper = {
        from = { 'tr', 'a-z', 'A-Z' },
        to = { 'tr', 'A-Z', 'a-z' },
        doc = 'Uppercase lines.',
      },
    },
  })

  local ok, err = pcall(function()
    local parsed = query['parse-query-lines']({ '#transform:upper token' })
    local items = directive['catalog']('#')
    local by_long = {}
    for _, item in ipairs(items) do
      by_long[item.long] = item
    end

    eq(parsed['include-custom-transform:upper'], true)
    eq(parsed.lines, { 'token' })
    eq(by_long['transform:upper'].short, 't:upper')
    eq(by_long['transform:upper'].doc, 'Uppercase lines.')
  end)

  custom['configure!'](prev)
  if not ok then error(err) end
end

return T
