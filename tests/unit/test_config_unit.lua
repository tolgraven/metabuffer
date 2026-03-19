local config = require('metabuffer.config')
local animation = require('metabuffer.window.animation')
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['defaults expose prompt and main keymaps'] = function()
  local d = config.defaults
  eq(type(d), 'table')
  eq(type(d.keymaps), 'table')
  eq(type(d.keymaps.prompt), 'table')
  eq(type(d.keymaps.main), 'table')
  eq(#d.keymaps.prompt > 0, true)
  eq(#d.keymaps.main > 0, true)
end

T['resolve reads nested keymaps overrides'] = function()
  local resolved = config.resolve({
    keymaps = {
      prompt = { { 'i', '<C-a>', 'prompt-home' } },
      main = { { 'n', '<CR>', 'accept-main' } },
      prompt_fallback = { { 'i', '<C-e>', 'prompt-end' } },
    },
  })

  eq(type(resolved.keymaps.prompt), 'table')
  eq(type(resolved.keymaps.main), 'table')
  eq(type(resolved.keymaps.prompt_fallback), 'table')
  eq(#resolved.keymaps.prompt, 1)
  eq(#resolved.keymaps.main, 1)
end

T['resolve preserves debounce defaults when options absent'] = function()
  local resolved = config.resolve({})
  eq(type(resolved.options.prompt_update_debounce_ms), 'number')
  eq(resolved.options.prompt_update_debounce_ms >= 0, true)
end

T['defaults treat deps directory as dependency content'] = function()
  local resolved = config.resolve({})
  eq(resolved.options.dep_dir_names.deps, true)
  local globs = resolved.options.project_rg_deps_exclude_globs
  local found = false
  for _, g in ipairs(globs) do
    if g == '!deps/**' then found = true end
  end
  eq(found, true)
end

T['resolve exposes animation controls with master and per-animation settings'] = function()
  local resolved = config.resolve({
    ui = {
      animation = {
        enabled = false,
        backend = 'mini',
        time_scale = 0.5,
        prompt = { enabled = true, time_scale = 2.0 },
        preview = { enabled = false },
        info = {},
        scroll = { time_scale = 0.75 },
        loading_indicator = false,
      },
    },
  })

  eq(resolved.options.ui_animations_enabled, false)
  eq(resolved.options.ui_animations_time_scale, 0.5)
  eq(resolved.options.ui_animation_backend, 'mini')
  eq(resolved.options.ui_animation_prompt_enabled, true)
  eq(resolved.options.ui_animation_prompt_time_scale, 2.0)
  eq(resolved.options.ui_animation_prompt_backend, 'mini')
  eq(resolved.options.ui_animation_preview_enabled, false)
  eq(resolved.options.ui_animation_info_backend, 'mini')
  eq(resolved.options.ui_animation_scroll_time_scale, 0.75)
  eq(resolved.options.ui_animation_scroll_backend, 'mini')
  eq(resolved.options.ui_loading_indicator, false)
end

T['resolve keeps legacy animation option names as fallback aliases'] = function()
  local resolved = config.resolve({
    ui_animate_enter = false,
  })

  eq(resolved.options.ui_animations_enabled, false)
  eq(resolved.options.ui_animation_prompt_ms, config.defaults.options.ui_animation_prompt_ms)
  eq(resolved.options.ui_animation_preview_ms, config.defaults.options.ui_animation_preview_ms)
  eq(resolved.options.ui_animation_info_ms, config.defaults.options.ui_animation_info_ms)
  eq(resolved.options.ui_animation_loading_ms, config.defaults.options.ui_animation_loading_ms)
  eq(resolved.options.ui_animation_scroll_ms, config.defaults.options.ui_animation_scroll_ms)
end

T['animation helper applies master and local time scales'] = function()
  local session = {
    ['animation-settings'] = {
      enabled = true,
      backend = 'mini',
      ['time-scale'] = 0.5,
      prompt = { enabled = true, ms = 140, ['time-scale'] = 2.0 },
      preview = { enabled = false, ms = 180, ['time-scale'] = 1.0 },
      info = {},
      scroll = {},
    },
  }

  eq(animation['enabled?'](session, 'prompt'), true)
  eq(animation['enabled?'](session, 'preview'), false)
  eq(animation['duration-ms'](session, 'prompt', 140), 140)
  eq(animation['duration-ms'](session, 'preview', 180), 90)
  eq(animation['animation-backend'](session, 'prompt'), 'mini')
  eq(animation['animation-backend'](session, 'info'), 'mini')
  eq(animation['scroll-backend'](session), 'mini')
  eq(animation['supports-backend?']('native'), true)
  eq(animation['supports-scroll-backend?']('native'), true)
end

return T
