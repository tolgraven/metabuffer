-- [nfnl] .deps/git/io.gitlab.andreyorst/async.fnl/a83b13b397fdfab3ebf7f17a16d21a7ec2674ceb/src/io/gitlab/andreyorst/async.fnl
--[[ "Copyright (c) 2023 Andrey Listopadov and contributors.  All rights reserved.
The use and distribution terms for this software are covered by the Eclipse
Public License 1.0 (http://opensource.org/licenses/eclipse-1.0.php) which
can be found in the file LICENSE at the root of this distribution.  By using
this software in any fashion, you are agreeing to be bound by the terms of
this license.
You must not remove this notice, or any other, from this software." ]]
local lib_name = (... or "src.io.gitlab.andreyorst.async")
local main_thread = (coroutine.running() or error((lib_name .. " requires Lua 5.2 or higher")))
local or_1_ = package.preload["io.gitlab.andreyorst.reduced"]
if not or_1_ then
  local function _2_()
    local Reduced
    local function _4_(_3_, view, options, indent)
      local x = _3_[1]
      return ("#<reduced: " .. view(x, options, (11 + indent)) .. ">")
    end
    local function _6_(_5_)
      local x = _5_[1]
      return x
    end
    local function _8_(_7_)
      local x = _7_[1]
      return ("reduced: " .. tostring(x))
    end
    Reduced = {__fennelview = _4_, __index = {unbox = _6_}, __name = "reduced", __tostring = _8_}
    local function reduced(value)
      return setmetatable({value}, Reduced)
    end
    local function reduced_3f(value)
      return rawequal(getmetatable(value), Reduced)
    end
    return {is_reduced = reduced_3f, reduced = reduced, ["reduced?"] = reduced_3f}
  end
  or_1_ = _2_
end
package.preload["io.gitlab.andreyorst.reduced"] = or_1_
local _local_9_ = require("io.gitlab.andreyorst.reduced")
local reduced = _local_9_.reduced
local reduced_3f = _local_9_["reduced?"]
local gethook, sethook
do
  local case_10_ = _G.debug
  if ((_G.type(case_10_) == "table") and (nil ~= case_10_.gethook) and (nil ~= case_10_.sethook)) then
    local gethook0 = case_10_.gethook
    local sethook0 = case_10_.sethook
    gethook, sethook = gethook0, sethook0
  else
    local _ = case_10_
    io.stderr:write("WARNING: debug library is unawailable.  ", lib_name, " uses debug.sethook to advance timers.  ", "Time-related features are disabled.\n")
    gethook, sethook = nil
  end
end
local t_2fremove = table.remove
local t_2fconcat = table.concat
local t_2finsert = table.insert
local t_2fsort = table.sort
local t_2funpack = (_G.unpack or table.unpack)
local c_2frunning = coroutine.running
local c_2fresume = coroutine.resume
local c_2fyield = coroutine.yield
local c_2fcreate = coroutine.create
local m_2fmin = math.min
local m_2frandom = math.random
local m_2fceil = math.ceil
local m_2ffloor = math.floor
local m_2fmodf = math.modf
local function main_thread_3f()
  local case_12_, case_13_ = c_2frunning()
  if (case_12_ == nil) then
    return true
  elseif (true and (case_13_ == true)) then
    local _ = case_12_
    return true
  else
    local _ = case_12_
    return false
  end
end
local function merge_2a(t1, t2)
  local res = {}
  do
    local tbl_21_ = res
    for k, v in pairs(t1) do
      local k_22_, v_23_ = k, v
      if ((k_22_ ~= nil) and (v_23_ ~= nil)) then
        tbl_21_[k_22_] = v_23_
      else
      end
    end
  end
  local tbl_21_ = res
  for k, v in pairs(t2) do
    local k_22_, v_23_ = k, v
    if ((k_22_ ~= nil) and (v_23_ ~= nil)) then
      tbl_21_[k_22_] = v_23_
    else
    end
  end
  return tbl_21_
end
local function merge_with(f, t1, t2)
  local res
  do
    local tbl_21_ = {}
    for k, v in pairs(t1) do
      local k_22_, v_23_ = k, v
      if ((k_22_ ~= nil) and (v_23_ ~= nil)) then
        tbl_21_[k_22_] = v_23_
      else
      end
    end
    res = tbl_21_
  end
  local tbl_21_ = res
  for k, v in pairs(t2) do
    local k_22_, v_23_
    do
      local case_18_ = res[k]
      if (nil ~= case_18_) then
        local e = case_18_
        k_22_, v_23_ = k, f(e, v)
      elseif (case_18_ == nil) then
        k_22_, v_23_ = k, v
      else
        k_22_, v_23_ = nil
      end
    end
    if ((k_22_ ~= nil) and (v_23_ ~= nil)) then
      tbl_21_[k_22_] = v_23_
    else
    end
  end
  return tbl_21_
end
local function active_3f(h)
  if (nil == h) then
    _G.error("Missing argument h on .deps/git/io.gitlab.andreyorst/async.fnl/a83b13b397fdfab3ebf7f17a16d21a7ec2674ceb/src/io/gitlab/andreyorst/async.fnl:334", 2)
  else
  end
  return h["active?"](h)
end
local function blockable_3f(h)
  if (nil == h) then
    _G.error("Missing argument h on .deps/git/io.gitlab.andreyorst/async.fnl/a83b13b397fdfab3ebf7f17a16d21a7ec2674ceb/src/io/gitlab/andreyorst/async.fnl:335", 2)
  else
  end
  return h["blockable?"](h)
end
local function commit(h)
  if (nil == h) then
    _G.error("Missing argument h on .deps/git/io.gitlab.andreyorst/async.fnl/a83b13b397fdfab3ebf7f17a16d21a7ec2674ceb/src/io/gitlab/andreyorst/async.fnl:336", 2)
  else
  end
  return h:commit()
end
local _local_24_ = {["active?"] = active_3f, ["blockable?"] = blockable_3f, commit = commit}
local active_3f0 = _local_24_["active?"]
local blockable_3f0 = _local_24_["blockable?"]
local commit0 = _local_24_.commit
local Handler = _local_24_
local function fn_handler(f, ...)
  local blockable
  if (0 == select("#", ...)) then
    blockable = true
  else
    blockable = ...
  end
  local _26_ = {}
  do
    do
      local case_27_ = Handler["active?"]
      if (nil ~= case_27_) then
        local f_3_auto = case_27_
        local function _28_(_)
          return true
        end
        _26_["active?"] = _28_
      else
        local _ = case_27_
        error("Protocol Handler doesn't define method active?")
      end
    end
    do
      local case_30_ = Handler["blockable?"]
      if (nil ~= case_30_) then
        local f_3_auto = case_30_
        local function _31_(_)
          return blockable
        end
        _26_["blockable?"] = _31_
      else
        local _ = case_30_
        error("Protocol Handler doesn't define method blockable?")
      end
    end
    local case_33_ = Handler.commit
    if (nil ~= case_33_) then
      local f_3_auto = case_33_
      local function _34_(_)
        return f
      end
      _26_["commit"] = _34_
    else
      local _ = case_33_
      error("Protocol Handler doesn't define method commit")
    end
  end
  local function _36_(_241)
    return ("#<" .. tostring(_241):gsub("table:", "reify:") .. ": " .. "Handler" .. ">")
  end
  return setmetatable({}, {__fennelview = _36_, __index = _26_, __name = "reify"})
end
local fhnop
local function _37_()
  return nil
end
fhnop = fn_handler(_37_)
local socket
do
  local case_38_, case_39_ = pcall(require, "socket")
  if ((case_38_ == true) and (nil ~= case_39_)) then
    local s = case_39_
    socket = s
  else
    local _ = case_38_
    socket = nil
  end
end
local posix
do
  local case_41_, case_42_ = pcall(require, "posix")
  if ((case_41_ == true) and (nil ~= case_42_)) then
    local p = case_42_
    posix = p
  else
    local _ = case_41_
    posix = nil
  end
end
local time, sleep, time_type
local _45_
do
  local t_44_ = socket
  if (nil ~= t_44_) then
    t_44_ = t_44_.gettime
  else
  end
  _45_ = t_44_
end
if _45_ then
  local sleep0 = socket.sleep
  local function _47_(_241)
    return sleep0((_241 / 1000))
  end
  time, sleep, time_type = socket.gettime, _47_, "socket"
else
  local _49_
  do
    local t_48_ = posix
    if (nil ~= t_48_) then
      t_48_ = t_48_.clock_gettime
    else
    end
    _49_ = t_48_
  end
  if _49_ then
    local gettime = posix.clock_gettime
    local nanosleep = posix.nanosleep
    local function _51_()
      local s, ns = gettime()
      return (s + (ns / 1000000000))
    end
    local function _52_(_241)
      local s, ms = m_2fmodf((_241 / 1000))
      return nanosleep(s, (1000000 * 1000 * ms))
    end
    time, sleep, time_type = _51_, _52_, "posix"
  else
    time, sleep, time_type = os.time, nil, "lua"
  end
end
local difftime
local function _54_(_241, _242)
  return (_241 - _242)
end
difftime = _54_
local function add_21(buffer, item)
  if (nil == item) then
    _G.error("Missing argument item on .deps/git/io.gitlab.andreyorst/async.fnl/a83b13b397fdfab3ebf7f17a16d21a7ec2674ceb/src/io/gitlab/andreyorst/async.fnl:375", 2)
  else
  end
  if (nil == buffer) then
    _G.error("Missing argument buffer on .deps/git/io.gitlab.andreyorst/async.fnl/a83b13b397fdfab3ebf7f17a16d21a7ec2674ceb/src/io/gitlab/andreyorst/async.fnl:375", 2)
  else
  end
  return buffer["add!"](buffer, item)
end
local function close_buf_21(buffer)
  if (nil == buffer) then
    _G.error("Missing argument buffer on .deps/git/io.gitlab.andreyorst/async.fnl/a83b13b397fdfab3ebf7f17a16d21a7ec2674ceb/src/io/gitlab/andreyorst/async.fnl:376", 2)
  else
  end
  return buffer["close-buf!"](buffer)
end
local function full_3f(buffer)
  if (nil == buffer) then
    _G.error("Missing argument buffer on .deps/git/io.gitlab.andreyorst/async.fnl/a83b13b397fdfab3ebf7f17a16d21a7ec2674ceb/src/io/gitlab/andreyorst/async.fnl:373", 2)
  else
  end
  return buffer["full?"](buffer)
end
local function remove_21(buffer)
  if (nil == buffer) then
    _G.error("Missing argument buffer on .deps/git/io.gitlab.andreyorst/async.fnl/a83b13b397fdfab3ebf7f17a16d21a7ec2674ceb/src/io/gitlab/andreyorst/async.fnl:374", 2)
  else
  end
  return buffer["remove!"](buffer)
end
local _local_60_ = {["add!"] = add_21, ["close-buf!"] = close_buf_21, ["full?"] = full_3f, ["remove!"] = remove_21}
local add_210 = _local_60_["add!"]
local close_buf_210 = _local_60_["close-buf!"]
local full_3f0 = _local_60_["full?"]
local remove_210 = _local_60_["remove!"]
local Buffer = _local_60_
local FixedBuffer
local function _62_(_61_)
  local buffer = _61_.buf
  local size = _61_.size
  return (#buffer >= size)
end
local function _64_(_63_)
  local buffer = _63_.buf
  return #buffer
end
local function _66_(_65_, val)
  local buffer = _65_.buf
  local this = _65_
  assert((val ~= nil), "value must not be nil")
  buffer[(1 + #buffer)] = val
  return this
end
local function _68_(_67_)
  local buffer = _67_.buf
  if (#buffer > 0) then
    return t_2fremove(buffer, 1)
  else
    return nil
  end
end
local function _70_(_)
  return nil
end
FixedBuffer = {type = Buffer, ["full?"] = _62_, length = _64_, ["add!"] = _66_, ["remove!"] = _68_, ["close-buf!"] = _70_}
local DroppingBuffer
local function _71_()
  return false
end
local function _73_(_72_)
  local buffer = _72_.buf
  return #buffer
end
local function _75_(_74_, val)
  local buffer = _74_.buf
  local size = _74_.size
  local this = _74_
  assert((val ~= nil), "value must not be nil")
  if (#buffer < size) then
    buffer[(1 + #buffer)] = val
  else
  end
  return this
end
local function _78_(_77_)
  local buffer = _77_.buf
  if (#buffer > 0) then
    return t_2fremove(buffer, 1)
  else
    return nil
  end
end
local function _80_(_)
  return nil
end
DroppingBuffer = {type = Buffer, ["full?"] = _71_, length = _73_, ["add!"] = _75_, ["remove!"] = _78_, ["close-buf!"] = _80_}
local SlidingBuffer
local function _81_()
  return false
end
local function _83_(_82_)
  local buffer = _82_.buf
  return #buffer
end
local function _85_(_84_, val)
  local buffer = _84_.buf
  local size = _84_.size
  local this = _84_
  assert((val ~= nil), "value must not be nil")
  buffer[(1 + #buffer)] = val
  if (size < #buffer) then
    t_2fremove(buffer, 1)
  else
  end
  return this
end
local function _88_(_87_)
  local buffer = _87_.buf
  if (#buffer > 0) then
    return t_2fremove(buffer, 1)
  else
    return nil
  end
end
local function _90_(_)
  return nil
end
SlidingBuffer = {type = Buffer, ["full?"] = _81_, length = _83_, ["add!"] = _85_, ["remove!"] = _88_, ["close-buf!"] = _90_}
local no_val = {}
local PromiseBuffer
local function _91_()
  return false
end
local function _92_(this)
  if rawequal(no_val, this.val) then
    return 0
  else
    return 1
  end
end
local function _94_(this, val)
  assert((val ~= nil), "value must not be nil")
  if rawequal(no_val, this.val) then
    this["val"] = val
  else
  end
  return this
end
local function _97_(_96_)
  local value = _96_.val
  return value
end
local function _99_(_98_)
  local value = _98_.val
  local this = _98_
  if rawequal(no_val, value) then
    this["val"] = nil
    return nil
  else
    return nil
  end
end
PromiseBuffer = {type = Buffer, val = no_val, ["full?"] = _91_, length = _92_, ["add!"] = _94_, ["remove!"] = _97_, ["close-buf!"] = _99_}
local function buffer_2a(size, buffer_type)
  do local _ = (size and assert(("number" == type(size)), ("size must be a number: " .. tostring(size)))) end
  assert(not tostring(size):match("%."), "size must be integer")
  local function _101_(self)
    return self:length()
  end
  local function _102_(_241)
    return ("#<" .. tostring(_241):gsub("table:", "buffer:") .. ">")
  end
  return setmetatable({size = size, buf = {}}, {__index = buffer_type, __name = "buffer", __len = _101_, __fennelview = _102_})
end
local function buffer(n)
  return buffer_2a(n, FixedBuffer)
end
local function dropping_buffer(n)
  return buffer_2a(n, DroppingBuffer)
end
local function sliding_buffer(n)
  return buffer_2a(n, SlidingBuffer)
end
local function promise_buffer()
  return buffer_2a(1, PromiseBuffer)
end
local function buffer_3f(obj)
  if ((_G.type(obj) == "table") and (obj.type == Buffer)) then
    return true
  else
    local _ = obj
    return false
  end
end
local function unblocking_buffer_3f(buff)
  local case_104_ = (buffer_3f(buff) and getmetatable(buff).__index)
  if (case_104_ == SlidingBuffer) then
    return true
  elseif (case_104_ == DroppingBuffer) then
    return true
  elseif (case_104_ == PromiseBuffer) then
    return true
  else
    local _ = case_104_
    return false
  end
end
local timeouts = {}
local dispatched_tasks = {}
local os_2fclock = os.clock
local n_instr, register_time, orig_hook, orig_mask, orig_n = 1000000
local function schedule_hook(hook, n)
  if (gethook and sethook) then
    local hook_2a, mask, n_2a = gethook()
    if (hook ~= hook_2a) then
      register_time, orig_hook, orig_mask, orig_n = os_2fclock(), hook_2a, mask, n_2a
      return sethook(main_thread, hook, "", n)
    else
      return nil
    end
  else
    return nil
  end
end
local function cancel_hook(hook)
  if (gethook and sethook) then
    local case_108_, case_109_, case_110_ = gethook(main_thread)
    if ((case_108_ == hook) and true and true) then
      local _3fmask = case_109_
      local _3fn = case_110_
      sethook(main_thread, orig_hook, orig_mask, orig_n)
      return _3fmask, _3fn
    else
      return nil
    end
  else
    return nil
  end
end
local function process_messages(event)
  local took = (os_2fclock() - register_time)
  local _, n = cancel_hook(process_messages)
  if (event ~= "count") then
    n_instr = n
  else
    n_instr = m_2ffloor((0.01 / (took / n)))
  end
  do
    local done = nil
    for _0 = 1, 1024 do
      if done then break end
      local case_114_ = next(dispatched_tasks)
      if (nil ~= case_114_) then
        local f = case_114_
        local _115_
        do
          pcall(f)
          _115_ = f
        end
        dispatched_tasks[_115_] = nil
        done = nil
      elseif (case_114_ == nil) then
        done = true
      else
        done = nil
      end
    end
  end
  for t, ch in pairs(timeouts) do
    if (0 >= difftime(t, time())) then
      timeouts[t] = ch["close!"](ch)
    else
    end
  end
  if (next(dispatched_tasks) or next(timeouts)) then
    return schedule_hook(process_messages, n_instr)
  else
    return nil
  end
end
local function dispatch(f)
  if (gethook and sethook) then
    dispatched_tasks[f] = true
    schedule_hook(process_messages, n_instr)
  else
    f()
  end
  return nil
end
local function put_active_3f(_120_)
  local handler = _120_[1]
  return handler["active?"](handler)
end
local function cleanup_21(t, pred)
  local to_keep
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for i, v in ipairs(t) do
      local val_28_
      if pred(v) then
        val_28_ = v
      else
        val_28_ = nil
      end
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    to_keep = tbl_26_
  end
  while t_2fremove(t) do
  end
  for _, v in ipairs(to_keep) do
    t_2finsert(t, v)
  end
  return t
end
local MAX_QUEUE_SIZE = 1024
local MAX_DIRTY = 64
local Channel = {["dirty-puts"] = 0, ["dirty-takes"] = 0}
Channel.abort = function(_123_)
  local puts = _123_.puts
  local function recur()
    local putter = t_2fremove(puts, 1)
    if (nil ~= putter) then
      local put_handler = putter[1]
      local val = putter[2]
      if put_handler["active?"](put_handler) then
        local put_cb = put_handler:commit()
        local function _124_()
          return put_cb(true)
        end
        return dispatch(_124_)
      else
        return recur()
      end
    else
      return nil
    end
  end
  return recur
end
Channel["put!"] = function(_127_, val, handler, enqueue_3f)
  local buf = _127_.buf
  local closed = _127_.closed
  local this = _127_
  assert((val ~= nil), "Can't put nil on a channel")
  if not handler["active?"]() then
    return {not closed}
  elseif closed then
    handler:commit()
    return {false}
  elseif (buf and not buf["full?"](buf)) then
    local takes = this.takes
    local add_211 = this["add!"]
    handler:commit()
    local done_3f = reduced_3f(add_211(buf, val))
    local take_cbs
    local function recur(takers)
      if (next(takes) and (#buf > 0)) then
        local taker = t_2fremove(takes, 1)
        if taker["active?"](taker) then
          local ret = taker:commit()
          local val0 = buf["remove!"](buf)
          local function _128_()
            local function _129_()
              return ret(val0)
            end
            t_2finsert(takers, _129_)
            return takers
          end
          return recur(_128_())
        else
          return recur(takers)
        end
      else
        return takers
      end
    end
    take_cbs = recur({})
    if done_3f then
      this:abort()
    else
    end
    if next(take_cbs) then
      for _, f in ipairs(take_cbs) do
        dispatch(f)
      end
    else
    end
    return {true}
  else
    local takes = this.takes
    local taker
    local function recur()
      local taker0 = t_2fremove(takes, 1)
      if taker0 then
        if taker0["active?"](taker0) then
          return taker0
        else
          return recur()
        end
      else
        return nil
      end
    end
    taker = recur()
    if taker then
      local take_cb = taker:commit()
      handler:commit()
      local function _136_()
        return take_cb(val)
      end
      dispatch(_136_)
      return {true}
    else
      local puts = this.puts
      local dirty_puts = this["dirty-puts"]
      if (dirty_puts > MAX_DIRTY) then
        this["dirty-puts"] = 0
        cleanup_21(puts, put_active_3f)
      else
        this["dirty-puts"] = (1 + dirty_puts)
      end
      if handler["blockable?"](handler) then
        assert((#puts < MAX_QUEUE_SIZE), ("No more than " .. MAX_QUEUE_SIZE .. " pending puts are allowed on a single channel." .. " Consider using a windowed buffer."))
        local handler_2a
        if (main_thread_3f() or enqueue_3f) then
          handler_2a = handler
        else
          local thunk = c_2frunning()
          local _138_ = {}
          do
            do
              local case_139_ = Handler["active?"]
              if (nil ~= case_139_) then
                local f_3_auto = case_139_
                local function _140_(_)
                  return handler["active?"](handler)
                end
                _138_["active?"] = _140_
              else
                local _ = case_139_
                error("Protocol Handler doesn't define method active?")
              end
            end
            do
              local case_142_ = Handler["blockable?"]
              if (nil ~= case_142_) then
                local f_3_auto = case_142_
                local function _143_(_)
                  return handler["blockable?"](handler)
                end
                _138_["blockable?"] = _143_
              else
                local _ = case_142_
                error("Protocol Handler doesn't define method blockable?")
              end
            end
            local case_145_ = Handler.commit
            if (nil ~= case_145_) then
              local f_3_auto = case_145_
              local function _146_(_)
                local function _147_(...)
                  return c_2fresume(thunk, ...)
                end
                return _147_
              end
              _138_["commit"] = _146_
            else
              local _ = case_145_
              error("Protocol Handler doesn't define method commit")
            end
          end
          local function _149_(_241)
            return ("#<" .. tostring(_241):gsub("table:", "reify:") .. ": " .. "Handler" .. ">")
          end
          handler_2a = setmetatable({}, {__fennelview = _149_, __index = _138_, __name = "reify"})
        end
        t_2finsert(puts, {handler_2a, val})
        if (handler ~= handler_2a) then
          local val0 = c_2fyield()
          handler:commit()(val0)
          return {val0}
        else
          return nil
        end
      else
        return nil
      end
    end
  end
end
Channel["take!"] = function(_155_, handler, enqueue_3f)
  local buf = _155_.buf
  local this = _155_
  if not handler["active?"](handler) then
    return nil
  elseif (not (nil == buf) and (#buf > 0)) then
    local case_156_ = handler:commit()
    if (nil ~= case_156_) then
      local take_cb = case_156_
      local puts = this.puts
      local val = buf["remove!"](buf)
      if (not buf["full?"](buf) and next(puts)) then
        local add_211 = this["add!"]
        local function recur(cbs)
          local putter = t_2fremove(puts, 1)
          local put_handler = putter[1]
          local val0 = putter[2]
          local cb = (put_handler["active?"](put_handler) and put_handler:commit())
          local cbs0
          if cb then
            t_2finsert(cbs, cb)
            cbs0 = cbs
          else
            cbs0 = cbs
          end
          local done_3f
          if cb then
            done_3f = reduced_3f(add_211(buf, val0))
          else
            done_3f = nil
          end
          if (not done_3f and not buf["full?"](buf) and next(puts)) then
            return recur(cbs0)
          else
            return {done_3f, cbs0}
          end
        end
        local _let_160_ = recur({})
        local done_3f = _let_160_[1]
        local cbs = _let_160_[2]
        if done_3f then
          this:abort()
        else
        end
        for _, cb in ipairs(cbs) do
          local function _162_()
            return cb(true)
          end
          dispatch(_162_)
        end
      else
      end
      return {val}
    else
      return nil
    end
  else
    local puts = this.puts
    local putter
    local function recur()
      local putter0 = t_2fremove(puts, 1)
      if putter0 then
        local tgt_165_ = putter0[1]
        if (tgt_165_)["active?"](tgt_165_) then
          return putter0
        else
          return recur()
        end
      else
        return nil
      end
    end
    putter = recur()
    if putter then
      local put_cb = putter[1]:commit()
      handler:commit()
      local function _168_()
        return put_cb(true)
      end
      dispatch(_168_)
      return {putter[2]}
    elseif this.closed then
      if buf then
        this["add!"](buf)
      else
      end
      if (handler["active?"](handler) and handler:commit()) then
        local has_val = (buf and next(buf.buf))
        local val
        if has_val then
          val = buf["remove!"](buf)
        else
          val = nil
        end
        return {val}
      else
        return nil
      end
    else
      local takes = this.takes
      local dirty_takes = this["dirty-takes"]
      if (dirty_takes > MAX_DIRTY) then
        this["dirty-takes"] = 0
        local function _172_(_241)
          return _241["active?"](_241)
        end
        cleanup_21(takes, _172_)
      else
        this["dirty-takes"] = (1 + dirty_takes)
      end
      if handler["blockable?"](handler) then
        assert((#takes < MAX_QUEUE_SIZE), ("No more than " .. MAX_QUEUE_SIZE .. " pending takes are allowed on a single channel."))
        local handler_2a
        if (main_thread_3f() or enqueue_3f) then
          handler_2a = handler
        else
          local thunk = c_2frunning()
          local _174_ = {}
          do
            do
              local case_175_ = Handler["active?"]
              if (nil ~= case_175_) then
                local f_3_auto = case_175_
                local function _176_(_)
                  return handler["active?"](handler)
                end
                _174_["active?"] = _176_
              else
                local _ = case_175_
                error("Protocol Handler doesn't define method active?")
              end
            end
            do
              local case_178_ = Handler["blockable?"]
              if (nil ~= case_178_) then
                local f_3_auto = case_178_
                local function _179_(_)
                  return handler["blockable?"](handler)
                end
                _174_["blockable?"] = _179_
              else
                local _ = case_178_
                error("Protocol Handler doesn't define method blockable?")
              end
            end
            local case_181_ = Handler.commit
            if (nil ~= case_181_) then
              local f_3_auto = case_181_
              local function _182_(_)
                local function _183_(...)
                  return c_2fresume(thunk, ...)
                end
                return _183_
              end
              _174_["commit"] = _182_
            else
              local _ = case_181_
              error("Protocol Handler doesn't define method commit")
            end
          end
          local function _185_(_241)
            return ("#<" .. tostring(_241):gsub("table:", "reify:") .. ": " .. "Handler" .. ">")
          end
          handler_2a = setmetatable({}, {__fennelview = _185_, __index = _174_, __name = "reify"})
        end
        t_2finsert(takes, handler_2a)
        if (handler ~= handler_2a) then
          local val = c_2fyield()
          handler:commit()(val)
          return {val}
        else
          return nil
        end
      else
        return nil
      end
    end
  end
end
Channel["close!"] = function(this)
  if this.closed then
    return nil
  else
    local buf = this.buf
    local takes = this.takes
    this.closed = true
    if (buf and (0 == #this.puts)) then
      this["add!"](buf)
    else
    end
    local function recur()
      local taker = t_2fremove(takes, 1)
      if (nil ~= taker) then
        if taker["active?"](taker) then
          local take_cb = taker:commit()
          local val
          if (buf and next(buf.buf)) then
            val = buf["remove!"](buf)
          else
            val = nil
          end
          local function _193_()
            return take_cb(val)
          end
          dispatch(_193_)
        else
        end
        return recur()
      else
        return nil
      end
    end
    recur()
    if buf then
      buf["close-buf!"](buf)
    else
    end
    return nil
  end
end
do
  Channel["type"] = Channel
  Channel["close"] = Channel["close!"]
end
local function err_handler_2a(e)
  io.stderr:write(tostring(e), "\n")
  return nil
end
local function add_21_2a(buf, ...)
  local case_198_, case_199_ = select("#", ...), ...
  if ((case_198_ == 1) and true) then
    local _3fval = case_199_
    return buf["add!"](buf, _3fval)
  elseif (case_198_ == 0) then
    return buf
  else
    return nil
  end
end
local function chan(buf_or_n, xform, err_handler)
  local buffer0
  if ((_G.type(buf_or_n) == "table") and (buf_or_n.type == Buffer)) then
    buffer0 = buf_or_n
  elseif (buf_or_n == 0) then
    buffer0 = nil
  elseif (nil ~= buf_or_n) then
    local size = buf_or_n
    buffer0 = buffer(size)
  else
    buffer0 = nil
  end
  local add_211
  if xform then
    assert((nil ~= buffer0), "buffer must be supplied when transducer is")
    add_211 = xform(add_21_2a)
  else
    add_211 = add_21_2a
  end
  local err_handler0 = (err_handler or err_handler_2a)
  local handler
  local function _203_(ch, err)
    local case_204_ = err_handler0(err)
    if (nil ~= case_204_) then
      local res = case_204_
      return ch["put!"](ch, res, fhnop)
    else
      return nil
    end
  end
  handler = _203_
  local c = {puts = {}, takes = {}, buf = buffer0, ["err-handler"] = handler}
  c["add!"] = function(...)
    local case_206_, case_207_ = pcall(add_211, ...)
    if ((case_206_ == true) and true) then
      local _ = case_207_
      return _
    elseif ((case_206_ == false) and (nil ~= case_207_)) then
      local e = case_207_
      return handler(c, e)
    else
      return nil
    end
  end
  local function _209_(_241)
    return ("#<" .. tostring(_241):gsub("table:", "ManyToManyChannel:") .. ">")
  end
  return setmetatable(c, {__index = Channel, __name = "ManyToManyChannel", __fennelview = _209_})
end
local function promise_chan(xform, err_handler)
  return chan(promise_buffer(), xform, err_handler)
end
local function chan_3f(obj)
  if ((_G.type(obj) == "table") and (obj.type == Channel)) then
    return true
  else
    local _ = obj
    return false
  end
end
local function closed_3f(port)
  assert(chan_3f(port), "expected a channel")
  return port.closed
end
local warned = false
local function timeout(msecs)
  assert((gethook and sethook), "Can't advance timers - debug.sethook unavailable")
  local dt
  if (time_type == "lua") then
    local s = (msecs / 1000)
    if (not warned and not (m_2fceil(s) == s)) then
      warned = true
      local function _211_()
        warned = false
        return nil
      end
      local tgt_212_ = timeout(10000)
      do end (tgt_212_)["take!"](tgt_212_, fn_handler(_211_))
      io.stderr:write(("WARNING Lua doesn't support sub-second time precision.  " .. "Timeout rounded to the next nearest whole second.  " .. "Install luasocket or luaposix to get sub-second precision.\n"))
    else
    end
    dt = s
  else
    local _ = time_type
    dt = (msecs / 1000)
  end
  local t = ((m_2fceil((time() * 100)) / 100) + dt)
  local c
  local or_215_ = timeouts[t]
  if not or_215_ then
    local c0 = chan()
    timeouts[t] = c0
    or_215_ = c0
  end
  c = or_215_
  schedule_hook(process_messages, n_instr)
  return c
end
local function take_21(port, fn1, ...)
  assert(chan_3f(port), "expected a channel as first argument")
  assert((nil ~= fn1), "expected a callback")
  local on_caller_3f
  if (select("#", ...) == 0) then
    on_caller_3f = true
  else
    on_caller_3f = ...
  end
  do
    local case_218_ = port["take!"](port, fn_handler(fn1))
    if (nil ~= case_218_) then
      local retb = case_218_
      local val = retb[1]
      if on_caller_3f then
        fn1(val)
      else
        local function _219_()
          return fn1(val)
        end
        dispatch(_219_)
      end
    else
    end
  end
  return nil
end
local function try_sleep()
  local timers
  do
    local tmp_9_
    do
      local tbl_26_ = {}
      local i_27_ = 0
      for timer in pairs(timeouts) do
        local val_28_ = timer
        if (nil ~= val_28_) then
          i_27_ = (i_27_ + 1)
          tbl_26_[i_27_] = val_28_
        else
        end
      end
      tmp_9_ = tbl_26_
    end
    t_2fsort(tmp_9_)
    timers = tmp_9_
  end
  local case_223_ = timers[1]
  local and_224_ = (nil ~= case_223_)
  if and_224_ then
    local t = case_223_
    and_224_ = (sleep and not next(dispatched_tasks))
  end
  if and_224_ then
    local t = case_223_
    local t0 = (t - time())
    if (t0 > 0) then
      sleep(t0)
      process_messages("manual")
    else
    end
    return true
  else
    local _ = case_223_
    if next(dispatched_tasks) then
      process_messages("manual")
      return true
    else
      return nil
    end
  end
end
local function _3c_21_21(port)
  assert(main_thread_3f(), "<!! used not on the main thread")
  local val = nil
  local function _229_(_241)
    val = _241
    return nil
  end
  take_21(port, _229_)
  while ((val == nil) and not port.closed and try_sleep()) do
  end
  if ((nil == val) and not port.closed) then
    error(("The " .. tostring(port) .. " is not ready and there are no scheduled tasks." .. " Value will never arrive."), 2)
  else
  end
  return val
end
local function _3c_21(port)
  assert(not main_thread_3f(), "<! used not in (go ...) block")
  assert(chan_3f(port), "expected a channel as first argument")
  local case_231_ = port["take!"](port, fhnop)
  if (nil ~= case_231_) then
    local retb = case_231_
    return retb[1]
  else
    return nil
  end
end
local function put_21(port, val, ...)
  assert(chan_3f(port), "expected a channel as first argument")
  local case_233_ = select("#", ...)
  if (case_233_ == 0) then
    local case_234_ = port["put!"](port, val, fhnop)
    if (nil ~= case_234_) then
      local retb = case_234_
      return retb[1]
    else
      local _ = case_234_
      return true
    end
  elseif (case_233_ == 1) then
    return put_21(port, val, ..., true)
  elseif (case_233_ == 2) then
    local fn1, on_caller_3f = ...
    local case_236_ = port["put!"](port, val, fn_handler(fn1))
    if (nil ~= case_236_) then
      local retb = case_236_
      local ret = retb[1]
      if on_caller_3f then
        fn1(ret)
      else
        local function _237_()
          return fn1(ret)
        end
        dispatch(_237_)
      end
      return ret
    else
      local _ = case_236_
      return true
    end
  else
    return nil
  end
end
local function _3e_21_21(port, val)
  assert(main_thread_3f(), ">!! used not on the main thread")
  local not_done, res = true
  local function _241_(_241)
    not_done, res = false, _241
    return nil
  end
  put_21(port, val, _241_)
  while (not_done and try_sleep(port)) do
  end
  if (not_done and not port.closed) then
    error(("The " .. tostring(port) .. " is not ready and there are no scheduled tasks." .. " Value was sent but there's no one to receive it"), 2)
  else
  end
  return res
end
local function _3e_21(port, val)
  assert(not main_thread_3f(), ">! used not in (go ...) block")
  local case_243_ = port["put!"](port, val, fhnop)
  if (nil ~= case_243_) then
    local retb = case_243_
    return retb[1]
  else
    return nil
  end
end
local function close_21(port)
  assert(chan_3f(port), "expected a channel")
  return port:close()
end
local function go_2a(fn1)
  local c = chan(1)
  do
    local case_245_, case_246_
    local function _247_()
      do
        local case_248_ = fn1()
        if (nil ~= case_248_) then
          local val = case_248_
          _3e_21(c, val)
        else
        end
      end
      return close_21(c)
    end
    case_245_, case_246_ = c_2fresume(c_2fcreate(_247_))
    if ((case_245_ == false) and (nil ~= case_246_)) then
      local msg = case_246_
      c["err-handler"](c, msg)
      close_21(c)
    else
    end
  end
  return c
end
local function random_array(n)
  local ids
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for i = 1, n do
      local val_28_ = i
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    ids = tbl_26_
  end
  for i = n, 2, -1 do
    local j = m_2frandom(i)
    local ti = ids[i]
    ids[i] = ids[j]
    ids[j] = ti
  end
  return ids
end
local function alt_flag()
  local atom = {flag = true}
  local _252_ = {}
  do
    do
      local case_253_ = Handler["active?"]
      if (nil ~= case_253_) then
        local f_3_auto = case_253_
        local function _254_(_)
          return atom.flag
        end
        _252_["active?"] = _254_
      else
        local _ = case_253_
        error("Protocol Handler doesn't define method active?")
      end
    end
    do
      local case_256_ = Handler["blockable?"]
      if (nil ~= case_256_) then
        local f_3_auto = case_256_
        local function _257_(_)
          return true
        end
        _252_["blockable?"] = _257_
      else
        local _ = case_256_
        error("Protocol Handler doesn't define method blockable?")
      end
    end
    local case_259_ = Handler.commit
    if (nil ~= case_259_) then
      local f_3_auto = case_259_
      local function _260_(_)
        atom.flag = false
        return true
      end
      _252_["commit"] = _260_
    else
      local _ = case_259_
      error("Protocol Handler doesn't define method commit")
    end
  end
  local function _262_(_241)
    return ("#<" .. tostring(_241):gsub("table:", "reify:") .. ": " .. "Handler" .. ">")
  end
  return setmetatable({}, {__fennelview = _262_, __index = _252_, __name = "reify"})
end
local function alt_handler(flag, cb)
  local _263_ = {}
  do
    do
      local case_264_ = Handler["active?"]
      if (nil ~= case_264_) then
        local f_3_auto = case_264_
        local function _265_(_)
          return flag["active?"](flag)
        end
        _263_["active?"] = _265_
      else
        local _ = case_264_
        error("Protocol Handler doesn't define method active?")
      end
    end
    do
      local case_267_ = Handler["blockable?"]
      if (nil ~= case_267_) then
        local f_3_auto = case_267_
        local function _268_(_)
          return true
        end
        _263_["blockable?"] = _268_
      else
        local _ = case_267_
        error("Protocol Handler doesn't define method blockable?")
      end
    end
    local case_270_ = Handler.commit
    if (nil ~= case_270_) then
      local f_3_auto = case_270_
      local function _271_(_)
        flag:commit()
        return cb
      end
      _263_["commit"] = _271_
    else
      local _ = case_270_
      error("Protocol Handler doesn't define method commit")
    end
  end
  local function _273_(_241)
    return ("#<" .. tostring(_241):gsub("table:", "reify:") .. ": " .. "Handler" .. ">")
  end
  return setmetatable({}, {__fennelview = _273_, __index = _263_, __name = "reify"})
end
local function alts_21(ports, ...)
  assert(not main_thread_3f(), "called alts! on the main thread")
  assert((#ports > 0), "alts must have at least one channel operation")
  local n = #ports
  local arglen = select("#", ...)
  local no_def = {}
  local opts
  do
    local case_274_, case_275_ = select("#", ...), ...
    if (case_274_ == 0) then
      opts = {default = no_def}
    else
      local and_276_ = ((case_274_ == 1) and (nil ~= case_275_))
      if and_276_ then
        local t = case_275_
        and_276_ = ("table" == type(t))
      end
      if and_276_ then
        local t = case_275_
        local res = {default = no_def}
        for k, v in pairs(t) do
          res[k] = v
          res = res
        end
        opts = res
      else
        local _ = case_274_
        local res = {default = no_def}
        for i = 1, arglen, 2 do
          local k, v = select(i, ...)
          res[k] = v
          res = res
        end
        opts = res
      end
    end
  end
  local ids = random_array(n)
  local res_ch = chan(promise_buffer())
  local flag = alt_flag()
  local done = nil
  for i = 1, n do
    if done then break end
    local id
    if (opts and opts.priority) then
      id = i
    else
      id = ids[i]
    end
    local retb, port
    do
      local case_280_ = ports[id]
      local and_281_ = ((_G.type(case_280_) == "table") and true and true)
      if and_281_ then
        local _3fc = case_280_[1]
        local _3fv = case_280_[2]
        and_281_ = chan_3f(_3fc)
      end
      if and_281_ then
        local _3fc = case_280_[1]
        local _3fv = case_280_[2]
        local function _283_(_241)
          put_21(res_ch, {_241, _3fc})
          return close_21(res_ch)
        end
        retb, port = _3fc["put!"](_3fc, _3fv, alt_handler(flag, _283_), true), _3fc
      else
        local and_284_ = true
        if and_284_ then
          local _3fc = case_280_
          and_284_ = chan_3f(_3fc)
        end
        if and_284_ then
          local _3fc = case_280_
          local function _286_(_241)
            put_21(res_ch, {_241, _3fc})
            return close_21(res_ch)
          end
          retb, port = _3fc["take!"](_3fc, alt_handler(flag, _286_), true), _3fc
        else
          local _ = case_280_
          retb, port = error(("expected a channel: " .. tostring(_)))
        end
      end
    end
    if (nil ~= retb) then
      _3e_21(res_ch, {retb[1], port})
      done = true
    else
    end
  end
  if (flag["active?"](flag) and (no_def ~= opts.default)) then
    flag:commit()
    return {opts.default, "default"}
  else
    return _3c_21(res_ch)
  end
end
local function offer_21(port, val)
  assert(chan_3f(port), "expected a channel as first argument")
  if (next(port.takes) or (port.buf and not port.buf["full?"](port.buf))) then
    local case_290_ = port["put!"](port, val, fhnop)
    if (nil ~= case_290_) then
      local retb = case_290_
      return retb[1]
    else
      return nil
    end
  else
    return nil
  end
end
local function poll_21(port)
  assert(chan_3f(port), "expected a channel")
  if (next(port.puts) or (port.buf and (nil ~= next(port.buf.buf)))) then
    local case_293_ = port["take!"](port, fhnop)
    if (nil ~= case_293_) then
      local retb = case_293_
      return retb[1]
    else
      return nil
    end
  else
    return nil
  end
end
local function pipe(from, to, ...)
  local close_3f
  if (select("#", ...) == 0) then
    close_3f = true
  else
    close_3f = ...
  end
  local _let_297_ = require("src.io.gitlab.andreyorst.async")
  local go_1_auto = _let_297_["go*"]
  local function _298_()
    local function recur()
      local val = _3c_21(from)
      if (nil == val) then
        if close_3f then
          return close_21(to)
        else
          return nil
        end
      else
        _3e_21(to, val)
        return recur()
      end
    end
    return recur()
  end
  return go_1_auto(_298_)
end
local function pipeline_2a(n, to, xf, from, close_3f, err_handler, kind)
  local jobs = chan(n)
  local results = chan(n)
  local finishes = ((kind == "async") and chan(n))
  local process
  local function _301_(job)
    if (job == nil) then
      close_21(results)
      return nil
    elseif ((_G.type(job) == "table") and (nil ~= job[1]) and (nil ~= job[2])) then
      local v = job[1]
      local p = job[2]
      local res = chan(1, xf, err_handler)
      do
        local _let_302_ = require("src.io.gitlab.andreyorst.async")
        local go_1_auto = _let_302_["go*"]
        local function _303_()
          _3e_21(res, v)
          return close_21(res)
        end
        go_1_auto(_303_)
      end
      put_21(p, res)
      return true
    else
      return nil
    end
  end
  process = _301_
  local async
  local function _305_(job)
    if (job == nil) then
      close_21(results)
      close_21(finishes)
      return nil
    elseif ((_G.type(job) == "table") and (nil ~= job[1]) and (nil ~= job[2])) then
      local v = job[1]
      local p = job[2]
      local res = chan(1)
      xf(v, res)
      put_21(p, res)
      return true
    else
      return nil
    end
  end
  async = _305_
  for _ = 1, n do
    if (kind == "compute") then
      local _let_307_ = require("src.io.gitlab.andreyorst.async")
      local go_1_auto = _let_307_["go*"]
      local function _308_()
        local function recur()
          local job = _3c_21(jobs)
          if process(job) then
            return recur()
          else
            return nil
          end
        end
        return recur()
      end
      go_1_auto(_308_)
    elseif (kind == "async") then
      local _let_310_ = require("src.io.gitlab.andreyorst.async")
      local go_1_auto = _let_310_["go*"]
      local function _311_()
        local function recur()
          local job = _3c_21(jobs)
          if async(job) then
            _3c_21(finishes)
            return recur()
          else
            return nil
          end
        end
        return recur()
      end
      go_1_auto(_311_)
    else
    end
  end
  do
    local _let_314_ = require("src.io.gitlab.andreyorst.async")
    local go_1_auto = _let_314_["go*"]
    local function _315_()
      local function recur()
        local case_316_ = _3c_21(from)
        if (case_316_ == nil) then
          return close_21(jobs)
        elseif (nil ~= case_316_) then
          local v = case_316_
          local p = chan(1)
          _3e_21(jobs, {v, p})
          _3e_21(results, p)
          return recur()
        else
          return nil
        end
      end
      return recur()
    end
    go_1_auto(_315_)
  end
  local _let_318_ = require("src.io.gitlab.andreyorst.async")
  local go_1_auto = _let_318_["go*"]
  local function _319_()
    local function recur()
      local case_320_ = _3c_21(results)
      if (case_320_ == nil) then
        if close_3f then
          return close_21(to)
        else
          return nil
        end
      elseif (nil ~= case_320_) then
        local p = case_320_
        local case_322_ = _3c_21(p)
        if (nil ~= case_322_) then
          local res = case_322_
          local function loop_2a()
            local case_323_ = _3c_21(res)
            if (nil ~= case_323_) then
              local val = case_323_
              _3e_21(to, val)
              return loop_2a()
            else
              return nil
            end
          end
          loop_2a()
          if finishes then
            _3e_21(finishes, "done")
          else
          end
          return recur()
        else
          return nil
        end
      else
        return nil
      end
    end
    return recur()
  end
  return go_1_auto(_319_)
end
local function pipeline_async(n, to, af, from, ...)
  local close_3f
  if (select("#", ...) == 0) then
    close_3f = true
  else
    close_3f = ...
  end
  return pipeline_2a(n, to, af, from, close_3f, nil, "async")
end
local function pipeline(n, to, xf, from, ...)
  local close_3f, err_handler
  if (select("#", ...) == 0) then
    close_3f, err_handler = true
  else
    close_3f, err_handler = ...
  end
  return pipeline_2a(n, to, xf, from, close_3f, err_handler, "compute")
end
local function split(p, ch, t_buf_or_n, f_buf_or_n)
  local tc = chan(t_buf_or_n)
  local fc = chan(f_buf_or_n)
  do
    local _let_330_ = require("src.io.gitlab.andreyorst.async")
    local go_1_auto = _let_330_["go*"]
    local function _331_()
      local function recur()
        local v = _3c_21(ch)
        if (nil == v) then
          close_21(tc)
          return close_21(fc)
        else
          local _332_
          if p(v) then
            _332_ = tc
          else
            _332_ = fc
          end
          if _3e_21(_332_, v) then
            return recur()
          else
            return nil
          end
        end
      end
      return recur()
    end
    go_1_auto(_331_)
  end
  return {tc, fc}
end
local function reduce(f, init, ch)
  local _let_337_ = require("src.io.gitlab.andreyorst.async")
  local go_1_auto = _let_337_["go*"]
  local function _338_()
    local _2_336_ = init
    local ret = _2_336_
    local function recur(ret0)
      local v = _3c_21(ch)
      if (nil == v) then
        return ret0
      else
        local res = f(ret0, v)
        if reduced_3f(res) then
          return res:unbox()
        else
          return recur(res)
        end
      end
    end
    return recur(_2_336_)
  end
  return go_1_auto(_338_)
end
local function transduce(xform, f, init, ch)
  local f0 = xform(f)
  local _let_341_ = require("src.io.gitlab.andreyorst.async")
  local go_1_auto = _let_341_["go*"]
  local function _342_()
    local ret = _3c_21(reduce(f0, init, ch))
    return f0(ret)
  end
  return go_1_auto(_342_)
end
local function onto_chan_21(ch, coll, ...)
  local close_3f
  if (select("#", ...) == 0) then
    close_3f = true
  else
    close_3f = ...
  end
  local _let_344_ = require("src.io.gitlab.andreyorst.async")
  local go_1_auto = _let_344_["go*"]
  local function _345_()
    for _, v in ipairs(coll) do
      _3e_21(ch, v)
    end
    if close_3f then
      close_21(ch)
    else
    end
    return ch
  end
  return go_1_auto(_345_)
end
local function bounded_length(bound, t)
  return m_2fmin(bound, #t)
end
local function to_chan_21(coll)
  local ch = chan(bounded_length(100, coll))
  onto_chan_21(ch, coll)
  return ch
end
local function pipeline_unordered_2a(n, to, xf, from, close_3f, err_handler, kind)
  local closes
  local function _347_()
    local tbl_26_ = {}
    local i_27_ = 0
    for _ = 1, (n - 1) do
      local val_28_ = "close"
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    return tbl_26_
  end
  closes = to_chan_21(_347_())
  local process
  local function _349_(v, p)
    local res = chan(1, xf, err_handler)
    local _let_350_ = require("src.io.gitlab.andreyorst.async")
    local go_1_auto = _let_350_["go*"]
    local function _351_()
      _3e_21(res, v)
      close_21(res)
      local function loop()
        local case_352_ = _3c_21(res)
        if (nil ~= case_352_) then
          local v0 = case_352_
          put_21(p, v0)
          return loop()
        else
          return nil
        end
      end
      loop()
      return close_21(p)
    end
    return go_1_auto(_351_)
  end
  process = _349_
  for _ = 1, n do
    local _let_354_ = require("src.io.gitlab.andreyorst.async")
    local go_1_auto = _let_354_["go*"]
    local function _355_()
      local function recur()
        local case_356_ = _3c_21(from)
        if (nil ~= case_356_) then
          local v = case_356_
          local c = chan(1)
          if (kind == "compute") then
            local _let_357_ = require("src.io.gitlab.andreyorst.async")
            local go_1_auto0 = _let_357_["go*"]
            local function _358_()
              return process(v, c)
            end
            go_1_auto0(_358_)
          elseif (kind == "async") then
            local _let_359_ = require("src.io.gitlab.andreyorst.async")
            local go_1_auto0 = _let_359_["go*"]
            local function _360_()
              return xf(v, c)
            end
            go_1_auto0(_360_)
          else
          end
          local function loop()
            local case_362_ = _3c_21(c)
            if (nil ~= case_362_) then
              local res = case_362_
              if _3e_21(to, res) then
                return loop()
              else
                return nil
              end
            else
              local _0 = case_362_
              return true
            end
          end
          if loop() then
            return recur()
          else
            return nil
          end
        else
          local _0 = case_356_
          if (close_3f and (nil == _3c_21(closes))) then
            return close_21(to)
          else
            return nil
          end
        end
      end
      return recur()
    end
    go_1_auto(_355_)
  end
  return nil
end
local function pipeline_unordered(n, to, xf, from, ...)
  local close_3f, err_handler
  if (select("#", ...) == 0) then
    close_3f, err_handler = true
  else
    close_3f, err_handler = ...
  end
  return pipeline_unordered_2a(n, to, xf, from, close_3f, err_handler, "compute")
end
local function pipeline_async_unordered(n, to, af, from, ...)
  local close_3f
  if (select("#", ...) == 0) then
    close_3f = true
  else
    close_3f = ...
  end
  return pipeline_unordered_2a(n, to, af, from, close_3f, nil, "async")
end
local function muxch_2a(_)
  return _["muxch*"](_)
end
local _local_370_ = {["muxch*"] = muxch_2a}
local muxch_2a0 = _local_370_["muxch*"]
local Mux = _local_370_
local function tap_2a(_, ch, close_3f)
  if (nil == close_3f) then
    _G.error("Missing argument close? on .deps/git/io.gitlab.andreyorst/async.fnl/a83b13b397fdfab3ebf7f17a16d21a7ec2674ceb/src/io/gitlab/andreyorst/async.fnl:1339", 2)
  else
  end
  if (nil == ch) then
    _G.error("Missing argument ch on .deps/git/io.gitlab.andreyorst/async.fnl/a83b13b397fdfab3ebf7f17a16d21a7ec2674ceb/src/io/gitlab/andreyorst/async.fnl:1339", 2)
  else
  end
  return _["tap*"](_, ch, close_3f)
end
local function untap_2a(_, ch)
  if (nil == ch) then
    _G.error("Missing argument ch on .deps/git/io.gitlab.andreyorst/async.fnl/a83b13b397fdfab3ebf7f17a16d21a7ec2674ceb/src/io/gitlab/andreyorst/async.fnl:1340", 2)
  else
  end
  return _["untap*"](_, ch)
end
local function untap_all_2a(_)
  return _["untap-all*"](_)
end
local _local_374_ = {["tap*"] = tap_2a, ["untap*"] = untap_2a, ["untap-all*"] = untap_all_2a}
local tap_2a0 = _local_374_["tap*"]
local untap_2a0 = _local_374_["untap*"]
local untap_all_2a0 = _local_374_["untap-all*"]
local Mult = _local_374_
local function mult(ch)
  local dctr = nil
  local atom = {cs = {}}
  local m
  do
    local _375_ = {}
    do
      do
        local case_376_ = Mux["muxch*"]
        if (nil ~= case_376_) then
          local f_3_auto = case_376_
          local function _377_(_)
            return ch
          end
          _375_["muxch*"] = _377_
        else
          local _ = case_376_
          error("Protocol Mux doesn't define method muxch*")
        end
      end
      do
        local case_379_ = Mult["tap*"]
        if (nil ~= case_379_) then
          local f_3_auto = case_379_
          local function _380_(_, ch0, close_3f)
            atom["cs"][ch0] = close_3f
            return nil
          end
          _375_["tap*"] = _380_
        else
          local _ = case_379_
          error("Protocol Mult doesn't define method tap*")
        end
      end
      do
        local case_382_ = Mult["untap*"]
        if (nil ~= case_382_) then
          local f_3_auto = case_382_
          local function _383_(_, ch0)
            atom["cs"][ch0] = nil
            return nil
          end
          _375_["untap*"] = _383_
        else
          local _ = case_382_
          error("Protocol Mult doesn't define method untap*")
        end
      end
      local case_385_ = Mult["untap-all*"]
      if (nil ~= case_385_) then
        local f_3_auto = case_385_
        local function _386_(_)
          atom["cs"] = {}
          return nil
        end
        _375_["untap-all*"] = _386_
      else
        local _ = case_385_
        error("Protocol Mult doesn't define method untap-all*")
      end
    end
    local function _388_(_241)
      return ("#<" .. tostring(_241):gsub("table:", "reify:") .. ": " .. "Mux, Mult" .. ">")
    end
    m = setmetatable({}, {__fennelview = _388_, __index = _375_, __name = "reify"})
  end
  local dchan = chan(1)
  local done
  local function _389_(_)
    dctr = (dctr - 1)
    if (0 == dctr) then
      return put_21(dchan, true)
    else
      return nil
    end
  end
  done = _389_
  do
    local _let_391_ = require("src.io.gitlab.andreyorst.async")
    local go_1_auto = _let_391_["go*"]
    local function _392_()
      local function recur()
        local val = _3c_21(ch)
        if (nil == val) then
          for c, close_3f in pairs(atom.cs) do
            if close_3f then
              close_21(c)
            else
            end
          end
          return nil
        else
          local chs
          do
            local tbl_26_ = {}
            local i_27_ = 0
            for k in pairs(atom.cs) do
              local val_28_ = k
              if (nil ~= val_28_) then
                i_27_ = (i_27_ + 1)
                tbl_26_[i_27_] = val_28_
              else
              end
            end
            chs = tbl_26_
          end
          dctr = #chs
          for _, c in ipairs(chs) do
            if not put_21(c, val, done) then
              untap_2a0(m, c)
            else
            end
          end
          if next(chs) then
            _3c_21(dchan)
          else
          end
          return recur()
        end
      end
      return recur()
    end
    go_1_auto(_392_)
  end
  return m
end
local function tap(mult0, ch, ...)
  local close_3f
  if (select("#", ...) == 0) then
    close_3f = true
  else
    close_3f = ...
  end
  tap_2a0(mult0, ch, close_3f)
  return ch
end
local function untap(mult0, ch)
  return untap_2a0(mult0, ch)
end
local function untap_all(mult0)
  return untap_all_2a0(mult0)
end
local function admix_2a(_, ch)
  if (nil == ch) then
    _G.error("Missing argument ch on .deps/git/io.gitlab.andreyorst/async.fnl/a83b13b397fdfab3ebf7f17a16d21a7ec2674ceb/src/io/gitlab/andreyorst/async.fnl:1403", 2)
  else
  end
  return _["admix*"](_, ch)
end
local function solo_mode_2a(_, mode)
  if (nil == mode) then
    _G.error("Missing argument mode on .deps/git/io.gitlab.andreyorst/async.fnl/a83b13b397fdfab3ebf7f17a16d21a7ec2674ceb/src/io/gitlab/andreyorst/async.fnl:1407", 2)
  else
  end
  return _["solo-mode*"](_, mode)
end
local function toggle_2a(_, state_map)
  if (nil == state_map) then
    _G.error("Missing argument state-map on .deps/git/io.gitlab.andreyorst/async.fnl/a83b13b397fdfab3ebf7f17a16d21a7ec2674ceb/src/io/gitlab/andreyorst/async.fnl:1406", 2)
  else
  end
  return _["toggle*"](_, state_map)
end
local function unmix_2a(_, ch)
  if (nil == ch) then
    _G.error("Missing argument ch on .deps/git/io.gitlab.andreyorst/async.fnl/a83b13b397fdfab3ebf7f17a16d21a7ec2674ceb/src/io/gitlab/andreyorst/async.fnl:1404", 2)
  else
  end
  return _["unmix*"](_, ch)
end
local function unmix_all_2a(_)
  return _["unmix-all*"](_)
end
local _local_403_ = {["admix*"] = admix_2a, ["solo-mode*"] = solo_mode_2a, ["toggle*"] = toggle_2a, ["unmix*"] = unmix_2a, ["unmix-all*"] = unmix_all_2a}
local admix_2a0 = _local_403_["admix*"]
local solo_mode_2a0 = _local_403_["solo-mode*"]
local toggle_2a0 = _local_403_["toggle*"]
local unmix_2a0 = _local_403_["unmix*"]
local unmix_all_2a0 = _local_403_["unmix-all*"]
local Mix = _local_403_
local function mix(out)
  local atom = {cs = {}, ["solo-mode"] = "mute"}
  local solo_modes = {mute = true, pause = true}
  local change = chan(sliding_buffer(1))
  local changed
  local function _404_()
    return put_21(change, true)
  end
  changed = _404_
  local pick
  local function _405_(attr, chs)
    local tbl_21_ = {}
    for c, v in pairs(chs) do
      local k_22_, v_23_
      if v[attr] then
        k_22_, v_23_ = c, true
      else
        k_22_, v_23_ = nil
      end
      if ((k_22_ ~= nil) and (v_23_ ~= nil)) then
        tbl_21_[k_22_] = v_23_
      else
      end
    end
    return tbl_21_
  end
  pick = _405_
  local calc_state
  local function _408_()
    local chs = atom.cs
    local mode = atom["solo-mode"]
    local solos = pick("solo", chs)
    local pauses = pick("pause", chs)
    local _409_
    do
      local tmp_9_
      if ((mode == "pause") and next(solos)) then
        local tbl_26_ = {}
        local i_27_ = 0
        for k in pairs(solos) do
          local val_28_ = k
          if (nil ~= val_28_) then
            i_27_ = (i_27_ + 1)
            tbl_26_[i_27_] = val_28_
          else
          end
        end
        tmp_9_ = tbl_26_
      else
        local tbl_26_ = {}
        local i_27_ = 0
        for k in pairs(chs) do
          local val_28_
          if not pauses[k] then
            val_28_ = k
          else
            val_28_ = nil
          end
          if (nil ~= val_28_) then
            i_27_ = (i_27_ + 1)
            tbl_26_[i_27_] = val_28_
          else
          end
        end
        tmp_9_ = tbl_26_
      end
      t_2finsert(tmp_9_, change)
      _409_ = tmp_9_
    end
    return {solos = solos, mutes = pick("mute", chs), reads = _409_}
  end
  calc_state = _408_
  local m
  do
    local _414_ = {}
    do
      do
        local case_415_ = Mux["muxch*"]
        if (nil ~= case_415_) then
          local f_3_auto = case_415_
          local function _416_(_)
            return out
          end
          _414_["muxch*"] = _416_
        else
          local _ = case_415_
          error("Protocol Mux doesn't define method muxch*")
        end
      end
      do
        local case_418_ = Mix["admix*"]
        if (nil ~= case_418_) then
          local f_3_auto = case_418_
          local function _419_(_, ch)
            atom.cs[ch] = {}
            return changed()
          end
          _414_["admix*"] = _419_
        else
          local _ = case_418_
          error("Protocol Mix doesn't define method admix*")
        end
      end
      do
        local case_421_ = Mix["unmix*"]
        if (nil ~= case_421_) then
          local f_3_auto = case_421_
          local function _422_(_, ch)
            atom.cs[ch] = nil
            return changed()
          end
          _414_["unmix*"] = _422_
        else
          local _ = case_421_
          error("Protocol Mix doesn't define method unmix*")
        end
      end
      do
        local case_424_ = Mix["unmix-all*"]
        if (nil ~= case_424_) then
          local f_3_auto = case_424_
          local function _425_(_)
            atom.cs = {}
            return changed()
          end
          _414_["unmix-all*"] = _425_
        else
          local _ = case_424_
          error("Protocol Mix doesn't define method unmix-all*")
        end
      end
      do
        local case_427_ = Mix["toggle*"]
        if (nil ~= case_427_) then
          local f_3_auto = case_427_
          local function _428_(_, state_map)
            atom.cs = merge_with(merge_2a, atom.cs, state_map)
            return changed()
          end
          _414_["toggle*"] = _428_
        else
          local _ = case_427_
          error("Protocol Mix doesn't define method toggle*")
        end
      end
      local case_430_ = Mix["solo-mode*"]
      if (nil ~= case_430_) then
        local f_3_auto = case_430_
        local function _431_(_, mode)
          if not solo_modes[mode] then
            local _432_
            do
              local tbl_26_ = {}
              local i_27_ = 0
              for k in pairs(solo_modes) do
                local val_28_ = k
                if (nil ~= val_28_) then
                  i_27_ = (i_27_ + 1)
                  tbl_26_[i_27_] = val_28_
                else
                end
              end
              _432_ = tbl_26_
            end
            assert(false, ("mode must be one of: " .. t_2fconcat(_432_, ", ")))
          else
          end
          atom["solo-mode"] = mode
          return changed()
        end
        _414_["solo-mode*"] = _431_
      else
        local _ = case_430_
        error("Protocol Mix doesn't define method solo-mode*")
      end
    end
    local function _436_(_241)
      return ("#<" .. tostring(_241):gsub("table:", "reify:") .. ": " .. "Mux, Mix" .. ">")
    end
    m = setmetatable({}, {__fennelview = _436_, __index = _414_, __name = "reify"})
  end
  do
    local _let_438_ = require("src.io.gitlab.andreyorst.async")
    local go_1_auto = _let_438_["go*"]
    local function _439_()
      local _2_437_ = calc_state()
      local solos = _2_437_.solos
      local mutes = _2_437_.mutes
      local reads = _2_437_.reads
      local state = _2_437_
      local function recur(_440_)
        local solos0 = _440_.solos
        local mutes0 = _440_.mutes
        local reads0 = _440_.reads
        local state0 = _440_
        local _let_441_ = alts_21(reads0)
        local v = _let_441_[1]
        local c = _let_441_[2]
        local res = _let_441_
        if ((nil == v) or (c == change)) then
          if (nil == v) then
            atom.cs[c] = nil
          else
          end
          return recur(calc_state())
        else
          if (solos0[c] or (not next(solos0) and not mutes0[c])) then
            if _3e_21(out, v) then
              return recur(state0)
            else
              return nil
            end
          else
            return recur(state0)
          end
        end
      end
      return recur(_2_437_)
    end
    go_1_auto(_439_)
  end
  return m
end
local function admix(mix0, ch)
  return admix_2a0(mix0, ch)
end
local function unmix(mix0, ch)
  return unmix_2a0(mix0, ch)
end
local function unmix_all(mix0)
  return unmix_all_2a0(mix0)
end
local function toggle(mix0, state_map)
  return toggle_2a0(mix0, state_map)
end
local function solo_mode(mix0, mode)
  return solo_mode_2a0(mix0, mode)
end
local function sub_2a(_, v, ch, close_3f)
  if (nil == close_3f) then
    _G.error("Missing argument close? on .deps/git/io.gitlab.andreyorst/async.fnl/a83b13b397fdfab3ebf7f17a16d21a7ec2674ceb/src/io/gitlab/andreyorst/async.fnl:1508", 2)
  else
  end
  if (nil == ch) then
    _G.error("Missing argument ch on .deps/git/io.gitlab.andreyorst/async.fnl/a83b13b397fdfab3ebf7f17a16d21a7ec2674ceb/src/io/gitlab/andreyorst/async.fnl:1508", 2)
  else
  end
  if (nil == v) then
    _G.error("Missing argument v on .deps/git/io.gitlab.andreyorst/async.fnl/a83b13b397fdfab3ebf7f17a16d21a7ec2674ceb/src/io/gitlab/andreyorst/async.fnl:1508", 2)
  else
  end
  return _["sub*"](_, v, ch, close_3f)
end
local function unsub_2a(_, v, ch)
  if (nil == ch) then
    _G.error("Missing argument ch on .deps/git/io.gitlab.andreyorst/async.fnl/a83b13b397fdfab3ebf7f17a16d21a7ec2674ceb/src/io/gitlab/andreyorst/async.fnl:1509", 2)
  else
  end
  if (nil == v) then
    _G.error("Missing argument v on .deps/git/io.gitlab.andreyorst/async.fnl/a83b13b397fdfab3ebf7f17a16d21a7ec2674ceb/src/io/gitlab/andreyorst/async.fnl:1509", 2)
  else
  end
  return _["unsub*"](_, v, ch)
end
local function unsub_all_2a(_, v)
  if (nil == v) then
    _G.error("Missing argument v on .deps/git/io.gitlab.andreyorst/async.fnl/a83b13b397fdfab3ebf7f17a16d21a7ec2674ceb/src/io/gitlab/andreyorst/async.fnl:1510", 2)
  else
  end
  return _["unsub-all*"](_, v)
end
local _local_452_ = {["sub*"] = sub_2a, ["unsub*"] = unsub_2a, ["unsub-all*"] = unsub_all_2a}
local sub_2a0 = _local_452_["sub*"]
local unsub_2a0 = _local_452_["unsub*"]
local unsub_all_2a0 = _local_452_["unsub-all*"]
local Pub = _local_452_
local function pub(ch, topic_fn, buf_fn)
  local buf_fn0
  local or_453_ = buf_fn
  if not or_453_ then
    local function _454_()
      return nil
    end
    or_453_ = _454_
  end
  buf_fn0 = or_453_
  local atom = {mults = {}}
  local ensure_mult
  local function _455_(topic)
    local case_456_ = atom.mults[topic]
    if (nil ~= case_456_) then
      local m = case_456_
      return m
    elseif (case_456_ == nil) then
      local mults = atom.mults
      local m = mult(chan(buf_fn0(topic)))
      do
        mults[topic] = m
      end
      return m
    else
      return nil
    end
  end
  ensure_mult = _455_
  local p
  do
    local _458_ = {}
    do
      do
        local case_459_ = Mux["muxch*"]
        if (nil ~= case_459_) then
          local f_3_auto = case_459_
          local function _460_(_)
            return ch
          end
          _458_["muxch*"] = _460_
        else
          local _ = case_459_
          error("Protocol Mux doesn't define method muxch*")
        end
      end
      do
        local case_462_ = Pub["sub*"]
        if (nil ~= case_462_) then
          local f_3_auto = case_462_
          local function _463_(_, topic, ch0, close_3f)
            local m = ensure_mult(topic)
            return tap_2a0(m, ch0, close_3f)
          end
          _458_["sub*"] = _463_
        else
          local _ = case_462_
          error("Protocol Pub doesn't define method sub*")
        end
      end
      do
        local case_465_ = Pub["unsub*"]
        if (nil ~= case_465_) then
          local f_3_auto = case_465_
          local function _466_(_, topic, ch0)
            local case_467_ = atom.mults[topic]
            if (nil ~= case_467_) then
              local m = case_467_
              return untap_2a0(m, ch0)
            else
              return nil
            end
          end
          _458_["unsub*"] = _466_
        else
          local _ = case_465_
          error("Protocol Pub doesn't define method unsub*")
        end
      end
      local case_470_ = Pub["unsub-all*"]
      if (nil ~= case_470_) then
        local f_3_auto = case_470_
        local function _471_(_, topic)
          if topic then
            atom["mults"][topic] = nil
            return nil
          else
            atom["mults"] = {}
            return nil
          end
        end
        _458_["unsub-all*"] = _471_
      else
        local _ = case_470_
        error("Protocol Pub doesn't define method unsub-all*")
      end
    end
    local function _474_(_241)
      return ("#<" .. tostring(_241):gsub("table:", "reify:") .. ": " .. "Mux, Pub" .. ">")
    end
    p = setmetatable({}, {__fennelview = _474_, __index = _458_, __name = "reify"})
  end
  do
    local _let_475_ = require("src.io.gitlab.andreyorst.async")
    local go_1_auto = _let_475_["go*"]
    local function _476_()
      local function recur()
        local val = _3c_21(ch)
        if (nil == val) then
          for _, m in pairs(atom.mults) do
            close_21(muxch_2a0(m))
          end
          return nil
        else
          local topic = topic_fn(val)
          do
            local case_477_ = atom.mults[topic]
            if (nil ~= case_477_) then
              local m = case_477_
              if not _3e_21(muxch_2a0(m), val) then
                atom["mults"][topic] = nil
              else
              end
            else
            end
          end
          return recur()
        end
      end
      return recur()
    end
    go_1_auto(_476_)
  end
  return p
end
local function sub(pub0, topic, ch, ...)
  local close_3f
  if (select("#", ...) == 0) then
    close_3f = true
  else
    close_3f = ...
  end
  return sub_2a0(pub0, topic, ch, close_3f)
end
local function unsub(pub0, topic, ch)
  return unsub_2a0(pub0, topic, ch)
end
local function unsub_all(pub0, topic)
  return unsub_all_2a0(pub0, topic)
end
local function map(f, chs, buf_or_n)
  local dctr = nil
  local out = chan(buf_or_n)
  local cnt = #chs
  local rets = {n = cnt}
  local dchan = chan(1)
  local done
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for i = 1, cnt do
      local val_28_
      local function _482_(ret)
        rets[i] = ret
        dctr = (dctr - 1)
        if (0 == dctr) then
          return put_21(dchan, rets)
        else
          return nil
        end
      end
      val_28_ = _482_
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    done = tbl_26_
  end
  if (0 == cnt) then
    close_21(out)
  else
    local _let_485_ = require("src.io.gitlab.andreyorst.async")
    local go_1_auto = _let_485_["go*"]
    local function _486_()
      local function recur()
        dctr = cnt
        for i = 1, cnt do
          local case_487_ = pcall(take_21, chs[i], done[i])
          if (case_487_ == false) then
            dctr = (dctr - 1)
          else
          end
        end
        local rets0 = _3c_21(dchan)
        local _489_
        do
          local res = false
          for i = 1, rets0.n do
            if res then break end
            res = (nil == rets0[i])
          end
          _489_ = res
        end
        if _489_ then
          return close_21(out)
        else
          _3e_21(out, f(t_2funpack(rets0)))
          return recur()
        end
      end
      return recur()
    end
    go_1_auto(_486_)
  end
  return out
end
local function merge(chs, buf_or_n)
  local out = chan(buf_or_n)
  do
    local _let_493_ = require("src.io.gitlab.andreyorst.async")
    local go_1_auto = _let_493_["go*"]
    local function _494_()
      local _2_492_ = chs
      local cs = _2_492_
      local function recur(cs0)
        if (#cs0 > 0) then
          local _let_495_ = alts_21(cs0)
          local v = _let_495_[1]
          local c = _let_495_[2]
          if (nil == v) then
            local function _496_()
              local tbl_26_ = {}
              local i_27_ = 0
              for _, c_2a in ipairs(cs0) do
                local val_28_
                if (c_2a ~= c) then
                  val_28_ = c_2a
                else
                  val_28_ = nil
                end
                if (nil ~= val_28_) then
                  i_27_ = (i_27_ + 1)
                  tbl_26_[i_27_] = val_28_
                else
                end
              end
              return tbl_26_
            end
            return recur(_496_())
          else
            _3e_21(out, v)
            return recur(cs0)
          end
        else
          return close_21(out)
        end
      end
      return recur(_2_492_)
    end
    go_1_auto(_494_)
  end
  return out
end
local function into(t, ch)
  local function _501_(_241, _242)
    _241[(1 + #_241)] = _242
    return _241
  end
  return reduce(_501_, t, ch)
end
local function take(n, ch, buf_or_n)
  local out = chan(buf_or_n)
  do
    local _let_502_ = require("src.io.gitlab.andreyorst.async")
    local go_1_auto = _let_502_["go*"]
    local function _503_()
      local done = false
      for i = 1, n do
        if done then break end
        local case_504_ = _3c_21(ch)
        if (nil ~= case_504_) then
          local v = case_504_
          _3e_21(out, v)
        elseif (case_504_ == nil) then
          done = true
        else
        end
      end
      return close_21(out)
    end
    go_1_auto(_503_)
  end
  return out
end
return {buffer = buffer, ["dropping-buffer"] = dropping_buffer, ["sliding-buffer"] = sliding_buffer, ["promise-buffer"] = promise_buffer, ["unblocking-buffer?"] = unblocking_buffer_3f, ["main-thread?"] = main_thread_3f, chan = chan, ["chan?"] = chan_3f, ["promise-chan"] = promise_chan, ["take!"] = take_21, ["<!!"] = _3c_21_21, ["<!"] = _3c_21, timeout = timeout, ["put!"] = put_21, [">!!"] = _3e_21_21, [">!"] = _3e_21, ["close!"] = close_21, ["go*"] = go_2a, ["alts!"] = alts_21, ["offer!"] = offer_21, ["poll!"] = poll_21, pipe = pipe, ["pipeline-async"] = pipeline_async, pipeline = pipeline, ["pipeline-async-unordered"] = pipeline_async_unordered, ["pipeline-unordered"] = pipeline_unordered, reduce = reduce, reduced = reduced, ["reduced?"] = reduced_3f, transduce = transduce, split = split, ["onto-chan!"] = onto_chan_21, ["to-chan!"] = to_chan_21, mult = mult, tap = tap, untap = untap, ["untap-all"] = untap_all, mix = mix, admix = admix, unmix = unmix, ["unmix-all"] = unmix_all, toggle = toggle, ["solo-mode"] = solo_mode, pub = pub, sub = sub, unsub = unsub, ["unsub-all"] = unsub_all, map = map, merge = merge, into = into, take = take, buffers = {FixedBuffer = FixedBuffer, SlidingBuffer = SlidingBuffer, DroppingBuffer = DroppingBuffer, PromiseBuffer = PromiseBuffer}, __VERSION = "dev"}
