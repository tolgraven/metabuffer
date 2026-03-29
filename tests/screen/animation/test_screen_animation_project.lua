local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['project Meta uses animated mini backend during launch and scroll'] = H.timed_case(function()
  H.child.lua([[
    require('metabuffer').setup({
      project_bootstrap_delay_ms = 80,
      project_bootstrap_idle_delay_ms = 80,
      ui = {
        animation = {
          enabled = true,
          loading_indicator = true,
          backend = 'mini',
        },
      },
    })
  ]])

  H.open_project_meta_from_file('README.md')

  H.wait_for(function()
    return H.session_preview_visible()
  end, 1500)

  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        if not (s and s['info-win'] and vim.api.nvim_win_is_valid(s['info-win'])) then
          return false
        end
        local blend = vim.api.nvim_get_option_value('winblend', { win = s['info-win'] })
        return (s['info-animated?'] == true) and blend > 0
      end)()
    ]]) == true
  end, 1500)

  H.wait_for(function()
    local snap = H.session_info_snapshot()
    return type(snap) == 'table' and snap.count > 0
  end, 1500)

  local before = H.session_main_view()
  local target = H.compute_main_scroll_target('half-down')
  H.feed_prompt_key('<C-d><C-d><C-d>', 'normal')
  H.wait_for(function()
    return H.child.lua_get([[
      _G.MiniAnimate and MiniAnimate.is_active('scroll')
    ]]) == true
  end, 1000)
  eq(H.session_main_view().topline == target.topline, false)
  H.wait_for(function()
    local view = H.session_main_view()
    return type(view) == 'table' and type(before) == 'table'
      and (view.topline ~= before.topline or view.lnum ~= before.lnum)
  end, 1500)
  H.wait_for(function()
    return H.session_prompt_focused() == true
  end, 1500)

  local main_view = H.session_main_view()
  local info_view = H.session_info_view()

  eq(H.session_active(), true)
  eq(main_view.topline, target.topline)
  eq(main_view.lnum, target.lnum)
  eq(type(info_view), 'table')
  eq(info_view.topline, main_view.topline)
  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        if not (s and s['info-win'] and vim.api.nvim_win_is_valid(s['info-win'])) then
          return false
        end
        local blend = vim.api.nvim_get_option_value('winblend', { win = s['info-win'] })
        return blend <= (vim.g.meta_float_winblend or 13)
      end)()
    ]]) == true
  end, 3000)
end)

return T
