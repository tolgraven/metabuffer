-- [nfnl] .deps/git/io.gitlab.andreyorst/itable/b6fc02715a84e6dc71d8ecd313338eede8f3c163/src/io/gitlab/andreyorst/itable.fnl
local t_2fsort = table.sort
local t_2fconcat = table.concat
local t_2fremove = table.remove
local t_2fmove = table.move
local t_2finsert = table.insert
local itable = {__VERSION = "0.1.33"}
local t_2funpack = (table.unpack or _G.unpack)
local pairs_2a
itable.pairs = function(t)
  local _2_
  do
    local case_1_ = getmetatable(t)
    if ((_G.type(case_1_) == "table") and (nil ~= case_1_.__pairs)) then
      local p = case_1_.__pairs
      _2_ = p
    else
      local _ = case_1_
      _2_ = pairs
    end
  end
  return _2_(t)
end
pairs_2a = itable.pairs
local ipairs_2a
itable.ipairs = function(t)
  local _7_
  do
    local case_6_ = getmetatable(t)
    if ((_G.type(case_6_) == "table") and (nil ~= case_6_.__ipairs)) then
      local i = case_6_.__ipairs
      _7_ = i
    else
      local _ = case_6_
      _7_ = ipairs
    end
  end
  return _7_(t)
end
ipairs_2a = itable.ipairs
local length_2a
itable.length = function(t)
  local _12_
  do
    local case_11_ = getmetatable(t)
    if ((_G.type(case_11_) == "table") and (nil ~= case_11_.__len)) then
      local l = case_11_.__len
      _12_ = l
    else
      local _ = case_11_
      local function _15_(...)
        return #...
      end
      _12_ = _15_
    end
  end
  return _12_(t)
end
length_2a = itable.length
local function copy(t)
  if t then
    local tbl_21_ = {}
    for k, v in pairs_2a(t) do
      local k_22_, v_23_ = k, v
      if ((k_22_ ~= nil) and (v_23_ ~= nil)) then
        tbl_21_[k_22_] = v_23_
      else
      end
    end
    return tbl_21_
  else
    return nil
  end
end
local function eq(...)
  local case_19_, case_20_, case_21_ = select("#", ...), ...
  if ((case_19_ == 0) or (case_19_ == 1)) then
    return true
  elseif ((case_19_ == 2) and true and true) then
    local _3fa = case_20_
    local _3fb = case_21_
    if (_3fa == _3fb) then
      return true
    else
      local _22_ = type(_3fb)
      if ((type(_3fa) == _22_) and (_22_ == "table")) then
        local res, count_a, count_b = true, 0, 0
        for k, v in pairs_2a(_3fa) do
          if not res then break end
          local function _23_(...)
            local res0 = nil
            for k_2a, v0 in pairs_2a(_3fb) do
              if res0 then break end
              if eq(k_2a, k) then
                res0 = v0
              else
              end
            end
            return res0
          end
          res = eq(v, _23_(...))
          count_a = (count_a + 1)
        end
        if res then
          for _, _0 in pairs_2a(_3fb) do
            count_b = (count_b + 1)
          end
          res = (count_a == count_b)
        else
        end
        return res
      else
        return false
      end
    end
  elseif (true and true and true) then
    local _ = case_19_
    local _3fa = case_20_
    local _3fb = case_21_
    return (eq(_3fa, _3fb) and eq(select(2, ...)))
  else
    return nil
  end
end
itable.eq = eq
local function deep_index(tbl, key)
  local res = nil
  for k, v in pairs_2a(tbl) do
    if res then break end
    if eq(k, key) then
      res = v
    else
      res = nil
    end
  end
  return res
end
local function deep_newindex(tbl, key, val)
  local done = false
  if ("table" == type(key)) then
    for k, _ in pairs_2a(tbl) do
      if done then break end
      if eq(k, key) then
        rawset(tbl, k, val)
        done = true
      else
      end
    end
  else
  end
  if not done then
    return rawset(tbl, key, val)
  else
    return nil
  end
end
local function immutable(t, opts)
  local t0
  if (opts and opts["fast-index?"]) then
    t0 = t
  else
    t0 = setmetatable(t, {__index = deep_index, __newindex = deep_newindex})
  end
  local len = length_2a(t0)
  local proxy = {}
  local __len
  local function _33_()
    return len
  end
  __len = _33_
  local __index
  local function _34_(_241, _242)
    return t0[_242]
  end
  __index = _34_
  local __newindex
  local function _35_()
    return error((tostring(proxy) .. " is immutable"), 2)
  end
  __newindex = _35_
  local __pairs
  local function _36_()
    local function _37_(_, k)
      return next(t0, k)
    end
    return _37_, nil, nil
  end
  __pairs = _36_
  local __ipairs
  local function _38_()
    local function _39_(_, k)
      return next(t0, k)
    end
    return _39_
  end
  __ipairs = _38_
  local __call
  local function _40_(_241, _242)
    return t0[_242]
  end
  __call = _40_
  local __fennelview
  local function _41_(_241, _242, _243, _244)
    return _242(t0, _243, _244)
  end
  __fennelview = _41_
  local __fennelrest
  local function _42_(_241, _242)
    return immutable({t_2funpack(t0, _242)})
  end
  __fennelrest = _42_
  return setmetatable(proxy, {__index = __index, __newindex = __newindex, __len = __len, __pairs = __pairs, __ipairs = __ipairs, __call = __call, __metatable = {__len = __len, __pairs = __pairs, __ipairs = __ipairs, __call = __call, __fennelrest = __fennelrest, __fennelview = __fennelview, __index = itable}})
end
itable.immutable = immutable
itable.insert = function(t, ...)
  local t0 = copy(t)
  do
    local case_43_, case_44_, case_45_ = select("#", ...), ...
    if (case_43_ == 0) then
      error("wrong number of arguments to 'insert'")
    elseif ((case_43_ == 1) and true) then
      local _3fv = case_44_
      t_2finsert(t0, _3fv)
    elseif (true and true and true) then
      local _ = case_43_
      local _3fk = case_44_
      local _3fv = case_45_
      t_2finsert(t0, _3fk, _3fv)
    else
    end
  end
  return immutable(t0)
end
if t_2fmove then
  local function _47_(src, start, _end, tgt, dest)
    local src0 = copy(src)
    local dest0 = copy(dest)
    return immutable(t_2fmove(src0, start, _end, tgt, dest0))
  end
  itable.move = _47_
else
  itable.move = nil
end
itable.pack = function(...)
  local function _49_(...)
    local tmp_9_ = {...}
    tmp_9_["n"] = select("#", ...)
    return tmp_9_
  end
  return immutable(_49_(...))
end
local function remove(t, key)
  local t0 = copy(t)
  local v = t_2fremove(t0, key)
  return immutable(t0), v
end
itable.remove = remove
itable.concat = function(t, sep, start, _end, serializer, opts)
  local serializer0 = (serializer or tostring)
  local _50_
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for _, v in ipairs_2a(t) do
      local val_28_ = serializer0(v, opts)
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    _50_ = tbl_26_
  end
  return t_2fconcat(_50_, sep, start, _end)
end
itable.unpack = function(t, ...)
  return t_2funpack(copy(t), ...)
end
itable.assoc = function(t, key, val, ...)
  local len = select("#", ...)
  if (0 ~= (len % 2)) then
    error(("no value supplied for key " .. tostring(select(len, ...))), 2)
  else
  end
  local t0
  do
    local tmp_9_ = copy(t)
    tmp_9_[key] = val
    t0 = tmp_9_
  end
  for i = 1, len, 2 do
    local k, v = select(i, ...)
    t0[k] = v
  end
  return immutable(t0)
end
local assoc = itable.assoc
local assoc_in = nil
itable["assoc-in"] = function(t, _53_, val)
  local k = _53_[1]
  local ks = (function (t, k) return ((getmetatable(t) or {}).__fennelrest or function (t, k) return {(table.unpack or unpack)(t, k)} end)(t, k) end)(_53_, 2)
  local t0 = (t or {})
  print(ks)
  if next(ks) then
    return assoc(t0, k, assoc_in((t0[k] or {}), ks, val))
  else
    return assoc(t0, k, val)
  end
end
assoc_in = itable["assoc-in"]
itable.update = function(t, key, f)
  local function _55_()
    local tmp_9_ = copy(t)
    tmp_9_[key] = f(t[key])
    return tmp_9_
  end
  return immutable(_55_())
end
local update = itable.update
local update_in = nil
itable["update-in"] = function(t, _56_, f)
  local k = _56_[1]
  local ks = (function (t, k) return ((getmetatable(t) or {}).__fennelrest or function (t, k) return {(table.unpack or unpack)(t, k)} end)(t, k) end)(_56_, 2)
  local t0 = (t or {})
  if next(ks) then
    return assoc(t0, k, update_in(t0[k], ks, f))
  else
    return update(t0, k, f)
  end
end
update_in = itable["update-in"]
itable.deepcopy = function(x)
  local function deepcopy_2a(x0, seen)
    local case_58_ = type(x0)
    if (case_58_ == "table") then
      local case_59_ = seen[x0]
      if (case_59_ == true) then
        return error("immutable tables can't contain self reference", 2)
      else
        local _ = case_59_
        seen[x0] = true
        local function _60_()
          local tbl_21_ = {}
          for k, v in pairs_2a(x0) do
            local k_22_, v_23_ = deepcopy_2a(k, seen), deepcopy_2a(v, seen)
            if ((k_22_ ~= nil) and (v_23_ ~= nil)) then
              tbl_21_[k_22_] = v_23_
            else
            end
          end
          return tbl_21_
        end
        return immutable(_60_())
      end
    else
      local _ = case_58_
      return x0
    end
  end
  return deepcopy_2a(x, {})
end
itable.first = function(_64_)
  local x = _64_[1]
  return x
end
itable.rest = function(t)
  return (remove(t, 1))
end
local function nthrest(t, n)
  local t_2a = {}
  for i = (n + 1), length_2a(t) do
    t_2finsert(t_2a, t[i])
  end
  return immutable(t_2a)
end
itable.nthrest = nthrest
itable.last = function(t)
  return t[length_2a(t)]
end
itable.butlast = function(t)
  return (remove(t, length_2a(t)))
end
local function join(...)
  local case_65_, case_66_, case_67_ = select("#", ...), ...
  if (case_65_ == 0) then
    return nil
  elseif ((case_65_ == 1) and true) then
    local _3ft = case_66_
    return immutable(copy(_3ft))
  elseif ((case_65_ == 2) and true and true) then
    local _3ft1 = case_66_
    local _3ft2 = case_67_
    local to = copy(_3ft1)
    local from = (_3ft2 or {})
    for _, v in ipairs_2a(from) do
      t_2finsert(to, v)
    end
    return immutable(to)
  elseif (true and true and true) then
    local _ = case_65_
    local _3ft1 = case_66_
    local _3ft2 = case_67_
    return join(join(_3ft1, _3ft2), select(3, ...))
  else
    return nil
  end
end
itable.join = join
local function take(n, t)
  local t_2a = {}
  for i = 1, n do
    t_2finsert(t_2a, t[i])
  end
  return immutable(t_2a)
end
itable.take = take
itable.drop = function(n, t)
  return nthrest(t, n)
end
itable.partition = function(...)
  local res = {}
  local function partition_2a(...)
    local case_69_, case_70_, case_71_, case_72_, case_73_ = select("#", ...), ...
    if ((case_69_ == 0) or (case_69_ == 1)) then
      return error("wrong amount arguments to 'partition'")
    elseif ((case_69_ == 2) and true and true) then
      local _3fn = case_70_
      local _3ft = case_71_
      return partition_2a(_3fn, _3fn, _3ft)
    elseif ((case_69_ == 3) and true and true and true) then
      local _3fn = case_70_
      local _3fstep = case_71_
      local _3ft = case_72_
      local p = take(_3fn, _3ft)
      if (_3fn == length_2a(p)) then
        t_2finsert(res, p)
        return partition_2a(_3fn, _3fstep, {t_2funpack(_3ft, (_3fstep + 1))})
      else
        return nil
      end
    elseif (true and true and true and true and true) then
      local _ = case_69_
      local _3fn = case_70_
      local _3fstep = case_71_
      local _3fpad = case_72_
      local _3ft = case_73_
      local p = take(_3fn, _3ft)
      if (_3fn == length_2a(p)) then
        t_2finsert(res, p)
        return partition_2a(_3fn, _3fstep, _3fpad, {t_2funpack(_3ft, (_3fstep + 1))})
      else
        return t_2finsert(res, take(_3fn, join(p, _3fpad)))
      end
    else
      return nil
    end
  end
  partition_2a(...)
  return immutable(res)
end
itable.keys = function(t)
  local function _77_()
    local tbl_26_ = {}
    local i_27_ = 0
    for k, _ in pairs_2a(t) do
      local val_28_ = k
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    return tbl_26_
  end
  return immutable(_77_())
end
itable.vals = function(t)
  local function _79_()
    local tbl_26_ = {}
    local i_27_ = 0
    for _, v in pairs_2a(t) do
      local val_28_ = v
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    return tbl_26_
  end
  return immutable(_79_())
end
itable["group-by"] = function(f, t)
  local res = {}
  local ungroupped = {}
  for _, v in pairs_2a(t) do
    local k = f(v)
    if (nil ~= k) then
      local case_81_ = res[k]
      if (nil ~= case_81_) then
        local t_2a = case_81_
        t_2finsert(t_2a, v)
      else
        local _0 = case_81_
        res[k] = {v}
      end
    else
      t_2finsert(ungroupped, v)
    end
  end
  local function _84_()
    local tbl_21_ = {}
    for k, t0 in pairs_2a(res) do
      local k_22_, v_23_ = k, immutable(t0)
      if ((k_22_ ~= nil) and (v_23_ ~= nil)) then
        tbl_21_[k_22_] = v_23_
      else
      end
    end
    return tbl_21_
  end
  return immutable(_84_()), immutable(ungroupped)
end
itable.frequencies = function(t)
  local res = setmetatable({}, {__index = deep_index, __newindex = deep_newindex})
  for _, v in pairs_2a(t) do
    local case_86_ = res[v]
    if (nil ~= case_86_) then
      local a = case_86_
      res[v] = (a + 1)
    else
      local _0 = case_86_
      res[v] = 1
    end
  end
  return immutable(res)
end
itable.sort = function(t, f)
  local function _88_()
    local tmp_9_ = copy(t)
    t_2fsort(tmp_9_, f)
    return tmp_9_
  end
  return immutable(_88_())
end
itable["immutable?"] = function(t)
  local case_89_ = getmetatable(t)
  if ((_G.type(case_89_) == "table") and (case_89_.__index == itable)) then
    return true
  else
    local _ = case_89_
    return false
  end
end
local function _91_(_, t, opts)
  local case_92_ = getmetatable(t)
  if ((_G.type(case_92_) == "table") and (case_92_.__index == itable)) then
    return t
  else
    local _0 = case_92_
    return immutable(copy(t), opts)
  end
end
return setmetatable(itable, {__call = _91_})
