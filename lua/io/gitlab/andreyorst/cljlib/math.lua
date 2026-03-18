-- [nfnl] .deps/git/io.gitlab.andreyorst/fennel-cljlib/256d59ef6efd0f39ca35bb6815e9c29bc8b8584a/src/io/gitlab/andreyorst/cljlib/math.fnl
local function _1_()
  return "#<namespace: io.gitlab.andreyorst.cljlib.math>"
end
--[[ "Math functions from `clojure.math`.
Implemented to the best of my ability." ]]
local _local_2_ = {setmetatable({}, {__fennelview = _1_, __name = "namespace"}), require("io.gitlab.andreyorst.cljlib.core"), require("math")}, nil
local math = _local_2_[1]
local _local_3_ = _local_2_[2]
local add = _local_3_.add
local dec = _local_3_.dec
local inc = _local_3_.inc
local mul = _local_3_.mul
local sub = _local_3_.sub
local core = _local_3_
local _local_4_ = _local_2_[3]
local m_2fabs = _local_4_.abs
local m_2facos = _local_4_.acos
local m_2fasin = _local_4_.asin
local m_2fatan = _local_4_.atan
local m_2fceil = _local_4_.ceil
local m_2fcos = _local_4_.cos
local m_2fdeg = _local_4_.deg
local m_2fexp = _local_4_.exp
local m_2ffloor = _local_4_.floor
local m_2ffmod = _local_4_.fmod
local m_2finf = _local_4_.huge
local m_2flog = _local_4_.log
local maxinteger = _local_4_.maxinteger
local mininteger = _local_4_.mininteger
local m_2frad = _local_4_.rad
local m_2frandom = _local_4_.random
local m_2fsin = _local_4_.sin
local m_2fsqrt = _local_4_.sqrt
local m_2ftan = _local_4_.tan
local m = _local_4_
local E
do
  local v_39_auto = m_2fexp(1)
  math.E = v_39_auto
  E = v_39_auto
end
local PI
do
  local v_39_auto = m.pi
  math.PI = v_39_auto
  PI = v_39_auto
end
local log2 = m_2flog(2)
local m_2fatan2
local or_5_ = m.atan2
if not or_5_ then
  local function _6_(a, b)
    return m_2fatan(a, b)
  end
  or_5_ = _6_
end
m_2fatan2 = or_5_
local m_2fpow
local or_7_ = m.pow
if not or_7_ then
  local function _8_(a, b)
    return (a ^ b)
  end
  or_7_ = _8_
end
m_2fpow = or_7_
local m_2fsinh
local or_9_ = m.sinh
if not or_9_ then
  local function _10_(x)
    return ((m_2fpow(E, x) - m_2fpow(E, ( - x))) / 2)
  end
  or_9_ = _10_
end
m_2fsinh = or_9_
local m_2fcosh
local or_11_ = m.cosh
if not or_11_ then
  local function _12_(x)
    return ((m_2fpow(E, x) + m_2fpow(E, ( - x))) / 2)
  end
  or_11_ = _12_
end
m_2fcosh = or_11_
local m_2ftanh
local or_13_ = m.tanh
if not or_13_ then
  local function _14_(x)
    return (m_2fsinh(x) / m_2fcosh(x))
  end
  or_13_ = _14_
end
m_2ftanh = or_13_
local m_2flog10
local or_15_ = m.log10
if not or_15_ then
  local function _16_(x)
    return m_2flog(x, 10)
  end
  or_15_ = _16_
end
m_2flog10 = or_15_
local m_2fldexp
local or_17_ = m.ldexp
if not or_17_ then
  local function _18_(x, exp)
    return (x * (2 ^ exp))
  end
  or_17_ = _18_
end
m_2fldexp = or_17_
local m_2ffrexp
local or_19_ = m.frexp
if not or_19_ then
  local function _20_(x)
    if (x == 0) then
      return 0, 0
    else
      local e = m_2ffloor(((m_2flog(m_2fabs(x)) / log2) + 1))
      return (x / (2 ^ e)), e
    end
  end
  or_19_ = _20_
end
m_2ffrexp = or_19_
local function nan_3f(x)
  return (x ~= x)
end
local function inf_3f(x)
  return ((x == m_2finf) or (x == ( - m_2finf)))
end
local function m_2fround(x)
  if (x < (m_2ffloor(x) + 0.5)) then
    return m_2ffloor(x)
  else
    return m_2fceil(x)
  end
end
local sin
do
  local sin0 = nil
  math.sin = function(...)
    local a = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.sin"))
      else
      end
    end
    if (nan_3f(a) or inf_3f(a)) then
      return (0/0)
    else
      return m_2fsin(a)
    end
  end
  sin0 = math.sin
  sin = math.sin
end
local cos
do
  local cos0 = nil
  math.cos = function(...)
    local a = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.cos"))
      else
      end
    end
    if (nan_3f(a) or inf_3f(a)) then
      return (0/0)
    else
      return m_2fcos(a)
    end
  end
  cos0 = math.cos
  cos = math.cos
end
local tan
do
  local tan0 = nil
  math.tan = function(...)
    local a = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.tan"))
      else
      end
    end
    if (nan_3f(a) or inf_3f(a)) then
      return (0/0)
    elseif (a == 0) then
      return a
    else
      return m_2ftan(a)
    end
  end
  tan0 = math.tan
  tan = math.tan
end
local asin
do
  local asin0 = nil
  math.asin = function(...)
    local a = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.asin"))
      else
      end
    end
    if (nan_3f(a) or (m_2fabs(a) > 1)) then
      return (0/0)
    elseif (a == 0) then
      return a
    else
      return m_2fasin(a)
    end
  end
  asin0 = math.asin
  asin = math.asin
end
local acos
do
  local acos0 = nil
  math.acos = function(...)
    local a = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.acos"))
      else
      end
    end
    if (nan_3f(a) or (m_2fabs(a) > 1)) then
      return (0/0)
    else
      return m_2facos(a)
    end
  end
  acos0 = math.acos
  acos = math.acos
end
local atan
do
  local atan0 = nil
  math.atan = function(...)
    local a = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.atan"))
      else
      end
    end
    if nan_3f(a) then
      return (0/0)
    elseif (0 == a) then
      return 0
    else
      return m_2fatan(a)
    end
  end
  atan0 = math.atan
  atan = math.atan
end
local to_radians
do
  local to_radians0 = nil
  math["to-radians"] = function(...)
    local deg = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.to-radians"))
      else
      end
    end
    return m_2frad(deg)
  end
  to_radians0 = math["to-radians"]
  to_radians = math["to-radians"]
end
local to_degrees
do
  local to_degrees0 = nil
  math["to-degrees"] = function(...)
    local r = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.to-degrees"))
      else
      end
    end
    return m_2fdeg(r)
  end
  to_degrees0 = math["to-degrees"]
  to_degrees = math["to-degrees"]
end
local exp
do
  local exp0 = nil
  math.exp = function(...)
    local a = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.exp"))
      else
      end
    end
    if nan_3f(a) then
      return a
    elseif (a == m_2finf) then
      return a
    elseif (a == ( - m_2finf)) then
      return 0
    else
      return m_2fexp(a)
    end
  end
  exp0 = math.exp
  exp = math.exp
end
local log
do
  local log0 = nil
  math.log = function(...)
    local a = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.log"))
      else
      end
    end
    if (nan_3f(a) or (a < 0)) then
      return (0/0)
    elseif (a == m_2finf) then
      return a
    elseif (a == 0) then
      return ( - m_2finf)
    else
      return m_2flog(a)
    end
  end
  log0 = math.log
  log = math.log
end
local log10
do
  local log100 = nil
  math.log10 = function(...)
    local a = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.log10"))
      else
      end
    end
    if (nan_3f(a) or (a < 0)) then
      return (0/0)
    elseif (a == m_2finf) then
      return a
    elseif (a == 0) then
      return ( - m_2finf)
    else
      return m_2flog10(a)
    end
  end
  log100 = math.log10
  log10 = math.log10
end
local sqrt
do
  local sqrt0 = nil
  math.sqrt = function(...)
    local a = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.sqrt"))
      else
      end
    end
    if (nan_3f(a) or (a < 0)) then
      return (0/0)
    elseif (a == m_2finf) then
      return a
    elseif (a == 0) then
      return a
    else
      return m_2fsqrt(a)
    end
  end
  sqrt0 = math.sqrt
  sqrt = math.sqrt
end
local function improve(guess, x)
  return (((x / m_2fpow(guess, 2)) + (2 * guess)) / 3)
end
local function good_enough_3f(old_guess, guess)
  return (m_2fabs((old_guess - guess)) < 1e-06)
end
local function cbrt_2a(guess, x)
  local old_guess = guess
  local guess0 = improve(guess, x)
  if good_enough_3f(old_guess, guess0) then
    return guess0
  else
    return cbrt_2a(guess0, x)
  end
end
local cbrt
do
  local cbrt0 = nil
  math.cbrt = function(...)
    local a = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.cbrt"))
      else
      end
    end
    if (a == 0) then
      return a
    elseif nan_3f(a) then
      return a
    elseif inf_3f(a) then
      return a
    else
      return cbrt_2a(1, a)
    end
  end
  cbrt0 = math.cbrt
  cbrt = math.cbrt
end
local IEEE_remainder
do
  local IEEE_remainder0 = nil
  math["IEEE-remainder"] = function(...)
    local dividend, divisor = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.IEEE-remainder"))
      else
      end
    end
    if (nan_3f(dividend) or nan_3f(divisor, divisor) or inf_3f(dividend) or (0 == divisor)) then
      return (0/0)
    elseif inf_3f(divisor) then
      return dividend
    else
      local quotient = (dividend / divisor)
      local n = m_2ffloor((quotient + 0.5))
      local n0
      if (((quotient - n) == 0.5) and ((n % 2) ~= 0)) then
        n0 = (n + 1)
      else
        n0 = n
      end
      return (dividend - (divisor * n0))
    end
  end
  IEEE_remainder0 = math["IEEE-remainder"]
  IEEE_remainder = math["IEEE-remainder"]
end
local ceil
do
  local ceil0 = nil
  math.ceil = function(...)
    local a = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.ceil"))
      else
      end
    end
    if (nan_3f(a) or inf_3f(a)) then
      return a
    else
      return m_2fceil(a)
    end
  end
  ceil0 = math.ceil
  ceil = math.ceil
end
local floor
do
  local floor0 = nil
  math.floor = function(...)
    local a = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.floor"))
      else
      end
    end
    if (nan_3f(a) or inf_3f(a)) then
      return a
    else
      return m_2ffloor(a)
    end
  end
  floor0 = math.floor
  floor = math.floor
end
local rint
do
  local rint0 = nil
  math.rint = function(...)
    local a = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.rint"))
      else
      end
    end
    if (nan_3f(a) or inf_3f(a) or (0 == a)) then
      return a
    else
      local lower = m_2ffloor(a)
      local upper = m_2fceil(a)
      if ((a - lower) == 0.5) then
        return ((((lower % 2) == 0) and lower) or upper)
      elseif ((upper - a) == 0.5) then
        return ((((upper % 2) == 0) and upper) or lower)
      else
        return (((m_2fabs((a - lower)) < m_2fabs((a - upper))) and lower) or upper)
      end
    end
  end
  rint0 = math.rint
  rint = math.rint
end
local atan2
do
  local atan20 = nil
  math.atan2 = function(...)
    local y, x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.atan2"))
      else
      end
    end
    return m_2fatan2(y, x)
  end
  atan20 = math.atan2
  atan2 = math.atan2
end
local pow
do
  local pow0 = nil
  math.pow = function(...)
    local a, b = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.pow"))
      else
      end
    end
    return m_2fpow(a, b)
  end
  pow0 = math.pow
  pow = math.pow
end
local round
do
  local round0 = nil
  math.round = function(...)
    local a = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.round"))
      else
      end
    end
    if nan_3f(a) then
      return 0
    elseif (( - m_2finf) == a) then
      return mininteger
    elseif (m_2finf == a) then
      return maxinteger
    else
      return m_2fround(a)
    end
  end
  round0 = math.round
  round = math.round
end
local random
do
  local random0 = nil
  math.random = function(...)
    do
      local cnt_69_auto = select("#", ...)
      if (0 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.random"))
      else
      end
    end
    return m_2frandom()
  end
  random0 = math.random
  random = math.random
end
local add_exact
do
  local add_exact0 = nil
  math["add-exact"] = function(...)
    local x, y = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.add-exact"))
      else
      end
    end
    return add(x, y)
  end
  add_exact0 = math["add-exact"]
  add_exact = math["add-exact"]
end
local subtract_exact
do
  local subtract_exact0 = nil
  math["subtract-exact"] = function(...)
    local x, y = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.subtract-exact"))
      else
      end
    end
    return sub(x, y)
  end
  subtract_exact0 = math["subtract-exact"]
  subtract_exact = math["subtract-exact"]
end
local multiply_exact
do
  local multiply_exact0 = nil
  math["multiply-exact"] = function(...)
    local x, y = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.multiply-exact"))
      else
      end
    end
    return mul(x, y)
  end
  multiply_exact0 = math["multiply-exact"]
  multiply_exact = math["multiply-exact"]
end
local increment_exact
do
  local increment_exact0 = nil
  math["increment-exact"] = function(...)
    local a = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.increment-exact"))
      else
      end
    end
    return inc(a)
  end
  increment_exact0 = math["increment-exact"]
  increment_exact = math["increment-exact"]
end
local decrement_exact
do
  local decrement_exact0 = nil
  math["decrement-exact"] = function(...)
    local a = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.decrement-exact"))
      else
      end
    end
    return dec(a)
  end
  decrement_exact0 = math["decrement-exact"]
  decrement_exact = math["decrement-exact"]
end
local negate_exact
do
  local negate_exact0 = nil
  math["negate-exact"] = function(...)
    local a = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.negate-exact"))
      else
      end
    end
    return sub(a)
  end
  negate_exact0 = math["negate-exact"]
  negate_exact = math["negate-exact"]
end
local floor_div
do
  local floor_div0 = nil
  math["floor-div"] = function(...)
    local x, y = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.floor-div"))
      else
      end
    end
    return (x // y)
  end
  floor_div0 = math["floor-div"]
  floor_div = math["floor-div"]
end
local floor_mod
do
  local floor_mod0 = nil
  math["floor-mod"] = function(...)
    local x, y = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.floor-mod"))
      else
      end
    end
    return m_2ffmod(x, y)
  end
  floor_mod0 = math["floor-mod"]
  floor_mod = math["floor-mod"]
end
local ulp
do
  local ulp0 = nil
  math.ulp = function(...)
    local d = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.ulp"))
      else
      end
    end
    if (nan_3f(d) or inf_3f(d)) then
      return d
    elseif (d == 0) then
      return m_2fldexp(1, ( - 1074))
    elseif ((d == m_2fldexp(1, 1023)) or (d == ( - m_2fldexp(1, 1023)))) then
      return m_2fldexp(1, 971)
    else
      local _, exponent = m_2ffrexp(d)
      return m_2fldexp(1, (exponent - 53))
    end
  end
  ulp0 = math.ulp
  ulp = math.ulp
end
local signum
do
  local signum0 = nil
  math.signum = function(...)
    local d = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.signum"))
      else
      end
    end
    if nan_3f(d) then
      return d
    elseif (d > 0) then
      return 1
    elseif (d < 0) then
      return -1
    else
      return 0
    end
  end
  signum0 = math.signum
  signum = math.signum
end
local sinh
do
  local sinh0 = nil
  math.sinh = function(...)
    local x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.sinh"))
      else
      end
    end
    if nan_3f(x) then
      return x
    elseif ((0 == x) or inf_3f(x)) then
      return x
    else
      return m_2fsinh(x)
    end
  end
  sinh0 = math.sinh
  sinh = math.sinh
end
local cosh
do
  local cosh0 = nil
  math.cosh = function(...)
    local x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.cosh"))
      else
      end
    end
    if nan_3f(x) then
      return x
    elseif (0 == x) then
      return 1
    elseif inf_3f(x) then
      return m_2finf
    else
      return m_2fcosh(x)
    end
  end
  cosh0 = math.cosh
  cosh = math.cosh
end
local tanh
do
  local tanh0 = nil
  math.tanh = function(...)
    local x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.tanh"))
      else
      end
    end
    if nan_3f(x) then
      return x
    elseif (0 == x) then
      return 0
    elseif (x == m_2finf) then
      return 1
    elseif (x == ( - m_2finf)) then
      return -1
    else
      return m_2ftanh(x)
    end
  end
  tanh0 = math.tanh
  tanh = math.tanh
end
local hypot
do
  local hypot0 = nil
  math.hypot = function(...)
    local x, y = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.hypot"))
      else
      end
    end
    if (inf_3f(x) or inf_3f(y)) then
      return (1/0)
    elseif (nan_3f(x) or nan_3f(y)) then
      return (0/0)
    elseif ((0 == x) and (0 == y) and 0) then
      return 0
    elseif "else" then
      local x0 = m_2fabs(x)
      local y0 = m_2fabs(y)
      if (x0 > y0) then
        return (x0 * m_2fsqrt((1 + m_2fpow((y0 / x0), 2))))
      else
        return (y0 * m_2fsqrt((1 + m_2fpow((x0 / y0), 2))))
      end
    else
      return nil
    end
  end
  hypot0 = math.hypot
  hypot = math.hypot
end
local expm1
do
  local expm10 = nil
  math.expm1 = function(...)
    local x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.expm1"))
      else
      end
    end
    if nan_3f(x) then
      return x
    elseif (x == m_2finf) then
      return m_2finf
    else
      local _85_ = ( - m_2finf)
      if ((x == _85_) and (_85_ == -1)) then
        return (x == 0)
      elseif x then
        return (m_2fpow(E, x) - 1)
      else
        return nil
      end
    end
  end
  expm10 = math.expm1
  expm1 = math.expm1
end
local log1p
do
  local log1p0 = nil
  math.log1p = function(...)
    local x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.log1p"))
      else
      end
    end
    if (nan_3f(x) or (x < -1)) then
      return (0/0)
    elseif (x == m_2finf) then
      return m_2finf
    elseif (x == -1) then
      return ( - m_2finf)
    elseif (x == 0) then
      return x
    else
      return m_2flog((1 + x))
    end
  end
  log1p0 = math.log1p
  log1p = math.log1p
end
local copy_sign
do
  local copy_sign0 = nil
  math["copy-sign"] = function(...)
    local magnitude, sign = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.copy-sign"))
      else
      end
    end
    local abs_magnitude = m_2fabs(magnitude)
    if (sign >= 0) then
      return abs_magnitude
    else
      return ( - abs_magnitude)
    end
  end
  copy_sign0 = math["copy-sign"]
  copy_sign = math["copy-sign"]
end
local get_exponent
do
  local get_exponent0 = nil
  math["get-exponent"] = function(...)
    local d = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.get-exponent"))
      else
      end
    end
    local MAX_EXPONENT = 1023
    local MIN_EXPONENT = -1022
    if nan_3f(d) then
      return (MAX_EXPONENT + 1)
    elseif inf_3f(d) then
      return (MAX_EXPONENT + 1)
    elseif (d == 0) then
      return (MIN_EXPONENT - 1)
    else
      local _, exponent = m_2ffrexp(d)
      local adjusted_exponent = (exponent - 1)
      if (adjusted_exponent < MIN_EXPONENT) then
        return (MIN_EXPONENT - 1)
      else
        return adjusted_exponent
      end
    end
  end
  get_exponent0 = math["get-exponent"]
  get_exponent = math["get-exponent"]
end
local next_after
do
  local next_after0 = nil
  math["next-after"] = function(...)
    local start, direction = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.next-after"))
      else
      end
    end
    if (nan_3f(start) or nan_3f(direction)) then
      return (0/0)
    elseif (start == direction) then
      return direction
    elseif (start == 0) then
      return (((direction > 0) and m_2fldexp(1, ( - 1074))) or ( - m_2fldexp(1, ( - 1074))))
    else
      local sign = (((start > 0) and 1) or ( - 1))
      local mantissa, exponent = m_2ffrexp(start)
      local mantissa0
      if (direction > start) then
        if (mantissa < 1) then
          mantissa0 = (mantissa + (2 ^ ( - 53)))
        else
          mantissa0 = (mantissa + 1)
        end
      else
        if (mantissa > ( - 1)) then
          mantissa0 = (mantissa - (2 ^ ( - 53)))
        else
          mantissa0 = (mantissa - 1)
        end
      end
      local mantissa1, exponent0
      if (mantissa0 >= 1) then
        mantissa1, exponent0 = (mantissa0 / 2), (exponent + 1)
      elseif ((mantissa0 < 0.5) and (mantissa0 > 0)) then
        mantissa1, exponent0 = (mantissa0 * 2), (exponent - 1)
      else
        mantissa1, exponent0 = mantissa0, exponent
      end
      return (sign * m_2fldexp(mantissa1, exponent0))
    end
  end
  next_after0 = math["next-after"]
  next_after = math["next-after"]
end
local next_up
do
  local next_up0 = nil
  math["next-up"] = function(...)
    local d = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.next-up"))
      else
      end
    end
    return next_after(d, 1)
  end
  next_up0 = math["next-up"]
  next_up = math["next-up"]
end
local next_down
do
  local next_down0 = nil
  math["next-down"] = function(...)
    local d = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.next-down"))
      else
      end
    end
    return next_after(d, -1)
  end
  next_down0 = math["next-down"]
  next_down = math["next-down"]
end
local scalb
do
  local scalb0 = nil
  math.scalb = function(...)
    local d, scale_factor = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "math.scalb"))
      else
      end
    end
    if nan_3f(d) then
      return d
    elseif inf_3f(d) then
      return d
    elseif (d == 0) then
      return d
    else
      local sign = (((d < 0) and ( - 1)) or 1)
      local d0 = m_2fabs(d)
      local mantissa, exponent = m_2ffrexp(d0)
      local exponent0 = (exponent + scale_factor)
      if (exponent0 > 1023) then
        return (sign * m_2finf)
      elseif (exponent0 < -1022) then
        return (sign * 0)
      else
        return (sign * mantissa * (2 ^ exponent0))
      end
    end
  end
  scalb0 = math.scalb
  scalb = math.scalb
end
return math
