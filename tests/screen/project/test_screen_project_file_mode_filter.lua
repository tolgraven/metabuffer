local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['typing inline #file filter narrows file entries and highlights arg separately'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_text('#file')
  H.wait_for(function() return H.session_file_entry_hit_count() > 0 end, 6000)

  local all_count = H.session_file_entry_hit_count()
  eq(type(all_count), 'number')
  eq(all_count > 1, true)

  H.type_prompt_text('#file:README')
  H.wait_for(function()
    local n = H.session_file_entry_hit_count()
    return n > 0 and n < all_count
  end, 6000)

  local filtered_count = H.session_file_entry_hit_count()
  eq(filtered_count > 0, true)
  eq(filtered_count < all_count, true)

  local has_flag_hl, has_arg_hl = H.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local ns = s['prompt-hl-ns']
      local marks = vim.api.nvim_buf_get_extmarks(s['prompt-buf'], ns, { 0, 0 }, { 0, -1 }, { details = true })
      local flag_hl, arg_hl = false, false
      for _, mark in ipairs(marks or {}) do
        local details = mark[4] or {}
        if details.hl_group == 'MetaPromptFlagTextOn' then
          flag_hl = true
        elseif details.hl_group == 'MetaPromptFileArg' then
          arg_hl = true
        end
      end
      return { flag_hl, arg_hl }
    end)()
  ]])
  eq(has_flag_hl, true)
  eq(has_arg_hl, true)
end)

T['backspacing from #file help does not leave an errmsg'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_text('#file')
  H.wait_for(function() return H.session_prompt_text() == '#file' end, 6000)

  H.type_prompt_tokens({ '<BS>' }, 20)
  H.wait_for(function() return H.session_prompt_text() == '#fil' end, 6000)
  H.wait_for(function()
    return H.child.lua_get([[(function() return vim.v.errmsg == '' end)()]])
  end, 6000)
end)

return T
