local H = require('tests.screen.support.screen_helpers')
local child = H.child

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['Meta startup is safe with global FileType Tree-sitter autocmd'] = H.timed_case(function()
  child.lua([[
    vim.api.nvim_create_autocmd('FileType', {
      pattern = '*',
      callback = function(args)
        if not vim.treesitter then return end
        pcall(vim.treesitter.start, args.buf, vim.bo[args.buf].filetype)
      end,
    })
  ]])

  local path = H.write_temp_file({
    'local function demo(x)',
    '  return x + 1',
    'end',
    'return demo(41)',
  }, '.lua')

  child.cmd('edit ' .. path)
  H.set_source_buf_to_current()
  child.type_keys(':', 'Meta', '<CR>')

  H.wait_for(function()
    return H.session_active()
  end, 3000)
end)

return T
