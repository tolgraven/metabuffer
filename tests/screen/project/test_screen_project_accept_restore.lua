local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['project <CR> hides Meta UI but restores full state when returning to results buffer'] = H.timed_case(function()
  local root = H.make_temp_project()
  H.open_project_meta_in_dir(root, 'main.txt')

  H.type_prompt_text('meta')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)
  H.type_prompt('<C-n>')
  H.wait_for(function()
    return H.session_preview_contains('contains meta token')
  end, 4000)

  local state_before = child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return nil end
      return {
        prompt = table.concat(vim.api.nvim_buf_get_lines(s['prompt-buf'], 0, -1, false), '\n'),
        selected = s.meta.selected_index or 0,
        results_buf = s.meta.buf.buffer,
      }
    end)()
  ]])
  eq(type(state_before), 'table')
  eq(type(state_before.results_buf), 'number')

  child.cmd('stopinsert')
  H.type_prompt('<CR>')
  local accepted_buf = H.current_buf()
  eq(type(accepted_buf), 'number')

  H.wait_for(function()
    return child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        if not s then return false end
        local pwin = s['prompt-win']
        return (pwin == nil) or (not vim.api.nvim_win_is_valid(pwin))
      end)()
    ]])
  end)

  child.cmd('normal! <C-o>')

  H.wait_for(function()
    return H.current_buf_matches(state_before.results_buf)
  end)

  H.wait_for(function()
    return child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        if not s then return false end
        local pwin = s['prompt-win']
        return pwin and vim.api.nvim_win_is_valid(pwin)
      end)()
    ]])
  end)

  eq(H.current_buf_matches(state_before.results_buf), true)

  local state_after = child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return nil end
      return {
        prompt = table.concat(vim.api.nvim_buf_get_lines(s['prompt-buf'], 0, -1, false), '\n'),
        selected = s.meta.selected_index or 0,
      }
    end)()
  ]])
  eq(state_after.prompt, state_before.prompt)
  eq(state_after.selected, state_before.selected)
  H.wait_for(function()
    return H.session_preview_contains('contains meta token')
  end, 4000)

  child.cmd('normal! <C-i>')

  H.wait_for(function()
    return H.current_buf_matches(accepted_buf)
  end)
  H.wait_for(function()
    return H.session_ui_hidden()
  end, 4000)

  child.cmd('normal! <C-o>')

  H.wait_for(function()
    return H.current_buf_matches(state_before.results_buf)
  end)
  H.wait_for(function()
    return child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        if not s then return false end
        local pwin = s['prompt-win']
        return pwin and vim.api.nvim_win_is_valid(pwin)
      end)()
    ]])
  end)
  H.wait_for(function()
    return H.session_preview_contains('contains meta token')
  end, 4000)
end)

T['project <C-o> restore does not restart lazy stream or reenter loading churn while results stay focused'] = H.timed_case(function()
  local root = H.make_temp_project()
  H.child.lua([[
    require('metabuffer').setup({
      project_bootstrap_delay_ms = 0,
      project_bootstrap_idle_delay_ms = 0,
      project_lazy_refresh_min_ms = 0,
      project_lazy_refresh_debounce_ms = 17,
    })
  ]])
  H.open_project_meta_in_dir(root, 'main.txt')

  H.wait_for(function()
    return H.session_hit_count() > 0
  end, 6000)

  local before_accept = H.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return nil end
      return {
        hits = #(s.meta.buf.indices or {}),
        results_buf = s.meta.buf.buffer,
        lazy_stream_id = s['lazy-stream-id'] or 0,
        lazy_stream_next = s['lazy-stream-next'] or 0,
        lazy_stream_done = s['lazy-stream-done'] == true,
        bootstrap_token = s['project-bootstrap-token'] or 0,
      }
    end)()
  ]])
  eq(type(before_accept), 'table')
  eq(type(before_accept.results_buf), 'number')

  H.type_prompt('<CR>')
  H.wait_for(function() return H.session_ui_hidden() end, 4000)

  H.child.cmd('normal! <C-o>')
  H.wait_for(function()
    return H.current_buf_matches(before_accept.results_buf)
  end, 4000)
  H.wait_for(function()
    return H.session_results_focused() and not H.session_ui_hidden()
  end, 4000)

  local after_restore = H.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return nil end
      return {
        hits = #(s.meta.buf.indices or {}),
        lazy_stream_id = s['lazy-stream-id'] or 0,
        lazy_stream_next = s['lazy-stream-next'] or 0,
        lazy_stream_done = s['lazy-stream-done'] == true,
        bootstrap_token = s['project-bootstrap-token'] or 0,
        restoring = s['restoring-ui?'] == true,
        ui_hidden = s['ui-hidden'] == true,
      }
    end)()
  ]])
  eq(type(after_restore), 'table')
  eq(after_restore.ui_hidden, false)
  eq(after_restore.restoring, false)
  eq(after_restore.lazy_stream_id, before_accept.lazy_stream_id)
  eq(after_restore.bootstrap_token, before_accept.bootstrap_token)

  H.child.lua([[vim.wait(250)]])

  local settled = H.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return nil end
      return {
        hits = #(s.meta.buf.indices or {}),
        lazy_stream_id = s['lazy-stream-id'] or 0,
        lazy_stream_next = s['lazy-stream-next'] or 0,
        lazy_stream_done = s['lazy-stream-done'] == true,
        bootstrap_token = s['project-bootstrap-token'] or 0,
        loading_phase = s['loading-anim-phase'],
        restoring = s['restoring-ui?'] == true,
        ui_hidden = s['ui-hidden'] == true,
      }
    end)()
  ]])
  eq(type(settled), 'table')
  eq(settled.ui_hidden, false)
  eq(settled.restoring, false)
  eq(settled.lazy_stream_id, after_restore.lazy_stream_id)
  eq(settled.bootstrap_token, after_restore.bootstrap_token)
  eq(settled.hits >= 1, true)
  eq(settled.lazy_stream_next < before_accept.lazy_stream_next, false)
end)

T['project <C-o> restore does not rebuild project sources from layout churn'] = H.timed_case(function()
  local root = H.make_temp_project()
  local debug_log = '/tmp/metabuffer-project-restore-debug.log'
  local function apply_source_set_count()
    local lines = H.read_file(debug_log) or {}
    local n = 0
    for _, line in ipairs(lines) do
      if H.str_contains(line, '[project-source] apply-source-set project=true') then
        n = n + 1
      end
    end
    return n
  end
  H.child.lua(string.format([[
    vim.g['meta#debug'] = true
    vim.g['meta#debug_log'] = %q
    pcall(vim.fn.delete, %q)
    require('metabuffer').setup({
      project_bootstrap_delay_ms = 350,
      project_bootstrap_idle_delay_ms = 350,
    })
  ]], debug_log, debug_log))

  H.open_project_meta_in_dir(root, 'main.txt')
  H.wait_for(function() return H.session_active() end, 4000)
  H.wait_for(function() return H.session_hit_count() >= 1 end, 4000)

  local before_accept = H.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return nil end
      return {
        results_buf = s.meta.buf.buffer,
        bootstrap_token = s['project-bootstrap-token'] or 0,
        lazy_stream_id = s['lazy-stream-id'] or 0,
      }
    end)()
  ]])
  eq(type(before_accept), 'table')
  local apply_count_before = apply_source_set_count()
  eq(apply_count_before >= 1, true)

  H.type_prompt('<CR>')
  H.wait_for(function() return H.session_ui_hidden() end, 4000)

  H.child.cmd('normal! <C-o>')
  H.wait_for(function()
    return H.current_buf_matches(before_accept.results_buf)
  end, 4000)
  H.wait_for(function()
    return H.session_results_focused() and not H.session_ui_hidden()
  end, 4000)

  local after_restore = H.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return nil end
      return {
        bootstrap_token = s['project-bootstrap-token'] or 0,
        lazy_stream_id = s['lazy-stream-id'] or 0,
        restoring = s['restoring-ui?'] == true,
      }
    end)()
  ]])
  eq(type(after_restore), 'table')
  eq(after_restore.restoring, false)
  eq(after_restore.bootstrap_token, before_accept.bootstrap_token)
  eq(after_restore.lazy_stream_id, before_accept.lazy_stream_id)

  H.child.lua([[vim.wait(700)]])

  local settled = H.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return nil end
      return {
        bootstrap_token = s['project-bootstrap-token'] or 0,
        lazy_stream_id = s['lazy-stream-id'] or 0,
        restoring = s['restoring-ui?'] == true,
      }
    end)()
  ]])
  eq(type(settled), 'table')
  eq(settled.restoring, false)
  eq(settled.bootstrap_token, after_restore.bootstrap_token)
  eq(settled.lazy_stream_id, after_restore.lazy_stream_id)
  eq(apply_source_set_count(), apply_count_before)
end)

T['project <CR> edits the selected file through a cwd-relative path'] = H.timed_case(function()
  local root = H.make_temp_project()
  H.open_project_meta_in_dir(root, 'main.txt')

  H.type_prompt_text('#file:lua/mod.lua')
  H.wait_for(function()
    local ref = H.session_selected_ref()
    return type(ref) == 'table' and ref.path and H.str_contains(ref.path, 'lua/mod.lua')
  end, 6000)

  local hist_before = H.child.fn.histnr(':')
  H.type_prompt('<CR>')

  H.wait_for(function()
    return H.child.fn.histnr(':') > hist_before
  end, 4000)

  local cmd = H.child.fn.histget(':', -1)
  eq(type(cmd), 'string')
  eq(H.str_contains(cmd, 'edit '), true)
  eq(H.str_contains(cmd, 'lua/mod.lua'), true)
  eq(H.str_contains(cmd, root), false)
end)

return T
