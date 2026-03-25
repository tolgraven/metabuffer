local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['headless :Meta! launch in real repo does not emit startup error'] = function()
  local root = vim.fn.getcwd()
  local cmd = {
    vim.v.progpath,
    '--headless',
    '-u', root .. '/tests/minimal_init.lua',
    '-n',
    '-i', 'NONE',
    '-c', 'cd ' .. root,
    '-c', 'edit README.md',
    '-c', 'Meta!',
    '-c', 'sleep 400m',
    '-c', 'messages',
    '-c', 'qa!',
  }

  local out = vim.fn.system(cmd)
  local rc = vim.v.shell_error

  eq(rc, 0)
  eq(type(out), 'string')
  eq(out:find('bad argument #1 to \'start\'', 1, true) == nil, true)
  eq(out:find('_core/editor.lua', 1, true) == nil, true)
  eq(out:find('stack traceback', 1, true) == nil, true)
end

return T
