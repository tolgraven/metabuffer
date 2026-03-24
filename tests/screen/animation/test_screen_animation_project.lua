local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['project Meta uses animated mini backend during launch and scroll'] = H.timed_case(function()
  H.child.lua([[
    require('metabuffer').setup({
      project_bootstrap_delay_ms = 300,
      project_bootstrap_idle_delay_ms = 300,
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
  end, 3000)

  H.wait_for(function()
    local snap = H.session_info_snapshot()
    return type(snap) == 'table' and snap.count > 0
  end, 3000)

  local before = H.session_main_view()
  local target = H.compute_main_scroll_target('half-down')
  H.feed_prompt_key('<C-d><C-d><C-d>', 'normal')
  H.wait_for(function()
    return H.child.lua_get([[
      return _G.MiniAnimate and MiniAnimate.is_active('scroll')
    ]]) == true
  end, 1500)
  eq(H.session_main_view().topline == target.topline, false)
  H.wait_for(function()
    local view = H.session_main_view()
    return type(view) == 'table' and type(before) == 'table'
      and (view.topline ~= before.topline or view.lnum ~= before.lnum)
  end, 3000)
  H.wait_for(function()
    return H.session_prompt_focused() == true
  end, 3000)

  local main_view = H.session_main_view()
  local info_view = H.session_info_view()

  eq(H.session_active(), true)
  eq(main_view.topline, target.topline)
  eq(main_view.lnum, target.lnum)
  eq(type(info_view), 'table')
  eq(info_view.topline, main_view.topline)
end)

return T
