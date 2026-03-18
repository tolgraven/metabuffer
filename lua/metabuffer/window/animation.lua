-- [nfnl] fnl/metabuffer/window/animation.fnl
local M = {}
local target_frame_ms = 17
local mini_animate_cache = nil
local mini_animate_tried_3f = false
local function now_ms()
  return math.floor((vim.uv.hrtime() / 1000000))
end
local function ensure_state(session)
  local state = (session["anim-state"] or {})
  session["anim-state"] = state
  return state
end
local function next_token_21(session, key)
  local state = ensure_state(session)
  local token = (1 + (state[key] or 0))
  state[key] = token
  return token
end
local function active_token_3f(session, key, token)
  return ((session["anim-state"] or {})[key] == token)
end
local function ease_in_out_cubic(t)
  local x = math.max(0, math.min(t, 1))
  if (x < 0.5) then
    return (4 * x * x * x)
  else
    local y = ((2 * x) - 2)
    return (1 + ((y * y * y) / 2))
  end
end
local function lerp(a, b, t)
  return (a + ((b - a) * t))
end
local function number_or(v, fallback)
  if (type(v) == "number") then
    return v
  else
    return fallback
  end
end
local function mini_animate_mod()
  if not mini_animate_tried_3f then
    mini_animate_tried_3f = true
    local ok,mod = pcall(require, "mini.animate")
    if ok then
      mini_animate_cache = mod
    else
      mini_animate_cache = false
    end
  else
  end
  if (mini_animate_cache == false) then
    return nil
  else
    return mini_animate_cache
  end
end
local function with_split_mins(f)
  local old_height = vim.o.winminheight
  local old_width = vim.o.winminwidth
  local old_equalalways = vim.o.equalalways
  vim.o.winminheight = 1
  vim.o.winminwidth = 1
  vim.o.equalalways = false
  local ok,res = pcall(f)
  vim.o.winminheight = old_height
  vim.o.winminwidth = old_width
  vim.o.equalalways = old_equalalways
  if ok then
    return res
  else
    return error(res)
  end
end
local function enabled_3f(session, kind)
  local settings = (session["animation-settings"] or {})
  local entry = (settings[kind] or {})
  return (not (false == settings.enabled) and not (false == entry.enabled))
end
local function duration_ms(session, kind, fallback)
  local settings = (session["animation-settings"] or {})
  local entry = (settings[kind] or {})
  local base = number_or(entry.ms, fallback)
  local global_scale = number_or(settings["time-scale"], 1)
  local local_scale = number_or(entry["time-scale"], 1)
  return math.max(0, math.floor((0.5 + (base * global_scale * local_scale))))
end
local function animation_backend(session, kind)
  local settings = (session["animation-settings"] or {})
  local entry = (settings[kind] or {})
  local backend = entry.backend
  if (backend == "mini") then
    return "mini"
  else
    return "native"
  end
end
local function supports_backend_3f(backend)
  if (backend == "mini") then
    return not not mini_animate_mod()
  else
    return true
  end
end
local function mini_timing(mini, duration_ms0, n_steps)
  local timing = mini.gen_timing.cubic({easing = "in-out", duration = duration_ms0, unit = "total"})
  local function _9_(step)
    return timing(step, n_steps)
  end
  return _9_
end
local function set_win_height_21(win, height)
  return pcall(vim.api.nvim_win_set_height, win, math.max(1, height))
end
local function float_step_config(from_cfg, to_cfg, t)
  local cfg = {relative = to_cfg.relative, anchor = to_cfg.anchor, row = lerp((from_cfg.row or to_cfg.row), to_cfg.row, t), col = lerp((from_cfg.col or to_cfg.col), to_cfg.col, t), width = math.max(1, math.floor((0.5 + lerp((from_cfg.width or to_cfg.width), to_cfg.width, t)))), height = math.max(1, math.floor((0.5 + lerp((from_cfg.height or to_cfg.height), to_cfg.height, t)))), style = "minimal"}
  do
    local val_110_auto = to_cfg.win
    if val_110_auto then
      local host = val_110_auto
      cfg["win"] = host
    else
    end
  end
  return cfg
end
local function apply_float_step_21(win, cfg, blend, opts, step)
  pcall(vim.api.nvim_win_set_config, win, cfg)
  pcall(vim.api.nvim_set_option_value, "winblend", blend, {win = win})
  local val_110_auto = opts["tick!"]
  if val_110_auto then
    local tick_21 = val_110_auto
    return tick_21(cfg, step)
  else
    return nil
  end
end
local animate_win_width_21 = nil
local animate_float_21 = nil
local animate_view_21 = nil
local animate_scroll_view_mini_21 = nil
local animate_scroll_view_21 = nil
local function run_21(session, key, opts)
  local steps = opts.steps
  local tick_21 = opts["tick!"]
  local done_21 = opts["done!"]
  local active_3f = opts["active?"]
  local token = next_token_21(session, key)
  local total = math.max(1, (steps or 1))
  local delay = math.max(8, target_frame_ms)
  local last_frame_ms0 = nil
  local last_frame_ms = last_frame_ms0
  local function frame_21(idx)
    if (active_token_3f(session, key, token) and (not active_3f or active_3f())) then
      local now = now_ms()
      local elapsed
      if last_frame_ms then
        elapsed = (now - last_frame_ms)
      else
        elapsed = delay
      end
      if (elapsed < delay) then
        local function _13_()
          return frame_21(idx)
        end
        return vim.defer_fn(_13_, (delay - elapsed))
      else
        last_frame_ms = now
        local t = ease_in_out_cubic((idx / total))
        tick_21(t, idx, total)
        if (idx < total) then
          local function _14_()
            return frame_21((idx + 1))
          end
          return vim.defer_fn(_14_, delay)
        else
          if done_21 then
            return done_21()
          else
            return nil
          end
        end
      end
    else
      return nil
    end
  end
  return frame_21(0)
end
local function animate_win_height_21(session, key, win, from, to, duration_ms0, opts)
  local start = math.max(1, from)
  local stop = math.max(1, to)
  local step
  if (start < stop) then
    step = 1
  else
    step = -1
  end
  local opts0 = (opts or {})
  local function _20_()
    local function _21_()
      return vim.api.nvim_win_is_valid(win)
    end
    local function _22_(_, idx)
      local height
      local function _23_()
        if (idx == 0) then
          return start
        else
          return (start + (idx * step))
        end
      end
      height = math.max(1, _23_())
      pcall(vim.api.nvim_win_set_height, win, height)
      local val_110_auto = opts0["tick!"]
      if val_110_auto then
        local tick_21 = val_110_auto
        return tick_21(height, idx)
      else
        return nil
      end
    end
    local function _25_()
      pcall(vim.api.nvim_win_set_height, win, stop)
      local val_110_auto = opts0["done!"]
      if val_110_auto then
        local done_21 = val_110_auto
        return done_21(stop)
      else
        return nil
      end
    end
    return run_21(session, key, {["duration-ms"] = duration_ms0, steps = math.max(1, math.abs((stop - start))), ["active?"] = _21_, ["tick!"] = _22_, ["done!"] = _25_})
  end
  return with_split_mins(_20_)
end
local function animate_win_height_stepwise_21(session, key, win, from, to, duration_ms0, opts)
  local start = math.max(1, from)
  local stop = math.max(1, to)
  local delta = math.abs((stop - start))
  local direction
  if (start < stop) then
    direction = 1
  else
    direction = -1
  end
  local frame_budget = math.max(1, math.floor((math.max(duration_ms0, target_frame_ms) / target_frame_ms)))
  local stride = math.max(1, math.ceil((math.max(1, delta) / frame_budget)))
  local opts0 = (opts or {})
  if ((animation_backend(session, "prompt") == "mini") and supports_backend_3f("mini")) then
    local mini = mini_animate_mod()
    local subresize_fn
    local function _28_(sizes_from, sizes_to)
      return (sizes_from.prompt.height ~= sizes_to.prompt.height)
    end
    subresize_fn = mini.gen_subresize.equal({predicate = _28_})
    local step_sizes = subresize_fn({prompt = {height = start, width = 1}}, {prompt = {height = stop, width = 1}})
    local n_steps = #step_sizes
    local function _29_()
      if ((delta <= 0) or (n_steps <= 0)) then
        set_win_height_21(win, stop)
        local val_110_auto = opts0["done!"]
        if val_110_auto then
          local done_21 = val_110_auto
          return done_21(stop)
        else
          return nil
        end
      else
        local token = next_token_21(session, key)
        local timing = mini_timing(mini, duration_ms0, n_steps)
        local function _31_(step)
          if (not active_token_3f(session, key, token) or not vim.api.nvim_win_is_valid(win)) then
            return false
          else
            do
              local step_size = step_sizes[step]
              local prompt_size = (step_size and step_size.prompt)
              local height
              if (step == 0) then
                height = start
              else
                height = ((prompt_size and prompt_size.height) or stop)
              end
              set_win_height_21(win, height)
              local val_110_auto = opts0["tick!"]
              if val_110_auto then
                local tick_21 = val_110_auto
                tick_21(height, step)
              else
              end
            end
            if (step < n_steps) then
              return true
            else
              set_win_height_21(win, stop)
              do
                local val_110_auto = opts0["done!"]
                if val_110_auto then
                  local done_21 = val_110_auto
                  done_21(stop)
                else
                end
              end
              return false
            end
          end
        end
        return mini.animate(_31_, timing, {max_steps = (n_steps + 1)})
      end
    end
    with_split_mins(_29_)
    local function _38_()
      local function _39_()
        return vim.api.nvim_win_is_valid(win)
      end
      local function _40_(_, idx)
        local next_height
        if (idx == 0) then
          next_height = start
        else
          next_height = (start + (idx * stride * direction))
        end
        local height
        if (direction > 0) then
          height = math.min(stop, next_height)
        else
          height = math.max(stop, next_height)
        end
        set_win_height_21(win, height)
        local val_110_auto = opts0["tick!"]
        if val_110_auto then
          local tick_21 = val_110_auto
          return tick_21(height, idx)
        else
          return nil
        end
      end
      local function _44_()
        set_win_height_21(win, stop)
        local val_110_auto = opts0["done!"]
        if val_110_auto then
          local done_21 = val_110_auto
          return done_21(stop)
        else
          return nil
        end
      end
      return run_21(session, key, {["duration-ms"] = duration_ms0, steps = math.max(1, math.ceil((math.max(1, delta) / stride))), ["active?"] = _39_, ["tick!"] = _40_, ["done!"] = _44_})
    end
    return with_split_mins(_38_)
  else
    return nil
  end
end
local function _47_(session, key, win, from, to, duration_ms0, opts)
  local start = math.max(1, from)
  local stop = math.max(1, to)
  local opts0 = (opts or {})
  local function _48_()
    local function _49_()
      return vim.api.nvim_win_is_valid(win)
    end
    local function _50_(t)
      local width = math.max(1, math.floor((0.5 + lerp(start, stop, t))))
      pcall(vim.api.nvim_win_set_width, win, width)
      local val_110_auto = opts0["tick!"]
      if val_110_auto then
        local tick_21 = val_110_auto
        return tick_21(width, t)
      else
        return nil
      end
    end
    local function _52_()
      pcall(vim.api.nvim_win_set_width, win, stop)
      local val_110_auto = opts0["done!"]
      if val_110_auto then
        local done_21 = val_110_auto
        return done_21(stop)
      else
        return nil
      end
    end
    return run_21(session, key, {["duration-ms"] = duration_ms0, steps = math.max(2, math.floor((duration_ms0 / target_frame_ms))), ["active?"] = _49_, ["tick!"] = _50_, ["done!"] = _52_})
  end
  return with_split_mins(_48_)
end
animate_win_width_21 = _47_
local function _54_(session, key, win, from_cfg, to_cfg, from_blend, to_blend, duration_ms0, opts)
  local opts0 = (opts or {})
  local kind = (opts0.kind or "info")
  if ((animation_backend(session, kind) == "mini") and supports_backend_3f("mini")) then
    local mini = mini_animate_mod()
    local n_steps = math.max(2, math.floor((duration_ms0 / target_frame_ms)))
    local timing = mini_timing(mini, duration_ms0, n_steps)
    local blend_fn = mini.gen_winblend.linear({from = from_blend, to = to_blend})
    local token = next_token_21(session, key)
    local function _55_(step)
      if (not active_token_3f(session, key, token) or not vim.api.nvim_win_is_valid(win)) then
        return false
      else
        local t = (step / n_steps)
        local cfg = float_step_config(from_cfg, to_cfg, t)
        local blend = math.max(0, math.min(100, blend_fn(step, n_steps)))
        apply_float_step_21(win, cfg, blend, opts0, t)
        if (step < n_steps) then
          return true
        else
          apply_float_step_21(win, to_cfg, to_blend, opts0, 1)
          do
            local val_110_auto = opts0["done!"]
            if val_110_auto then
              local done_21 = val_110_auto
              done_21(to_cfg)
            else
            end
          end
          return false
        end
      end
    end
    return mini.animate(_55_, timing, {max_steps = (n_steps + 1)})
  else
    local function _59_()
      return vim.api.nvim_win_is_valid(win)
    end
    local function _60_(t)
      local cfg = float_step_config(from_cfg, to_cfg, t)
      local blend = math.max(0, math.min(100, math.floor((0.5 + lerp(from_blend, to_blend, t)))))
      return apply_float_step_21(win, cfg, blend, opts0, t)
    end
    local function _61_()
      apply_float_step_21(win, to_cfg, to_blend, opts0, 1)
      local val_110_auto = opts0["done!"]
      if val_110_auto then
        local done_21 = val_110_auto
        return done_21(to_cfg)
      else
        return nil
      end
    end
    return run_21(session, key, {["duration-ms"] = duration_ms0, steps = math.max(2, math.floor((duration_ms0 / target_frame_ms))), ["active?"] = _59_, ["tick!"] = _60_, ["done!"] = _61_})
  end
end
animate_float_21 = _54_
local function _64_(session, key, win, from_view, to_view, duration_ms0, opts)
  local opts0 = (opts or {})
  local function _65_()
    return vim.api.nvim_win_is_valid(win)
  end
  local function _66_(t)
    local function _67_()
      return pcall(vim.fn.winrestview, {topline = math.max(1, math.floor((0.5 + lerp((from_view.topline or 1), (to_view.topline or 1), t)))), lnum = math.max(1, math.floor((0.5 + lerp((from_view.lnum or 1), (to_view.lnum or 1), t)))), leftcol = math.max(0, math.floor((0.5 + lerp((from_view.leftcol or 0), (to_view.leftcol or 0), t)))), col = math.max(0, math.floor((0.5 + lerp((from_view.col or 0), (to_view.col or 0), t))))})
    end
    return vim.api.nvim_win_call(win, _67_)
  end
  local function _68_()
    local function _69_()
      return pcall(vim.fn.winrestview, to_view)
    end
    vim.api.nvim_win_call(win, _69_)
    local val_110_auto = opts0["done!"]
    if val_110_auto then
      local done_21 = val_110_auto
      return done_21(to_view)
    else
      return nil
    end
  end
  return run_21(session, key, {["duration-ms"] = duration_ms0, steps = math.max(2, math.floor((duration_ms0 / target_frame_ms))), ["active?"] = _65_, ["tick!"] = _66_, ["done!"] = _68_})
end
animate_view_21 = _64_
local function _71_(session, key, win, from_view, to_view, duration_ms0, opts)
  local opts0 = (opts or {})
  local mini = mini_animate_mod()
  local from_top = (from_view.topline or 1)
  local to_top = (to_view.topline or from_top)
  local total_scroll = math.abs((to_top - from_top))
  local subscroll_fn
  local function _72_(n)
    return (n > 1)
  end
  subscroll_fn = mini.gen_subscroll.equal({predicate = _72_, max_output_steps = 60})
  local win_restore
  local function _73_(target)
    local function _74_()
      return pcall(vim.fn.winrestview, target)
    end
    return vim.api.nvim_win_call(win, _74_)
  end
  win_restore = _73_
  local step_scrolls = subscroll_fn(total_scroll)
  local n_steps = #step_scrolls
  if ((total_scroll <= 0) or (n_steps <= 0)) then
    win_restore(to_view)
    local val_110_auto = opts0["done!"]
    if val_110_auto then
      local done_21 = val_110_auto
      return done_21(to_view)
    else
      return nil
    end
  else
    local token = next_token_21(session, key)
    local timing = mini.gen_timing.cubic({easing = "in-out", duration = duration_ms0, unit = "total"})
    local dir
    if (from_top < to_top) then
      dir = 1
    else
      dir = -1
    end
    local from_lnum = (from_view.lnum or from_top)
    local to_lnum = (to_view.lnum or to_top)
    local scrolled0 = 0
    local scrolled = scrolled0
    local function _77_(step)
      if (not active_token_3f(session, key, token) or not vim.api.nvim_win_is_valid(win)) then
        return false
      else
        if (step > 0) then
          scrolled = (scrolled + (step_scrolls[step] or 0))
          local coef = (step / n_steps)
          local target = {topline = (from_top + (dir * scrolled)), lnum = math.max(1, math.floor((0.5 + lerp(from_lnum, to_lnum, coef)))), leftcol = (to_view.leftcol or from_view.leftcol or 0), col = (to_view.col or from_view.col or 0)}
          win_restore(target)
        else
        end
        if (step < n_steps) then
          return true
        else
          win_restore(to_view)
          do
            local val_110_auto = opts0["done!"]
            if val_110_auto then
              local done_21 = val_110_auto
              done_21(to_view)
            else
            end
          end
          return false
        end
      end
    end
    local function _82_(step)
      return timing(step, n_steps)
    end
    return mini.animate(_77_, _82_, {max_steps = (n_steps + 1)})
  end
end
animate_scroll_view_mini_21 = _71_
local function _84_(session, key, win, from_view, to_view, duration_ms0, opts)
  if ((animation_backend(session, "scroll") == "mini") and supports_backend_3f("mini")) then
    return animate_scroll_view_mini_21(session, key, win, from_view, to_view, duration_ms0, opts)
  else
    return animate_view_21(session, key, win, from_view, to_view, duration_ms0, opts)
  end
end
animate_scroll_view_21 = _84_
local function reset_mini_animate_cache_21()
  mini_animate_cache = nil
  mini_animate_tried_3f = false
  return nil
end
M["enabled?"] = enabled_3f
M["duration-ms"] = duration_ms
M["animation-backend"] = animation_backend
local function _86_(session)
  return animation_backend(session, "scroll")
end
M["scroll-backend"] = _86_
M["supports-backend?"] = supports_backend_3f
M["supports-scroll-backend?"] = supports_backend_3f
M["with-split-mins"] = with_split_mins
M["run!"] = run_21
M["animate-win-height!"] = animate_win_height_21
M["animate-win-height-stepwise!"] = animate_win_height_stepwise_21
M["animate-win-width!"] = animate_win_width_21
M["animate-float!"] = animate_float_21
M["animate-view!"] = animate_view_21
M["animate-scroll-view!"] = animate_scroll_view_21
M["reset-mini-animate-cache!"] = reset_mini_animate_cache_21
return M
