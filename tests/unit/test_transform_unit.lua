local transform = require('metabuffer.transform')
local custom = require('metabuffer.custom')
local b64 = require('metabuffer.transform.b64')
local bplist = require('metabuffer.transform.bplist')
local css = require('metabuffer.transform.css')
local hex = require('metabuffer.transform.hex')
local json = require('metabuffer.transform.json')
local strings = require('metabuffer.transform.strings')
local xml = require('metabuffer.transform.xml')
local eq = MiniTest.expect.equality

local function write_binary(path, bytes)
  local uv = vim.uv or vim.loop
  local fd = uv.fs_open(path, 'w', 438)
  uv.fs_write(fd, string.char(unpack(bytes)))
  uv.fs_close(fd)
end

local T = MiniTest.new_set()

T['enabled-map resolves transform toggles from parsed and session state'] = function()
  local flags = transform['enabled-map'](
    { ['include-json'] = true, ['include-b64'] = false },
    { ['effective-transforms'] = { css = true } },
    {}
  )

  eq(flags.json, true)
  eq(flags.b64, false)
  eq(flags.css, true)
  eq(flags.hex, false)
end

T['hex transform only applies to binary files'] = function()
  eq(hex['should-apply-file?']('/tmp/a.bin', {}, { binary = true }), true)
  eq(hex['should-apply-file?']('/tmp/a.txt', {}, { binary = false }), false)
end

T['hex transform renders deterministic hex and ascii columns'] = function()
  local path = vim.fn.tempname()
  write_binary(path, { 137, 80, 78, 71, 13, 10, 26, 10, 73, 72, 68, 82 })
  local out = hex['apply-file'](path, {}, { binary = true, size = 12 })
  eq(type(out), 'table')
  eq(out[1], 'binary 1 KB')
  eq(out[2], '00000000: 89 50 4E 47 0D 0A 1A 0A  49 48 44 52              .PNG....IHDR')
end

T['bplist transform only applies to binary plist files'] = function()
  eq(bplist['should-apply-file?']('/tmp/a', {}, { binary = true, head = 'bplist00abc' }), true)
  eq(bplist['should-apply-file?']('/tmp/a', {}, { binary = true, head = 'PNG....' }), false)
end

T['bplist transform reverses xml plist lines back to binary plist bytes'] = function()
  local blob = bplist['reverse-file']({
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">',
    '<plist version="1.0">',
    '<dict>',
    '  <key>alpha</key>',
    '  <string>beta</string>',
    '</dict>',
    '</plist>',
  }, {})

  eq(type(blob), 'string')
  eq(string.sub(blob, 1, 8), 'bplist00')
end

T['strings transform only applies to binary files'] = function()
  eq(strings['should-apply-file?']('/tmp/a.bin', {}, { binary = true }), true)
  eq(strings['should-apply-file?']('/tmp/a.txt', {}, { binary = false }), false)
end

T['strings transform extracts printable binary strings deterministically'] = function()
  local path = vim.fn.tempname()
  write_binary(path, { 0, 73, 72, 68, 82, 0, 73, 68, 65, 84, 0, 73, 69, 78, 68, 0 })
  local out = strings['apply-file'](path, {}, { binary = true, size = 16 })
  eq(type(out), 'table')
  eq(out[1], 'binary 1 KB')
  eq(out[2], 'IHDR')
  eq(out[3], 'IDAT')
  eq(out[4], 'IEND')
end

T['strings transform reverse-file patches extracted strings back into the binary'] = function()
  local path = vim.fn.tempname()
  write_binary(path, { 0, 73, 72, 68, 82, 0, 73, 68, 65, 84, 0, 73, 69, 78, 68, 0 })

  local blob = strings['reverse-file']({
    'binary 1 KB',
    'XHDR',
    'IDAT',
    'IEND',
  }, { path = path })

  eq(type(blob), 'string')
  eq(blob:find('XHDR', 1, true) ~= nil, true)
  eq(blob:find('IHDR', 1, true) == nil, true)
end

T['b64 transform decodes obvious base64 payloads'] = function()
  local line = 'U29tZSBsb25nZXIgYmFzZTY0IHRleHQgd2l0aCBuZXdsaW5lcw=='
  eq(b64['should-apply-line?'](line, {}), true)
  eq(type(b64['apply-line'](line, {})), 'table')
end

T['b64 transform recurses through nested base64 payloads'] = function()
  local nested = 'U0dWc2JHOGdkMjl5YkdRPQ=='
  local out = b64['apply-line'](nested, {})
  eq(type(out), 'table')
  eq(table.concat(out, '\n'), 'Hello world')
end

T['b64 transform reverse-line encodes edited content back to base64'] = function()
  local out = b64['reverse-line']({ 'Hello world' }, {})
  eq(type(out), 'table')
  eq(out[1], 'SGVsbG8gd29ybGQ=')
end

T['json xml and css transforms pretty-print minified lines'] = function()
  local json_lines = json['apply-line']('{"alpha":1,"beta":{"gamma":2}}', {})
  local xml_lines = xml['apply-line']('<root><child>v</child><child2/></root>', {})
  local css_lines = css['apply-line']('body{color:red;background:blue}.x{display:block}', {})

  eq(type(json_lines), 'table')
  eq(type(xml_lines), 'table')
  eq(type(css_lines), 'table')
  eq(#json_lines > 1, true)
  eq(#xml_lines > 1, true)
  eq(#css_lines > 1, true)
end

T['json xml and css reverse-line compact rendered lines back to one source line'] = function()
  eq(json['reverse-line']({ '{', '  "alpha": 1', '}' }, {})[1], '{"alpha":1}')
  eq(xml['reverse-line']({ '<root>', '  <child>v</child>', '</root>' }, {})[1], '<root><child>v</child></root>')
  eq(css['reverse-line']({ 'body {', '  color:red;', '}' }, {})[1], 'body {color:red;}')
end

T['apply-view preserves source line ownership for expanded transformed lines'] = function()
  local view = transform['apply-view'](
    '/tmp/a.txt',
    {
      'plain',
      '{"alpha":1,"beta":{"gamma":2},"delta":{"epsilon":3},"zeta":7}',
      'tail',
    },
    { binary = false, transforms = { json = true } }
  )

  eq(view['line-map'][1], 1)
  eq(view['line-map'][2], 2)
  eq(view['line-map'][#view['line-map']], 3)
  eq(#view.lines > 3, true)
end

T['apply-view keeps row metadata for reverse writeback'] = function()
  local view = transform['apply-view'](
    '/tmp/a.txt',
    { '{"alpha":1,"beta":2,"gamma":3,"delta":4,"epsilon":{"nested":true}}' },
    { binary = false, transforms = { json = true }, ['wrap-width'] = 8, linebreak = false }
  )

  eq(type(view['row-meta']), 'table')
  eq(view['row-meta'][1]['source-group-id'], 1)
  eq(view['row-meta'][1]['source-group-kind'], 'line')
  eq(view['row-meta'][1]['source-text'], '{"alpha":1,"beta":2,"gamma":3,"delta":4,"epsilon":{"nested":true}}')
  eq(view['row-meta'][1]['transform-chain'][1], 'json')
  eq(view['row-meta'][2]['source-group-id'], 1)
end

T['reverse-group collapses wrapped pretty json back to compact source line'] = function()
  local reversed = transform['reverse-group'](
    {
      ['source-group-kind'] = 'line',
      ['transform-chain'] = { 'json' },
      ['source-text'] = '{"alpha":1,"beta":2}',
    },
    { '{', '  "alpha": 3,', '  "beta": 2', '}' },
    {}
  )

  eq(reversed.kind, 'replace')
  eq(reversed.text, '{"alpha":3,"beta":2}')
end

T['reverse-group writes strings transforms back as rewritten bytes'] = function()
  local reversed = transform['reverse-group'](
    {
      ['source-group-kind'] = 'file',
      ['transform-chain'] = { 'strings' },
    },
    { 'binary 1 KB', 'XHDR', 'IDAT', 'IEND' },
    {
      path = (function()
        local path = vim.fn.tempname()
        write_binary(path, { 0, 73, 72, 68, 82, 0, 73, 68, 65, 84, 0, 73, 69, 78, 68, 0 })
        return path
      end)(),
    }
  )

  eq(reversed.kind, 'rewrite-bytes')
  eq(type(reversed.bytes), 'string')
  eq(reversed.bytes:find('XHDR', 1, true) ~= nil, true)
end

T['hex reverse-file parses rendered hex view back to bytes'] = function()
  local blob = hex['reverse-file']({
    'binary 1 KB',
    '00000000: 89 50 4E 47 0D 0A 1A 0A  49 48 44 52              .PNG....IHDR',
  }, {})

  eq(type(blob), 'string')
  eq(#blob, 12)
  eq(string.byte(blob, 1), 137)
  eq(string.byte(blob, 12), 82)
end

T['custom line transform runs shell commands forward and backward'] = function()
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
    local flags = transform['enabled-map'](
      { ['include-custom-transform:upper'] = true },
      {},
      {}
    )
    local view = transform['apply-view'](
      '/tmp/a.txt',
      { 'hello world' },
      { binary = false, transforms = flags }
    )
    local reversed = transform['reverse-group'](
      view['row-meta'][1],
      { 'CHANGED TEXT' },
      {}
    )

    eq(flags['custom-transform:upper'], true)
    eq(view.lines[1], 'HELLO WORLD')
    eq(reversed.kind, 'replace')
    eq(reversed.text, 'changed text')
  end)

  custom['configure!'](prev)
  if not ok then error(err) end
end

T['custom transforms can be gated by detected filetype'] = function()
  local prev = custom.config()
  custom['configure!']({
    transforms = {
      pyupper = {
        from = { 'tr', 'a-z', 'A-Z' },
        to = { 'tr', 'A-Z', 'a-z' },
        filetypes = { 'python' },
        doc = 'Uppercase python lines.',
      },
    },
  })

  local ok, err = pcall(function()
    local flags = transform['enabled-map'](
      { ['include-custom-transform:pyupper'] = true },
      {},
      {}
    )
    local py = transform['apply-view'](
      '/tmp/sample.py',
      { 'print("hello")' },
      { binary = false, path = '/tmp/sample.py', transforms = flags }
    )
    local txt = transform['apply-view'](
      '/tmp/sample.txt',
      { 'print("hello")' },
      { binary = false, path = '/tmp/sample.txt', transforms = flags }
    )

    eq(py.lines[1], 'PRINT("HELLO")')
    eq(txt.lines[1], 'print("hello")')
  end)

  custom['configure!'](prev)
  if not ok then error(err) end
end

T['custom transforms can choose different commands by detected filetype'] = function()
  local prev = custom.config()
  custom['configure!']({
    transforms = {
      decompile = {
        from = { 'tr', 'a-z', 'A-Z' },
        applies_to = 'all',
        filetype_commands = {
          python = {
            from = { 'tr', 'a-z', 'A-Z' },
            to = { 'tr', 'A-Z', 'a-z' },
          },
          lua = {
            from = { 'tr', 'a-z', 'A-Z' },
            to = { 'tr', 'A-Z', 'a-z' },
          },
        },
        doc = 'Example decompile transform.',
      },
    },
  })

  local ok, err = pcall(function()
    local flags = transform['enabled-map'](
      { ['include-custom-transform:decompile'] = true },
      {},
      {}
    )
    local py = transform['apply-view'](
      '/tmp/sample.pyc',
      { 'print("hello")' },
      { binary = true, path = '/tmp/sample.py', transforms = flags }
    )
    local lua_view = transform['apply-view'](
      '/tmp/sample.luac',
      { 'print("world")' },
      { binary = true, path = '/tmp/sample.lua', transforms = flags }
    )
    local txt = transform['apply-view'](
      '/tmp/sample.txt',
      { 'print("plain")' },
      { binary = false, path = '/tmp/sample.txt', transforms = flags }
    )
    local reversed = transform['reverse-group'](
      py['row-meta'][1],
      { 'CHANGED PYTHON' },
      { path = '/tmp/sample.py' }
    )

    eq(py.lines[1], 'PRINT("HELLO")')
    eq(lua_view.lines[1], 'PRINT("WORLD")')
    eq(txt.lines[1], 'PRINT("PLAIN")')
    eq(reversed.kind, 'replace')
    eq(reversed.text, 'changed python')
  end)

  custom['configure!'](prev)
  if not ok then error(err) end
end

return T
