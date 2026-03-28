local lgrep = require('metabuffer.source.lgrep')
local source = require('metabuffer.source')
local util = require('metabuffer.util')
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['collect-source-set groups lgrep results by file and expands chunk lines'] = function()
  local prev = _G.__meta_test_lgrep_runner
  _G.__meta_test_lgrep_runner = function(_settings, spec)
    if spec.query ~= 'setup' then
      return { count = 0, results = {} }
    end
    return {
      count = 2,
      results = {
        { file = 'lua/a.lua', line = 20, score = 0.8, chunk = 'local setup = true\nreturn setup' },
        { file = 'fnl/b.fnl', line = 4, score = 0.9, chunk = '(fn setup []\n  true)' },
      },
    }
  end

  local parsed = {
    ['lgrep-lines'] = {
      { kind = 'search', query = 'setup' },
    },
  }
  local cwd = vim.fn.getcwd()
  local pool = lgrep['collect-source-set']({ ['lgrep-limit'] = 20 }, parsed, function(path)
    local rel = path
    if vim.startswith(path, cwd .. '/') then
      rel = path:sub(#cwd + 2)
    end
    return '/tmp/root/' .. rel
  end)

  _G.__meta_test_lgrep_runner = prev

  eq(pool.content, {
    '(fn setup []',
    '  true)',
    'local setup = true',
    'return setup',
  })
  eq(pool.refs[1].path, '/tmp/root/fnl/b.fnl')
  eq(pool.refs[1].lnum, 4)
  eq(pool.refs[2].lnum, 5)
  eq(pool.refs[3].path, '/tmp/root/lua/a.lua')
  eq(pool.refs[3].lnum, 20)
  eq(pool.refs[4].lnum, 21)
end

T['source init resolves lgrep as active query source'] = function()
  local parsed = {
    ['lgrep-lines'] = {
      { kind = 'search', query = 'setup' },
    },
  }

  eq(source['query-source-key'](parsed), 'lgrep')
  eq(source['query-source-active?'](parsed), true)
  eq(source['query-source-signature'](parsed), 'lgrep:search:setup')
  eq(source['query-source-debounce-ms']({ ['lgrep-debounce-ms'] = 375 }, parsed), 375)
end

T['source marker signs differ between plain text and lgrep hits'] = function()
  local text_sign = util['icon-sign']({ category = '', name = '', fallback = '󰈔', hl = 'MetaSourceFile' })
  local lgrep_sign = util['icon-sign']({ category = 'lsp', name = 'reference', fallback = '', hl = 'MiniIconsCyan' })

  eq(vim.trim(text_sign.text) ~= '', true)
  eq(vim.trim(lgrep_sign.text) ~= '', true)
  eq(text_sign.text ~= lgrep_sign.text or text_sign.hl ~= lgrep_sign.hl, true)
end

T['source marker sign uses configured MiniIcons branch safely'] = function()
  local prev = _G.MiniIcons
  _G.MiniIcons = {
    get = function(category, name)
      if category == 'lsp' and name == 'reference' then
        return 'R', 'MiniIconsCyan', false
      end
      return 'T', 'MiniIconsGrey', false
    end,
  }

  local sign = util['icon-sign']({ category = 'lsp', name = 'reference', fallback = '', hl = 'MiniIconsCyan' })

  _G.MiniIcons = prev

  eq(sign.text, 'R')
  eq(sign.hl, 'MiniIconsCyan')
end

T['file-icon-info resolves MiniIcons file paths and extension highlights separately'] = function()
  local prev = _G.MiniIcons
  local calls = {}
  _G.MiniIcons = {
    get = function(category, name)
      table.insert(calls, { category = category, name = name })
      if category == 'file' then
        return 'F', 'MiniIconsBlue', false
      end
      if category == 'extension' then
        return 'E', 'MiniIconsGreen', false
      end
      return '', '', false
    end,
  }

  local info = util['file-icon-info']('/tmp/nested/demo.lua', 'Normal')

  _G.MiniIcons = prev

  eq(info.icon, 'F')
  eq(info['icon-hl'], 'MiniIconsBlue')
  eq(info['ext-hl'], 'MiniIconsGreen')
  eq(info['file-hl'], 'Normal')
  eq(calls[1].category, 'file')
  eq(calls[1].name, '/tmp/nested/demo.lua')
  eq(calls[2].category, 'extension')
  eq(calls[2].name, 'lua')
end

T['source markers cover plain text file, file source, and lgrep source kinds'] = function()
  local text_sign = util['icon-sign']({ category = '', name = '', fallback = '󰈔', hl = 'MetaSourceFile' })
  local file_sign = util['icon-sign']({ category = 'directory', name = '.', fallback = '󰉋', hl = 'MiniIconsAzure' })
  local lgrep_sign = util['icon-sign']({ category = 'lsp', name = 'reference', fallback = '', hl = 'MiniIconsCyan' })

  eq(text_sign.text, '󰈔')
  eq(text_sign.hl, 'MetaSourceFile')
  eq(vim.trim(file_sign.text) ~= '', true)
  eq(vim.trim(lgrep_sign.text) ~= '', true)
  eq(file_sign.text ~= lgrep_sign.text or file_sign.hl ~= lgrep_sign.hl, true)
end

return T
