-- [nfnl] fnl/metabuffer/window/animation.fnl
local M = {}
local target_frame_ms = 17
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
local function ease_out_cubic(t)
  local x = (1 - math.max(0, math.min(t, 1)))
  return (1 - (x * x * x))
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
local function run_21(session, key, opts)
  local duration_ms0 = opts["duration-ms"]
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
        local function _4_()
          return frame_21(idx)
        end
        return vim.defer_fn(_4_, (delay - elapsed))
      else
        last_frame_ms = now
        local t = ease_out_cubic((idx / total))
        tick_21(t, idx, total)
        if (idx < total) then
          local function _5_()
            return frame_21((idx + 1))
          end
          return vim.defer_fn(_5_, delay)
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
  local function _11_()
    local function _12_()
      return vim.api.nvim_win_is_valid(win)
    end
    local function _13_(_, idx)
      local height
      local function _14_()
        if (idx == 0) then
          return start
        else
          return (start + (idx * step))
        end
      end
      height = math.max(1, _14_())
      pcall(vim.api.nvim_win_set_height, win, height)
      local val_110_auto = opts0["tick!"]
      if val_110_auto then
        local tick_21 = val_110_auto
        return tick_21(height, idx)
      else
        return nil
      end
    end
    local function _16_()
      pcall(vim.api.nvim_win_set_height, win, stop)
      local val_110_auto = opts0["done!"]
      if val_110_auto then
        local done_21 = val_110_auto
        return done_21(stop)
      else
        return nil
      end
    end
    return run_21(session, key, {["duration-ms"] = duration_ms0, steps = math.max(1, math.abs((stop - start))), ["active?"] = _12_, ["tick!"] = _13_, ["done!"] = _16_})
  end
  return with_split_mins(_11_)
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
  local function _19_()
    local function _20_()
      return vim.api.nvim_win_is_valid(win)
    end
    local function _21_(_, idx)
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
    return run_21(session, key, {["duration-ms"] = duration_ms0, steps = math.max(1, math.ceil((math.max(1, delta) / stride))), ["active?"] = _20_, ["tick!"] = _21_, ["done!"] = _25_})
  end
  return with_split_mins(_19_)
end
local function animate_win_width_21(session, key, win, from, to, duration_ms0, opts)
  local start = math.max(1, from)
  local stop = math.max(1, to)
  local opts0 = (opts or {})
  local function _27_()
    local function _28_()
      return vim.api.nvim_win_is_valid(win)
    end
    local function _29_(t)
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
    local function _31_()
      pcall(vim.api.nvim_win_set_width, win, stop)
      local val_110_auto = opts0["done!"]
      if val_110_auto then
        local done_21 = val_110_auto
        return done_21(stop)
      else
        return nil
      end
    end
    return run_21(session, key, {["duration-ms"] = duration_ms0, steps = math.max(2, math.floor((duration_ms0 / target_frame_ms))), ["active?"] = _28_, ["tick!"] = _29_, ["done!"] = _31_})
  end
  return with_split_mins(_27_)
end
local function animate_float_21(session, key, win, from_cfg, to_cfg, from_blend, to_blend, duration_ms0)
  local function _33_()
    return vim.api.nvim_win_is_valid(win)
  end
  local function _34_(t)
    local cfg = {relative = to_cfg.relative, anchor = to_cfg.anchor, row = lerp((from_cfg.row or to_cfg.row), to_cfg.row, t), col = lerp((from_cfg.col or to_cfg.col), to_cfg.col, t), width = math.max(1, math.floor((0.5 + lerp((from_cfg.width or to_cfg.width), to_cfg.width, t)))), height = math.max(1, math.floor((0.5 + lerp((from_cfg.height or to_cfg.height), to_cfg.height, t)))), style = "minimal"}
    local _
    do
      local val_110_auto = to_cfg.win
      if val_110_auto then
        local host = val_110_auto
        cfg["win"] = host
        _ = nil
      else
        _ = nil
      end
    end
    local blend = math.max(0, math.min(100, math.floor((0.5 + lerp(from_blend, to_blend, t)))))
    pcall(vim.api.nvim_win_set_config, win, cfg)
    return pcall(vim.api.nvim_set_option_value, "winblend", blend, {win = win})
  end
  local function _36_()
    pcall(vim.api.nvim_win_set_config, win, to_cfg)
    return pcall(vim.api.nvim_set_option_value, "winblend", to_blend, {win = win})
  end
  return run_21(session, key, {["duration-ms"] = duration_ms0, steps = math.max(2, math.floor((duration_ms0 / target_frame_ms))), ["active?"] = _33_, ["tick!"] = _34_, ["done!"] = _36_})
end
local function animate_view_21(session, key, win, from_view, to_view, duration_ms0)
  local function _37_()
    return vim.api.nvim_win_is_valid(win)
  end
  local function _38_(t)
    local function _39_()
      return pcall(vim.fn.winrestview, {topline = math.max(1, math.floor((0.5 + lerp((from_view.topline or 1), (to_view.topline or 1), t)))), lnum = math.max(1, math.floor((0.5 + lerp((from_view.lnum or 1), (to_view.lnum or 1), t)))), leftcol = math.max(0, math.floor((0.5 + lerp((from_view.leftcol or 0), (to_view.leftcol or 0), t)))), col = math.max(0, math.floor((0.5 + lerp((from_view.col or 0), (to_view.col or 0), t))))})
    end
    return vim.api.nvim_win_call(win, _39_)
  end
  local function _40_()
    local function _41_()
      return pcall(vim.fn.winrestview, to_view)
    end
    return vim.api.nvim_win_call(win, _41_)
  end
  return run_21(session, key, {["duration-ms"] = duration_ms0, steps = math.max(2, math.floor((duration_ms0 / target_frame_ms))), ["active?"] = _37_, ["tick!"] = _38_, ["done!"] = _40_})
end
M["enabled?"] = enabled_3f
M["duration-ms"] = duration_ms
M["run!"] = run_21
M["animate-win-height!"] = animate_win_height_21
M["animate-win-height-stepwise!"] = animate_win_height_stepwise_21
M["animate-win-width!"] = animate_win_width_21
M["animate-float!"] = animate_float_21
M["animate-view!"] = animate_view_21
return M
