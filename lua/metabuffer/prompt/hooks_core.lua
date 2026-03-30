-- [nfnl] fnl/metabuffer/prompt/hooks_core.fnl
local M = {}
local animation_mod = require("metabuffer.window.animation")
local events = require("metabuffer.events")
M.new = function(opts)
  local _let_1_ = (opts or {})
  local active_by_prompt = _let_1_["active-by-prompt"]
  local animation_enabled_3f = animation_mod["enabled?"]
  local animation_duration_ms = animation_mod["duration-ms"]
  local function prompt_animation_delay_ms(session)
    if (animation_mod and animation_enabled_3f and animation_enabled_3f(session, "prompt")) then
      return animation_duration_ms(session, "prompt", 140)
    else
      return 0
    end
  end
  local function switch_mode_21(session, which)
    local meta = session.meta
    local function mode_label(value)
      if (type(value) == "table") then
        return (value.name or tostring(value))
      else
        return tostring(value)
      end
    end
    local old = mode_label(meta.mode[which].current())
    meta.switch_mode(which)
    return events.post("on-mode-switch!", {session = session, kind = which, old = old, new = mode_label(meta.mode[which].current())}, {["supersede?"] = true, ["dedupe-key"] = ("on-mode-switch:" .. tostring(session["prompt-buf"]) .. ":" .. which)})
  end
  local function nvim_exiting_3f()
    local v = (vim.v and vim.v.exiting)
    return ((v ~= nil) and (v ~= vim.NIL) and (v ~= 0) and (v ~= ""))
  end
  local function session_prompt_valid_3f(session)
    return (not nvim_exiting_3f() and session and not session["ui-hidden"] and not session.closing and session.meta and session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and (active_by_prompt[session["prompt-buf"]] == session))
  end
  local function schedule_when_valid(session, f)
    local function _4_()
      if session_prompt_valid_3f(session) then
        return f()
      else
        return nil
      end
    end
    return vim.schedule(_4_)
  end
  local function option_prefix()
    local p = vim.g["meta#prefix"]
    if ((type(p) == "string") and (p ~= "")) then
      return p
    else
      return "#"
    end
  end
  return {["option-prefix"] = option_prefix, ["prompt-animation-delay-ms"] = prompt_animation_delay_ms, ["schedule-when-valid"] = schedule_when_valid, ["session-prompt-valid?"] = session_prompt_valid_3f, ["switch-mode!"] = switch_mode_21}
end
return M
