local config = require('metabuffer.config')
local custom = require('metabuffer.custom')
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
  eq(resolved.options.ui_animation_backend, 'mini')
  eq(resolved.options.ui_animation_prompt_backend, 'mini')
  eq(resolved.options.ui_animation_info_backend, 'mini')
  eq(resolved.options.ui_animation_scroll_backend, 'mini')
  eq(resolved.options.ui_animation_scroll_ms, 100)
  eq(resolved.options.default_include_lgrep, false)
  eq(resolved.options.lgrep_bin, 'lgrep')
  eq(resolved.options.lgrep_limit, 80)
  eq(resolved.options.lgrep_debounce_ms, 260)
  eq(type(resolved.options.custom), 'table')
  eq(type(resolved.options.custom.transforms), 'table')
end

T['resolve keeps custom transform config under options.custom'] = function()
  local resolved = config.resolve({
    options = {
      custom = {
        transforms = {
          upper = {
            from = { 'tr', 'a-z', 'A-Z' },
            to = { 'tr', 'A-Z', 'a-z' },
            doc = 'Uppercase lines.',
          },
        },
      },
    },
  })

  eq(type(resolved.options.custom.transforms.upper), 'table')
  eq(type(resolved.options.custom.transforms.upper.from), 'table')
  eq(resolved.options.custom.transforms.upper.doc, 'Uppercase lines.')
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

T['apply-router-defaults configures custom transform registry'] = function()
  local router = {}
  local prev = custom.config()
  config['apply-router-defaults'](router, vim, {
    options = {
      custom = {
        transforms = {
          upper = {
            from = { 'tr', 'a-z', 'A-Z' },
            doc = 'Uppercase lines.',
          },
        },
      },
    },
  })

  local mods = custom.modules('transform')
  custom['configure!'](prev)

  eq(type(router["custom-config"]), 'table')
  eq(type(mods), 'table')
  eq(#mods > 0, true)
  eq(mods[1]['transform-key'], 'custom-transform:upper')
end

return T
