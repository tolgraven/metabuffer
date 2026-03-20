-- [nfnl] fnl/metabuffer/window/animation.fnl
local M = {}
local target_frame_ms = 17
local mini_animate_cache = nil
local mini_animate_tried_3f = false
local mini_animate_scoped_3f = false
local mark_mini_session_21 = nil
local unmark_mini_session_21 = nil
local execute_after_21 = nil
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
  local _6_ = res
  if not ok then
    return error(_6_)
  else
    return _6_
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
  local backend = (entry.backend or settings.backend)
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
local function mini_autocmds_present_3f()
  local ok,acs = pcall(vim.api.nvim_get_autocmds, {group = "MiniAnimate"})
  return (ok and (#(acs or {}) > 0))
end
local function mini_managed_buf_3f(buf)
  local ok,v = pcall(vim.api.nvim_buf_get_var, buf, "metabuffer_minianimate_enable")
  return (ok and not not v)
end
local function apply_mini_scope_21(buf)
  if (buf and vim.api.nvim_buf_is_valid(buf)) then
    if mini_managed_buf_3f(buf) then
      pcall(vim.api.nvim_buf_set_var, buf, "minianimate_disable", false)
      local ok,cfg = pcall(vim.api.nvim_buf_get_var, buf, "metabuffer_minianimate_config")
      if ok then
        return pcall(vim.api.nvim_buf_set_var, buf, "minianimate_config", cfg)
      else
        return nil
      end
    else
      return pcall(vim.api.nvim_buf_set_var, buf, "minianimate_disable", true)
    end
  else
    return nil
  end
end
local function ensure_mini_scope_21()
  if not mini_animate_scoped_3f then
    mini_animate_scoped_3f = true
    local group = vim.api.nvim_create_augroup("MetabufferMiniAnimateScope", {clear = true})
    local apply_21
    local function _13_(ev)
      return apply_mini_scope_21(ev.buf)
    end
    apply_21 = _13_
    return vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {group = group, callback = apply_21})
  else
    return nil
  end
end
local function ensure_mini_global_21(session)
  local mini = mini_animate_mod()
  if mini then
    if not mini_autocmds_present_3f() then
      mini.setup({cursor = {enable = false}, scroll = {enable = true}, resize = {enable = true}, open = {enable = false}, close = {enable = false}})
    else
    end
    ensure_mini_scope_21()
    if session then
      mark_mini_session_21(session)
    else
    end
  else
  end
  return mini
end
local function mini_timing(mini, duration_ms0, n_steps)
  local timing = mini.gen_timing.cubic({easing = "in-out", duration = duration_ms0, unit = "total"})
  local function _18_(step)
    return timing(step, n_steps)
  end
  return _18_
end
local function once(f)
  local called0 = false
  local called = called0
  local function _19_(...)
    if not called then
      called = true
      return f(...)
    else
      return nil
    end
  end
  return _19_
end
local function mini_run_21(mini, session, key, n_steps, duration_ms0, active_3f, step_action)
  local token = next_token_21(session, key)
  local timing = mini_timing(mini, duration_ms0, n_steps)
  local function _21_(step)
    if (not active_token_3f(session, key, token) or (active_3f and not active_3f())) then
      return false
    else
      return step_action(step)
    end
  end
  return mini.animate(_21_, timing, {max_steps = (n_steps + 1)})
end
local function mini_float_winblend_fn(mini, from_blend, to_blend)
  return mini.gen_winblend.linear({from = from_blend, to = to_blend})
end
local function mini_after_21(animation_type, delay_ms, action)
  local run_21 = once(action)
  execute_after_21(animation_type, run_21)
  return vim.defer_fn(run_21, math.max(0, ((delay_ms or 0) + 24)))
end
local function mini_buffer_config(session)
  local mini = mini_animate_mod()
  local function _23_(n)
    return (n > 1)
  end
  return {cursor = {enable = false}, scroll = {enable = enabled_3f(session, "scroll"), timing = mini.gen_timing.cubic({easing = "in-out", duration = duration_ms(session, "scroll", 140), unit = "total"}), subscroll = mini.gen_subscroll.equal({predicate = _23_, max_output_steps = 60})}, resize = {enable = enabled_3f(session, "prompt"), timing = mini.gen_timing.cubic({easing = "in-out", duration = duration_ms(session, "prompt", 140), unit = "total"}), subresize = mini.gen_subresize.equal()}, open = {enable = false}, close = {enable = false}}
end
local function _24_(session)
  if (session and supports_backend_3f("mini")) then
    local cfg = mini_buffer_config(session)
    for _, buf in ipairs({(session.meta and session.meta.buf and session.meta.buf.buffer), session["prompt-buf"], session["info-buf"]}) do
      if (buf and vim.api.nvim_buf_is_valid(buf)) then
        pcall(vim.api.nvim_buf_set_var, buf, "metabuffer_minianimate_enable", true)
        pcall(vim.api.nvim_buf_set_var, buf, "metabuffer_minianimate_config", cfg)
        apply_mini_scope_21(buf)
      else
      end
    end
    return nil
  else
    return nil
  end
end
mark_mini_session_21 = _24_
local function _27_(session)
  if session then
    for _, buf in ipairs({(session.meta and session.meta.buf and session.meta.buf.buffer), session["prompt-buf"], session["info-buf"]}) do
      if (buf and vim.api.nvim_buf_is_valid(buf)) then
        pcall(vim.api.nvim_buf_del_var, buf, "metabuffer_minianimate_enable")
        pcall(vim.api.nvim_buf_del_var, buf, "metabuffer_minianimate_config")
        pcall(vim.api.nvim_buf_set_var, buf, "minianimate_disable", true)
      else
      end
    end
    return nil
  else
    return nil
  end
end
unmark_mini_session_21 = _27_
local function _30_(animation_type, action)
  local mini = mini_animate_mod()
  if mini then
    return mini.execute_after(animation_type, action)
  else
    return action()
  end
end
execute_after_21 = _30_
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
  local wait = math.max(8, target_frame_ms)
  local last_frame_ms0 = nil
  local last_frame_ms = last_frame_ms0
  local function frame_21(idx)
    if (active_token_3f(session, key, token) and (not active_3f or active_3f())) then
      local now = now_ms()
      local elapsed
      if last_frame_ms then
        elapsed = (now - last_frame_ms)
      else
        elapsed = wait
      end
      if (elapsed < wait) then
        local function _35_()
          return frame_21(idx)
        end
        return vim.defer_fn(_35_, (wait - elapsed))
      else
        last_frame_ms = now
        local t = ease_in_out_cubic((idx / total))
        tick_21(t, idx, total)
        if (idx < total) then
          local function _36_()
            return frame_21((idx + 1))
          end
          return vim.defer_fn(_36_, wait)
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
  local function _42_()
    local function _43_()
      return vim.api.nvim_win_is_valid(win)
    end
    local function _44_(_, idx)
      local height
      local function _45_()
        if (idx == 0) then
          return start
        else
          return (start + (idx * step))
        end
      end
      height = math.max(1, _45_())
      pcall(vim.api.nvim_win_set_height, win, height)
      local val_110_auto = opts0["tick!"]
      if val_110_auto then
        local tick_21 = val_110_auto
        return tick_21(height, idx)
      else
        return nil
      end
    end
    local function _47_()
      pcall(vim.api.nvim_win_set_height, win, stop)
      local val_110_auto = opts0["done!"]
      if val_110_auto then
        local done_21 = val_110_auto
        return done_21(stop)
      else
        return nil
      end
    end
    return run_21(session, key, {["duration-ms"] = duration_ms0, steps = math.max(1, math.abs((stop - start))), ["active?"] = _43_, ["tick!"] = _44_, ["done!"] = _47_})
  end
  return with_split_mins(_42_)
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
    ensure_mini_global_21(session)
    local function _50_()
      set_win_height_21(win, stop)
      local function _51_()
        local val_110_auto = opts0["done!"]
        if val_110_auto then
          local done_21 = val_110_auto
          return done_21(stop)
        else
          return nil
        end
      end
      return mini_after_21("resize", duration_ms0, _51_)
    end
    return with_split_mins(_50_)
  else
    local function _53_()
      local function _54_()
        return vim.api.nvim_win_is_valid(win)
      end
      local function _55_(_, idx)
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
      local function _59_()
        set_win_height_21(win, stop)
        local val_110_auto = opts0["done!"]
        if val_110_auto then
          local done_21 = val_110_auto
          return done_21(stop)
        else
          return nil
        end
      end
      return run_21(session, key, {["duration-ms"] = duration_ms0, steps = math.max(1, math.ceil((math.max(1, delta) / stride))), ["active?"] = _54_, ["tick!"] = _55_, ["done!"] = _59_})
    end
    return with_split_mins(_53_)
  end
end
local function _62_(session, key, win, from, to, duration_ms0, opts)
  local start = math.max(1, from)
  local stop = math.max(1, to)
  local opts0 = (opts or {})
  local function _63_()
    local function _64_()
      return vim.api.nvim_win_is_valid(win)
    end
    local function _65_(t)
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
    local function _67_()
      pcall(vim.api.nvim_win_set_width, win, stop)
      local val_110_auto = opts0["done!"]
      if val_110_auto then
        local done_21 = val_110_auto
        return done_21(stop)
      else
        return nil
      end
    end
    return run_21(session, key, {["duration-ms"] = duration_ms0, steps = math.max(2, math.floor((duration_ms0 / target_frame_ms))), ["active?"] = _64_, ["tick!"] = _65_, ["done!"] = _67_})
  end
  return with_split_mins(_63_)
end
animate_win_width_21 = _62_
local function _69_(session, key, win, from_cfg, to_cfg, from_blend, to_blend, duration_ms0, opts)
  local opts0 = (opts or {})
  local kind = (opts0.kind or "info")
  if ((animation_backend(session, kind) == "mini") and supports_backend_3f("mini")) then
    local mini = mini_animate_mod()
    local n_steps = math.max(2, math.floor((duration_ms0 / target_frame_ms)))
    local blend_fn = mini_float_winblend_fn(mini, from_blend, to_blend)
    local function _70_()
      return vim.api.nvim_win_is_valid(win)
    end
    local function _71_(step)
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
    return mini_run_21(mini, session, key, n_steps, duration_ms0, _70_, _71_)
  else
    local function _74_()
      return vim.api.nvim_win_is_valid(win)
    end
    local function _75_(t)
      local cfg = float_step_config(from_cfg, to_cfg, t)
      local blend = math.max(0, math.min(100, math.floor((0.5 + lerp(from_blend, to_blend, t)))))
      return apply_float_step_21(win, cfg, blend, opts0, t)
    end
    local function _76_()
      apply_float_step_21(win, to_cfg, to_blend, opts0, 1)
      local val_110_auto = opts0["done!"]
      if val_110_auto then
        local done_21 = val_110_auto
        return done_21(to_cfg)
      else
        return nil
      end
    end
    return run_21(session, key, {["duration-ms"] = duration_ms0, steps = math.max(2, math.floor((duration_ms0 / target_frame_ms))), ["active?"] = _74_, ["tick!"] = _75_, ["done!"] = _76_})
  end
end
animate_float_21 = _69_
local function _79_(session, key, win, from_view, to_view, duration_ms0, opts)
  local opts0 = (opts or {})
  local function _80_()
    return vim.api.nvim_win_is_valid(win)
  end
  local function _81_(t)
    local function _82_()
      return pcall(vim.fn.winrestview, {topline = math.max(1, math.floor((0.5 + lerp((from_view.topline or 1), (to_view.topline or 1), t)))), lnum = math.max(1, math.floor((0.5 + lerp((from_view.lnum or 1), (to_view.lnum or 1), t)))), leftcol = math.max(0, math.floor((0.5 + lerp((from_view.leftcol or 0), (to_view.leftcol or 0), t)))), col = math.max(0, math.floor((0.5 + lerp((from_view.col or 0), (to_view.col or 0), t))))})
    end
    return vim.api.nvim_win_call(win, _82_)
  end
  local function _83_()
    local function _84_()
      return pcall(vim.fn.winrestview, to_view)
    end
    vim.api.nvim_win_call(win, _84_)
    local val_110_auto = opts0["done!"]
    if val_110_auto then
      local done_21 = val_110_auto
      return done_21(to_view)
    else
      return nil
    end
  end
  return run_21(session, key, {["duration-ms"] = duration_ms0, steps = math.max(2, math.floor((duration_ms0 / target_frame_ms))), ["active?"] = _80_, ["tick!"] = _81_, ["done!"] = _83_})
end
animate_view_21 = _79_
local function _86_(session, _key, win, _from_view, to_view, _duration_ms, opts)
  ensure_mini_global_21(session)
  local function _87_()
    return pcall(vim.fn.winrestview, to_view)
  end
  vim.api.nvim_win_call(win, _87_)
  local function _88_()
    local val_110_auto = (opts or {})["done!"]
    if val_110_auto then
      local done_21 = val_110_auto
      return done_21(to_view)
    else
      return nil
    end
  end
  return mini_after_21("scroll", duration_ms, _88_)
end
animate_scroll_view_mini_21 = _86_
local function _90_(session, key, win, from_view, to_view, duration_ms0, opts)
  if ((animation_backend(session, "scroll") == "mini") and supports_backend_3f("mini")) then
    return animate_scroll_view_mini_21(session, key, win, from_view, to_view, duration_ms0, opts)
  else
    return animate_view_21(session, key, win, from_view, to_view, duration_ms0, opts)
  end
end
animate_scroll_view_21 = _90_
local function reset_mini_animate_cache_21()
  mini_animate_cache = nil
  mini_animate_tried_3f = false
  return nil
end
M["enabled?"] = enabled_3f
M["duration-ms"] = duration_ms
M["animation-backend"] = animation_backend
local function _92_(session)
  return animation_backend(session, "scroll")
end
M["scroll-backend"] = _92_
M["supports-backend?"] = supports_backend_3f
M["supports-scroll-backend?"] = supports_backend_3f
M["ensure-mini-global!"] = ensure_mini_global_21
M["mark-mini-session!"] = mark_mini_session_21
M["unmark-mini-session!"] = unmark_mini_session_21
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
