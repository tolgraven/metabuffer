local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

local function enter_results_edit_mode()
  child.lua([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      assert(s and s['prompt-buf'], 'missing metabuffer session')
      router['enter-edit-mode'](s['prompt-buf'])
    end)()
  ]])
end

T['contiguous plain-meta edits patch the real file region in place'] = H.timed_case(function()
  local path = child.lua_get([[
    (function()
      local path = vim.fn.tempname() .. '.txt'
      vim.fn.writefile({ 'alpha', 'beta', 'gamma' }, path)
      return path
    end)()
  ]])

  child.cmd('edit ' .. path)
  child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
  child.type_keys(':', 'Meta', '<CR>')
  H.wait_for(function()
    return H.session_active()
  end, 3000)

  child.cmd('stopinsert')
  enter_results_edit_mode()
  child.type_keys('g', 'g')
  child.type_keys('o')
  child.type_keys('insert-after-alpha')
  child.type_keys('<Esc>')
  child.cmd('write')

  eq(child.lua_get(string.format([[
    return vim.fn.readfile(%q)
  ]], path)), { 'alpha', 'insert-after-alpha', 'beta', 'gamma' })
end)

T['sparse project edits anchor inserts to one source line only'] = H.timed_case(function()
  local root = H.make_temp_project()
  local main_before = child.lua_get(string.format([[
    return vim.fn.readfile(%q)
  ]], root .. '/main.txt'))
  local lua_before = child.lua_get(string.format([[
    return vim.fn.readfile(%q)
  ]], root .. '/lua/mod.lua'))

  H.open_project_meta_in_dir(root, 'main.txt')
  H.type_prompt_text('other')
  H.wait_for(function()
    return H.session_hit_count() == 1
  end, 6000)

  local target = child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local meta = s and s.meta or nil
      if not meta then return nil end
      local idx = (meta.buf.indices or {})[1]
      local ref = idx and (meta.buf['source-refs'] or {})[idx] or nil
      if not ref then return nil end
      return { path = ref.path or '', lnum = ref.lnum or 0 }
    end)()
  ]])
  eq(target.path, root .. '/doc/readme.md')
  eq(target.lnum, 3)

  child.cmd('stopinsert')
  enter_results_edit_mode()
  child.type_keys('O')
  child.type_keys('insert-before-other')
  child.type_keys('<Esc>')
  child.cmd('write')

  eq(child.lua_get(string.format([[
    return vim.fn.readfile(%q)
  ]], root .. '/doc/readme.md')), { 'meta docs', 'metam docs', 'insert-before-other', 'other' })
  eq(child.lua_get(string.format([[
    return vim.fn.readfile(%q)
  ]], root .. '/main.txt')), main_before)
  eq(child.lua_get(string.format([[
    return vim.fn.readfile(%q)
  ]], root .. '/lua/mod.lua')), lua_before)
end)

T['sparse project paste uses the owned line as after-anchor only'] = H.timed_case(function()
  local root = H.make_temp_project()
  local doc_before = child.lua_get(string.format([[
    return vim.fn.readfile(%q)
  ]], root .. '/doc/readme.md'))
  local main_before = child.lua_get(string.format([[
    return vim.fn.readfile(%q)
  ]], root .. '/main.txt'))

  H.open_project_meta_in_dir(root, 'main.txt')
  H.type_prompt_text('other')
  H.wait_for(function()
    return H.session_hit_count() == 1
  end, 6000)

  child.cmd('stopinsert')
  enter_results_edit_mode()
  child.lua([[vim.fn.setreg('"', "paste-after-other\n", 'l')]])
  child.type_keys('p')
  child.cmd('write')

  eq(child.lua_get(string.format([[
    return vim.fn.readfile(%q)
  ]], root .. '/doc/readme.md')), { 'meta docs', 'metam docs', 'other', 'paste-after-other' })
  eq(child.lua_get(string.format([[
    return vim.fn.readfile(%q)
  ]], root .. '/main.txt')), main_before)
  eq(doc_before[1], 'meta docs')
end)

T['sparse project uppercase paste uses the owned line as before-anchor only'] = H.timed_case(function()
  local root = H.make_temp_project()
  local main_before = child.lua_get(string.format([[
    return vim.fn.readfile(%q)
  ]], root .. '/main.txt'))

  H.open_project_meta_in_dir(root, 'main.txt')
  H.type_prompt_text('other')
  H.wait_for(function()
    return H.session_hit_count() == 1
  end, 6000)

  child.cmd('stopinsert')
  enter_results_edit_mode()
  child.lua([[vim.fn.setreg('"', "paste-before-other\n", 'l')]])
  child.type_keys('P')
  child.cmd('write')

  eq(child.lua_get(string.format([[
    return vim.fn.readfile(%q)
  ]], root .. '/doc/readme.md')), { 'meta docs', 'metam docs', 'paste-before-other', 'other' })
  eq(child.lua_get(string.format([[
    return vim.fn.readfile(%q)
  ]], root .. '/main.txt')), main_before)
end)

return T
