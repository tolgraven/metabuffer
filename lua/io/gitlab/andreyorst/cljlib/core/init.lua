-- [nfnl] .deps/git/io.gitlab.andreyorst/fennel-cljlib/256d59ef6efd0f39ca35bb6815e9c29bc8b8584a/src/io/gitlab/andreyorst/cljlib/core/init.fnl
local function _1_()
  return "#<namespace: io.gitlab.andreyorst.cljlib.core>"
end
--[[ "MIT License

Copyright (c) 2022 Andrey Listopadov

Permission is hereby granted‚ free of charge‚ to any person obtaining a copy
of this software and associated documentation files (the “Software”)‚ to deal
in the Software without restriction‚ including without limitation the rights
to use‚ copy‚ modify‚ merge‚ publish‚ distribute‚ sublicense‚ and/or sell
copies of the Software‚ and to permit persons to whom the Software is
furnished to do so‚ subject to the following conditions：

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”‚ WITHOUT WARRANTY OF ANY KIND‚ EXPRESS OR
IMPLIED‚ INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY‚
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM‚ DAMAGES OR OTHER
LIABILITY‚ WHETHER IN AN ACTION OF CONTRACT‚ TORT OR OTHERWISE‚ ARISING FROM‚
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE." ]]
local _local_2_ = {setmetatable({}, {__fennelview = _1_, __name = "namespace"}), require("io.gitlab.andreyorst.lazy-seq"), require("io.gitlab.andreyorst.itable"), require("io.gitlab.andreyorst.reduced"), require("io.gitlab.andreyorst.inst"), require("io.gitlab.andreyorst.async"), require("io.gitlab.andreyorst.uuid"), require("io.gitlab.andreyorst.ImmutableRedBlackTree"), require("bc"), require("fennel"), require("math")}, nil
local core = _local_2_[1]
local lazy = _local_2_[2]
local itable = _local_2_[3]
local rdc = _local_2_[4]
local lua_inst = _local_2_[5]
local a = _local_2_[6]
local uuid = _local_2_[7]
local RedBlackTree = _local_2_[8]
local bc = _local_2_[9]
local _local_3_ = _local_2_[10]
local view = _local_3_.view
local fennel = _local_3_
local _local_4_ = _local_2_[11]
local m_2ffloor = _local_4_.floor
local max = _local_4_.max
local maxinteger = _local_4_.maxinteger
local min = _local_4_.min
local mininteger = _local_4_.mininteger
local math = _local_4_
core.__VERSION = "0.1.263"
local class
do
  local class0 = nil
  core.class = function(...)
    local x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.class"))
      else
      end
    end
    local case_6_ = type(x)
    if (case_6_ == "table") then
      local case_7_ = getmetatable(x)
      if ((_G.type(case_7_) == "table") and (nil ~= case_7_["cljlib/type"])) then
        local t = case_7_["cljlib/type"]
        return t
      else
        local _ = case_7_
        return "table"
      end
    elseif (case_6_ == "userdata") then
      local case_9_ = getmetatable(x)
      if ((_G.type(case_9_) == "table") and (nil ~= case_9_["cljlib/type"])) then
        local t = case_9_["cljlib/type"]
        return t
      else
        local _ = case_9_
        return "userdata"
      end
    elseif (nil ~= case_6_) then
      local t = case_6_
      return t
    else
      return nil
    end
  end
  class0 = core.class
  class = core.class
end
local function class_name(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "class-name"))
    else
    end
  end
  local case_13_ = type(x)
  if (case_13_ == "table") then
    local case_14_ = getmetatable(x)
    if ((_G.type(case_14_) == "table") and (nil ~= case_14_.__name)) then
      local n = case_14_.__name
      return n
    else
      local _ = case_14_
      return "table"
    end
  elseif (case_13_ == "userdata") then
    local case_16_ = getmetatable(x)
    if ((_G.type(case_16_) == "table") and (nil ~= case_16_.__name)) then
      local n = case_16_.__name
      return n
    else
      local _ = case_16_
      return "userdata"
    end
  elseif (nil ~= case_13_) then
    local t = case_13_
    return t
  else
    return nil
  end
end
local instance_3f
do
  local instance_3f0 = nil
  core["instance?"] = function(...)
    local c, x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.instance?"))
      else
      end
    end
    local mt = getmetatable(x)
    if (nil ~= mt) then
      if rawequal(c, mt.__index) then
        return true
      else
        return instance_3f0(c, mt.__index)
      end
    else
      return false
    end
  end
  instance_3f0 = core["instance?"]
  instance_3f = core["instance?"]
end
local bc_zero = bc.new(0)
local bc_one = bc.new(1)
local bc_minus_one = bc.new(-1)
local Ratio
do
  local v_39_auto = {__name = "Ratio", ["cljlib/class"] = true, __fennelview = tostring}
  core.Ratio = v_39_auto
  Ratio = v_39_auto
end
bc.digits(1024)
local BigDecimal
do
  local v_39_auto = {__fennelview = tostring, __name = "BigDecimal", ["cljlib/class"] = true}
  core.BigDecimal = v_39_auto
  BigDecimal = v_39_auto
end
BigDecimal.new = function(...)
  local self, x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "BigDecimal.new"))
    else
    end
  end
  if instance_3f(BigDecimal, x) then
    return x
  elseif instance_3f(Ratio, x) then
    return x:bigdec()
  else
    self.__index = self
    self["cljlib/type"] = self
    return setmetatable({val = bc.new(x)}, self)
  end
end
core.PI = BigDecimal:new(("3.1415926535897932384626433832795028841971693993751058209749445923" .. "0781640628620899862803482534211706798214808651328230664709384460" .. "9550582231725359408128481117450284102701938521105559644622948954" .. "9303819644288109756659334461284756482337867831652712019091456485" .. "6692346034861045432664821339360726024914127372458700660631558817" .. "4881520920962829254091715364367892590360011330530548820466521384" .. "1469519415116094330572703657595919530921861173819326117931051185" .. "4807446237996274956735188575272489122793818301194912983367336244" .. "0656643086021394946395224737190702179860943702770539217176293176" .. "7523846748184676694051320005681271452635608277857713427577896091" .. "7363717872146844090122495343014654958537105079227968925892354201" .. "9956112129021960864034418159813629774771309960518707211349999998" .. "3729780499510597317328160963185950244594553469083026425223082533" .. "4468503526193118817101000313783875288658753320838142061717766914" .. "7303598253490428755468731159562863882353787593751957781857780532" .. "1712268066130019278766111959092164201989380952572010654858632788"))
core.E = BigDecimal:new(("2.7182818284590452353602874713526624977572470936999595749669676277" .. "2407663035354759457138217852516642742746639193200305992181741359" .. "6629043572900334295260595630738132328627943490763233829880753195" .. "2510190115738341879307021540891499348841675092447614606680822648" .. "0016847741185374234544243710753907774499206955170276183860626133" .. "1384583000752044933826560297606737113200709328709127443747047230" .. "6969772093101416928368190255151086574637721112523897844250569536" .. "9677078544996996794686445490598793163688923009879312773617821542" .. "4999229576351482208269895193668033182528869398496465105820939239" .. "8294887933203625094431173012381970684161403970198376793206832823" .. "7646480429531180232878250981945581530175671736133206981125099618" .. "1881593041690351598888519345807273866738589422879228499892086805" .. "8257492796104841984443634632449684875602336248270419786232090021" .. "6099023530436994184914631409343173814364054625315209618369088870" .. "7016768396424378140592714563549061303107208510383750510115747704" .. "1718986106873969655212671546889570350354021234078498193343210681"))
local BigInteger
do
  local v_39_auto = BigDecimal:new(0)
  core.BigInteger = v_39_auto
  BigInteger = v_39_auto
end
BigInteger.new = function(...)
  local self, x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "BigInteger.new"))
    else
    end
  end
  if instance_3f(BigInteger, x) then
    return x
  elseif instance_3f(BigDecimal, x) then
    return BigInteger:new(x.val)
  elseif instance_3f(Ratio, x) then
    return BigInteger:new(x:bigdec())
  elseif "else" then
    self.__index = self
    self["cljlib/type"] = self
    return setmetatable({val = bc.trunc(x)}, self)
  else
    return nil
  end
end
local BigInt
do
  local v_39_auto = BigInteger:new(0)
  core.BigInt = v_39_auto
  BigInt = v_39_auto
end
BigInt.new = function(...)
  local self, x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "BigInt.new"))
    else
    end
  end
  if instance_3f(BigInt, x) then
    return x
  elseif (instance_3f(BigInteger, x) or instance_3f(BigDecimal, x)) then
    return BigInt:new(x.val)
  elseif instance_3f(Ratio, x) then
    return BigInt:new(x:bigdec())
  elseif "else" then
    self.__index = self
    self["cljlib/type"] = self
    return setmetatable({val = bc.trunc(x)}, self)
  else
    return nil
  end
end
local number_3f
do
  local number_3f0 = nil
  core["number?"] = function(...)
    local x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.number?"))
      else
      end
    end
    local pred___29_ = rawequal
    local expr___30_ = class(x)
    if pred___29_(BigDecimal, expr___30_) then
      return true
    else
      if pred___29_(BigInteger, expr___30_) then
        return true
      else
        if pred___29_(BigInt, expr___30_) then
          return true
        else
          if pred___29_(Ratio, expr___30_) then
            return true
          else
            if pred___29_("number", expr___30_) then
              return true
            else
              return false
            end
          end
        end
      end
    end
  end
  number_3f0 = core["number?"]
  number_3f = core["number?"]
end
local int_3f
do
  local int_3f0 = nil
  core["int?"] = function(...)
    local x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.int?"))
      else
      end
    end
    return (number_3f(x) and not instance_3f(Ratio, x) and not rawequal(BigDecimal, class(x)) and (instance_3f(BigInteger, x) or (x == m_2ffloor(x))))
  end
  int_3f0 = core["int?"]
  int_3f = core["int?"]
end
local float_3f
do
  local float_3f0 = nil
  core["float?"] = function(...)
    local n = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.float?"))
      else
      end
    end
    return (core["number?"](n) and not core["int?"](n))
  end
  float_3f0 = core["float?"]
  float_3f = core["float?"]
end
BigDecimal.__add = function(self, other)
  local self_2_auto = self
  local other_3_auto = other
  if not instance_3f(BigDecimal, self_2_auto) then
    if float_3f(self_2_auto) then
      return BigDecimal:new((bc.new(self_2_auto) + other_3_auto.val))
    else
      return class(other_3_auto):new((bc.new(self_2_auto) + other_3_auto.val))
    end
  elseif instance_3f(Ratio, other_3_auto) then
    if instance_3f(BigInteger, self_2_auto) then
      return (Ratio:unreduced(self_2_auto, 1) + other_3_auto)
    else
      return (self_2_auto + other_3_auto:bigdec())
    end
  elseif ((instance_3f(BigInteger, self_2_auto) and instance_3f(BigInteger, other_3_auto)) or (instance_3f(BigDecimal, self_2_auto) and instance_3f(BigInteger, other_3_auto))) then
    return class(self_2_auto):new((self_2_auto.val + other_3_auto.val))
  elseif ((instance_3f(BigInteger, self_2_auto) and core["int?"](other_3_auto)) or (instance_3f(BigDecimal, self_2_auto) and core["int?"](other_3_auto))) then
    return class(self_2_auto):new((self_2_auto.val + other_3_auto))
  elseif (instance_3f(BigInteger, self_2_auto) and instance_3f(BigDecimal, other_3_auto)) then
    return class(other_3_auto):new((self_2_auto.val + other_3_auto.val))
  elseif instance_3f(BigDecimal, other_3_auto) then
    return class(self_2_auto):new((self_2_auto.val + other_3_auto.val))
  elseif float_3f(other_3_auto) then
    return BigDecimal:new((self_2_auto.val + other_3_auto))
  else
    return class(self_2_auto):new((self_2_auto.val + other_3_auto))
  end
end
BigDecimal.__sub = function(self, other)
  local self_2_auto = self
  local other_3_auto = other
  if not instance_3f(BigDecimal, self_2_auto) then
    if float_3f(self_2_auto) then
      return BigDecimal:new((bc.new(self_2_auto) - other_3_auto.val))
    else
      return class(other_3_auto):new((bc.new(self_2_auto) - other_3_auto.val))
    end
  elseif instance_3f(Ratio, other_3_auto) then
    if instance_3f(BigInteger, self_2_auto) then
      return (Ratio:unreduced(self_2_auto, 1) - other_3_auto)
    else
      return (self_2_auto - other_3_auto:bigdec())
    end
  elseif ((instance_3f(BigInteger, self_2_auto) and instance_3f(BigInteger, other_3_auto)) or (instance_3f(BigDecimal, self_2_auto) and instance_3f(BigInteger, other_3_auto))) then
    return class(self_2_auto):new((self_2_auto.val - other_3_auto.val))
  elseif ((instance_3f(BigInteger, self_2_auto) and core["int?"](other_3_auto)) or (instance_3f(BigDecimal, self_2_auto) and core["int?"](other_3_auto))) then
    return class(self_2_auto):new((self_2_auto.val - other_3_auto))
  elseif (instance_3f(BigInteger, self_2_auto) and instance_3f(BigDecimal, other_3_auto)) then
    return class(other_3_auto):new((self_2_auto.val - other_3_auto.val))
  elseif instance_3f(BigDecimal, other_3_auto) then
    return class(self_2_auto):new((self_2_auto.val - other_3_auto.val))
  elseif float_3f(other_3_auto) then
    return BigDecimal:new((self_2_auto.val - other_3_auto))
  else
    return class(self_2_auto):new((self_2_auto.val - other_3_auto))
  end
end
BigDecimal.__mul = function(self, other)
  local self_2_auto = self
  local other_3_auto = other
  if not instance_3f(BigDecimal, self_2_auto) then
    if float_3f(self_2_auto) then
      return BigDecimal:new((bc.new(self_2_auto) * other_3_auto.val))
    else
      return class(other_3_auto):new((bc.new(self_2_auto) * other_3_auto.val))
    end
  elseif instance_3f(Ratio, other_3_auto) then
    if instance_3f(BigInteger, self_2_auto) then
      return (Ratio:unreduced(self_2_auto, 1) * other_3_auto)
    else
      return (self_2_auto * other_3_auto:bigdec())
    end
  elseif ((instance_3f(BigInteger, self_2_auto) and instance_3f(BigInteger, other_3_auto)) or (instance_3f(BigDecimal, self_2_auto) and instance_3f(BigInteger, other_3_auto))) then
    return class(self_2_auto):new((self_2_auto.val * other_3_auto.val))
  elseif ((instance_3f(BigInteger, self_2_auto) and core["int?"](other_3_auto)) or (instance_3f(BigDecimal, self_2_auto) and core["int?"](other_3_auto))) then
    return class(self_2_auto):new((self_2_auto.val * other_3_auto))
  elseif (instance_3f(BigInteger, self_2_auto) and instance_3f(BigDecimal, other_3_auto)) then
    return class(other_3_auto):new((self_2_auto.val * other_3_auto.val))
  elseif instance_3f(BigDecimal, other_3_auto) then
    return class(self_2_auto):new((self_2_auto.val * other_3_auto.val))
  elseif float_3f(other_3_auto) then
    return BigDecimal:new((self_2_auto.val * other_3_auto))
  else
    return class(self_2_auto):new((self_2_auto.val * other_3_auto))
  end
end
BigDecimal.__mod = function(self, other)
  local self_2_auto = self
  local other_3_auto = other
  if not instance_3f(BigDecimal, self_2_auto) then
    if float_3f(self_2_auto) then
      return BigDecimal:new((bc.new(self_2_auto) % other_3_auto.val))
    else
      return class(other_3_auto):new((bc.new(self_2_auto) % other_3_auto.val))
    end
  elseif instance_3f(Ratio, other_3_auto) then
    if instance_3f(BigInteger, self_2_auto) then
      return (Ratio:unreduced(self_2_auto, 1) % other_3_auto)
    else
      return (self_2_auto % other_3_auto:bigdec())
    end
  elseif ((instance_3f(BigInteger, self_2_auto) and instance_3f(BigInteger, other_3_auto)) or (instance_3f(BigDecimal, self_2_auto) and instance_3f(BigInteger, other_3_auto))) then
    return class(self_2_auto):new((self_2_auto.val % other_3_auto.val))
  elseif ((instance_3f(BigInteger, self_2_auto) and core["int?"](other_3_auto)) or (instance_3f(BigDecimal, self_2_auto) and core["int?"](other_3_auto))) then
    return class(self_2_auto):new((self_2_auto.val % other_3_auto))
  elseif (instance_3f(BigInteger, self_2_auto) and instance_3f(BigDecimal, other_3_auto)) then
    return class(other_3_auto):new((self_2_auto.val % other_3_auto.val))
  elseif instance_3f(BigDecimal, other_3_auto) then
    return class(self_2_auto):new((self_2_auto.val % other_3_auto.val))
  elseif float_3f(other_3_auto) then
    return BigDecimal:new((self_2_auto.val % other_3_auto))
  else
    return class(self_2_auto):new((self_2_auto.val % other_3_auto))
  end
end
BigDecimal.__unm = function(self)
  return class(self):new(( - self.val))
end
BigDecimal.__div = function(self, other)
  if not instance_3f(BigDecimal, self) then
    if float_3f(self) then
      return BigDecimal:new((bc.new(self) / other.val))
    elseif instance_3f(BigInteger, other) then
      return Ratio:new(self, other)
    else
      return BigDecimal:new((bc.new(self) / other.val))
    end
  elseif instance_3f(Ratio, other) then
    if instance_3f(BigInteger, self) then
      return (Ratio:unreduced(self, 1) / other)
    else
      return (self / other:bigdec())
    end
  elseif (instance_3f(BigInteger, self) and core["int?"](other)) then
    return Ratio:new(self, other)
  elseif (instance_3f(BigDecimal, self) and instance_3f(BigInteger, other)) then
    return class(self):new((self.val / other.val))
  elseif (instance_3f(BigDecimal, self) and core["int?"](other)) then
    return class(self):new((self.val / other))
  elseif (instance_3f(BigInteger, self) and instance_3f(BigDecimal, other)) then
    return class(other):new((self.val / other.val))
  elseif instance_3f(BigDecimal, other) then
    return class(self):new((self.val / other.val))
  elseif float_3f(other) then
    return BigDecimal:new((self.val / other))
  else
    return class(self):new((self.val / other))
  end
end
BigDecimal.__idiv = function(self, other)
  return BigInteger:new((self / other))
end
BigDecimal.__pow = function(self, other)
  if not instance_3f(BigDecimal, self) then
    if float_3f(self) then
      return (self ^ bc.tonumber(other.val))
    else
      return class(other):new((bc.new(self) ^ other.val))
    end
  elseif instance_3f(Ratio, other) then
    if instance_3f(BigInteger, self) then
      return (Ratio:unreduced(self, 1) ^ other)
    else
      return (bc.tonumber(self.val) ^ other:float())
    end
  elseif ((instance_3f(BigInteger, self) and instance_3f(BigInteger, other)) or (instance_3f(BigDecimal, self) and instance_3f(BigInteger, other))) then
    return class(self):new((self.val ^ other.val))
  elseif (instance_3f(BigInteger, self) and instance_3f(BigDecimal, other)) then
    return (bc.tonumber(self.val) ^ bc.tonumber(other.val))
  else
    return (bc.tonumber(self.val) ^ other)
  end
end
BigDecimal.__eq = function(self, other)
  if not instance_3f(BigDecimal, self) then
    return (bc.new(self) == other.val)
  elseif instance_3f(Ratio, other) then
    if instance_3f(BigInteger, self) then
      return (Ratio:unreduced(self, 1) == other)
    else
      return (self == other:bigdec())
    end
  elseif instance_3f(BigDecimal, other) then
    return (self.val == other.val)
  else
    return (self.val == bc.new(other))
  end
end
BigDecimal.__le = function(self, other)
  if not instance_3f(BigDecimal, self) then
    return (bc.new(self) <= other.val)
  elseif instance_3f(Ratio, other) then
    if instance_3f(BigInteger, self) then
      return (Ratio:unreduced(self, 1) <= other)
    else
      return (self <= other:bigdec())
    end
  elseif instance_3f(BigDecimal, other) then
    return (self.val <= other.val)
  else
    return (self.val <= bc.new(other))
  end
end
BigDecimal.__lt = function(self, other)
  if not instance_3f(BigDecimal, self) then
    return (bc.new(self) < other.val)
  elseif instance_3f(Ratio, other) then
    if instance_3f(BigInteger, self) then
      return (Ratio:unreduced(self, 1) < other)
    else
      return (self < other:bigdec())
    end
  elseif instance_3f(BigDecimal, other) then
    return (self.val < other.val)
  else
    return (self.val < bc.new(other))
  end
end
BigDecimal.__concat = function(self, other)
  if not instance_3f(BigDecimal, self) then
    return (self .. tostring(other))
  elseif instance_3f(BigDecimal, other) then
    return (tostring(self) .. tostring(other))
  else
    return (tostring(self) .. other)
  end
end
BigDecimal.__tostring = function(_63_)
  local n = _63_.val
  local self = _63_
  local s = tostring(n)
  local suffix
  if instance_3f(BigInteger, self) then
    suffix = "N"
  else
    suffix = "M"
  end
  local dot = s:find(".", 1, true)
  if (nil ~= dot) then
    if s:find("%.[^0]+") then
      return (s:gsub("0+$", "") .. suffix)
    else
      return (s:sub(1, (dot - 1)) .. suffix)
    end
  else
    return (s .. suffix)
  end
end
BigInteger.__add = BigDecimal.__add
BigInteger.__div = BigDecimal.__div
BigInteger.__idiv = BigDecimal.__idiv
BigInteger.__eq = BigDecimal.__eq
BigInteger.__le = BigDecimal.__le
BigInteger.__lt = BigDecimal.__lt
BigInteger.__mod = BigDecimal.__mod
BigInteger.__mul = BigDecimal.__mul
BigInteger.__pow = BigDecimal.__pow
BigInteger.__sub = BigDecimal.__sub
BigInteger.__unm = BigDecimal.__unm
BigInteger.__concat = BigDecimal.__concat
BigInteger.__tostring = BigDecimal.__tostring
local function super(c)
  return getmetatable(c)
end
local class_3f
do
  local class_3f0 = nil
  core["class?"] = function(...)
    local x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.class?"))
      else
      end
    end
    return (("table" == type(x)) and (rawget(x, "cljlib/class") or false))
  end
  class_3f0 = core["class?"]
  class_3f = core["class?"]
end
core.supers = function(...)
  local class0 = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.supers"))
    else
    end
  end
  if class_3f(class0) then
    local sups = {}
    local class1 = class0
    while super(class1) do
      local c = super(class1)
      table.insert(sups, c)
      class1 = c
    end
    return core.into(core["hash-set"](), sups)
  else
    return error("expected a class as the fist argument")
  end
end
BigInt.__add = BigDecimal.__add
BigInt.__div = BigDecimal.__div
BigInt.__idiv = BigDecimal.__idiv
BigInt.__eq = BigDecimal.__eq
BigInt.__le = BigDecimal.__le
BigInt.__lt = BigDecimal.__lt
BigInt.__mod = BigDecimal.__mod
BigInt.__mul = BigDecimal.__mul
BigInt.__pow = BigDecimal.__pow
BigInt.__sub = BigDecimal.__sub
BigInt.__unm = BigDecimal.__unm
BigInt.__concat = BigDecimal.__concat
BigInt.__tostring = BigDecimal.__tostring
Ratio.__add = function(self, other)
  if (not instance_3f(Ratio, self) and core["int?"](self)) then
    return Ratio:unreduced(self, 1):__add(other)
  elseif (not instance_3f(Ratio, self) and float_3f(self)) then
    return (self + other:float())
  elseif instance_3f(BigInteger, other) then
    return (self + Ratio:unreduced(other, 1))
  elseif instance_3f(BigDecimal, other) then
    return (self:bigdec() + other)
  elseif instance_3f(Ratio, other) then
    local numerator = ((self.numerator * other.denominator) + (other.numerator * self.denominator))
    local denominator = (self.denominator * other.denominator)
    return Ratio:new(numerator, denominator)
  elseif float_3f(other) then
    return (self:float() + other)
  else
    return self:__add(Ratio:unreduced(other, 1))
  end
end
Ratio.__mul = function(self, other)
  if (not instance_3f(Ratio, self) and core["int?"](self)) then
    return Ratio:unreduced(self, 1):__mul(other)
  elseif (not instance_3f(Ratio, self) and float_3f(self)) then
    return (self * other:float())
  elseif instance_3f(BigInteger, other) then
    return (self * Ratio:unreduced(other, 1))
  elseif instance_3f(BigDecimal, other) then
    return (self:bigdec() * other)
  elseif instance_3f(Ratio, other) then
    local numerator = (self.numerator * other.numerator)
    local denominator = (self.denominator * other.denominator)
    return Ratio:new(numerator, denominator)
  elseif float_3f(other) then
    return (self:float() * other)
  else
    return self:__mul(Ratio:unreduced(other, 1))
  end
end
Ratio.__div = function(self, other)
  if (not instance_3f(Ratio, self) and core["int?"](self)) then
    return Ratio:unreduced(self, 1):__div(other)
  elseif (not instance_3f(Ratio, self) and float_3f(self)) then
    return (self / other:float())
  elseif instance_3f(BigInteger, other) then
    return (self / Ratio:unreduced(other, 1))
  elseif instance_3f(BigDecimal, other) then
    return (self:bigdec() / other)
  elseif instance_3f(Ratio, other) then
    if (other.numerator == bc_zero) then
      error("Cannot divide by zero")
    else
    end
    local numerator = (self.numerator * other.denominator)
    local denominator = (self.denominator * other.numerator)
    return Ratio:new(numerator, denominator)
  elseif float_3f(other) then
    return (self:float() / other)
  else
    return self:__div(Ratio:unreduced(other, 1))
  end
end
Ratio.__idiv = function(self, other)
  return BigInteger:new((self / other))
end
Ratio.__eq = function(self, other)
  if not instance_3f(Ratio, self) then
    return Ratio:unreduced(self, 1):__eq(other)
  elseif instance_3f(BigInteger, other) then
    return (self == Ratio:unreduced(other, 1))
  elseif instance_3f(BigDecimal, other) then
    return (self:bigdec() == other)
  elseif instance_3f(Ratio, other) then
    return ((self.numerator * other.denominator) == (other.numerator * self.denominator))
  else
    return self:__eq(Ratio:unreduced(other, 1))
  end
end
Ratio.__lt = function(self, other)
  if not instance_3f(Ratio, self) then
    return Ratio:unreduced(self, 1):__lt(other)
  elseif instance_3f(BigInteger, other) then
    return (self < Ratio:unreduced(other, 1))
  elseif instance_3f(BigDecimal, other) then
    return (self:bigdec() < other)
  elseif instance_3f(Ratio, other) then
    return ((self.numerator * other.denominator) < (other.numerator * self.denominator))
  else
    return self:__lt(Ratio:unreduced(other, 1))
  end
end
Ratio.__le = function(self, other)
  if not instance_3f(Ratio, self) then
    return Ratio:unreduced(self, 1):__le(other)
  elseif instance_3f(BigInteger, other) then
    return (self <= Ratio:unreduced(other, 1))
  elseif instance_3f(BigDecimal, other) then
    return (self:bigdec() <= other)
  elseif instance_3f(Ratio, other) then
    return ((self.numerator * other.denominator) <= (other.numerator * self.denominator))
  else
    return self:__le(Ratio:unreduced(other, 1))
  end
end
Ratio.__mod = function(self, other)
  if (not instance_3f(Ratio, self) and core["int?"](self)) then
    return Ratio:unreduced(self, 1):__mod(other)
  elseif (not instance_3f(Ratio, self) and float_3f(self)) then
    return (self % other:float())
  elseif instance_3f(BigInteger, other) then
    return (self % Ratio:unreduced(other, 1))
  elseif instance_3f(BigDecimal, other) then
    return (self:bigdec() % other)
  elseif instance_3f(Ratio, other) then
    local common_denominator = (self.denominator.val * other.denominator.val)
    local numerator1 = (self.numerator.val * other.denominator.val)
    local numerator2 = (other.numerator.val * self.denominator.val)
    local quotient = bc.trunc((numerator1 / numerator2))
    local remainder = (numerator1 - (quotient * numerator2))
    return Ratio:new(remainder, common_denominator)
  elseif float_3f(other) then
    return (self:float() % other)
  else
    return self:__mod(Ratio:unreduced(other, 1))
  end
end
Ratio.__pow = function(self, exp)
  if (not instance_3f(Ratio, self) and core["int?"](self)) then
    return Ratio:unreduced(self, 1):__pow(exp)
  elseif (not instance_3f(Ratio, self) and float_3f(self)) then
    return (self ^ exp:float())
  elseif instance_3f(Ratio, exp) then
    return (self ^ exp:float())
  elseif instance_3f(BigDecimal, exp) then
    return (self:float() ^ bc.tonumber(exp.val))
  else
    return (self:float() ^ exp)
  end
end
Ratio.__sub = function(self, other)
  if (not instance_3f(Ratio, self) and core["int?"](self)) then
    return Ratio:unreduced(self, 1):__sub(other)
  elseif (not instance_3f(Ratio, self) and float_3f(self)) then
    return (self - other:float())
  elseif instance_3f(BigInteger, other) then
    return (self - Ratio:unreduced(other, 1))
  elseif instance_3f(BigDecimal, other) then
    return (self:bigdec() - other)
  elseif instance_3f(Ratio, other) then
    local numerator = ((self.numerator * other.denominator) - (other.numerator * self.denominator))
    local denominator = (self.denominator * other.denominator)
    return Ratio:new(numerator, denominator)
  elseif float_3f(other) then
    return (self:float() - other)
  else
    return self:__sub(Ratio:unreduced(other, 1))
  end
end
Ratio.__unm = function(self)
  return Ratio:new(( - self.numerator), self.denominator)
end
Ratio.__tostring = function(self)
  return string.format("%s/%s", tostring(self.numerator.val), tostring(self.denominator.val))
end
Ratio.__concat = function(self, other)
  if not instance_3f(Ratio, self) then
    return (self .. tostring(other))
  elseif instance_3f(Ratio, other) then
    return (tostring(self) .. tostring(other))
  else
    return (tostring(self) .. other)
  end
end
local function gcd(a0, b)
  if (b ~= bc_zero) then
    return gcd(b, (a0 % b))
  else
    return a0
  end
end
Ratio.reduce = function(self)
  local divisor = gcd(bc.abs(self.numerator.val), bc.abs(self.denominator.val))
  do
    self["numerator"] = BigInteger:new((self.numerator.val / divisor))
    self["denominator"] = BigInteger:new((self.denominator.val / divisor))
  end
  if (self.denominator.val < 0) then
    self["numerator"] = ( - self.numerator)
    self["denominator"] = ( - self.denominator)
  else
  end
  if (self.numerator.val == self.denominator.val) then
    return 1
  elseif ((self.denominator.val == bc_one) or (self.denominator.val == bc_minus_one)) then
    return self.numerator
  else
    return self
  end
end
Ratio.bigdec = function(self)
  return BigDecimal:new((self.numerator.val / self.denominator.val))
end
Ratio.float = function(self)
  return bc.tonumber((self.numerator.val / self.denominator.val))
end
Ratio.new = function(self, numerator, denominator)
  self.__index = self
  self["cljlib/type"] = self
  return setmetatable({numerator = BigInteger:new(numerator), denominator = BigInteger:new(denominator)}, self):reduce()
end
Ratio.unreduced = function(self, numerator, denominator)
  self.__index = self
  self["cljlib/type"] = self
  return setmetatable({numerator = BigInteger:new(numerator), denominator = BigInteger:new(denominator)}, self)
end
local function floor(x)
  if instance_3f(BigDecimal, x) then
    return BigInteger:new(x)
  elseif instance_3f(Ratio, x) then
    return BigInteger:new(x:bigdec())
  else
    return m_2ffloor(x)
  end
end
core["decimal?"] = function(...)
  local n = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.decimal?"))
    else
    end
  end
  return rawequal(BigDecimal, class(n))
end
core.denominator = function(...)
  local r = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.denominator"))
    else
    end
  end
  assert(instance_3f(Ratio, r), "expected a Ratio")
  return r.denominator
end
core.numerator = function(...)
  local r = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.numerator"))
    else
    end
  end
  assert(instance_3f(Ratio, r), "expected a Ratio")
  return r.numerator
end
core["ratio?"] = function(...)
  local n = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.ratio?"))
    else
    end
  end
  return rawequal(Ratio, class(n))
end
core["rational?"] = function(...)
  local n = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.rational?"))
    else
    end
  end
  assert(core["number?"](n), "Expected a number")
  return (core["int?"](n) or core["ratio?"](n) or core["decimal?"](n))
end
core.rationalize = function(...)
  local num = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.rationalize"))
    else
    end
  end
  assert(core["number?"](num), "expected a number")
  local num0
  if instance_3f(BigDecimal, num) then
    num0 = num.val
  else
    num0 = bc.new(num)
  end
  local tolerance = bc.new("1e-1024")
  local numerator
  if instance_3f(BigDecimal, num0) then
    numerator = num0.val
  else
    numerator = bc.new(num0)
  end
  local denominator = bc.new(1)
  while (bc.abs((num0 - (numerator / denominator))) > tolerance) do
    numerator = (num0 * denominator)
    denominator = (denominator + 1)
  end
  local divisor = gcd(bc.abs(numerator), denominator)
  local numerator0 = (numerator / divisor)
  local denominator0 = (denominator / divisor)
  return Ratio:new(numerator0, denominator0)
end
core.float = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.float"))
    else
    end
  end
  if instance_3f(Ratio, x) then
    return x:float()
  elseif instance_3f(BigDecimal, x) then
    return bc.tonumber(x.val)
  elseif core["number?"](x) then
    return x
  else
    return nil
  end
end
core.double = core.float
local function limited_cast(x, min_limit, max_limit, kind)
  if ((min_limit <= x) and (x <= max_limit)) then
    return m_2ffloor(core.float(x))
  else
    return error(("Value out of range for " .. kind .. ": " .. x))
  end
end
local function mod_cast(x, min_limit, max_limit)
  if ((min_limit <= x) and (x <= max_limit)) then
    return m_2ffloor(core.float(x))
  else
    local range = ((max_limit - min_limit) + 1)
    local adjust = (x - min_limit)
    local trunc = (((adjust % range) + range) % range)
    return (trunc + min_limit)
  end
end
core.long = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.long"))
    else
    end
  end
  return limited_cast(x, mininteger, maxinteger, "long")
end
core["unchecked-long"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.unchecked-long"))
    else
    end
  end
  return mod_cast(x, mininteger, maxinteger)
end
core.short = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.short"))
    else
    end
  end
  return limited_cast(x, -32768, 32767, "short")
end
core["unchecked-short"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.unchecked-short"))
    else
    end
  end
  return mod_cast(x, -32768, 32767)
end
core.char = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.char"))
    else
    end
  end
  return limited_cast(x, 0, 65535, "char")
end
core["unchecked-char"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.unchecked-char"))
    else
    end
  end
  return mod_cast(x, 0, 65535)
end
core.byte = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.byte"))
    else
    end
  end
  return limited_cast(x, -128, 127, "byte")
end
core["unchecked-byte"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.unchecked-byte"))
    else
    end
  end
  return mod_cast(x, -128, 127)
end
core.int = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.int"))
    else
    end
  end
  limited_cast(x, -2147483648, 2147483647, "int")
  return x
end
core["unchecked-int"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.unchecked-int"))
    else
    end
  end
  mod_cast(x, -2147483648, 2147483647)
  return x
end
core.num = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.num"))
    else
    end
  end
  if core["number?"](x) then
    return x
  else
    return error(("can't cast " .. class_name(x) .. " to a number"))
  end
end
local function unpack_2a(x, ...)
  if core["seq?"](x) then
    return lazy.unpack(x)
  else
    return itable.unpack(x, ...)
  end
end
local function pack_2a(...)
  local tmp_9_ = {...}
  tmp_9_["n"] = select("#", ...)
  return tmp_9_
end
local function pairs_2a(t)
  local case_110_ = getmetatable(t)
  if ((_G.type(case_110_) == "table") and (nil ~= case_110_.__pairs)) then
    local p = case_110_.__pairs
    return p(t)
  else
    local _ = case_110_
    return pairs(t)
  end
end
local function ipairs_2a(t)
  local case_112_ = getmetatable(t)
  if ((_G.type(case_112_) == "table") and (nil ~= case_112_.__ipairs)) then
    local i = case_112_.__ipairs
    return i(t)
  else
    local _ = case_112_
    return ipairs(t)
  end
end
local function length_2a(t)
  local case_114_ = getmetatable(t)
  if ((_G.type(case_114_) == "table") and (nil ~= case_114_.__len)) then
    local l = case_114_.__len
    return l(t)
  else
    local _ = case_114_
    return #t
  end
end
local apply
do
  local apply0 = nil
  core.apply = function(...)
    local case_117_ = select("#", ...)
    if (case_117_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "core.apply"))
    elseif (case_117_ == 1) then
      return error(("Wrong number of args (%s) passed to %s"):format(1, "core.apply"))
    elseif (case_117_ == 2) then
      local f, args = ...
      return f(unpack_2a(args))
    elseif (case_117_ == 3) then
      local f, a0, args = ...
      return f(a0, unpack_2a(args))
    elseif (case_117_ == 4) then
      local f, a0, b, args = ...
      return f(a0, b, unpack_2a(args))
    elseif (case_117_ == 5) then
      local f, a0, b, c, args = ...
      return f(a0, b, c, unpack_2a(args))
    else
      local _ = case_117_
      local _let_118_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_51_auto = _let_118_.list
      local f, a0, b, c, d = ...
      local args = list_51_auto(select(6, ...))
      local flat_args = {}
      local len = (length_2a(args) - 1)
      for i = 1, len do
        flat_args[i] = args[i]
      end
      for i, a1 in pairs_2a(args[(len + 1)]) do
        flat_args[(i + len)] = a1
      end
      return f(a0, b, c, d, unpack_2a(flat_args))
    end
  end
  apply0 = core.apply
  apply = core.apply
end
local function add_overflow_3f(a0, b)
  return (instance_3f(BigDecimal, a0) or instance_3f(BigDecimal, b) or ((b < 0) and (a0 < (mininteger - b))) or ((b > 0) and (a0 > (maxinteger - b))))
end
local function mul_overflow_3f(a0, b)
  if (instance_3f(BigDecimal, a0) or instance_3f(BigDecimal, b)) then
    return true
  elseif ((a0 == 0) or (b == 0)) then
    return false
  elseif (((a0 > 0) and (b > 0) and (a0 > (maxinteger / b))) or ((a0 > 0) and (b < 0) and (b < (mininteger / a0))) or ((a0 < 0) and (b > 0) and (a0 < (mininteger / b))) or ((a0 < 0) and (b < 0) and (a0 < (maxinteger / b)))) then
    return true
  else
    return nil
  end
end
local add
do
  local add0 = nil
  core.add = function(...)
    local case_121_ = select("#", ...)
    if (case_121_ == 0) then
      return 0
    elseif (case_121_ == 1) then
      local a0 = ...
      return a0
    elseif (case_121_ == 2) then
      local a0, b = ...
      if add_overflow_3f(a0, b) then
        return error("Arithmetic overflow")
      else
        return (a0 + b)
      end
    else
      local _ = case_121_
      local _let_123_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_51_auto = _let_123_.list
      local a0, b = ...
      local rest = list_51_auto(select(3, ...))
      return apply(add0, add0(a0, b), rest)
    end
  end
  add0 = core.add
  add = core.add
end
core["+"] = add
local add_2a
do
  local add_2a0 = nil
  core["add*"] = function(...)
    local case_125_ = select("#", ...)
    if (case_125_ == 0) then
      return 0
    elseif (case_125_ == 1) then
      local a0 = ...
      return a0
    elseif (case_125_ == 2) then
      local a0, b = ...
      if add_overflow_3f(a0, b) then
        if (float_3f(a0) or float_3f(b)) then
          return (BigDecimal:new(a0) + b)
        else
          return (BigInteger:new(a0) + b)
        end
      else
        return (a0 + b)
      end
    else
      local _ = case_125_
      local _let_128_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_51_auto = _let_128_.list
      local a0, b = ...
      local rest = list_51_auto(select(3, ...))
      return apply(add_2a0, add_2a0(a0, b), rest)
    end
  end
  add_2a0 = core["add*"]
  add_2a = core["add*"]
end
local sub
do
  local sub0 = nil
  core.sub = function(...)
    local case_130_ = select("#", ...)
    if (case_130_ == 0) then
      return 0
    elseif (case_130_ == 1) then
      local a0 = ...
      return ( - a0)
    elseif (case_130_ == 2) then
      local a0, b = ...
      if add_overflow_3f(a0, ( - b)) then
        return error("Arithmetic overflow")
      else
        return (a0 - b)
      end
    else
      local _ = case_130_
      local _let_132_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_51_auto = _let_132_.list
      local a0, b = ...
      local rest = list_51_auto(select(3, ...))
      return apply(sub0, sub0(a0, b), rest)
    end
  end
  sub0 = core.sub
  sub = core.sub
end
core["-"] = sub
local sub_2a
do
  local sub_2a0 = nil
  core["sub*"] = function(...)
    local case_134_ = select("#", ...)
    if (case_134_ == 0) then
      return 0
    elseif (case_134_ == 1) then
      local a0 = ...
      return ( - a0)
    elseif (case_134_ == 2) then
      local a0, b = ...
      if add_overflow_3f(a0, ( - b)) then
        if (float_3f(a0) or float_3f(b)) then
          return (BigDecimal:new(a0) - b)
        else
          return (BigInteger:new(a0) - b)
        end
      else
        return (a0 - b)
      end
    else
      local _ = case_134_
      local _let_137_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_51_auto = _let_137_.list
      local a0, b = ...
      local rest = list_51_auto(select(3, ...))
      return apply(sub_2a0, sub_2a0(a0, b), rest)
    end
  end
  sub_2a0 = core["sub*"]
  sub_2a = core["sub*"]
end
local mul
do
  local mul0 = nil
  core.mul = function(...)
    local case_139_ = select("#", ...)
    if (case_139_ == 0) then
      return 1
    elseif (case_139_ == 1) then
      local a0 = ...
      return a0
    elseif (case_139_ == 2) then
      local a0, b = ...
      if mul_overflow_3f(a0, b) then
        return error("Arithmetic overflow")
      else
        return (a0 * b)
      end
    else
      local _ = case_139_
      local _let_141_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_51_auto = _let_141_.list
      local a0, b = ...
      local rest = list_51_auto(select(3, ...))
      return apply(mul0, mul0(a0, b), rest)
    end
  end
  mul0 = core.mul
  mul = core.mul
end
core["*"] = mul
local mul_2a
do
  local mul_2a0 = nil
  core["mul*"] = function(...)
    local case_143_ = select("#", ...)
    if (case_143_ == 0) then
      return 1
    elseif (case_143_ == 1) then
      local a0 = ...
      return a0
    elseif (case_143_ == 2) then
      local a0, b = ...
      if mul_overflow_3f(a0, b) then
        if (float_3f(a0) or float_3f(b)) then
          return (BigDecimal:new(a0) * b)
        else
          return (BigInteger:new(a0) * b)
        end
      else
        return (a0 * b)
      end
    else
      local _ = case_143_
      local _let_146_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_51_auto = _let_146_.list
      local a0, b = ...
      local rest = list_51_auto(select(3, ...))
      return apply(mul_2a0, mul_2a0(a0, b), rest)
    end
  end
  mul_2a0 = core["mul*"]
  mul_2a = core["mul*"]
end
local div
do
  local div0 = nil
  core.div = function(...)
    local case_148_ = select("#", ...)
    if (case_148_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "core.div"))
    elseif (case_148_ == 1) then
      local a0 = ...
      if core["int?"](a0) then
        return Ratio:new(1, a0)
      else
        return (1 / a0)
      end
    elseif (case_148_ == 2) then
      local a0, b = ...
      if (core["int?"](a0) and core["int?"](b)) then
        return Ratio:new(a0, b)
      elseif (instance_3f(Ratio, a0) and not core["int?"](b)) then
        return (a0:bigdec() / b)
      elseif (instance_3f(Ratio, b) and not core["int?"](a0)) then
        return (a0 / b:bigdec())
      elseif "else" then
        return (a0 / b)
      else
        return nil
      end
    else
      local _ = case_148_
      local _let_151_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_51_auto = _let_151_.list
      local a0, b = ...
      local rest = list_51_auto(select(3, ...))
      return apply(div0, div0(a0, b), rest)
    end
  end
  div0 = core.div
  div = core.div
end
core["/"] = core.div
core.rem = function(...)
  local numerator, denominator = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.rem"))
    else
    end
  end
  assert((0 ~= denominator), "division by zero")
  return (numerator % denominator)
end
core.quot = function(...)
  local numerator, denominator = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.quot"))
    else
    end
  end
  assert((0 ~= denominator), "division by zero")
  return m_2ffloor((numerator / denominator))
end
core.mod = function(...)
  local num, div0 = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.mod"))
    else
    end
  end
  assert((0 ~= div0), "division by zero")
  return m_2ffloor((num / div0))
end
local _3d_3d
do
  local _3d_3d0 = nil
  core["=="] = function(...)
    local case_156_ = select("#", ...)
    if (case_156_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "core.=="))
    elseif (case_156_ == 1) then
      local _ = ...
      return true
    elseif (case_156_ == 2) then
      local a0, b = ...
      assert((("number" == type(a0)) and ("number" == type(b))), "all operands must be numbers")
      return rawequal(a0, b)
    else
      local _ = case_156_
      local _let_157_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_51_auto = _let_157_.list
      local a0, b = ...
      local _let_158_ = list_51_auto(select(3, ...))
      local c = _let_158_[1]
      local d = _let_158_[2]
      local more = (function (t, k) return ((getmetatable(t) or {}).__fennelrest or function (t, k) return {(table.unpack or unpack)(t, k)} end)(t, k) end)(_let_158_, 3)
      if _3d_3d0(a0, b) then
        if d then
          return apply(_3d_3d0, b, c, d, more)
        else
          return _3d_3d0(b, c)
        end
      else
        return false
      end
    end
  end
  _3d_3d0 = core["=="]
  _3d_3d = core["=="]
end
local le
do
  local le0 = nil
  core.le = function(...)
    local case_162_ = select("#", ...)
    if (case_162_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "core.le"))
    elseif (case_162_ == 1) then
      local _ = ...
      return true
    elseif (case_162_ == 2) then
      local a0, b = ...
      return (a0 <= b)
    else
      local _ = case_162_
      local _let_163_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_51_auto = _let_163_.list
      local a0, b = ...
      local _let_164_ = list_51_auto(select(3, ...))
      local c = _let_164_[1]
      local d = _let_164_[2]
      local more = (function (t, k) return ((getmetatable(t) or {}).__fennelrest or function (t, k) return {(table.unpack or unpack)(t, k)} end)(t, k) end)(_let_164_, 3)
      if (a0 <= b) then
        if d then
          return apply(le0, b, c, d, more)
        else
          return (b <= c)
        end
      else
        return false
      end
    end
  end
  le0 = core.le
  le = core.le
end
core["<="] = le
local lt
do
  local lt0 = nil
  core.lt = function(...)
    local case_168_ = select("#", ...)
    if (case_168_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "core.lt"))
    elseif (case_168_ == 1) then
      local _ = ...
      return true
    elseif (case_168_ == 2) then
      local a0, b = ...
      return (a0 < b)
    else
      local _ = case_168_
      local _let_169_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_51_auto = _let_169_.list
      local a0, b = ...
      local _let_170_ = list_51_auto(select(3, ...))
      local c = _let_170_[1]
      local d = _let_170_[2]
      local more = (function (t, k) return ((getmetatable(t) or {}).__fennelrest or function (t, k) return {(table.unpack or unpack)(t, k)} end)(t, k) end)(_let_170_, 3)
      if (a0 < b) then
        if d then
          return apply(lt0, b, c, d, more)
        else
          return (b < c)
        end
      else
        return false
      end
    end
  end
  lt0 = core.lt
  lt = core.lt
end
core["<"] = lt
local ge
do
  local ge0 = nil
  core.ge = function(...)
    local case_174_ = select("#", ...)
    if (case_174_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "core.ge"))
    elseif (case_174_ == 1) then
      local _ = ...
      return true
    elseif (case_174_ == 2) then
      local a0, b = ...
      return (a0 >= b)
    else
      local _ = case_174_
      local _let_175_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_51_auto = _let_175_.list
      local a0, b = ...
      local _let_176_ = list_51_auto(select(3, ...))
      local c = _let_176_[1]
      local d = _let_176_[2]
      local more = (function (t, k) return ((getmetatable(t) or {}).__fennelrest or function (t, k) return {(table.unpack or unpack)(t, k)} end)(t, k) end)(_let_176_, 3)
      if (a0 >= b) then
        if d then
          return apply(ge0, b, c, d, more)
        else
          return (b >= c)
        end
      else
        return false
      end
    end
  end
  ge0 = core.ge
  ge = core.ge
end
core[">="] = ge
local gt
do
  local gt0 = nil
  core.gt = function(...)
    local case_180_ = select("#", ...)
    if (case_180_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "core.gt"))
    elseif (case_180_ == 1) then
      local _ = ...
      return true
    elseif (case_180_ == 2) then
      local a0, b = ...
      return (a0 > b)
    else
      local _ = case_180_
      local _let_181_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_51_auto = _let_181_.list
      local a0, b = ...
      local _let_182_ = list_51_auto(select(3, ...))
      local c = _let_182_[1]
      local d = _let_182_[2]
      local more = (function (t, k) return ((getmetatable(t) or {}).__fennelrest or function (t, k) return {(table.unpack or unpack)(t, k)} end)(t, k) end)(_let_182_, 3)
      if (a0 > b) then
        if d then
          return apply(gt0, b, c, d, more)
        else
          return (b > c)
        end
      else
        return false
      end
    end
  end
  gt0 = core.gt
  gt = core.gt
end
core[">"] = gt
core.inc = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.inc"))
    else
    end
  end
  if add_overflow_3f(x, 1) then
    return error("Arithmetic overflow")
  else
    return (x + 1)
  end
end
core["inc*"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.inc*"))
    else
    end
  end
  if add_overflow_3f(x, 1) then
    return (BigDecimal:new(x) + 1)
  else
    return (x + 1)
  end
end
core.dec = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.dec"))
    else
    end
  end
  if add_overflow_3f(x, -1) then
    return error("Arithmetic overflow")
  else
    return (x - 1)
  end
end
core["dec*"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.dec*"))
    else
    end
  end
  if add_overflow_3f(x, -1) then
    return (BigDecimal:new(x) - 1)
  else
    return (x - 1)
  end
end
core["unchecked-add"] = function(...)
  local x, y = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.unchecked-add"))
    else
    end
  end
  return (x + y)
end
core["unchecked-add-int"] = core["unchecked-add"]
core["unchecked-dec"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.unchecked-dec"))
    else
    end
  end
  return (x - 1)
end
core["unchecked-dec-int"] = core["unchecked-dec"]
core["unchecked-inc"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.unchecked-inc"))
    else
    end
  end
  return (x + 1)
end
core["unchecked-inc-int"] = core["unchecked-inc"]
core["unchecked-multiply"] = function(...)
  local x, y = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.unchecked-multiply"))
    else
    end
  end
  return (x * y)
end
core["unchecked-multiply-int"] = core["unchecked-multiply"]
core["unchecked-negate"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.unchecked-negate"))
    else
    end
  end
  return ( - x)
end
core["unchecked-negate-int"] = core["unchecked-negate"]
core["unchecked-subtract"] = function(...)
  local x, y = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.unchecked-subtract"))
    else
    end
  end
  return (x - y)
end
core["unchecked-subtract-int"] = core["unchecked-subtract"]
core["unchecked-divide-int"] = function(...)
  local x, y = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.unchecked-divide-int"))
    else
    end
  end
  return (x / y)
end
core["unchecked-remainder-int"] = function(...)
  local x, y = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.unchecked-remainder-int"))
    else
    end
  end
  return (x % y)
end
core.max = function(...)
  local case_202_ = select("#", ...)
  if (case_202_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.max"))
  elseif (case_202_ == 1) then
    local x = ...
    return x
  elseif (case_202_ == 2) then
    local x, y = ...
    return max(x, y)
  else
    local _ = case_202_
    local _let_203_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_51_auto = _let_203_.list
    local x, y = ...
    local rest = list_51_auto(select(3, ...))
    return apply(max, x, y, rest)
  end
end
core.min = function(...)
  local case_205_ = select("#", ...)
  if (case_205_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.min"))
  elseif (case_205_ == 1) then
    local x = ...
    return x
  elseif (case_205_ == 2) then
    local x, y = ...
    return min(x, y)
  else
    local _ = case_205_
    local _let_206_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_51_auto = _let_206_.list
    local x, y = ...
    local rest = list_51_auto(select(3, ...))
    return apply(max, x, y, rest)
  end
end
core["nat-int?"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.nat-int?"))
    else
    end
  end
  return (core["int?"](x) and (x >= 0))
end
core["rand-int"] = function(...)
  local n = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.rand-int"))
    else
    end
  end
  if (n < 0) then
    return (math.random(math.ceil(n), -1) + 1)
  else
    return (math.random(math.ceil((n + 1))) - 1)
  end
end
core.rand = function(...)
  local case_211_ = select("#", ...)
  if (case_211_ == 0) then
    return math.random()
  elseif (case_211_ == 1) then
    local n = ...
    if (n < 0) then
      return (core["rand-int"](n) - math.random())
    else
      return (core["rand-int"](n) + math.random())
    end
  else
    local _ = case_211_
    return error(("Wrong number of args (%s) passed to %s"):format(_, "core.rand"))
  end
end
core["rand-nth"] = function(...)
  local coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.rand-nth"))
    else
    end
  end
  return core.nth(coll, core["rand-int"](core.count(coll)))
end
core.bigdec = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.bigdec"))
    else
    end
  end
  assert(core["number?"](x), "argument must be a number")
  return BigDecimal:new(x)
end
core.bigint = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.bigint"))
    else
    end
  end
  assert(core["number?"](x), "argument must be a number")
  return BigInt:new(x)
end
core.biginteger = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.biginteger"))
    else
    end
  end
  assert(core["number?"](x), "argument must be a number")
  return BigInteger:new(x)
end
local constantly
do
  local constantly0 = nil
  core.constantly = function(...)
    local x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.constantly"))
      else
      end
    end
    local function _219_()
      return x
    end
    return _219_
  end
  constantly0 = core.constantly
  constantly = core.constantly
end
local complement
do
  local complement0 = nil
  core.complement = function(...)
    local f = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.complement"))
      else
      end
    end
    local function fn_221_(...)
      local case_222_ = select("#", ...)
      if (case_222_ == 0) then
        return not f()
      elseif (case_222_ == 1) then
        local a0 = ...
        return not f(a0)
      elseif (case_222_ == 2) then
        local a0, b = ...
        return not f(a0, b)
      else
        local _ = case_222_
        local _let_223_ = require("io.gitlab.andreyorst.cljlib.core")
        local list_51_auto = _let_223_.list
        local a0, b = ...
        local cs = list_51_auto(select(3, ...))
        return not apply(f, a0, b, cs)
      end
    end
    return fn_221_
  end
  complement0 = core.complement
  complement = core.complement
end
local identity
do
  local identity0 = nil
  core.identity = function(...)
    local x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.identity"))
      else
      end
    end
    return x
  end
  identity0 = core.identity
  identity = core.identity
end
local comp
do
  local comp0 = nil
  core.comp = function(...)
    local case_226_ = select("#", ...)
    if (case_226_ == 0) then
      return identity
    elseif (case_226_ == 1) then
      local f = ...
      return f
    elseif (case_226_ == 2) then
      local f, g = ...
      local function fn_227_(...)
        local case_228_ = select("#", ...)
        if (case_228_ == 0) then
          return f(g())
        elseif (case_228_ == 1) then
          local x = ...
          return f(g(x))
        elseif (case_228_ == 2) then
          local x, y = ...
          return f(g(x, y))
        elseif (case_228_ == 3) then
          local x, y, z = ...
          return f(g(x, y, z))
        else
          local _ = case_228_
          local _let_229_ = require("io.gitlab.andreyorst.cljlib.core")
          local list_51_auto = _let_229_.list
          local x, y, z = ...
          local args = list_51_auto(select(4, ...))
          return f(apply(g, x, y, z, args))
        end
      end
      return fn_227_
    else
      local _ = case_226_
      local _let_231_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_51_auto = _let_231_.list
      local f, g = ...
      local fs = list_51_auto(select(3, ...))
      return core.reduce(comp0, core.cons(f, core.cons(g, fs)))
    end
  end
  comp0 = core.comp
  comp = core.comp
end
local function eq_tables_3f(a0, b, eq)
  local res, count_a = true, 0
  for k, v in pairs_2a(a0) do
    if not res then break end
    local function _233_()
      local res0, done = nil, nil
      for k_2a, v0 in pairs_2a(b) do
        if done then break end
        if eq(k_2a, k) then
          res0, done = v0, true
        else
        end
      end
      return res0
    end
    res = eq(v, _233_())
    count_a = (count_a + 1)
  end
  if res then
    local count_b
    do
      local res0 = 0
      for _, _0 in pairs_2a(b) do
        res0 = (res0 + 1)
      end
      count_b = res0
    end
    res = (count_a == count_b)
  else
  end
  return res
end
local function primitive_eq(a0, b, eq)
  local or_236_ = rawequal(a0, b) or ((a0 == b) and (b == a0))
  if not or_236_ then
    local _237_ = type(a0)
    or_236_ = ((("table" == _237_) and (_237_ == type(b))) and eq_tables_3f(a0, b, eq))
  end
  return or_236_
end
local eq
do
  local eq0 = nil
  core.eq = function(...)
    local case_238_ = select("#", ...)
    if (case_238_ == 0) then
      return true
    elseif (case_238_ == 1) then
      local _ = ...
      return true
    elseif (case_238_ == 2) then
      local a0, b = ...
      local case_239_ = class_name(a0)
      if ((case_239_ == "BigDecimal") or (case_239_ == "BigInteger") or (case_239_ == "BigInt")) then
        return BigDecimal.__eq(a0, b)
      elseif (case_239_ == "Ratio") then
        return Ratio.__eq(a0, b)
      elseif (case_239_ == "number") then
        local case_240_ = class_name(b)
        if ((case_240_ == "BigDecimal") or (case_240_ == "BigInteger") or (case_240_ == "BigInt")) then
          return BigDecimal.__eq(b, a0)
        elseif (case_240_ == "Ratio") then
          return Ratio.__eq(b, a0)
        else
          local _ = case_240_
          return primitive_eq(a0, b, eq0)
        end
      else
        local _ = case_239_
        return primitive_eq(a0, b, eq0)
      end
    else
      local _ = case_238_
      local _let_243_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_51_auto = _let_243_.list
      local a0, b = ...
      local cs = list_51_auto(select(3, ...))
      return (eq0(a0, b) and apply(eq0, b, cs))
    end
  end
  eq0 = core.eq
  eq = core.eq
end
core["="] = eq
core["not="] = function(...)
  local case_245_ = select("#", ...)
  if (case_245_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.not="))
  elseif (case_245_ == 1) then
    local _ = ...
    return false
  elseif (case_245_ == 2) then
    local x, y = ...
    return not eq(x, y)
  else
    local _ = case_245_
    local _let_246_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_51_auto = _let_246_.list
    local x, y = ...
    local more = list_51_auto(select(3, ...))
    return not apply(eq, x, y, more)
  end
end
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
core.memoize = function(...)
  local f = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.memoize"))
    else
    end
  end
  local memo = setmetatable({}, {__index = deep_index})
  local function _253_(...)
    local args = pack_2a(...)
    local case_254_ = memo[args]
    if (nil ~= case_254_) then
      local res = case_254_
      return unpack_2a(res, 1, res.n)
    else
      local _ = case_254_
      local res = pack_2a(f(...))
      memo[args] = res
      return unpack_2a(res, 1, res.n)
    end
  end
  return _253_
end
local deref
do
  local deref0 = nil
  core.deref = function(...)
    local case_258_ = select("#", ...)
    if (case_258_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "core.deref"))
    elseif (case_258_ == 1) then
      local x = ...
      local case_259_ = getmetatable(x)
      if ((_G.type(case_259_) == "table") and (nil ~= case_259_["cljlib/deref"])) then
        local f = case_259_["cljlib/deref"]
        return f(x)
      else
        local _ = case_259_
        return error("object doesn't implement cljlib/deref metamethod", 2)
      end
    elseif (case_258_ == 2) then
      return error(("Wrong number of args (%s) passed to %s"):format(2, "core.deref"))
    elseif (case_258_ == 3) then
      local x, timeout, timeout_val = ...
      local case_261_ = getmetatable(x)
      if ((_G.type(case_261_) == "table") and (nil ~= case_261_["cljlib/deref"])) then
        local f = case_261_["cljlib/deref"]
        return f(x, timeout, timeout_val)
      else
        local _ = case_261_
        return error("object doesn't implement cljlib/deref metamethod", 2)
      end
    else
      local _ = case_258_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "core.deref"))
    end
  end
  deref0 = core.deref
  deref = core.deref
end
core.empty = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.empty"))
    else
    end
  end
  local case_265_ = getmetatable(x)
  if ((_G.type(case_265_) == "table") and (nil ~= case_265_["cljlib/empty"])) then
    local f = case_265_["cljlib/empty"]
    return f(x)
  else
    local _ = case_265_
    local case_266_ = type(x)
    if (case_266_ == "table") then
      return {}
    elseif (case_266_ == "string") then
      return ""
    else
      local _0 = case_266_
      return error(("don't know how to create empty variant of type " .. _0))
    end
  end
end
core.str = function(...)
  local function _269_(...)
    local tbl_26_ = {}
    local i_27_ = 0
    for i = 1, select("#", ...) do
      local val_28_
      do
        local case_270_ = select(i, ...)
        if (case_270_ == nil) then
          val_28_ = ""
        elseif (nil ~= case_270_) then
          local x = case_270_
          val_28_ = tostring(x)
        else
          val_28_ = nil
        end
      end
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    return tbl_26_
  end
  return table.concat(_269_(...))
end
local subs = string.sub
core.subs = function(...)
  local case_274_ = select("#", ...)
  if (case_274_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.subs"))
  elseif (case_274_ == 1) then
    return error(("Wrong number of args (%s) passed to %s"):format(1, "core.subs"))
  elseif (case_274_ == 2) then
    local s, start = ...
    return subs(s, (start + 1))
  elseif (case_274_ == 3) then
    local s, start, _end = ...
    return subs(s, (start + 1), _end)
  else
    local _ = case_274_
    return error(("Wrong number of args (%s) passed to %s"):format(_, "core.subs"))
  end
end
core["not"] = function(x)
  return not x
end
core.partial = function(f, ...)
  local args
  local function _276_(...)
    local tmp_9_ = {...}
    tmp_9_["n"] = select("#", ...)
    return tmp_9_
  end
  args = _276_(...)
  local function _277_(...)
    local args_2a = {}
    for i = 1, args.n do
      args_2a[i] = args[i]
    end
    for i = 1, select("#", ...) do
      args_2a[(args.n + i)] = select(i, ...)
    end
    return f((table.unpack or _G.unpack)(args_2a))
  end
  return _277_
end
local ExceptionInfo
do
  local v_39_auto
  local function _279_(_278_)
    local message = _278_.message
    local map = _278_.map
    local self = _278_
    return ("#<" .. tostring(self) .. ": " .. view({message = message, map = map}, {["one-line?"] = true}) .. ">")
  end
  v_39_auto = {__name = "ExceptionInfo", ["cljlib/class"] = true, __fennelview = _279_}
  core.ExceptionInfo = v_39_auto
  ExceptionInfo = v_39_auto
end
ExceptionInfo.new = function(...)
  local self, message, map = ...
  do
    local cnt_69_auto = select("#", ...)
    if (3 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "ExceptionInfo.new"))
    else
    end
  end
  self.__index = self
  self["cljlib/type"] = self
  return setmetatable({message = message, map = map}, self)
end
core["ex-info"] = function(...)
  local message, map = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.ex-info"))
    else
    end
  end
  return ExceptionInfo:new(message, map)
end
core["ex-data"] = function(...)
  local ex = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.ex-data"))
    else
    end
  end
  local case_283_ = class_name(ex)
  if (case_283_ == "ExceptionInfo") then
    return ex.map
  else
    return nil
  end
end
core["ex-message"] = function(...)
  local ex = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.ex-message"))
    else
    end
  end
  local case_286_ = class_name(ex)
  if (case_286_ == "ExceptionInfo") then
    return ex.message
  elseif (case_286_ == "string") then
    return ex
  else
    return nil
  end
end
core.format = function(fmt, ...)
  local function _288_(...)
    local tbl_26_ = {}
    local i_27_ = 0
    for i = 1, select("#", ...) do
      local val_28_
      if ("table" == type(select(i, ...))) then
        val_28_ = view(select(i, ...), {["one-line?"] = true})
      else
        val_28_ = select(i, ...)
      end
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    return tbl_26_
  end
  return string.format(fmt, (_G.unpack or table.unpack)(_288_(...)))
end
core.newline = function(...)
  do
    local cnt_69_auto = select("#", ...)
    if (0 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.newline"))
    else
    end
  end
  io.write("\n")
  return nil
end
core.flush = function(...)
  do
    local cnt_69_auto = select("#", ...)
    if (0 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.flush"))
    else
    end
  end
  io.flush()
  return nil
end
core.print = function(...)
  local _293_
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for i = 1, select("#", ...) do
      local val_28_
      if ("table" == type(select(i, ...))) then
        val_28_ = view(select(i, ...), {["one-line?"] = true})
      else
        val_28_ = select(i, ...)
      end
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    _293_ = tbl_26_
  end
  io.write(table.concat(_293_, " "))
  return nil
end
core["print-str"] = function(...)
  local G_167_auto = _G
  local out_168_auto = {}
  local _let_296_ = G_167_auto.io
  local stdout_170_auto = _let_296_.stdout
  local write_169_auto = _let_296_.write
  local _let_297_ = getmetatable(stdout_170_auto).__index
  local fd_2fwrite_171_auto = _let_297_.write
  local fd_172_auto = _let_297_
  local lua_print_173_auto = G_167_auto.print
  local function join_174_auto(sep_175_auto, ...)
    local _298_
    do
      local tbl_26_ = {}
      local i_27_ = 0
      for i_176_auto = 1, select("#", ...) do
        local val_28_ = tostring(select(i_176_auto, ...))
        if (nil ~= val_28_) then
          i_27_ = (i_27_ + 1)
          tbl_26_[i_27_] = val_28_
        else
        end
      end
      _298_ = tbl_26_
    end
    return table.concat(_298_, sep_175_auto)
  end
  local function _300_(fd_172_auto0, ...)
    if rawequal(fd_172_auto0, stdout_170_auto) then
      return table.insert(out_168_auto, join_174_auto("", ...))
    else
      return fd_2fwrite_171_auto(fd_172_auto0, ...)
    end
  end
  fd_172_auto["write"] = _300_
  local function _302_(...)
    G_167_auto.io.write((join_174_auto("\t", ...) .. "\n"))
    return nil
  end
  G_167_auto["print"] = _302_
  local function _303_(...)
    return G_167_auto.io.output():write(...)
  end
  G_167_auto["io"]["write"] = _303_
  local ok_177_auto, msg_178_auto
  local function _304_(...)
    return core.print(...)
  end
  ok_177_auto, msg_178_auto = pcall(_304_, ...)
  G_167_auto["print"] = lua_print_173_auto
  G_167_auto["io"]["write"] = write_169_auto
  fd_172_auto["write"] = fd_2fwrite_171_auto
  if ok_177_auto then
    return table.concat(out_168_auto, "")
  else
    return error(msg_178_auto)
  end
end
core.println = function(...)
  core.print(...)
  return core.newline()
end
core["println-str"] = function(...)
  local G_167_auto = _G
  local out_168_auto = {}
  local _let_306_ = G_167_auto.io
  local stdout_170_auto = _let_306_.stdout
  local write_169_auto = _let_306_.write
  local _let_307_ = getmetatable(stdout_170_auto).__index
  local fd_2fwrite_171_auto = _let_307_.write
  local fd_172_auto = _let_307_
  local lua_print_173_auto = G_167_auto.print
  local function join_174_auto(sep_175_auto, ...)
    local _308_
    do
      local tbl_26_ = {}
      local i_27_ = 0
      for i_176_auto = 1, select("#", ...) do
        local val_28_ = tostring(select(i_176_auto, ...))
        if (nil ~= val_28_) then
          i_27_ = (i_27_ + 1)
          tbl_26_[i_27_] = val_28_
        else
        end
      end
      _308_ = tbl_26_
    end
    return table.concat(_308_, sep_175_auto)
  end
  local function _310_(fd_172_auto0, ...)
    if rawequal(fd_172_auto0, stdout_170_auto) then
      return table.insert(out_168_auto, join_174_auto("", ...))
    else
      return fd_2fwrite_171_auto(fd_172_auto0, ...)
    end
  end
  fd_172_auto["write"] = _310_
  local function _312_(...)
    G_167_auto.io.write((join_174_auto("\t", ...) .. "\n"))
    return nil
  end
  G_167_auto["print"] = _312_
  local function _313_(...)
    return G_167_auto.io.output():write(...)
  end
  G_167_auto["io"]["write"] = _313_
  local ok_177_auto, msg_178_auto
  local function _314_(...)
    return core.println(...)
  end
  ok_177_auto, msg_178_auto = pcall(_314_, ...)
  G_167_auto["print"] = lua_print_173_auto
  G_167_auto["io"]["write"] = write_169_auto
  fd_172_auto["write"] = fd_2fwrite_171_auto
  if ok_177_auto then
    return table.concat(out_168_auto, "")
  else
    return error(msg_178_auto)
  end
end
core.printf = function(...)
  return core.print(core.format(...))
end
core.pr = function(...)
  local _316_
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for i = 1, select("#", ...) do
      local val_28_ = view(select(i, ...), {["one-line?"] = true})
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    _316_ = tbl_26_
  end
  io.write(table.concat(_316_, " "))
  return nil
end
core["pr-str"] = function(...)
  local G_167_auto = _G
  local out_168_auto = {}
  local _let_318_ = G_167_auto.io
  local stdout_170_auto = _let_318_.stdout
  local write_169_auto = _let_318_.write
  local _let_319_ = getmetatable(stdout_170_auto).__index
  local fd_2fwrite_171_auto = _let_319_.write
  local fd_172_auto = _let_319_
  local lua_print_173_auto = G_167_auto.print
  local function join_174_auto(sep_175_auto, ...)
    local _320_
    do
      local tbl_26_ = {}
      local i_27_ = 0
      for i_176_auto = 1, select("#", ...) do
        local val_28_ = tostring(select(i_176_auto, ...))
        if (nil ~= val_28_) then
          i_27_ = (i_27_ + 1)
          tbl_26_[i_27_] = val_28_
        else
        end
      end
      _320_ = tbl_26_
    end
    return table.concat(_320_, sep_175_auto)
  end
  local function _322_(fd_172_auto0, ...)
    if rawequal(fd_172_auto0, stdout_170_auto) then
      return table.insert(out_168_auto, join_174_auto("", ...))
    else
      return fd_2fwrite_171_auto(fd_172_auto0, ...)
    end
  end
  fd_172_auto["write"] = _322_
  local function _324_(...)
    G_167_auto.io.write((join_174_auto("\t", ...) .. "\n"))
    return nil
  end
  G_167_auto["print"] = _324_
  local function _325_(...)
    return G_167_auto.io.output():write(...)
  end
  G_167_auto["io"]["write"] = _325_
  local ok_177_auto, msg_178_auto
  local function _326_(...)
    return core.pr(...)
  end
  ok_177_auto, msg_178_auto = pcall(_326_, ...)
  G_167_auto["print"] = lua_print_173_auto
  G_167_auto["io"]["write"] = write_169_auto
  fd_172_auto["write"] = fd_2fwrite_171_auto
  if ok_177_auto then
    return table.concat(out_168_auto, "")
  else
    return error(msg_178_auto)
  end
end
core.prn = function(...)
  core.pr(...)
  core.newline()
  return nil
end
core["prn-str"] = function(...)
  local G_167_auto = _G
  local out_168_auto = {}
  local _let_328_ = G_167_auto.io
  local stdout_170_auto = _let_328_.stdout
  local write_169_auto = _let_328_.write
  local _let_329_ = getmetatable(stdout_170_auto).__index
  local fd_2fwrite_171_auto = _let_329_.write
  local fd_172_auto = _let_329_
  local lua_print_173_auto = G_167_auto.print
  local function join_174_auto(sep_175_auto, ...)
    local _330_
    do
      local tbl_26_ = {}
      local i_27_ = 0
      for i_176_auto = 1, select("#", ...) do
        local val_28_ = tostring(select(i_176_auto, ...))
        if (nil ~= val_28_) then
          i_27_ = (i_27_ + 1)
          tbl_26_[i_27_] = val_28_
        else
        end
      end
      _330_ = tbl_26_
    end
    return table.concat(_330_, sep_175_auto)
  end
  local function _332_(fd_172_auto0, ...)
    if rawequal(fd_172_auto0, stdout_170_auto) then
      return table.insert(out_168_auto, join_174_auto("", ...))
    else
      return fd_2fwrite_171_auto(fd_172_auto0, ...)
    end
  end
  fd_172_auto["write"] = _332_
  local function _334_(...)
    G_167_auto.io.write((join_174_auto("\t", ...) .. "\n"))
    return nil
  end
  G_167_auto["print"] = _334_
  local function _335_(...)
    return G_167_auto.io.output():write(...)
  end
  G_167_auto["io"]["write"] = _335_
  local ok_177_auto, msg_178_auto
  local function _336_(...)
    return core.prn(...)
  end
  ok_177_auto, msg_178_auto = pcall(_336_, ...)
  G_167_auto["print"] = lua_print_173_auto
  G_167_auto["io"]["write"] = write_169_auto
  fd_172_auto["write"] = fd_2fwrite_171_auto
  if ok_177_auto then
    return table.concat(out_168_auto, "")
  else
    return error(msg_178_auto)
  end
end
local nil_3f
do
  local nil_3f0 = nil
  core["nil?"] = function(...)
    local case_338_ = select("#", ...)
    if (case_338_ == 0) then
      return true
    elseif (case_338_ == 1) then
      local x = ...
      return (x == nil)
    else
      local _ = case_338_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "core.nil?"))
    end
  end
  nil_3f0 = core["nil?"]
  nil_3f = core["nil?"]
end
core.fnil = function(...)
  local case_341_ = select("#", ...)
  if (case_341_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.fnil"))
  elseif (case_341_ == 1) then
    return error(("Wrong number of args (%s) passed to %s"):format(1, "core.fnil"))
  elseif (case_341_ == 2) then
    local f, x = ...
    local function fn_342_(...)
      local case_343_ = select("#", ...)
      if (case_343_ == 0) then
        return error(("Wrong number of args (%s) passed to %s"):format(0, "fn_342_"))
      elseif (case_343_ == 1) then
        local a0 = ...
        local function _344_(...)
          if nil_3f(a0) then
            return x
          else
            return a0
          end
        end
        return f(_344_(...))
      elseif (case_343_ == 2) then
        local a0, b = ...
        local _345_
        if nil_3f(a0) then
          _345_ = x
        else
          _345_ = a0
        end
        return f(_345_, b)
      elseif (case_343_ == 3) then
        local a0, b, c = ...
        local _347_
        if nil_3f(a0) then
          _347_ = x
        else
          _347_ = a0
        end
        return f(_347_, b, c)
      else
        local _ = case_343_
        local _let_349_ = require("io.gitlab.andreyorst.cljlib.core")
        local list_51_auto = _let_349_.list
        local a0, b, c = ...
        local ds = list_51_auto(select(4, ...))
        local _350_
        if nil_3f(a0) then
          _350_ = x
        else
          _350_ = a0
        end
        return apply(f, _350_, b, c, ds)
      end
    end
    return fn_342_
  elseif (case_341_ == 3) then
    local f, x, y = ...
    local function fn_353_(...)
      local case_355_ = select("#", ...)
      if (case_355_ == 0) then
        return error(("Wrong number of args (%s) passed to %s"):format(0, "fn_353_"))
      elseif (case_355_ == 1) then
        return error(("Wrong number of args (%s) passed to %s"):format(1, "fn_353_"))
      elseif (case_355_ == 2) then
        local a0, b = ...
        local _356_
        if nil_3f(a0) then
          _356_ = x
        else
          _356_ = a0
        end
        local function _358_(...)
          if nil_3f(b) then
            return y
          else
            return b
          end
        end
        return f(_356_, _358_(...))
      elseif (case_355_ == 3) then
        local a0, b, c = ...
        local _359_
        if nil_3f(a0) then
          _359_ = x
        else
          _359_ = a0
        end
        local _361_
        if nil_3f(b) then
          _361_ = y
        else
          _361_ = b
        end
        return f(_359_, _361_, c)
      else
        local _ = case_355_
        local _let_363_ = require("io.gitlab.andreyorst.cljlib.core")
        local list_51_auto = _let_363_.list
        local a0, b, c = ...
        local ds = list_51_auto(select(4, ...))
        local _364_
        if nil_3f(a0) then
          _364_ = x
        else
          _364_ = a0
        end
        local _366_
        if nil_3f(b) then
          _366_ = y
        else
          _366_ = b
        end
        return apply(f, _364_, _366_, c, ds)
      end
    end
    return fn_353_
  elseif (case_341_ == 4) then
    local f, x, y, z = ...
    local function fn_369_(...)
      local case_371_ = select("#", ...)
      if (case_371_ == 0) then
        return error(("Wrong number of args (%s) passed to %s"):format(0, "fn_369_"))
      elseif (case_371_ == 1) then
        return error(("Wrong number of args (%s) passed to %s"):format(1, "fn_369_"))
      elseif (case_371_ == 2) then
        local a0, b = ...
        local _372_
        if nil_3f(a0) then
          _372_ = x
        else
          _372_ = a0
        end
        local function _374_(...)
          if nil_3f(b) then
            return y
          else
            return b
          end
        end
        return f(_372_, _374_(...))
      elseif (case_371_ == 3) then
        local a0, b, c = ...
        local _375_
        if nil_3f(a0) then
          _375_ = x
        else
          _375_ = a0
        end
        local _377_
        if nil_3f(b) then
          _377_ = y
        else
          _377_ = b
        end
        local function _379_(...)
          if nil_3f(c) then
            return z
          else
            return c
          end
        end
        return f(_375_, _377_, _379_(...))
      else
        local _ = case_371_
        local _let_380_ = require("io.gitlab.andreyorst.cljlib.core")
        local list_51_auto = _let_380_.list
        local a0, b, c = ...
        local ds = list_51_auto(select(4, ...))
        local _381_
        if nil_3f(a0) then
          _381_ = x
        else
          _381_ = a0
        end
        local _383_
        if nil_3f(b) then
          _383_ = y
        else
          _383_ = b
        end
        local _385_
        if nil_3f(c) then
          _385_ = z
        else
          _385_ = c
        end
        return apply(f, _381_, _383_, _385_, ds)
      end
    end
    return fn_369_
  else
    local _ = case_341_
    return error(("Wrong number of args (%s) passed to %s"):format(_, "core.fnil"))
  end
end
local fn_3f
do
  local fn_3f0 = nil
  core["fn?"] = function(...)
    local x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.fn?"))
      else
      end
    end
    return ("function" == type(x))
  end
  fn_3f0 = core["fn?"]
  fn_3f = core["fn?"]
end
local ifn_3f
do
  local ifn_3f0 = nil
  core["ifn?"] = function(...)
    local x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.ifn?"))
      else
      end
    end
    local case_391_ = getmetatable(x)
    if ((_G.type(case_391_) == "table") and (nil ~= case_391_.__call)) then
      local f = case_391_.__call
      return ifn_3f0(f)
    else
      local _ = case_391_
      return fn_3f(x)
    end
  end
  ifn_3f0 = core["ifn?"]
  ifn_3f = core["ifn?"]
end
core["zero?"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.zero?"))
    else
    end
  end
  return (x == 0)
end
local pos_3f
do
  local pos_3f0 = nil
  core["pos?"] = function(...)
    local x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.pos?"))
      else
      end
    end
    return (x > 0)
  end
  pos_3f0 = core["pos?"]
  pos_3f = core["pos?"]
end
local neg_3f
do
  local neg_3f0 = nil
  core["neg?"] = function(...)
    local x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.neg?"))
      else
      end
    end
    return (x < 0)
  end
  neg_3f0 = core["neg?"]
  neg_3f = core["neg?"]
end
local even_3f
do
  local even_3f0 = nil
  core["even?"] = function(...)
    local x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.even?"))
      else
      end
    end
    return ((x % 2) == 0)
  end
  even_3f0 = core["even?"]
  even_3f = core["even?"]
end
core["odd?"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.odd?"))
    else
    end
  end
  return not even_3f(x)
end
local string_3f
do
  local string_3f0 = nil
  core["string?"] = function(...)
    local x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.string?"))
      else
      end
    end
    return (type(x) == "string")
  end
  string_3f0 = core["string?"]
  string_3f = core["string?"]
end
core["char?"] = function(...)
  local s = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.char?"))
    else
    end
  end
  return (string_3f(s) and (#s == 1))
end
core["boolean?"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.boolean?"))
    else
    end
  end
  return (type(x) == "boolean")
end
core["true?"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.true?"))
    else
    end
  end
  return (x == true)
end
core["false?"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.false?"))
    else
    end
  end
  return (x == false)
end
core["pos-int?"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.pos-int?"))
    else
    end
  end
  return (int_3f(x) and pos_3f(x))
end
core["neg-int?"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.neg-int?"))
    else
    end
  end
  return (int_3f(x) and neg_3f(x))
end
core["double?"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.double?"))
    else
    end
  end
  return (number_3f(x) and ((instance_3f(BigDecimal, x) and not instance_3f(BigInteger, x)) or (x ~= m_2ffloor(x))))
end
local empty_3f
do
  local empty_3f0 = nil
  core["empty?"] = function(...)
    local x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.empty?"))
      else
      end
    end
    local case_407_ = type(x)
    if (case_407_ == "table") then
      local case_408_ = getmetatable(x)
      if ((_G.type(case_408_) == "table") and (case_408_["cljlib/type"] == "seq")) then
        return nil_3f(core.seq(x))
      elseif ((case_408_ == nil) or ((_G.type(case_408_) == "table") and (case_408_["cljlib/type"] == nil))) then
        local next_2a = pairs_2a(x)
        return (next_2a(x) == nil)
      else
        return nil
      end
    elseif (case_407_ == "string") then
      return (x == "")
    elseif (case_407_ == "nil") then
      return true
    else
      local _ = case_407_
      return error("empty?: unsupported collection")
    end
  end
  empty_3f0 = core["empty?"]
  empty_3f = core["empty?"]
end
core["not-empty"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.not-empty"))
    else
    end
  end
  if not empty_3f(x) then
    return x
  else
    return nil
  end
end
local SortedSet
do
  local v_39_auto = RedBlackTree:new()
  core.SortedSet = v_39_auto
  SortedSet = v_39_auto
end
local SortedMap
do
  local v_39_auto = RedBlackTree:new()
  core.SortedMap = v_39_auto
  SortedMap = v_39_auto
end
local function map_3f_2a(x)
  local case_413_ = getmetatable(x)
  if ((_G.type(case_413_) == "table") and (case_413_["cljlib/type"] == "hash-map")) then
    return true
  elseif ((_G.type(case_413_) == "table") and (case_413_["cljlib/type"] == "ImmutableStructMap")) then
    return true
  elseif ((_G.type(case_413_) == "table") and (case_413_["cljlib/type"] == "ImmutableArrayMap")) then
    return true
  elseif ((_G.type(case_413_) == "table") and (case_413_["cljlib/type"] == SortedMap)) then
    return true
  else
    return nil
  end
end
local map_3f
do
  local map_3f0 = nil
  core["map?"] = function(...)
    local x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.map?"))
      else
      end
    end
    if ("table" == type(x)) then
      local or_416_ = map_3f_2a(x)
      if not or_416_ then
        local case_417_ = getmetatable(x)
        if ((case_417_ == nil) or ((_G.type(case_417_) == "table") and (case_417_["cljlib/type"] == nil))) then
          local len = length_2a(x)
          local nxt, t, k = pairs_2a(x)
          local function _421_(...)
            if (len == 0) then
              return k
            else
              return len
            end
          end
          or_416_ = (nil ~= nxt(t, _421_(...)))
        else
          local _ = case_417_
          or_416_ = false
        end
      end
      return or_416_
    else
      return false
    end
  end
  map_3f0 = core["map?"]
  map_3f = core["map?"]
end
core["associative?"] = function(...)
  local coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.associative?"))
    else
    end
  end
  return map_3f(coll)
end
local vector_3f
do
  local vector_3f0 = nil
  core["vector?"] = function(...)
    local x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.vector?"))
      else
      end
    end
    if ("table" == type(x)) then
      local case_427_ = getmetatable(x)
      if ((_G.type(case_427_) == "table") and (case_427_["cljlib/type"] == "vector")) then
        return true
      elseif ((case_427_ == nil) or ((_G.type(case_427_) == "table") and (case_427_["cljlib/type"] == nil))) then
        local len = length_2a(x)
        local nxt, t, k = pairs_2a(x)
        local function _428_(...)
          if (len == 0) then
            return k
          else
            return len
          end
        end
        if (nil ~= nxt(t, _428_(...))) then
          return false
        elseif (len > 0) then
          return true
        else
          return false
        end
      else
        local _ = case_427_
        return false
      end
    else
      return false
    end
  end
  vector_3f0 = core["vector?"]
  vector_3f = core["vector?"]
end
core["set?"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.set?"))
    else
    end
  end
  local case_433_ = getmetatable(x)
  if ((_G.type(case_433_) == "table") and (case_433_["cljlib/type"] == "hash-set")) then
    return true
  elseif ((_G.type(case_433_) == "table") and (case_433_["cljlib/type"] == SortedSet)) then
    return true
  else
    local _ = case_433_
    return false
  end
end
local seq_3f
do
  local seq_3f0 = nil
  core["seq?"] = function(...)
    local x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.seq?"))
      else
      end
    end
    return lazy["seq?"](x)
  end
  seq_3f0 = core["seq?"]
  seq_3f = core["seq?"]
end
core["some?"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.some?"))
    else
    end
  end
  return (x ~= nil)
end
core["any?"] = function(...)
  local _ = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.any?"))
    else
    end
  end
  return true
end
core["identical?"] = function(...)
  local x, y = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.identical?"))
    else
    end
  end
  return rawequal(x, y)
end
core["chunked-seq?"] = function(...)
  local _s = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.chunked-seq?"))
    else
    end
  end
  return false
end
local sequential_3f
do
  local sequential_3f0 = nil
  core["sequential?"] = function(...)
    local coll = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.sequential?"))
      else
      end
    end
    return (seq_3f(coll) or vector_3f(coll))
  end
  sequential_3f0 = core["sequential?"]
  sequential_3f = core["sequential?"]
end
core["distinct?"] = function(...)
  local case_441_ = select("#", ...)
  if (case_441_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.distinct?"))
  elseif (case_441_ == 1) then
    local _ = ...
    return true
  elseif (case_441_ == 2) then
    local x, y = ...
    return not eq(x, y)
  else
    local _ = case_441_
    local _let_442_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_51_auto = _let_442_.list
    local x, y = ...
    local more = list_51_auto(select(3, ...))
    if not eq(x, y) then
      local function recur(s, _443_)
        local x0 = _443_[1]
        local etc = (function (t, k) return ((getmetatable(t) or {}).__fennelrest or function (t, k) return {(table.unpack or unpack)(t, k)} end)(t, k) end)(_443_, 2)
        local xs = _443_
        if core.seq(xs) then
          if core["contains?"](s, x0) then
            return false
          else
            return recur(core.conj(s, x0), etc)
          end
        else
          return true
        end
      end
      return recur(core["hash-set"](x, y), more)
    else
      return false
    end
  end
end
local function vec__3etransient(immutable)
  local function _448_(vec)
    local len = #vec
    local function _449_(_, i)
      if (i <= len) then
        return vec[i]
      else
        return nil
      end
    end
    local function _451_()
      return len
    end
    local function _452_()
      return error("can't `conj` onto transient vector, use `conj!`")
    end
    local function _453_()
      return error("can't `assoc` onto transient vector, use `assoc!`")
    end
    local function _454_()
      return error("can't `dissoc` onto transient vector, use `dissoc!`")
    end
    local function _455_(tvec, v)
      len = (len + 1)
      tvec[len] = v
      return tvec
    end
    local function _456_(tvec, ...)
      do
        local len0 = #tvec
        for i = 1, select("#", ...), 2 do
          local _k, v = select(i, ...)
          if ((1 <= i) and (i <= len0)) then
            tvec[i] = v
          else
            error(("index " .. i .. " is out of bounds"))
          end
        end
      end
      return tvec
    end
    local function _458_(tvec)
      if (len == 0) then
        return error("transient vector is empty", 2)
      else
        local _val = table.remove(tvec)
        len = (len - 1)
        return tvec
      end
    end
    local function _460_()
      return error("can't `dissoc!` with a transient vector")
    end
    local function _461_(tvec)
      local v
      do
        local tbl_26_ = {}
        local i_27_ = 0
        for i = 1, len do
          local val_28_ = tvec[i]
          if (nil ~= val_28_) then
            i_27_ = (i_27_ + 1)
            tbl_26_[i_27_] = val_28_
          else
          end
        end
        v = tbl_26_
      end
      while (len > 0) do
        table.remove(tvec)
        len = (len - 1)
      end
      local function _463_()
        return error("attempt to use transient after it was persistet")
      end
      local function _464_()
        return error("attempt to use transient after it was persistet")
      end
      setmetatable(tvec, {__index = _463_, __newindex = _464_})
      return immutable(itable(v))
    end
    return setmetatable({}, {__index = _449_, __len = _451_, ["cljlib/type"] = "transient", ["cljlib/conj"] = _452_, ["cljlib/assoc"] = _453_, ["cljlib/dissoc"] = _454_, ["cljlib/conj!"] = _455_, ["cljlib/assoc!"] = _456_, ["cljlib/pop!"] = _458_, ["cljlib/dissoc!"] = _460_, ["cljlib/persistent!"] = _461_})
  end
  return _448_
end
local function vec_2a(v, len)
  do
    local case_465_ = getmetatable(v)
    if (nil ~= case_465_) then
      local mt = case_465_
      mt["__len"] = constantly((len or length_2a(v)))
      mt["cljlib/type"] = "vector"
      mt["cljlib/editable"] = true
      local function _466_(t, v0)
        local len0 = length_2a(t)
        return vec_2a(itable.assoc(t, (len0 + 1), v0), (len0 + 1))
      end
      mt["cljlib/conj"] = _466_
      local function _467_(t)
        local len0 = (length_2a(t) - 1)
        local coll = {}
        if (len0 < 0) then
          error("can't pop empty vector", 2)
        else
        end
        for i = 1, len0 do
          coll[i] = t[i]
        end
        return vec_2a(itable(coll), len0)
      end
      mt["cljlib/pop"] = _467_
      local function _469_()
        return vec_2a(itable({}))
      end
      mt["cljlib/empty"] = _469_
      mt["cljlib/transient"] = vec__3etransient(vec_2a)
      local function _470_(coll, view0, inspector, indent)
        if empty_3f(coll) then
          return "[]"
        else
          local lines
          do
            local tbl_26_ = {}
            local i_27_ = 0
            for i = 1, length_2a(coll) do
              local val_28_ = (" " .. view0(coll[i], inspector, indent))
              if (nil ~= val_28_) then
                i_27_ = (i_27_ + 1)
                tbl_26_[i_27_] = val_28_
              else
              end
            end
            lines = tbl_26_
          end
          lines[1] = ("[" .. string.gsub((lines[1] or ""), "^%s+", ""))
          lines[#lines] = (lines[#lines] .. "]")
          return lines
        end
      end
      mt["__fennelview"] = _470_
    elseif (case_465_ == nil) then
      vec_2a(setmetatable(v, {}))
    else
    end
  end
  return v
end
local vec
do
  local vec0 = nil
  core.vec = function(...)
    local coll = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.vec"))
      else
      end
    end
    if empty_3f(coll) then
      return vec_2a(itable({}), 0)
    elseif vector_3f(coll) then
      return vec_2a(itable(coll), length_2a(coll))
    elseif "else" then
      local packed = lazy.pack(core.seq(coll))
      local len = packed.n
      local _475_
      do
        packed["n"] = nil
        _475_ = packed
      end
      return vec_2a(itable(_475_, {["fast-index?"] = true}), len)
    else
      return nil
    end
  end
  vec0 = core.vec
  vec = core.vec
end
local vector
do
  local vector0 = nil
  core.vector = function(...)
    local _let_477_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_52_auto = _let_477_.list
    local args = list_52_auto(...)
    return vec(args)
  end
  vector0 = core.vector
  vector = core.vector
end
local nth
do
  local nth0 = nil
  core.nth = function(...)
    local case_479_ = select("#", ...)
    if (case_479_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "core.nth"))
    elseif (case_479_ == 1) then
      return error(("Wrong number of args (%s) passed to %s"):format(1, "core.nth"))
    elseif (case_479_ == 2) then
      local coll, i = ...
      if vector_3f(coll) then
        if ((i < 1) or (length_2a(coll) < i)) then
          return error(string.format("index %d is out of bounds", i))
        else
          return coll[i]
        end
      elseif string_3f(coll) then
        return nth0(vec(coll), i)
      elseif seq_3f(coll) then
        return nth0(vec(coll), i)
      elseif "else" then
        return error("expected an indexed collection")
      else
        return nil
      end
    elseif (case_479_ == 3) then
      local coll, i, not_found = ...
      assert(int_3f(i), "expected an integer key")
      if vector_3f(coll) then
        return (coll[i] or not_found)
      elseif string_3f(coll) then
        return nth0(vec(coll), i, not_found)
      elseif seq_3f(coll) then
        return nth0(vec(coll), i, not_found)
      elseif "else" then
        return error("expected an indexed collection")
      else
        return nil
      end
    else
      local _ = case_479_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "core.nth"))
    end
  end
  nth0 = core.nth
  nth = core.nth
end
local seq_2a
local function seq_2a0(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "seq*"))
    else
    end
  end
  do
    local case_485_ = getmetatable(x)
    if (nil ~= case_485_) then
      local mt = case_485_
      mt["cljlib/type"] = "seq"
      local function _486_(s, v)
        return core.cons(v, s)
      end
      mt["cljlib/conj"] = _486_
      local function _487_()
        return core.list()
      end
      mt["cljlib/empty"] = _487_
    else
    end
  end
  return x
end
seq_2a = seq_2a0
local seq
do
  local seq0 = nil
  core.seq = function(...)
    local coll = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.seq"))
      else
      end
    end
    local function _491_(...)
      local case_490_ = getmetatable(coll)
      if ((_G.type(case_490_) == "table") and (nil ~= case_490_["cljlib/seq"])) then
        local f = case_490_["cljlib/seq"]
        return f(coll)
      else
        local _ = case_490_
        if lazy["seq?"](coll) then
          return lazy.seq(coll)
        elseif map_3f(coll) then
          return lazy.map(vec, coll)
        elseif "else" then
          return lazy.seq(coll)
        else
          return nil
        end
      end
    end
    return seq_2a(_491_(...))
  end
  seq0 = core.seq
  seq = core.seq
end
core.rseq = function(...)
  local rev = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.rseq"))
    else
    end
  end
  return seq_2a(lazy.rseq(rev))
end
local lazy_seq_2a
do
  local lazy_seq_2a0 = nil
  core["lazy-seq*"] = function(...)
    local f = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.lazy-seq*"))
      else
      end
    end
    return seq_2a(lazy["lazy-seq*"](f))
  end
  lazy_seq_2a0 = core["lazy-seq*"]
  lazy_seq_2a = core["lazy-seq*"]
end
local first
do
  local first0 = nil
  core.first = function(...)
    local coll = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.first"))
      else
      end
    end
    return lazy.first(seq(coll))
  end
  first0 = core.first
  first = core.first
end
local rest
do
  local rest0 = nil
  core.rest = function(...)
    local coll = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.rest"))
      else
      end
    end
    return seq_2a(lazy.rest(seq(coll)))
  end
  rest0 = core.rest
  rest = core.rest
end
local next_2a
local function next_2a0(...)
  local s = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "next*"))
    else
    end
  end
  return seq_2a(lazy.next(s))
end
next_2a = next_2a0
core.next = next_2a
core.second = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.second"))
    else
    end
  end
  return first(next_2a(x))
end
core.ffirst = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.ffirst"))
    else
    end
  end
  return first(first(x))
end
core.nfirst = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.nfirst"))
    else
    end
  end
  return first(next_2a(x))
end
core.nnext = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.nnext"))
    else
    end
  end
  return next_2a(next_2a(x))
end
core["counted?"] = function(...)
  local coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.counted?"))
    else
    end
  end
  local case_504_ = getmetatable(coll)
  if ((_G.type(case_504_) == "table") and (case_504_["cljlib/type"] == "vector")) then
    return true
  else
    local _ = case_504_
    return false
  end
end
core.count = function(...)
  local s = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.count"))
    else
    end
  end
  if core["counted?"](s) then
    return length_2a(s)
  else
    return lazy.count(s)
  end
end
core["bounded-count"] = function(...)
  local n, coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.bounded-count"))
    else
    end
  end
  if core["counted?"](coll) then
    return length_2a(coll)
  else
    local function recur(i, s)
      if (s and (i < n)) then
        return recur((i + 1), next_2a(s))
      else
        return i
      end
    end
    return recur(0, seq(coll))
  end
end
local cons
do
  local cons0 = nil
  core.cons = function(...)
    local head, tail = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.cons"))
      else
      end
    end
    return seq_2a(lazy.cons(head, tail))
  end
  cons0 = core.cons
  cons = core.cons
end
core.list = function(...)
  return seq_2a(lazy.list(...))
end
local list = core.list
core["list*"] = function(...)
  local _let_512_ = require("io.gitlab.andreyorst.cljlib.core")
  local list_52_auto = _let_512_.list
  local args = list_52_auto(...)
  return seq_2a(apply(lazy["list*"], args))
end
local last
do
  local last0 = nil
  core.last = function(...)
    local coll = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.last"))
      else
      end
    end
    local case_514_ = next_2a(coll)
    if (nil ~= case_514_) then
      local coll_2a = case_514_
      return last0(coll_2a)
    else
      local _ = case_514_
      return first(coll)
    end
  end
  last0 = core.last
  last = core.last
end
core.peek = function(...)
  local coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.peek"))
    else
    end
  end
  if seq(coll) then
    if vector_3f(coll) then
      return coll[core.count(coll)]
    else
      return last(coll)
    end
  else
    return nil
  end
end
core.butlast = function(...)
  local coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.butlast"))
    else
    end
  end
  return seq(lazy["drop-last"](coll))
end
local map
do
  local map0 = nil
  core.map = function(...)
    local case_520_ = select("#", ...)
    if (case_520_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "core.map"))
    elseif (case_520_ == 1) then
      local f = ...
      local function fn_521_(...)
        local rf = ...
        do
          local cnt_69_auto = select("#", ...)
          if (1 ~= cnt_69_auto) then
            error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "fn_521_"))
          else
          end
        end
        local function fn_523_(...)
          local case_524_ = select("#", ...)
          if (case_524_ == 0) then
            return rf()
          elseif (case_524_ == 1) then
            local result = ...
            return rf(result)
          elseif (case_524_ == 2) then
            local result, input = ...
            return rf(result, f(input))
          else
            local _ = case_524_
            local _let_525_ = require("io.gitlab.andreyorst.cljlib.core")
            local list_51_auto = _let_525_.list
            local result, input = ...
            local inputs = list_51_auto(select(3, ...))
            return rf(result, apply(f, input, inputs))
          end
        end
        return fn_523_
      end
      return fn_521_
    elseif (case_520_ == 2) then
      local f, coll = ...
      return seq_2a(lazy.map(f, coll))
    else
      local _ = case_520_
      local _let_527_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_51_auto = _let_527_.list
      local f, coll = ...
      local colls = list_51_auto(select(3, ...))
      return seq_2a(apply(lazy.map, f, coll, colls))
    end
  end
  map0 = core.map
  map = core.map
end
core.mapv = function(...)
  local case_530_ = select("#", ...)
  if (case_530_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.mapv"))
  elseif (case_530_ == 1) then
    return error(("Wrong number of args (%s) passed to %s"):format(1, "core.mapv"))
  elseif (case_530_ == 2) then
    local f, coll = ...
    return core["persistent!"](core.transduce(map(f), core["conj!"], core.transient(vector()), coll))
  else
    local _ = case_530_
    local _let_531_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_51_auto = _let_531_.list
    local f, coll = ...
    local colls = list_51_auto(select(3, ...))
    return vec(apply(map, f, coll, colls))
  end
end
core["map-indexed"] = function(...)
  local case_533_ = select("#", ...)
  if (case_533_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.map-indexed"))
  elseif (case_533_ == 1) then
    local f = ...
    local function fn_534_(...)
      local rf = ...
      do
        local cnt_69_auto = select("#", ...)
        if (1 ~= cnt_69_auto) then
          error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "fn_534_"))
        else
        end
      end
      local i = -1
      local function fn_536_(...)
        local case_537_ = select("#", ...)
        if (case_537_ == 0) then
          return rf()
        elseif (case_537_ == 1) then
          local result = ...
          return rf(result)
        elseif (case_537_ == 2) then
          local result, input = ...
          i = (i + 1)
          return rf(result, f(i, input))
        else
          local _ = case_537_
          return error(("Wrong number of args (%s) passed to %s"):format(_, "fn_536_"))
        end
      end
      return fn_536_
    end
    return fn_534_
  elseif (case_533_ == 2) then
    local f, coll = ...
    return seq_2a(lazy["map-indexed"](f, coll))
  else
    local _ = case_533_
    return error(("Wrong number of args (%s) passed to %s"):format(_, "core.map-indexed"))
  end
end
core.mapcat = function(...)
  local case_540_ = select("#", ...)
  if (case_540_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.mapcat"))
  elseif (case_540_ == 1) then
    local f = ...
    return comp(map(f), core.cat)
  else
    local _ = case_540_
    local _let_541_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_51_auto = _let_541_.list
    local f = ...
    local colls = list_51_auto(select(2, ...))
    return seq_2a(apply(lazy.mapcat, f, colls))
  end
end
core.pmap = function(...)
  local case_544_ = select("#", ...)
  if (case_544_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.pmap"))
  elseif (case_544_ == 1) then
    return error(("Wrong number of args (%s) passed to %s"):format(1, "core.pmap"))
  elseif (case_544_ == 2) then
    local f, coll = ...
    local n = 8
    local rets
    local function _545_(x)
      local function _546_()
        return f(x)
      end
      return core.Future(_546_)
    end
    rets = map(_545_, coll)
    local step
    local function step0(_547_, fs)
      local x = _547_[1]
      local xs = (function (t, k) return ((getmetatable(t) or {}).__fennelrest or function (t, k) return {(table.unpack or unpack)(t, k)} end)(t, k) end)(_547_, 2)
      local vs = _547_
      local _let_548_ = require("io.gitlab.andreyorst.cljlib.core")
      local cons_154_auto = _let_548_.cons
      local list_155_auto = _let_548_.list
      local res_156_auto
      do
        local _let_549_ = require("io.gitlab.andreyorst.lazy-seq")
        local lazy_seq_1_auto = _let_549_["lazy-seq*"]
        local function _550_()
          local val_111_auto = seq(fs)
          if val_111_auto then
            local s = val_111_auto
            return cons(deref(x), step0(xs, rest(s)))
          else
            return map(deref, vs)
          end
        end
        res_156_auto = lazy_seq_1_auto(_550_)
      end
      do
        local case_552_ = getmetatable(res_156_auto)
        if (nil ~= case_552_) then
          local mt_157_auto = case_552_
          mt_157_auto["cljlib/type"] = "seq"
          local function _553_(s_158_auto, v_159_auto)
            return cons_154_auto(v_159_auto, s_158_auto)
          end
          mt_157_auto["cljlib/conj"] = _553_
          local function _554_()
            return list_155_auto()
          end
          mt_157_auto["cljlib/empty"] = _554_
        else
        end
      end
      return res_156_auto
    end
    step = step0
    return step(rets, core.drop(n, rets))
  else
    local _ = case_544_
    local _let_556_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_51_auto = _let_556_.list
    local f, coll = ...
    local colls = list_51_auto(select(3, ...))
    local step
    local function step0(cs)
      local _let_557_ = require("io.gitlab.andreyorst.cljlib.core")
      local cons_154_auto = _let_557_.cons
      local list_155_auto = _let_557_.list
      local res_156_auto
      do
        local _let_558_ = require("io.gitlab.andreyorst.lazy-seq")
        local lazy_seq_1_auto = _let_558_["lazy-seq*"]
        local function _559_()
          local ss = map(seq, cs)
          if core["every?"](identity, ss) then
            return cons(map(first, ss), step0(map(rest, ss)))
          else
            return nil
          end
        end
        res_156_auto = lazy_seq_1_auto(_559_)
      end
      do
        local case_561_ = getmetatable(res_156_auto)
        if (nil ~= case_561_) then
          local mt_157_auto = case_561_
          mt_157_auto["cljlib/type"] = "seq"
          local function _562_(s_158_auto, v_159_auto)
            return cons_154_auto(v_159_auto, s_158_auto)
          end
          mt_157_auto["cljlib/conj"] = _562_
          local function _563_()
            return list_155_auto()
          end
          mt_157_auto["cljlib/empty"] = _563_
        else
        end
      end
      return res_156_auto
    end
    step = step0
    local function _565_(_241)
      return apply(f, _241)
    end
    return core.pmap(_565_, step(cons(coll, colls)))
  end
end
local filter
do
  local filter0 = nil
  core.filter = function(...)
    local case_567_ = select("#", ...)
    if (case_567_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "core.filter"))
    elseif (case_567_ == 1) then
      local pred = ...
      local function fn_568_(...)
        local rf = ...
        do
          local cnt_69_auto = select("#", ...)
          if (1 ~= cnt_69_auto) then
            error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "fn_568_"))
          else
          end
        end
        local function fn_570_(...)
          local case_571_ = select("#", ...)
          if (case_571_ == 0) then
            return rf()
          elseif (case_571_ == 1) then
            local result = ...
            return rf(result)
          elseif (case_571_ == 2) then
            local result, input = ...
            if pred(input) then
              return rf(result, input)
            else
              return result
            end
          else
            local _ = case_571_
            return error(("Wrong number of args (%s) passed to %s"):format(_, "fn_570_"))
          end
        end
        return fn_570_
      end
      return fn_568_
    elseif (case_567_ == 2) then
      local pred, coll = ...
      return seq_2a(lazy.filter(pred, coll))
    else
      local _ = case_567_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "core.filter"))
    end
  end
  filter0 = core.filter
  filter = core.filter
end
core.filterv = function(...)
  local pred, coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.filterv"))
    else
    end
  end
  return vec(filter(pred, coll))
end
local every_3f
do
  local every_3f0 = nil
  core["every?"] = function(...)
    local pred, coll = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.every?"))
      else
      end
    end
    return lazy["every?"](pred, coll)
  end
  every_3f0 = core["every?"]
  every_3f = core["every?"]
end
core["not-every?"] = function(...)
  local pred, coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.not-every?"))
    else
    end
  end
  return not every_3f(pred, coll)
end
core["max-key"] = function(...)
  local case_579_ = select("#", ...)
  if (case_579_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.max-key"))
  elseif (case_579_ == 1) then
    return error(("Wrong number of args (%s) passed to %s"):format(1, "core.max-key"))
  elseif (case_579_ == 2) then
    local _, x = ...
    return x
  elseif (case_579_ == 3) then
    local k, x, y = ...
    if (k(x) > k(y)) then
      return x
    else
      return y
    end
  else
    local _ = case_579_
    local _let_581_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_51_auto = _let_581_.list
    local k, x, y = ...
    local more = list_51_auto(select(4, ...))
    local kx = k(x)
    local ky = k(y)
    local function _582_(...)
      if (kx > ky) then
        return {x, kx}
      else
        return {y, ky}
      end
    end
    local _let_583_ = _582_(...)
    local v = _let_583_[1]
    local kv = _let_583_[2]
    local loop_2_584_ = v
    local v0 = loop_2_584_
    local loop_4_585_ = kv
    local kv0 = loop_4_585_
    local loop_6_586_ = more
    local more0 = loop_6_586_
    local function recur(v1, kv1, more1)
      if more1 then
        local w = first(more1)
        local kw = k(w)
        if (kw >= kv1) then
          return recur(w, kw, next_2a(more1))
        else
          return recur(v1, kv1, next_2a(more1))
        end
      else
        return v1
      end
    end
    return recur(loop_2_584_, loop_4_585_, loop_6_586_)
  end
end
core["min-key"] = function(...)
  local case_591_ = select("#", ...)
  if (case_591_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.min-key"))
  elseif (case_591_ == 1) then
    return error(("Wrong number of args (%s) passed to %s"):format(1, "core.min-key"))
  elseif (case_591_ == 2) then
    local _, x = ...
    return x
  elseif (case_591_ == 3) then
    local k, x, y = ...
    if (k(x) < k(y)) then
      return x
    else
      return y
    end
  else
    local _ = case_591_
    local _let_593_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_51_auto = _let_593_.list
    local k, x, y = ...
    local more = list_51_auto(select(4, ...))
    local kx = k(x)
    local ky = k(y)
    local function _594_(...)
      if (kx < ky) then
        return {x, kx}
      else
        return {y, ky}
      end
    end
    local _let_595_ = _594_(...)
    local v = _let_595_[1]
    local kv = _let_595_[2]
    local loop_2_596_ = v
    local v0 = loop_2_596_
    local loop_4_597_ = kv
    local kv0 = loop_4_597_
    local loop_6_598_ = more
    local more0 = loop_6_598_
    local function recur(v1, kv1, more1)
      if more1 then
        local w = first(more1)
        local kw = k(w)
        if (kw <= kv1) then
          return recur(w, kw, next_2a(more1))
        else
          return recur(v1, kv1, next_2a(more1))
        end
      else
        return v1
      end
    end
    return recur(loop_2_596_, loop_4_597_, loop_6_598_)
  end
end
local boolean
do
  local boolean0 = nil
  core.boolean = function(...)
    local x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.boolean"))
      else
      end
    end
    if x then
      return true
    else
      return false
    end
  end
  boolean0 = core.boolean
  boolean = core.boolean
end
core["every-pred"] = function(...)
  local case_604_ = select("#", ...)
  if (case_604_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.every-pred"))
  elseif (case_604_ == 1) then
    local p = ...
    local function ep1(...)
      local case_605_ = select("#", ...)
      if (case_605_ == 0) then
        return true
      elseif (case_605_ == 1) then
        local x = ...
        return boolean(p(x))
      elseif (case_605_ == 2) then
        local x, y = ...
        return boolean((p(x) and p(y)))
      elseif (case_605_ == 3) then
        local x, y, z = ...
        return boolean((p(x) and p(y) and p(z)))
      else
        local _ = case_605_
        local _let_606_ = require("io.gitlab.andreyorst.cljlib.core")
        local list_51_auto = _let_606_.list
        local x, y, z = ...
        local args = list_51_auto(select(4, ...))
        return boolean((ep1(x, y, z) and every_3f(p, args)))
      end
    end
    return ep1
  elseif (case_604_ == 2) then
    local p1, p2 = ...
    local function ep2(...)
      local case_608_ = select("#", ...)
      if (case_608_ == 0) then
        return true
      elseif (case_608_ == 1) then
        local x = ...
        return boolean((p1(x) and p2(x)))
      elseif (case_608_ == 2) then
        local x, y = ...
        return boolean((p1(x) and p1(y) and p2(x) and p2(y)))
      elseif (case_608_ == 3) then
        local x, y, z = ...
        return boolean((p1(x) and p1(y) and p1(z) and p2(x) and p2(y) and p2(z)))
      else
        local _ = case_608_
        local _let_609_ = require("io.gitlab.andreyorst.cljlib.core")
        local list_51_auto = _let_609_.list
        local x, y, z = ...
        local args = list_51_auto(select(4, ...))
        local and_610_ = ep2(x, y, z)
        if and_610_ then
          local function _611_(_241)
            return (p1(_241) and p2(_241))
          end
          and_610_ = every_3f(_611_, args)
        end
        return boolean(and_610_)
      end
    end
    return ep2
  elseif (case_604_ == 3) then
    local p1, p2, p3 = ...
    local function ep3(...)
      local case_613_ = select("#", ...)
      if (case_613_ == 0) then
        return true
      elseif (case_613_ == 1) then
        local x = ...
        return boolean((p1(x) and p2(x) and p3(x)))
      elseif (case_613_ == 2) then
        local x, y = ...
        return boolean((p1(x) and p1(y) and p2(x) and p2(y) and p3(x) and p3(y)))
      elseif (case_613_ == 3) then
        local x, y, z = ...
        return boolean((p1(x) and p1(y) and p1(z) and p2(x) and p2(y) and p2(z) and p3(x) and p3(y) and p3(z)))
      else
        local _ = case_613_
        local _let_614_ = require("io.gitlab.andreyorst.cljlib.core")
        local list_51_auto = _let_614_.list
        local x, y, z = ...
        local args = list_51_auto(select(4, ...))
        local and_615_ = ep3(x, y, z)
        if and_615_ then
          local function _616_(_241)
            return (p1(_241) and p2(_241) and p3(_241))
          end
          and_615_ = every_3f(_616_, args)
        end
        return boolean(and_615_)
      end
    end
    return ep3
  else
    local _ = case_604_
    local _let_618_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_51_auto = _let_618_.list
    local p1, p2, p3 = ...
    local ps = list_51_auto(select(4, ...))
    local ps0 = core["list*"](p1, p2, p3, ps)
    local function epn(...)
      local case_619_ = select("#", ...)
      if (case_619_ == 0) then
        return true
      elseif (case_619_ == 1) then
        local x = ...
        local function _620_()
          return x
        end
        return every_3f(_620_, ps0)
      elseif (case_619_ == 2) then
        local x, y = ...
        local function _621_()
          return (x and y)
        end
        return every_3f(_621_, ps0)
      elseif (case_619_ == 3) then
        local x, y, z = ...
        local function _622_()
          return (x and y and z)
        end
        return every_3f(_622_, ps0)
      else
        local _0 = case_619_
        local _let_623_ = require("io.gitlab.andreyorst.cljlib.core")
        local list_51_auto0 = _let_623_.list
        local x, y, z = ...
        local args = list_51_auto0(select(4, ...))
        local and_624_ = epn(x, y, z)
        if and_624_ then
          local function _625_(_241)
            return every_3f(_241, args)
          end
          and_624_ = every_3f(_625_, ps0)
        end
        return boolean(and_624_)
      end
    end
    return epn
  end
end
local some
do
  local some0 = nil
  core.some = function(...)
    local pred, coll = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.some"))
      else
      end
    end
    return lazy["some?"](pred, coll)
  end
  some0 = core.some
  some = core.some
end
core["not-any?"] = function(...)
  local pred, coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.not-any?"))
    else
    end
  end
  local function _630_(_241)
    return not pred(_241)
  end
  return some(_630_, coll)
end
local range
do
  local range0 = nil
  core.range = function(...)
    local case_631_ = select("#", ...)
    if (case_631_ == 0) then
      return seq_2a(lazy.range())
    elseif (case_631_ == 1) then
      local upper = ...
      return seq_2a(lazy.range(upper))
    elseif (case_631_ == 2) then
      local lower, upper = ...
      return seq_2a(lazy.range(lower, upper))
    elseif (case_631_ == 3) then
      local lower, upper, step = ...
      return seq_2a(lazy.range(lower, upper, step))
    else
      local _ = case_631_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "core.range"))
    end
  end
  range0 = core.range
  range = core.range
end
local concat
do
  local concat0 = nil
  core.concat = function(...)
    local _let_633_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_52_auto = _let_633_.list
    local colls = list_52_auto(...)
    return seq_2a(apply(lazy.concat, colls))
  end
  concat0 = core.concat
  concat = core.concat
end
core.reverse = function(...)
  local coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.reverse"))
    else
    end
  end
  return seq_2a(lazy.reverse(coll))
end
core.take = function(...)
  local case_635_ = select("#", ...)
  if (case_635_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.take"))
  elseif (case_635_ == 1) then
    local n = ...
    local function fn_636_(...)
      local rf = ...
      do
        local cnt_69_auto = select("#", ...)
        if (1 ~= cnt_69_auto) then
          error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "fn_636_"))
        else
        end
      end
      local n0 = n
      local function fn_638_(...)
        local case_639_ = select("#", ...)
        if (case_639_ == 0) then
          return rf()
        elseif (case_639_ == 1) then
          local result = ...
          return rf(result)
        elseif (case_639_ == 2) then
          local result, input = ...
          local result0
          if (0 < n0) then
            result0 = rf(result, input)
          else
            result0 = result
          end
          n0 = (n0 - 1)
          if not (0 < n0) then
            return core["ensure-reduced"](result0)
          else
            return result0
          end
        else
          local _ = case_639_
          return error(("Wrong number of args (%s) passed to %s"):format(_, "fn_638_"))
        end
      end
      return fn_638_
    end
    return fn_636_
  elseif (case_635_ == 2) then
    local n, coll = ...
    return seq_2a(lazy.take(n, coll))
  else
    local _ = case_635_
    return error(("Wrong number of args (%s) passed to %s"):format(_, "core.take"))
  end
end
core["take-while"] = function(...)
  local case_644_ = select("#", ...)
  if (case_644_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.take-while"))
  elseif (case_644_ == 1) then
    local pred = ...
    local function fn_645_(...)
      local rf = ...
      do
        local cnt_69_auto = select("#", ...)
        if (1 ~= cnt_69_auto) then
          error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "fn_645_"))
        else
        end
      end
      local function fn_647_(...)
        local case_648_ = select("#", ...)
        if (case_648_ == 0) then
          return rf()
        elseif (case_648_ == 1) then
          local result = ...
          return rf(result)
        elseif (case_648_ == 2) then
          local result, input = ...
          if pred(input) then
            return rf(result, input)
          else
            return core.reduced(result)
          end
        else
          local _ = case_648_
          return error(("Wrong number of args (%s) passed to %s"):format(_, "fn_647_"))
        end
      end
      return fn_647_
    end
    return fn_645_
  elseif (case_644_ == 2) then
    local pred, coll = ...
    return seq_2a(lazy["take-while"](pred, coll))
  else
    local _ = case_644_
    return error(("Wrong number of args (%s) passed to %s"):format(_, "core.take-while"))
  end
end
local drop
do
  local drop0 = nil
  core.drop = function(...)
    local case_652_ = select("#", ...)
    if (case_652_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "core.drop"))
    elseif (case_652_ == 1) then
      local n = ...
      local function fn_653_(...)
        local rf = ...
        do
          local cnt_69_auto = select("#", ...)
          if (1 ~= cnt_69_auto) then
            error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "fn_653_"))
          else
          end
        end
        local nv = n
        local function fn_655_(...)
          local case_656_ = select("#", ...)
          if (case_656_ == 0) then
            return rf()
          elseif (case_656_ == 1) then
            local result = ...
            return rf(result)
          elseif (case_656_ == 2) then
            local result, input = ...
            local n0 = nv
            nv = (nv - 1)
            if pos_3f(n0) then
              return result
            else
              return rf(result, input)
            end
          else
            local _ = case_656_
            return error(("Wrong number of args (%s) passed to %s"):format(_, "fn_655_"))
          end
        end
        return fn_655_
      end
      return fn_653_
    elseif (case_652_ == 2) then
      local n, coll = ...
      return seq_2a(lazy.drop(n, coll))
    else
      local _ = case_652_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "core.drop"))
    end
  end
  drop0 = core.drop
  drop = core.drop
end
core["drop-while"] = function(...)
  local case_660_ = select("#", ...)
  if (case_660_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.drop-while"))
  elseif (case_660_ == 1) then
    local pred = ...
    local function fn_661_(...)
      local rf = ...
      do
        local cnt_69_auto = select("#", ...)
        if (1 ~= cnt_69_auto) then
          error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "fn_661_"))
        else
        end
      end
      local dv = true
      local function fn_663_(...)
        local case_664_ = select("#", ...)
        if (case_664_ == 0) then
          return rf()
        elseif (case_664_ == 1) then
          local result = ...
          return rf(result)
        elseif (case_664_ == 2) then
          local result, input = ...
          local drop_3f = dv
          if (drop_3f and pred(input)) then
            return result
          else
            dv = nil
            return rf(result, input)
          end
        else
          local _ = case_664_
          return error(("Wrong number of args (%s) passed to %s"):format(_, "fn_663_"))
        end
      end
      return fn_663_
    end
    return fn_661_
  elseif (case_660_ == 2) then
    local pred, coll = ...
    return seq_2a(lazy["drop-while"](pred, coll))
  else
    local _ = case_660_
    return error(("Wrong number of args (%s) passed to %s"):format(_, "core.drop-while"))
  end
end
core["drop-last"] = function(...)
  local case_668_ = select("#", ...)
  if (case_668_ == 0) then
    return seq_2a(lazy["drop-last"]())
  elseif (case_668_ == 1) then
    local coll = ...
    return seq_2a(lazy["drop-last"](coll))
  elseif (case_668_ == 2) then
    local n, coll = ...
    return seq_2a(lazy["drop-last"](n, coll))
  else
    local _ = case_668_
    return error(("Wrong number of args (%s) passed to %s"):format(_, "core.drop-last"))
  end
end
core["take-last"] = function(...)
  local n, coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.take-last"))
    else
    end
  end
  return seq_2a(lazy["take-last"](n, coll))
end
core["take-nth"] = function(...)
  local case_671_ = select("#", ...)
  if (case_671_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.take-nth"))
  elseif (case_671_ == 1) then
    local n = ...
    local function fn_672_(...)
      local rf = ...
      do
        local cnt_69_auto = select("#", ...)
        if (1 ~= cnt_69_auto) then
          error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "fn_672_"))
        else
        end
      end
      local iv = -1
      local function fn_674_(...)
        local case_675_ = select("#", ...)
        if (case_675_ == 0) then
          return rf()
        elseif (case_675_ == 1) then
          local result = ...
          return rf(result)
        elseif (case_675_ == 2) then
          local result, input = ...
          iv = (iv + 1)
          if (0 == (iv % n)) then
            return rf(result, input)
          else
            return result
          end
        else
          local _ = case_675_
          return error(("Wrong number of args (%s) passed to %s"):format(_, "fn_674_"))
        end
      end
      return fn_674_
    end
    return fn_672_
  elseif (case_671_ == 2) then
    local n, coll = ...
    return seq_2a(lazy["take-nth"](n, coll))
  else
    local _ = case_671_
    return error(("Wrong number of args (%s) passed to %s"):format(_, "core.take-nth"))
  end
end
core["split-at"] = function(...)
  local n, coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.split-at"))
    else
    end
  end
  return vec(lazy["split-at"](n, coll))
end
core["split-with"] = function(...)
  local pred, coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.split-with"))
    else
    end
  end
  return vec(lazy["split-with"](pred, coll))
end
core.nthrest = function(...)
  local coll, n = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.nthrest"))
    else
    end
  end
  return seq_2a(lazy.nthrest(coll, n))
end
core.nthnext = function(...)
  local coll, n = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.nthnext"))
    else
    end
  end
  return lazy.nthnext(coll, n)
end
core.keep = function(...)
  local case_683_ = select("#", ...)
  if (case_683_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.keep"))
  elseif (case_683_ == 1) then
    local f = ...
    local function fn_684_(...)
      local rf = ...
      do
        local cnt_69_auto = select("#", ...)
        if (1 ~= cnt_69_auto) then
          error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "fn_684_"))
        else
        end
      end
      local function fn_686_(...)
        local case_687_ = select("#", ...)
        if (case_687_ == 0) then
          return rf()
        elseif (case_687_ == 1) then
          local result = ...
          return rf(result)
        elseif (case_687_ == 2) then
          local result, input = ...
          local v = f(input)
          if nil_3f(v) then
            return result
          else
            return rf(result, v)
          end
        else
          local _ = case_687_
          return error(("Wrong number of args (%s) passed to %s"):format(_, "fn_686_"))
        end
      end
      return fn_686_
    end
    return fn_684_
  elseif (case_683_ == 2) then
    local f, coll = ...
    return seq_2a(lazy.keep(f, coll))
  else
    local _ = case_683_
    return error(("Wrong number of args (%s) passed to %s"):format(_, "core.keep"))
  end
end
core["keep-indexed"] = function(...)
  local case_691_ = select("#", ...)
  if (case_691_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.keep-indexed"))
  elseif (case_691_ == 1) then
    local f = ...
    local function fn_692_(...)
      local rf = ...
      do
        local cnt_69_auto = select("#", ...)
        if (1 ~= cnt_69_auto) then
          error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "fn_692_"))
        else
        end
      end
      local iv = -1
      local function fn_694_(...)
        local case_695_ = select("#", ...)
        if (case_695_ == 0) then
          return rf()
        elseif (case_695_ == 1) then
          local result = ...
          return rf(result)
        elseif (case_695_ == 2) then
          local result, input = ...
          iv = (iv + 1)
          local v = f(iv, input)
          if nil_3f(v) then
            return result
          else
            return rf(result, v)
          end
        else
          local _ = case_695_
          return error(("Wrong number of args (%s) passed to %s"):format(_, "fn_694_"))
        end
      end
      return fn_694_
    end
    return fn_692_
  elseif (case_691_ == 2) then
    local f, coll = ...
    return seq_2a(lazy["keep-indexed"](f, coll))
  else
    local _ = case_691_
    return error(("Wrong number of args (%s) passed to %s"):format(_, "core.keep-indexed"))
  end
end
core.partition = function(...)
  local case_700_ = select("#", ...)
  if (case_700_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.partition"))
  elseif (case_700_ == 1) then
    return error(("Wrong number of args (%s) passed to %s"):format(1, "core.partition"))
  elseif (case_700_ == 2) then
    local n, coll = ...
    return map(seq_2a, lazy.partition(n, coll))
  elseif (case_700_ == 3) then
    local n, step, coll = ...
    return map(seq_2a, lazy.partition(n, step, coll))
  elseif (case_700_ == 4) then
    local n, step, pad, coll = ...
    return map(seq_2a, lazy.partition(n, step, pad, coll))
  else
    local _ = case_700_
    return error(("Wrong number of args (%s) passed to %s"):format(_, "core.partition"))
  end
end
local function array()
  local len = 0
  local function _702_()
    return len
  end
  local function _703_(self)
    while (0 ~= len) do
      self[len] = nil
      len = (len - 1)
    end
    return nil
  end
  local function _704_(self, val)
    len = (len + 1)
    self[len] = val
    return self
  end
  return setmetatable({}, {__len = _702_, __index = {clear = _703_, add = _704_}})
end
core["partition-by"] = function(...)
  local case_705_ = select("#", ...)
  if (case_705_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.partition-by"))
  elseif (case_705_ == 1) then
    local f = ...
    local function fn_706_(...)
      local rf = ...
      do
        local cnt_69_auto = select("#", ...)
        if (1 ~= cnt_69_auto) then
          error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "fn_706_"))
        else
        end
      end
      local a0 = array()
      local none = {}
      local pv = none
      local function fn_708_(...)
        local case_709_ = select("#", ...)
        if (case_709_ == 0) then
          return rf()
        elseif (case_709_ == 1) then
          local result = ...
          local function _710_(...)
            if empty_3f(a0) then
              return result
            else
              local v = vec(a0)
              a0:clear()
              return core.unreduced(rf(result, v))
            end
          end
          return rf(_710_(...))
        elseif (case_709_ == 2) then
          local result, input = ...
          local pval = pv
          local val = f(input)
          pv = val
          if ((pval == none) or (val == pval)) then
            a0:add(input)
            return result
          else
            local v = vec(a0)
            a0:clear()
            local ret = rf(result, v)
            if not core["reduced?"](ret) then
              a0:add(input)
            else
            end
            return ret
          end
        else
          local _ = case_709_
          return error(("Wrong number of args (%s) passed to %s"):format(_, "fn_708_"))
        end
      end
      return fn_708_
    end
    return fn_706_
  elseif (case_705_ == 2) then
    local f, coll = ...
    return map(seq_2a, lazy["partition-by"](f, coll))
  else
    local _ = case_705_
    return error(("Wrong number of args (%s) passed to %s"):format(_, "core.partition-by"))
  end
end
core["partition-all"] = function(...)
  local case_715_ = select("#", ...)
  if (case_715_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.partition-all"))
  elseif (case_715_ == 1) then
    local n = ...
    local function fn_716_(...)
      local rf = ...
      do
        local cnt_69_auto = select("#", ...)
        if (1 ~= cnt_69_auto) then
          error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "fn_716_"))
        else
        end
      end
      local a0 = array()
      local function fn_718_(...)
        local case_719_ = select("#", ...)
        if (case_719_ == 0) then
          return rf()
        elseif (case_719_ == 1) then
          local result = ...
          local function _720_(...)
            if (0 == #a0) then
              return result
            else
              local v = vec(a0)
              a0:clear()
              return core.unreduced(rf(result, v))
            end
          end
          return rf(_720_(...))
        elseif (case_719_ == 2) then
          local result, input = ...
          a0:add(input)
          if (n == #a0) then
            local v = vec(a0)
            a0:clear()
            return rf(result, v)
          else
            return result
          end
        else
          local _ = case_719_
          return error(("Wrong number of args (%s) passed to %s"):format(_, "fn_718_"))
        end
      end
      return fn_718_
    end
    return fn_716_
  elseif (case_715_ == 2) then
    local n, coll = ...
    return map(seq_2a, lazy["partition-all"](n, coll))
  elseif (case_715_ == 3) then
    local n, step, coll = ...
    return map(seq_2a, lazy["partition-all"](n, step, coll))
  else
    local _ = case_715_
    return error(("Wrong number of args (%s) passed to %s"):format(_, "core.partition-all"))
  end
end
core.reductions = function(...)
  local case_725_ = select("#", ...)
  if (case_725_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.reductions"))
  elseif (case_725_ == 1) then
    return error(("Wrong number of args (%s) passed to %s"):format(1, "core.reductions"))
  elseif (case_725_ == 2) then
    local f, coll = ...
    return seq_2a(lazy.reductions(f, coll))
  elseif (case_725_ == 3) then
    local f, init, coll = ...
    return seq_2a(lazy.reductions(f, init, coll))
  else
    local _ = case_725_
    return error(("Wrong number of args (%s) passed to %s"):format(_, "core.reductions"))
  end
end
local contains_3f
do
  local contains_3f0 = nil
  core["contains?"] = function(...)
    local coll, elt = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.contains?"))
      else
      end
    end
    return lazy["contains?"](coll, elt)
  end
  contains_3f0 = core["contains?"]
  contains_3f = core["contains?"]
end
core.distinct = function(...)
  local case_728_ = select("#", ...)
  if (case_728_ == 0) then
    local function fn_729_(...)
      local rf = ...
      do
        local cnt_69_auto = select("#", ...)
        if (1 ~= cnt_69_auto) then
          error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "fn_729_"))
        else
        end
      end
      local seen = setmetatable({}, {__index = deep_index})
      local function fn_731_(...)
        local case_732_ = select("#", ...)
        if (case_732_ == 0) then
          return rf()
        elseif (case_732_ == 1) then
          local result = ...
          return rf(result)
        elseif (case_732_ == 2) then
          local result, input = ...
          if seen[input] then
            return result
          else
            seen[input] = true
            return rf(result, input)
          end
        else
          local _ = case_732_
          return error(("Wrong number of args (%s) passed to %s"):format(_, "fn_731_"))
        end
      end
      return fn_731_
    end
    return fn_729_
  elseif (case_728_ == 1) then
    local coll = ...
    return seq_2a(lazy.distinct(coll))
  else
    local _ = case_728_
    return error(("Wrong number of args (%s) passed to %s"):format(_, "core.distinct"))
  end
end
local dedupe
do
  local dedupe0 = nil
  core.dedupe = function(...)
    local case_736_ = select("#", ...)
    if (case_736_ == 0) then
      local function fn_737_(...)
        local rf = ...
        do
          local cnt_69_auto = select("#", ...)
          if (1 ~= cnt_69_auto) then
            error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "fn_737_"))
          else
          end
        end
        local none = {}
        local pv = none
        local function fn_739_(...)
          local case_740_ = select("#", ...)
          if (case_740_ == 0) then
            return rf()
          elseif (case_740_ == 1) then
            local result = ...
            return rf(result)
          elseif (case_740_ == 2) then
            local result, input = ...
            local prior = pv
            pv = input
            if (prior == input) then
              return result
            else
              return rf(result, input)
            end
          else
            local _ = case_740_
            return error(("Wrong number of args (%s) passed to %s"):format(_, "fn_739_"))
          end
        end
        return fn_739_
      end
      return fn_737_
    elseif (case_736_ == 1) then
      local coll = ...
      return core.sequence(dedupe0(), coll)
    else
      local _ = case_736_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "core.dedupe"))
    end
  end
  dedupe0 = core.dedupe
  dedupe = core.dedupe
end
core["random-sample"] = function(...)
  local case_744_ = select("#", ...)
  if (case_744_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.random-sample"))
  elseif (case_744_ == 1) then
    local prob = ...
    local function _745_()
      return (math.random() < prob)
    end
    return filter(_745_)
  elseif (case_744_ == 2) then
    local prob, coll = ...
    local function _746_()
      return (math.random() < prob)
    end
    return filter(_746_, coll)
  else
    local _ = case_744_
    return error(("Wrong number of args (%s) passed to %s"):format(_, "core.random-sample"))
  end
end
local function shuffle_table(t)
  for i = #t, 2, -1 do
    local j = math.random(i)
    local ti = t[i]
    t[i] = t[j]
    t[j] = ti
  end
  return nil
end
core.shuffle = function(...)
  local coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.shuffle"))
    else
    end
  end
  local al = core["to-array"](coll)
  shuffle_table(al)
  return core.vec(al)
end
core.doall = function(...)
  local seq0 = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.doall"))
    else
    end
  end
  return seq_2a(lazy.doall(seq0))
end
core.dorun = function(...)
  local seq0 = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.dorun"))
    else
    end
  end
  return lazy.dorun(seq0)
end
core["run!"] = function(...)
  local proc, coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.run!"))
    else
    end
  end
  local function _752_(_241, _242)
    return proc(_242)
  end
  core.reduce(_752_, nil, coll)
  return nil
end
core["line-seq"] = function(...)
  local file = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.line-seq"))
    else
    end
  end
  return seq_2a(lazy["line-seq"](file))
end
core.iterate = function(...)
  local f, x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.iterate"))
    else
    end
  end
  return seq_2a(lazy.iterate(f, x))
end
core.remove = function(...)
  local case_755_ = select("#", ...)
  if (case_755_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.remove"))
  elseif (case_755_ == 1) then
    local pred = ...
    return filter(complement(pred))
  elseif (case_755_ == 2) then
    local pred, coll = ...
    return seq_2a(lazy.remove(pred, coll))
  else
    local _ = case_755_
    return error(("Wrong number of args (%s) passed to %s"):format(_, "core.remove"))
  end
end
core.cycle = function(...)
  local coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.cycle"))
    else
    end
  end
  return seq_2a(lazy.cycle(coll))
end
core["repeat"] = function(...)
  local case_758_ = select("#", ...)
  if (case_758_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.repeat"))
  elseif (case_758_ == 1) then
    local x = ...
    return seq_2a(lazy["repeat"](x))
  elseif (case_758_ == 2) then
    local n, x = ...
    return core.take(n, seq_2a(lazy["repeat"](x)))
  else
    local _ = case_758_
    return error(("Wrong number of args (%s) passed to %s"):format(_, "core.repeat"))
  end
end
core.repeatedly = function(...)
  local _let_760_ = require("io.gitlab.andreyorst.cljlib.core")
  local list_51_auto = _let_760_.list
  local f = ...
  local args = list_51_auto(select(2, ...))
  return seq_2a(apply(lazy.repeatedly, f, args))
end
local tree_seq
do
  local tree_seq0 = nil
  core["tree-seq"] = function(...)
    local branch_3f, children, root = ...
    do
      local cnt_69_auto = select("#", ...)
      if (3 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.tree-seq"))
      else
      end
    end
    return seq_2a(lazy["tree-seq"](branch_3f, children, root))
  end
  tree_seq0 = core["tree-seq"]
  tree_seq = core["tree-seq"]
end
core.flatten = function(...)
  local coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.flatten"))
    else
    end
  end
  return filter(complement(sequential_3f), rest(tree_seq(sequential_3f, seq, coll)))
end
core.interleave = function(...)
  local case_763_ = select("#", ...)
  if (case_763_ == 0) then
    return seq_2a(lazy.interleave())
  elseif (case_763_ == 1) then
    local s = ...
    return seq_2a(lazy.interleave(s))
  elseif (case_763_ == 2) then
    local s1, s2 = ...
    return seq_2a(lazy.interleave(s1, s2))
  else
    local _ = case_763_
    local _let_764_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_51_auto = _let_764_.list
    local s1, s2 = ...
    local ss = list_51_auto(select(3, ...))
    return seq_2a(apply(lazy.interleave, s1, s2, ss))
  end
end
core.interpose = function(...)
  local case_766_ = select("#", ...)
  if (case_766_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.interpose"))
  elseif (case_766_ == 1) then
    local sep = ...
    local function fn_767_(...)
      local rf = ...
      do
        local cnt_69_auto = select("#", ...)
        if (1 ~= cnt_69_auto) then
          error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "fn_767_"))
        else
        end
      end
      local started = false
      local function fn_769_(...)
        local case_770_ = select("#", ...)
        if (case_770_ == 0) then
          return rf()
        elseif (case_770_ == 1) then
          local result = ...
          return rf(result)
        elseif (case_770_ == 2) then
          local result, input = ...
          if started then
            local sepr = rf(result, sep)
            if core["reduced?"](sepr) then
              return sepr
            else
              return rf(sepr, input)
            end
          else
            started = true
            return rf(result, input)
          end
        else
          local _ = case_770_
          return error(("Wrong number of args (%s) passed to %s"):format(_, "fn_769_"))
        end
      end
      return fn_769_
    end
    return fn_767_
  elseif (case_766_ == 2) then
    local separator, coll = ...
    return seq_2a(lazy.interpose(separator, coll))
  else
    local _ = case_766_
    return error(("Wrong number of args (%s) passed to %s"):format(_, "core.interpose"))
  end
end
local halt_when
do
  local halt_when0 = nil
  core["halt-when"] = function(...)
    local case_775_ = select("#", ...)
    if (case_775_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "core.halt-when"))
    elseif (case_775_ == 1) then
      local pred = ...
      return halt_when0(pred, nil)
    elseif (case_775_ == 2) then
      local pred, retf = ...
      local function fn_776_(...)
        local rf = ...
        do
          local cnt_69_auto = select("#", ...)
          if (1 ~= cnt_69_auto) then
            error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "fn_776_"))
          else
          end
        end
        local halt
        local function _778_()
          return "#<halt>"
        end
        halt = setmetatable({}, {__fennelview = _778_})
        local function fn_779_(...)
          local case_780_ = select("#", ...)
          if (case_780_ == 0) then
            return rf()
          elseif (case_780_ == 1) then
            local result = ...
            if (map_3f(result) and contains_3f(result, halt)) then
              return result.value
            else
              return rf(result)
            end
          elseif (case_780_ == 2) then
            local result, input = ...
            if pred(input) then
              local _782_
              if retf then
                _782_ = retf(rf(result), input)
              else
                _782_ = input
              end
              return core.reduced({[halt] = true, value = _782_})
            else
              return rf(result, input)
            end
          else
            local _ = case_780_
            return error(("Wrong number of args (%s) passed to %s"):format(_, "fn_779_"))
          end
        end
        return fn_779_
      end
      return fn_776_
    else
      local _ = case_775_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "core.halt-when"))
    end
  end
  halt_when0 = core["halt-when"]
  halt_when = core["halt-when"]
end
core["realized?"] = function(...)
  local s = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.realized?"))
    else
    end
  end
  local case_788_ = getmetatable(s)
  if ((_G.type(case_788_) == "table") and (nil ~= case_788_["cljlib/realized?"])) then
    local f = case_788_["cljlib/realized?"]
    return f(s)
  else
    local and_789_ = (nil ~= case_788_)
    if and_789_ then
      local s0 = case_788_
      and_789_ = seq_3f(s0)
    end
    if and_789_ then
      local s0 = case_788_
      return lazy["realized?"](s0)
    else
      local _ = case_788_
      return error("object doesn't implement cljlib/realized? metamethod")
    end
  end
end
core.keys = function(...)
  local coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.keys"))
    else
    end
  end
  assert((map_3f(coll) or empty_3f(coll)), "expected a map")
  if empty_3f(coll) then
    return lazy.list()
  else
    return lazy.keys(coll)
  end
end
core.vals = function(...)
  local coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.vals"))
    else
    end
  end
  assert((map_3f(coll) or empty_3f(coll)), "expected a map")
  if empty_3f(coll) then
    return lazy.list()
  else
    return lazy.vals(coll)
  end
end
local find
do
  local find0 = nil
  core.find = function(...)
    local coll, key = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.find"))
      else
      end
    end
    assert((map_3f(coll) or empty_3f(coll)), "expected a map")
    local case_797_ = coll[key]
    if (nil ~= case_797_) then
      local v = case_797_
      return {key, v}
    else
      return nil
    end
  end
  find0 = core.find
  find = core.find
end
local reduce
do
  local reduce0 = nil
  core.reduce = function(...)
    local case_800_ = select("#", ...)
    if (case_800_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "core.reduce"))
    elseif (case_800_ == 1) then
      return error(("Wrong number of args (%s) passed to %s"):format(1, "core.reduce"))
    elseif (case_800_ == 2) then
      local f, coll = ...
      return lazy.reduce(f, seq(coll))
    elseif (case_800_ == 3) then
      local f, val, coll = ...
      return lazy.reduce(f, val, seq(coll))
    else
      local _ = case_800_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "core.reduce"))
    end
  end
  reduce0 = core.reduce
  reduce = core.reduce
end
local reduced
do
  local reduced0 = nil
  core.reduced = function(...)
    local value = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.reduced"))
      else
      end
    end
    local tmp_9_ = rdc.reduced(value)
    local function _803_(_241)
      return _241:unbox()
    end
    getmetatable(tmp_9_)["cljlib/deref"] = _803_
    return tmp_9_
  end
  reduced0 = core.reduced
  reduced = core.reduced
end
local reduced_3f
do
  local reduced_3f0 = nil
  core["reduced?"] = function(...)
    local x = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.reduced?"))
      else
      end
    end
    return rdc["reduced?"](x)
  end
  reduced_3f0 = core["reduced?"]
  reduced_3f = core["reduced?"]
end
core["ensure-reduced"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.ensure-reduced"))
    else
    end
  end
  if reduced_3f(x) then
    return x
  else
    return reduced(x)
  end
end
core.unreduced = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.unreduced"))
    else
    end
  end
  if reduced_3f(x) then
    return deref(x)
  else
    return x
  end
end
core["ensure-reduced"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.ensure-reduced"))
    else
    end
  end
  if reduced_3f(x) then
    return x
  else
    return reduced(x)
  end
end
local preserving_reduced
local function preserving_reduced0(...)
  local rf = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "preserving-reduced"))
    else
    end
  end
  local function fn_812_(...)
    local a0, b = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "fn_812_"))
      else
      end
    end
    local ret = rf(a0, b)
    if reduced_3f(ret) then
      return reduced(ret)
    else
      return ret
    end
  end
  return fn_812_
end
preserving_reduced = preserving_reduced0
core.cat = function(...)
  local rf = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.cat"))
    else
    end
  end
  local rrf = preserving_reduced(rf)
  local function fn_816_(...)
    local case_817_ = select("#", ...)
    if (case_817_ == 0) then
      return rf()
    elseif (case_817_ == 1) then
      local result = ...
      return rf(result)
    elseif (case_817_ == 2) then
      local result, input = ...
      return reduce(rrf, result, input)
    else
      local _ = case_817_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "fn_816_"))
    end
  end
  return fn_816_
end
core["reduce-kv"] = function(...)
  local f, val, s = ...
  do
    local cnt_69_auto = select("#", ...)
    if (3 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.reduce-kv"))
    else
    end
  end
  if map_3f(s) then
    local function _821_(res, _820_)
      local k = _820_[1]
      local v = _820_[2]
      return f(res, k, v)
    end
    return reduce(_821_, val, seq(s))
  else
    local function _823_(res, _822_)
      local k = _822_[1]
      local v = _822_[2]
      return f(res, k, v)
    end
    return reduce(_823_, val, map(vector, drop(1, range()), seq(s)))
  end
end
local completing
do
  local completing0 = nil
  core.completing = function(...)
    local case_825_ = select("#", ...)
    if (case_825_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "core.completing"))
    elseif (case_825_ == 1) then
      local f = ...
      return completing0(f, identity)
    elseif (case_825_ == 2) then
      local f, cf = ...
      local function fn_826_(...)
        local case_827_ = select("#", ...)
        if (case_827_ == 0) then
          return f()
        elseif (case_827_ == 1) then
          local x = ...
          return cf(x)
        elseif (case_827_ == 2) then
          local x, y = ...
          return f(x, y)
        else
          local _ = case_827_
          return error(("Wrong number of args (%s) passed to %s"):format(_, "fn_826_"))
        end
      end
      return fn_826_
    else
      local _ = case_825_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "core.completing"))
    end
  end
  completing0 = core.completing
  completing = core.completing
end
local transduce
do
  local transduce0 = nil
  core.transduce = function(...)
    local case_833_ = select("#", ...)
    if (case_833_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "core.transduce"))
    elseif (case_833_ == 1) then
      return error(("Wrong number of args (%s) passed to %s"):format(1, "core.transduce"))
    elseif (case_833_ == 2) then
      return error(("Wrong number of args (%s) passed to %s"):format(2, "core.transduce"))
    elseif (case_833_ == 3) then
      local xform, f, coll = ...
      return transduce0(xform, f, f(), coll)
    elseif (case_833_ == 4) then
      local xform, f, init, coll = ...
      local f0 = xform(f)
      return f0(reduce(f0, init, seq(coll)))
    else
      local _ = case_833_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "core.transduce"))
    end
  end
  transduce0 = core.transduce
  transduce = core.transduce
end
core.sequence = function(...)
  local case_835_ = select("#", ...)
  if (case_835_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.sequence"))
  elseif (case_835_ == 1) then
    local coll = ...
    if seq_3f(coll) then
      return coll
    else
      return (seq(coll) or list())
    end
  elseif (case_835_ == 2) then
    local xform, coll = ...
    local f
    local function _837_(_241, _242)
      return cons(_242, _241)
    end
    f = xform(completing(_837_))
    local function step(coll0)
      local val_113_auto = seq(coll0)
      if (nil ~= val_113_auto) then
        local s = val_113_auto
        local res = f(nil, first(s))
        if reduced_3f(res) then
          return f(deref(res))
        elseif seq_3f(res) then
          local function _838_()
            return step(rest(s))
          end
          return concat(res, lazy_seq_2a(_838_))
        elseif "else" then
          return step(rest(s))
        else
          return nil
        end
      else
        return f(nil)
      end
    end
    return (step(coll) or list())
  else
    local _ = case_835_
    local _let_841_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_51_auto = _let_841_.list
    local xform, coll = ...
    local colls = list_51_auto(select(3, ...))
    local f
    local function _842_(_241, _242)
      return cons(_242, _241)
    end
    f = xform(completing(_842_))
    local function step(colls0)
      if every_3f(seq, colls0) then
        local res = apply(f, nil, map(first, colls0))
        if reduced_3f(res) then
          return f(deref(res))
        elseif seq_3f(res) then
          local function _843_()
            return step(map(rest, colls0))
          end
          return concat(res, lazy_seq_2a(_843_))
        elseif "else" then
          return step(map(rest, colls0))
        else
          return nil
        end
      else
        return f(nil)
      end
    end
    return (step(cons(coll, colls)) or list())
  end
end
local function map__3etransient(immutable)
  local function _847_(map0)
    local removed = setmetatable({}, {__index = deep_index})
    local function _848_(_, k)
      if not removed[k] then
        return map0[k]
      else
        return nil
      end
    end
    local function _850_()
      return error("can't `conj` onto transient map, use `conj!`")
    end
    local function _851_()
      return error("can't `assoc` onto transient map, use `assoc!`")
    end
    local function _852_()
      return error("can't `dissoc` onto transient map, use `dissoc!`")
    end
    local function _854_(tmap, _853_)
      local k = _853_[1]
      local v = _853_[2]
      if (nil == v) then
        removed[k] = true
      else
        removed[k] = nil
      end
      tmap[k] = v
      return tmap
    end
    local function _856_(tmap, ...)
      for i = 1, select("#", ...), 2 do
        local k, v = select(i, ...)
        tmap[k] = v
        if (nil == v) then
          removed[k] = true
        else
          removed[k] = nil
        end
      end
      return tmap
    end
    local function _858_(tmap, ...)
      for i = 1, select("#", ...) do
        local k = select(i, ...)
        tmap[k] = nil
        removed[k] = true
      end
      return tmap
    end
    local function _859_(tmap)
      local t
      do
        local tbl_21_
        do
          local tbl_21_0 = {}
          for k, v in pairs(map0) do
            local k_22_, v_23_ = k, v
            if ((k_22_ ~= nil) and (v_23_ ~= nil)) then
              tbl_21_0[k_22_] = v_23_
            else
            end
          end
          tbl_21_ = tbl_21_0
        end
        for k, v in pairs(tmap) do
          local k_22_, v_23_ = k, v
          if ((k_22_ ~= nil) and (v_23_ ~= nil)) then
            tbl_21_[k_22_] = v_23_
          else
          end
        end
        t = tbl_21_
      end
      for k in pairs(removed) do
        t[k] = nil
      end
      local function _862_()
        local tbl_26_ = {}
        local i_27_ = 0
        for k in pairs_2a(tmap) do
          local val_28_ = k
          if (nil ~= val_28_) then
            i_27_ = (i_27_ + 1)
            tbl_26_[i_27_] = val_28_
          else
          end
        end
        return tbl_26_
      end
      for _, k in ipairs(_862_()) do
        tmap[k] = nil
      end
      local function _864_()
        return error("attempt to use transient after it was persistet")
      end
      local function _865_()
        return error("attempt to use transient after it was persistet")
      end
      setmetatable(tmap, {__index = _864_, __newindex = _865_})
      return immutable(itable(t))
    end
    return setmetatable({}, {__index = _848_, ["cljlib/type"] = "transient", ["cljlib/conj"] = _850_, ["cljlib/assoc"] = _851_, ["cljlib/dissoc"] = _852_, ["cljlib/conj!"] = _854_, ["cljlib/assoc!"] = _856_, ["cljlib/dissoc!"] = _858_, ["cljlib/persistent!"] = _859_})
  end
  return _847_
end
local function hash_map_2a(x)
  do
    local case_866_ = getmetatable(x)
    if (nil ~= case_866_) then
      local mt = case_866_
      mt["cljlib/type"] = "hash-map"
      mt["cljlib/editable"] = true
      local function _868_(t, _867_, ...)
        local k = _867_[1]
        local v = _867_[2]
        local function _869_(...)
          local kvs = {}
          for _, _870_ in ipairs_2a({...}) do
            local k0 = _870_[1]
            local v0 = _870_[2]
            table.insert(kvs, k0)
            table.insert(kvs, v0)
            kvs = kvs
          end
          return kvs
        end
        return apply(core.assoc, t, k, v, _869_(...))
      end
      mt["cljlib/conj"] = _868_
      mt["cljlib/transient"] = map__3etransient(hash_map_2a)
      local function _871_()
        return hash_map_2a(itable({}))
      end
      mt["cljlib/empty"] = _871_
    else
      local _ = case_866_
      hash_map_2a(setmetatable(x, {}))
    end
  end
  return x
end
local assoc
do
  local assoc0 = nil
  core.assoc = function(...)
    local case_876_ = select("#", ...)
    if (case_876_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "core.assoc"))
    elseif (case_876_ == 1) then
      return error(("Wrong number of args (%s) passed to %s"):format(1, "core.assoc"))
    elseif (case_876_ == 2) then
      return error(("Wrong number of args (%s) passed to %s"):format(2, "core.assoc"))
    elseif (case_876_ == 3) then
      local tbl, k, v = ...
      local case_877_ = getmetatable(tbl)
      if ((_G.type(case_877_) == "table") and (nil ~= case_877_["cljlib/assoc"])) then
        local f = case_877_["cljlib/assoc"]
        return f(tbl, k, v)
      else
        local _ = case_877_
        assert((nil_3f(tbl) or map_3f(tbl) or empty_3f(tbl)), "expected a map")
        assert(not nil_3f(k), "attempt to use nil as key")
        return hash_map_2a(itable.assoc((tbl or {}), k, v))
      end
    else
      local _ = case_876_
      local _let_879_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_51_auto = _let_879_.list
      local tbl, k, v = ...
      local kvs = list_51_auto(select(4, ...))
      local case_880_ = getmetatable(tbl)
      if ((_G.type(case_880_) == "table") and (nil ~= case_880_["cljlib/assoc"])) then
        local f = case_880_["cljlib/assoc"]
        return apply(f, tbl, k, v, kvs)
      else
        local _0 = case_880_
        assert((nil_3f(tbl) or map_3f(tbl) or empty_3f(tbl)), "expected a map")
        assert(not nil_3f(k), "attempt to use nil as key")
        return hash_map_2a(apply(itable.assoc, (tbl or {}), k, v, kvs))
      end
    end
  end
  assoc0 = core.assoc
  assoc = core.assoc
end
core["assoc-in"] = function(...)
  local tbl, key_seq, val = ...
  do
    local cnt_69_auto = select("#", ...)
    if (3 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.assoc-in"))
    else
    end
  end
  assert((nil_3f(tbl) or map_3f(tbl) or empty_3f(tbl)), "expected a map or nil")
  return hash_map_2a(itable["assoc-in"](tbl, key_seq, val))
end
core.update = function(...)
  local tbl, key, f = ...
  do
    local cnt_69_auto = select("#", ...)
    if (3 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.update"))
    else
    end
  end
  assert((nil_3f(tbl) or map_3f(tbl) or empty_3f(tbl)), "expected a map")
  return hash_map_2a(itable.update(tbl, key, f))
end
core["update-in"] = function(...)
  local tbl, key_seq, f = ...
  do
    local cnt_69_auto = select("#", ...)
    if (3 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.update-in"))
    else
    end
  end
  assert((nil_3f(tbl) or map_3f(tbl) or empty_3f(tbl)), "expected a map or nil")
  return hash_map_2a(itable["update-in"](tbl, key_seq, f))
end
local hash_map
do
  local hash_map0 = nil
  core["hash-map"] = function(...)
    local case_886_ = select("#", ...)
    if (case_886_ == 0) then
      return hash_map_2a(itable({}))
    else
      local _ = case_886_
      local _let_887_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_52_auto = _let_887_.list
      local kvs = list_52_auto(...)
      return apply(assoc, {}, kvs)
    end
  end
  hash_map0 = core["hash-map"]
  hash_map = core["hash-map"]
end
core["array-map"] = function(...)
  local case_889_ = select("#", ...)
  if (case_889_ == 0) then
    return hash_map(list())
  else
    local _ = case_889_
    local _let_890_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_52_auto = _let_890_.list
    local kvs = list_52_auto(...)
    local m = apply(hash_map, kvs)
    do
      local tmp_9_ = getmetatable(m)
      tmp_9_["__name"] = "ImmutableArrayMap"
      tmp_9_["cljlib/type"] = "ImmutableArrayMap"
    end
    return m
  end
end
core["create-struct"] = function(...)
  local _let_892_ = require("io.gitlab.andreyorst.cljlib.core")
  local list_52_auto = _let_892_.list
  local keys = list_52_auto(...)
  local b = vec(keys)
  do
    local tmp_9_ = getmetatable(b)
    tmp_9_["cljlib/type"] = "StructBasis"
    tmp_9_["__name"] = "StructBasis"
    local function _893_(_241)
      return ("#<" .. tostring(_241) .. ">")
    end
    tmp_9_["__fennelview"] = _893_
  end
  return b
end
local function struct_map_2a(s)
  do
    local tmp_9_ = getmetatable(s)
    tmp_9_["__name"] = "ImmutableStructMap"
    tmp_9_["cljlib/type"] = "ImmutableStructMap"
  end
  return s
end
core.struct = function(...)
  local _let_894_ = require("io.gitlab.andreyorst.cljlib.core")
  local list_51_auto = _let_894_.list
  local structure_basis = ...
  local vals = list_51_auto(select(2, ...))
  return struct_map_2a(core.zipmap(structure_basis, vals))
end
core["struct-map"] = function(...)
  local _let_895_ = require("io.gitlab.andreyorst.cljlib.core")
  local list_51_auto = _let_895_.list
  local structure_basis = ...
  local keyvals = list_51_auto(select(2, ...))
  assert(("StructBasis" == class_name(structure_basis)), "Expected a StructBasis as a first argument")
  return struct_map_2a(apply(hash_map, keyvals))
end
local get
do
  local get0 = nil
  core.get = function(...)
    local case_897_ = select("#", ...)
    if (case_897_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "core.get"))
    elseif (case_897_ == 1) then
      return error(("Wrong number of args (%s) passed to %s"):format(1, "core.get"))
    elseif (case_897_ == 2) then
      local tbl, key = ...
      return get0(tbl, key, nil)
    elseif (case_897_ == 3) then
      local tbl, key, not_found = ...
      local case_898_ = getmetatable(tbl)
      if ((_G.type(case_898_) == "table") and (nil ~= case_898_["cljlib/get"])) then
        local f = case_898_["cljlib/get"]
        return f(tbl, key, not_found)
      else
        local _ = case_898_
        assert((map_3f(tbl) or empty_3f(tbl)), "expected a map")
        return (tbl[key] or not_found)
      end
    else
      local _ = case_897_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "core.get"))
    end
  end
  get0 = core.get
  get = core.get
end
core.accessor = function(...)
  local s, key = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.accessor"))
    else
    end
  end
  local function _902_(k)
    return eq(k, key)
  end
  assert(first(filter(_902_, s)), "Not a key of struct")
  local function _903_(sm)
    return get(sm, key)
  end
  return _903_
end
local get_in
do
  local get_in0 = nil
  core["get-in"] = function(...)
    local case_905_ = select("#", ...)
    if (case_905_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "core.get-in"))
    elseif (case_905_ == 1) then
      return error(("Wrong number of args (%s) passed to %s"):format(1, "core.get-in"))
    elseif (case_905_ == 2) then
      local tbl, keys = ...
      return get_in0(tbl, keys, nil)
    elseif (case_905_ == 3) then
      local tbl, keys, not_found = ...
      assert((map_3f(tbl) or empty_3f(tbl)), "expected a map")
      local res, t, done = tbl, tbl, nil
      for _, k in ipairs_2a(keys) do
        if done then break end
        local case_906_ = get(t, k)
        if (nil ~= case_906_) then
          local v = case_906_
          res, t = v, v
        else
          local _0 = case_906_
          res, done = not_found, true
        end
      end
      return res
    else
      local _ = case_905_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "core.get-in"))
    end
  end
  get_in0 = core["get-in"]
  get_in = core["get-in"]
end
local dissoc
do
  local dissoc0 = nil
  core.dissoc = function(...)
    local case_909_ = select("#", ...)
    if (case_909_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "core.dissoc"))
    elseif (case_909_ == 1) then
      local tbl = ...
      return tbl
    elseif (case_909_ == 2) then
      local tbl, key = ...
      local case_910_ = getmetatable(tbl)
      if ((_G.type(case_910_) == "table") and (nil ~= case_910_["cljlib/dissoc"])) then
        local f = case_910_["cljlib/dissoc"]
        return f(tbl, key)
      else
        local _ = case_910_
        assert((map_3f(tbl) or empty_3f(tbl)), "expected a map")
        local function _911_(...)
          tbl[key] = nil
          return tbl
        end
        return hash_map_2a(_911_(...))
      end
    else
      local _ = case_909_
      local _let_913_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_51_auto = _let_913_.list
      local tbl, key = ...
      local keys = list_51_auto(select(3, ...))
      local case_914_ = getmetatable(tbl)
      if ((_G.type(case_914_) == "table") and (nil ~= case_914_["cljlib/dissoc"])) then
        local f = case_914_["cljlib/dissoc"]
        return apply(f, tbl, key, keys)
      else
        local _0 = case_914_
        return apply(dissoc0, dissoc0(tbl, key), keys)
      end
    end
  end
  dissoc0 = core.dissoc
  dissoc = core.dissoc
end
core.merge = function(...)
  local _let_917_ = require("io.gitlab.andreyorst.cljlib.core")
  local list_52_auto = _let_917_.list
  local maps = list_52_auto(...)
  if some(identity, maps) then
    local function _918_(a0, b)
      local tbl_21_ = a0
      for k, v in pairs_2a(b) do
        local k_22_, v_23_ = k, v
        if ((k_22_ ~= nil) and (v_23_ ~= nil)) then
          tbl_21_[k_22_] = v_23_
        else
        end
      end
      return tbl_21_
    end
    return hash_map_2a(itable(reduce(_918_, {}, maps)))
  else
    return nil
  end
end
core["merge-with"] = function(...)
  local _let_921_ = require("io.gitlab.andreyorst.cljlib.core")
  local list_51_auto = _let_921_.list
  local f = ...
  local maps = list_51_auto(select(2, ...))
  if some(identity, maps) then
    local merge_entry
    local function _923_(m, _922_)
      local k = _922_[1]
      local v = _922_[2]
      if contains_3f(m, k) then
        return assoc(m, k, f(get(m, k), v))
      else
        return assoc(m, k, v)
      end
    end
    merge_entry = _923_
    local merge2
    local function _925_(m1, m2)
      return core.reduce(merge_entry, (m1 or {}), seq(m2))
    end
    merge2 = _925_
    return core.reduce(merge2, maps)
  else
    return nil
  end
end
core.frequencies = function(...)
  local t = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.frequencies"))
    else
    end
  end
  return hash_map_2a(itable.frequencies(t))
end
core["group-by"] = function(...)
  local f, t = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.group-by"))
    else
    end
  end
  return hash_map_2a((itable["group-by"](f, t)))
end
core["select-keys"] = function(...)
  local map0, keyseq = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.select-keys"))
    else
    end
  end
  assert((map_3f(map0) or core["multifn?"](map0)), "Expected a map as the first argument")
  local function _930_(k)
    return {k, map0[k]}
  end
  return core.into(hash_map(), core.map(_930_), keyseq)
end
core.zipmap = function(...)
  local keys, vals = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.zipmap"))
    else
    end
  end
  return hash_map_2a(itable(lazy.zipmap(keys, vals)))
end
core.replace = function(...)
  local case_932_ = select("#", ...)
  if (case_932_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.replace"))
  elseif (case_932_ == 1) then
    local smap = ...
    local function _933_(_241)
      local val_111_auto = find(smap, _241)
      if val_111_auto then
        local e = val_111_auto
        return e[2]
      else
        return _241
      end
    end
    return map(_933_)
  elseif (case_932_ == 2) then
    local smap, coll = ...
    if vector_3f(coll) then
      local function _935_(res, v)
        local val_111_auto = find(smap, v)
        if val_111_auto then
          local e = val_111_auto
          table.insert(res, e[2])
          return res
        else
          table.insert(res, v)
          return res
        end
      end
      return vec_2a(itable(reduce(_935_, {}, coll)))
    else
      local function _937_(_241)
        local val_111_auto = find(smap, _241)
        if val_111_auto then
          local e = val_111_auto
          return e[2]
        else
          return _241
        end
      end
      return map(_937_, coll)
    end
  else
    local _ = case_932_
    return error(("Wrong number of args (%s) passed to %s"):format(_, "core.replace"))
  end
end
local conj
do
  local conj0 = nil
  core.conj = function(...)
    local case_941_ = select("#", ...)
    if (case_941_ == 0) then
      return vector()
    elseif (case_941_ == 1) then
      local s = ...
      return s
    elseif (case_941_ == 2) then
      local s, x = ...
      local case_942_ = getmetatable(s)
      if ((_G.type(case_942_) == "table") and (nil ~= case_942_["cljlib/conj"])) then
        local f = case_942_["cljlib/conj"]
        return f(s, x)
      else
        local _ = case_942_
        if vector_3f(s) then
          return vec_2a(itable.insert(s, x))
        elseif map_3f(s) then
          return apply(assoc, s, x)
        elseif nil_3f(s) then
          return cons(x, s)
        elseif empty_3f(s) then
          return vector(x)
        else
          return error(("expected collection, got " .. class(s)))
        end
      end
    else
      local _ = case_941_
      local _let_945_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_51_auto = _let_945_.list
      local s, x = ...
      local xs = list_51_auto(select(3, ...))
      return apply(conj0, conj0(s, x), xs)
    end
  end
  conj0 = core.conj
  conj = core.conj
end
core.disj = function(...)
  local case_947_ = select("#", ...)
  if (case_947_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.disj"))
  elseif (case_947_ == 1) then
    local Set = ...
    return Set
  elseif (case_947_ == 2) then
    local Set, key = ...
    local case_948_ = getmetatable(Set)
    if ((_G.type(case_948_) == "table") and (nil ~= case_948_["cljlib/disj"])) then
      local f = case_948_["cljlib/disj"]
      return f(Set, key)
    else
      local _ = case_948_
      return error(("disj is not supported on " .. class(Set)), 2)
    end
  else
    local _ = case_947_
    local _let_950_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_51_auto = _let_950_.list
    local Set, key = ...
    local keys = list_51_auto(select(3, ...))
    local case_951_ = getmetatable(Set)
    if ((_G.type(case_951_) == "table") and (nil ~= case_951_["cljlib/disj"])) then
      local f = case_951_["cljlib/disj"]
      return apply(f, Set, key, keys)
    else
      local _0 = case_951_
      return error(("disj is not supported on " .. class(Set)), 2)
    end
  end
end
core.pop = function(...)
  local coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.pop"))
    else
    end
  end
  local case_955_ = getmetatable(coll)
  if ((_G.type(case_955_) == "table") and (case_955_["cljlib/type"] == "seq")) then
    local case_956_ = seq(coll)
    if (nil ~= case_956_) then
      local s = case_956_
      return drop(1, s)
    else
      local _ = case_956_
      return error("can't pop empty list", 2)
    end
  elseif ((_G.type(case_955_) == "table") and (nil ~= case_955_["cljlib/pop"])) then
    local f = case_955_["cljlib/pop"]
    return f(coll)
  else
    local _ = case_955_
    return error(("pop is not supported on " .. class(coll)), 2)
  end
end
core.juxt = function(...)
  local case_959_ = select("#", ...)
  if (case_959_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.juxt"))
  elseif (case_959_ == 1) then
    local f = ...
    local function fn_960_(...)
      local case_961_ = select("#", ...)
      if (case_961_ == 0) then
        return vector(f())
      elseif (case_961_ == 1) then
        local x = ...
        return vector(f(x))
      elseif (case_961_ == 2) then
        local x, y = ...
        return vector(f(x, y))
      elseif (case_961_ == 3) then
        local x, y, z = ...
        return vector(f(x, y, z))
      else
        local _ = case_961_
        local _let_962_ = require("io.gitlab.andreyorst.cljlib.core")
        local list_51_auto = _let_962_.list
        local x, y, z = ...
        local args = list_51_auto(select(4, ...))
        return vector(apply(f, x, y, z, args))
      end
    end
    return fn_960_
  elseif (case_959_ == 2) then
    local f, g = ...
    local function fn_964_(...)
      local case_965_ = select("#", ...)
      if (case_965_ == 0) then
        return vector(f(), g())
      elseif (case_965_ == 1) then
        local x = ...
        return vector(f(x), g(x))
      elseif (case_965_ == 2) then
        local x, y = ...
        return vector(f(x, y), g(x, y))
      elseif (case_965_ == 3) then
        local x, y, z = ...
        return vector(f(x, y, z), g(x, y, z))
      else
        local _ = case_965_
        local _let_966_ = require("io.gitlab.andreyorst.cljlib.core")
        local list_51_auto = _let_966_.list
        local x, y, z = ...
        local args = list_51_auto(select(4, ...))
        return vector(apply(f, x, y, z, args), apply(g, x, y, z, args))
      end
    end
    return fn_964_
  elseif (case_959_ == 3) then
    local f, g, h = ...
    local function fn_968_(...)
      local case_969_ = select("#", ...)
      if (case_969_ == 0) then
        return vector(f(), g(), h())
      elseif (case_969_ == 1) then
        local x = ...
        return vector(f(x), g(x), h(x))
      elseif (case_969_ == 2) then
        local x, y = ...
        return vector(f(x, y), g(x, y), h(x, y))
      elseif (case_969_ == 3) then
        local x, y, z = ...
        return vector(f(x, y, z), g(x, y, z), h(x, y, z))
      else
        local _ = case_969_
        local _let_970_ = require("io.gitlab.andreyorst.cljlib.core")
        local list_51_auto = _let_970_.list
        local x, y, z = ...
        local args = list_51_auto(select(4, ...))
        return vector(apply(f, x, y, z, args), apply(g, x, y, z, args), apply(h, x, y, z, args))
      end
    end
    return fn_968_
  else
    local _ = case_959_
    local _let_972_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_51_auto = _let_972_.list
    local f, g, h = ...
    local fs = list_51_auto(select(4, ...))
    local fs0 = core["list*"](f, g, h, fs)
    local function fn_973_(...)
      local case_974_ = select("#", ...)
      if (case_974_ == 0) then
        local function _975_(_241, _242)
          return conj(_241, _242())
        end
        return reduce(_975_, vector(), fs0)
      elseif (case_974_ == 1) then
        local x = ...
        local function _976_(_241, _242)
          return conj(_241, _242(x))
        end
        return reduce(_976_, vector(), fs0)
      elseif (case_974_ == 2) then
        local x, y = ...
        local function _977_(_241, _242)
          return conj(_241, _242(x, y))
        end
        return reduce(_977_, vector(), fs0)
      elseif (case_974_ == 3) then
        local x, y, z = ...
        local function _978_(_241, _242)
          return conj(_241, _242(x, y, z))
        end
        return reduce(_978_, vector(), fs0)
      else
        local _0 = case_974_
        local _let_979_ = require("io.gitlab.andreyorst.cljlib.core")
        local list_51_auto0 = _let_979_.list
        local x, y, z = ...
        local args = list_51_auto0(select(4, ...))
        local function _980_(_241, _242)
          return conj(_241, apply(_242, x, y, z, args))
        end
        return reduce(_980_, vector(), fs0)
      end
    end
    return fn_973_
  end
end
local transient
do
  local transient0 = nil
  core.transient = function(...)
    local coll = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.transient"))
      else
      end
    end
    local case_984_ = getmetatable(coll)
    if ((_G.type(case_984_) == "table") and (case_984_["cljlib/editable"] == true) and (nil ~= case_984_["cljlib/transient"])) then
      local f = case_984_["cljlib/transient"]
      return f(coll)
    else
      local _ = case_984_
      return error("expected editable collection", 2)
    end
  end
  transient0 = core.transient
  transient = core.transient
end
local conj_21
do
  local conj_210 = nil
  core["conj!"] = function(...)
    local case_986_ = select("#", ...)
    if (case_986_ == 0) then
      return transient(vec_2a({}))
    elseif (case_986_ == 1) then
      local coll = ...
      return coll
    elseif (case_986_ == 2) then
      local coll, x = ...
      do
        local case_987_ = getmetatable(coll)
        if ((_G.type(case_987_) == "table") and (case_987_["cljlib/type"] == "transient") and (nil ~= case_987_["cljlib/conj!"])) then
          local f = case_987_["cljlib/conj!"]
          f(coll, x)
        elseif ((_G.type(case_987_) == "table") and (case_987_["cljlib/type"] == "transient")) then
          error("unsupported transient operation", 2)
        else
          local _ = case_987_
          error("expected transient collection", 2)
        end
      end
      return coll
    else
      local _ = case_986_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "core.conj!"))
    end
  end
  conj_210 = core["conj!"]
  conj_21 = core["conj!"]
end
core["assoc!"] = function(...)
  local _let_990_ = require("io.gitlab.andreyorst.cljlib.core")
  local list_51_auto = _let_990_.list
  local map0, k = ...
  local ks = list_51_auto(select(3, ...))
  do
    local case_991_ = getmetatable(map0)
    if ((_G.type(case_991_) == "table") and (case_991_["cljlib/type"] == "transient") and (nil ~= case_991_["cljlib/dissoc!"])) then
      local f = case_991_["cljlib/dissoc!"]
      apply(f, map0, k, ks)
    elseif ((_G.type(case_991_) == "table") and (case_991_["cljlib/type"] == "transient")) then
      error("unsupported transient operation", 2)
    else
      local _ = case_991_
      error("expected transient collection", 2)
    end
  end
  return map0
end
core["dissoc!"] = function(...)
  local _let_993_ = require("io.gitlab.andreyorst.cljlib.core")
  local list_51_auto = _let_993_.list
  local map0, k = ...
  local ks = list_51_auto(select(3, ...))
  do
    local case_994_ = getmetatable(map0)
    if ((_G.type(case_994_) == "table") and (case_994_["cljlib/type"] == "transient") and (nil ~= case_994_["cljlib/dissoc!"])) then
      local f = case_994_["cljlib/dissoc!"]
      apply(f, map0, k, ks)
    elseif ((_G.type(case_994_) == "table") and (case_994_["cljlib/type"] == "transient")) then
      error("unsupported transient operation", 2)
    else
      local _ = case_994_
      error("expected transient collection", 2)
    end
  end
  return map0
end
core["disj!"] = function(...)
  local case_996_ = select("#", ...)
  if (case_996_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.disj!"))
  elseif (case_996_ == 1) then
    local Set = ...
    return Set
  else
    local _ = case_996_
    local _let_997_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_51_auto = _let_997_.list
    local Set, key = ...
    local ks = list_51_auto(select(3, ...))
    local case_998_ = getmetatable(Set)
    if ((_G.type(case_998_) == "table") and (case_998_["cljlib/type"] == "transient") and (nil ~= case_998_["cljlib/disj!"])) then
      local f = case_998_["cljlib/disj!"]
      return apply(f, Set, key, ks)
    elseif ((_G.type(case_998_) == "table") and (case_998_["cljlib/type"] == "transient")) then
      return error("unsupported transient operation", 2)
    else
      local _0 = case_998_
      return error("expected transient collection", 2)
    end
  end
end
core["pop!"] = function(...)
  local coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.pop!"))
    else
    end
  end
  local case_1002_ = getmetatable(coll)
  if ((_G.type(case_1002_) == "table") and (case_1002_["cljlib/type"] == "transient") and (nil ~= case_1002_["cljlib/pop!"])) then
    local f = case_1002_["cljlib/pop!"]
    return f(coll)
  elseif ((_G.type(case_1002_) == "table") and (case_1002_["cljlib/type"] == "transient")) then
    return error("unsupported transient operation", 2)
  else
    local _ = case_1002_
    return error("expected transient collection", 2)
  end
end
local persistent_21
do
  local persistent_210 = nil
  core["persistent!"] = function(...)
    local coll = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.persistent!"))
      else
      end
    end
    local case_1005_ = getmetatable(coll)
    if ((_G.type(case_1005_) == "table") and (case_1005_["cljlib/type"] == "transient") and (nil ~= case_1005_["cljlib/persistent!"])) then
      local f = case_1005_["cljlib/persistent!"]
      return f(coll)
    else
      local _ = case_1005_
      return error("expected transient collection", 2)
    end
  end
  persistent_210 = core["persistent!"]
  persistent_21 = core["persistent!"]
end
core.into = function(...)
  local case_1007_ = select("#", ...)
  if (case_1007_ == 0) then
    return vector()
  elseif (case_1007_ == 1) then
    local to = ...
    return to
  elseif (case_1007_ == 2) then
    local to, from = ...
    local case_1008_ = getmetatable(to)
    if ((_G.type(case_1008_) == "table") and (case_1008_["cljlib/editable"] == true)) then
      return persistent_21(reduce(conj_21, transient(to), from))
    else
      local _ = case_1008_
      return reduce(conj, to, from)
    end
  elseif (case_1007_ == 3) then
    local to, xform, from = ...
    local case_1010_ = getmetatable(to)
    if ((_G.type(case_1010_) == "table") and (case_1010_["cljlib/editable"] == true)) then
      return persistent_21(transduce(xform, conj_21, transient(to), from))
    else
      local _ = case_1010_
      return transduce(xform, conj, to, from)
    end
  else
    local _ = case_1007_
    return error(("Wrong number of args (%s) passed to %s"):format(_, "core.into"))
  end
end
local function viewset(Set, view0, inspector, indent)
  if inspector.seen[Set] then
    return ("@set" .. inspector.seen[Set] .. "{...}")
  else
    local prefix
    local _1013_
    if inspector["visible-cycle?"](Set) then
      _1013_ = inspector.seen[Set]
    else
      _1013_ = ""
    end
    prefix = ("@set" .. _1013_ .. "{")
    local set_indent = #prefix
    local indent_str = string.rep(" ", set_indent)
    local lines
    do
      local tbl_26_ = {}
      local i_27_ = 0
      for v in pairs_2a(Set) do
        local val_28_ = (indent_str .. view0(v, inspector, (indent + set_indent), true))
        if (nil ~= val_28_) then
          i_27_ = (i_27_ + 1)
          tbl_26_[i_27_] = val_28_
        else
        end
      end
      lines = tbl_26_
    end
    lines[1] = (prefix .. string.gsub((lines[1] or ""), "^%s+", ""))
    lines[#lines] = (lines[#lines] .. "}")
    return lines
  end
end
local function hash_set__3etransient(immutable)
  local function _1017_(hset)
    local removed = setmetatable({}, {__index = deep_index})
    local function _1018_(_, k)
      if not removed[k] then
        return hset[k]
      else
        return nil
      end
    end
    local function _1020_()
      return error("can't `conj` onto transient set, use `conj!`")
    end
    local function _1021_()
      return error("can't `disj` a transient set, use `disj!`")
    end
    local function _1022_()
      return error("can't `assoc` onto transient set, use `assoc!`")
    end
    local function _1023_()
      return error("can't `dissoc` onto transient set, use `dissoc!`")
    end
    local function _1024_(thset, v)
      if (nil == v) then
        removed[v] = true
      else
        removed[v] = nil
      end
      thset[v] = v
      return thset
    end
    local function _1026_()
      return error("can't `dissoc!` a transient set")
    end
    local function _1027_(thset, ...)
      for i = 1, select("#", ...) do
        local k = select(i, ...)
        thset[k] = nil
        removed[k] = true
      end
      return thset
    end
    local function _1028_(thset)
      local t
      do
        local tbl_21_
        do
          local tbl_21_0 = {}
          for k, v in pairs(hset) do
            local k_22_, v_23_ = k, v
            if ((k_22_ ~= nil) and (v_23_ ~= nil)) then
              tbl_21_0[k_22_] = v_23_
            else
            end
          end
          tbl_21_ = tbl_21_0
        end
        for k, v in pairs(thset) do
          local k_22_, v_23_ = k, v
          if ((k_22_ ~= nil) and (v_23_ ~= nil)) then
            tbl_21_[k_22_] = v_23_
          else
          end
        end
        t = tbl_21_
      end
      for k in pairs(removed) do
        t[k] = nil
      end
      local function _1031_()
        local tbl_26_ = {}
        local i_27_ = 0
        for k in pairs_2a(thset) do
          local val_28_ = k
          if (nil ~= val_28_) then
            i_27_ = (i_27_ + 1)
            tbl_26_[i_27_] = val_28_
          else
          end
        end
        return tbl_26_
      end
      for _, k in ipairs(_1031_()) do
        thset[k] = nil
      end
      local function _1033_()
        return error("attempt to use transient after it was persistet")
      end
      local function _1034_()
        return error("attempt to use transient after it was persistet")
      end
      setmetatable(thset, {__index = _1033_, __newindex = _1034_})
      return immutable(itable(t))
    end
    return setmetatable({}, {__index = _1018_, ["cljlib/type"] = "transient", ["cljlib/conj"] = _1020_, ["cljlib/disj"] = _1021_, ["cljlib/assoc"] = _1022_, ["cljlib/dissoc"] = _1023_, ["cljlib/conj!"] = _1024_, ["cljlib/assoc!"] = _1026_, ["cljlib/disj!"] = _1027_, ["cljlib/persistent!"] = _1028_})
  end
  return _1017_
end
local function hash_set_2a(x)
  do
    local case_1035_ = getmetatable(x)
    if (nil ~= case_1035_) then
      local mt = case_1035_
      mt["cljlib/type"] = "hash-set"
      local function _1036_(s, v, ...)
        local function _1037_(...)
          local res = {}
          for _, v0 in ipairs({...}) do
            table.insert(res, v0)
            table.insert(res, v0)
          end
          return res
        end
        return hash_set_2a(itable.assoc(s, v, v, unpack_2a(_1037_(...))))
      end
      mt["cljlib/conj"] = _1036_
      local function _1038_(s, k, ...)
        local to_remove
        do
          local tbl_21_ = setmetatable({[k] = true}, {__index = deep_index})
          for _, k0 in ipairs({...}) do
            local k_22_, v_23_ = k0, true
            if ((k_22_ ~= nil) and (v_23_ ~= nil)) then
              tbl_21_[k_22_] = v_23_
            else
            end
          end
          to_remove = tbl_21_
        end
        local function _1040_(...)
          local res = {}
          for _, v in pairs(s) do
            if not to_remove[v] then
              table.insert(res, v)
              table.insert(res, v)
            else
            end
          end
          return res
        end
        return hash_set_2a(itable.assoc({}, unpack_2a(_1040_(...))))
      end
      mt["cljlib/disj"] = _1038_
      local function _1042_()
        return hash_set_2a(itable({}))
      end
      mt["cljlib/empty"] = _1042_
      mt["cljlib/editable"] = true
      mt["cljlib/transient"] = hash_set__3etransient(hash_set_2a)
      local function _1043_(s)
        local function _1044_(_241)
          if vector_3f(_241) then
            return _241[1]
          else
            return _241
          end
        end
        return map(_1044_, s)
      end
      mt["cljlib/seq"] = _1043_
      mt["__fennelview"] = viewset
      local function _1046_(s, i)
        local j = 1
        local vals = {}
        for v in pairs_2a(s) do
          if (j >= i) then
            table.insert(vals, v)
          else
            j = (j + 1)
          end
        end
        return core["hash-set"](unpack_2a(vals))
      end
      mt["__fennelrest"] = _1046_
    else
      local _ = case_1035_
      hash_set_2a(setmetatable(x, {}))
    end
  end
  return x
end
core["hash-set"] = function(...)
  local _let_1049_ = require("io.gitlab.andreyorst.cljlib.core")
  local list_52_auto = _let_1049_.list
  local xs = list_52_auto(...)
  local Set
  do
    local tbl_21_ = setmetatable({}, {__newindex = deep_newindex})
    for _, val in pairs_2a(xs) do
      local k_22_, v_23_ = val, val
      if ((k_22_ ~= nil) and (v_23_ ~= nil)) then
        tbl_21_[k_22_] = v_23_
      else
      end
    end
    Set = tbl_21_
  end
  return hash_set_2a(itable(Set))
end
local dispatcher, multifn_name, multifn_opts, multifn_methods = {}, {}, {}, {}
local Multifn
do
  local v_39_auto
  local function _1051_(self, ...)
    local dispatch_fn = rawget(self, dispatcher)
    local name = rawget(self, multifn_name)
    local options = rawget(self, multifn_opts)
    local methods = rawget(self, multifn_methods)
    local dispatch_value = dispatch_fn(...)
    local view0
    local function _1052_(_241)
      return view(_241, {["one-line"] = true})
    end
    view0 = _1052_
    return (methods[dispatch_value] or methods[(options.default or "default")] or error(("No method in multimethod '" .. name .. "' for dispatch value: " .. view0(dispatch_value)), 2))(...)
  end
  local function _1053_(_241)
    return ("#<" .. tostring(_241) .. ">")
  end
  v_39_auto = {__call = _1051_, __name = "Multifn", __fennelview = _1053_, ["cljlib/class"] = true}
  core.Multifn = v_39_auto
  Multifn = v_39_auto
end
Multifn.new = function(...)
  local self, name, dispatch_fn, opts = ...
  do
    local cnt_69_auto = select("#", ...)
    if (4 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "Multifn.new"))
    else
    end
  end
  self.__index = self
  self["cljlib/type"] = self
  local function _1055_(t, key)
    local res = nil
    for k, v in pairs(t) do
      if res then break end
      if eq(k, key) then
        res = v
      else
        res = nil
      end
    end
    return res
  end
  return setmetatable({[dispatcher] = dispatch_fn, [multifn_name] = name, [multifn_opts] = opts, [multifn_methods] = setmetatable({}, {__index = _1055_})}, self)
end
local multifn_3f
do
  local multifn_3f0 = nil
  core["multifn?"] = function(...)
    local mf = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.multifn?"))
      else
      end
    end
    local case_1058_ = class_name(mf)
    if (case_1058_ == "Multifn") then
      return true
    else
      local _ = case_1058_
      return false
    end
  end
  multifn_3f0 = core["multifn?"]
  multifn_3f = core["multifn?"]
end
core.defmethod = function(...)
  local multi_fn, dispatch_val, f = ...
  do
    local cnt_69_auto = select("#", ...)
    if (3 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.defmethod"))
    else
    end
  end
  assert(multifn_3f(multi_fn), "Expected a multimethod as the first argument")
  local methods = rawget(multi_fn, multifn_methods)
  if not methods[dispatch_val] then
    methods[dispatch_val] = f
    return multi_fn
  else
    return nil
  end
end
core["remove-method"] = function(...)
  local multimethod, dispatch_value = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.remove-method"))
    else
    end
  end
  if multifn_3f(multimethod) then
    local methods = rawget(multimethod, multifn_methods)
    methods[dispatch_value] = nil
  else
    error((tostring(multimethod) .. " is not a multifn"), 2)
  end
  return multimethod
end
core["remove-all-methods"] = function(...)
  local multimethod = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.remove-all-methods"))
    else
    end
  end
  if multifn_3f(multimethod) then
    local methods = rawget(multimethod, multifn_methods)
    for k, _ in pairs(methods) do
      methods[k] = nil
    end
  else
    error((tostring(multimethod) .. " is not a multifn"), 2)
  end
  return multimethod
end
core.methods = function(...)
  local multimethod = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.methods"))
    else
    end
  end
  if multifn_3f(multimethod) then
    local function _1067_(...)
      local tbl_21_ = {}
      for k, v in pairs(rawget(multimethod, multifn_methods)) do
        local k_22_, v_23_ = k, v
        if ((k_22_ ~= nil) and (v_23_ ~= nil)) then
          tbl_21_[k_22_] = v_23_
        else
        end
      end
      return tbl_21_
    end
    return hash_map_2a(itable(_1067_(...)))
  else
    return error((tostring(multimethod) .. " is not a multifn"), 2)
  end
end
core["get-method"] = function(...)
  local multimethod, dispatch_value = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.get-method"))
    else
    end
  end
  if multifn_3f(multimethod) then
    local methods = rawget(multimethod, multifn_methods)
    return (methods[dispatch_value] or methods.default)
  else
    return error((tostring(multimethod) .. " is not a multifn"), 2)
  end
end
local compare_2a
local function _1072_(x, _y)
  return class_name(x)
end
compare_2a = Multifn:new("compare*", _1072_, {})
local function fn_1073_(...)
  local x, _ = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "fn_1073_"))
    else
    end
  end
  return error(string.format("%s is not comparable", x))
end
core.defmethod(compare_2a, "default", fn_1073_)
local function fn_1075_(...)
  local x, y = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "fn_1075_"))
    else
    end
  end
  if (y == nil) then
    return 1
  else
    local y0
    do
      local case_1077_ = class(y)
      if (case_1077_ == "vector") then
        y0 = y
      elseif (case_1077_ == "table") then
        if core["vector?"](y) then
          y0 = y
        elseif core["empty?"](y) then
          y0 = {}
        else
          y0 = error(string.format("can't coerse %s to a vector", y))
        end
      else
        local _ = case_1077_
        y0 = error(string.format("can't coerse %s to a vector", y))
      end
    end
    if (length_2a(x) < length_2a(y0)) then
      return -1
    elseif (length_2a(x) > length_2a(y0)) then
      return 1
    else
      local res = 0
      for i = 1, length_2a(x) do
        if (res ~= 0) then break end
        res = compare_2a(x[i], y0[i])
      end
      return res
    end
  end
end
core.defmethod(compare_2a, "vector", fn_1075_)
local function fn_1082_(...)
  local x, y = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "fn_1082_"))
    else
    end
  end
  if (y == nil) then
    return 1
  elseif (core["vector?"](x) or core["empty?"](x)) then
    return compare_2a(core.vec(x), y)
  else
    return error("can't compare non-sequential tables")
  end
end
core.defmethod(compare_2a, "table", fn_1082_)
local function fn_1085_(...)
  local x, y = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "fn_1085_"))
    else
    end
  end
  if (x == y) then
    return 0
  elseif (y ~= nil) then
    return -1
  else
    return 1
  end
end
core.defmethod(compare_2a, "nil", fn_1085_)
local function fn_1088_(...)
  local x, y = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "fn_1088_"))
    else
    end
  end
  if (x == y) then
    return 0
  elseif x then
    return 1
  else
    return -1
  end
end
core.defmethod(compare_2a, "boolean", fn_1088_)
local function default_compare(...)
  local x, y = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "default-compare"))
    else
    end
  end
  if (y == nil) then
    return 1
  elseif (x == y) then
    return 0
  elseif (x < y) then
    return -1
  elseif (x > y) then
    return 1
  else
    return nil
  end
end
core.defmethod(compare_2a, "string", default_compare)
core.defmethod(compare_2a, "number", default_compare)
core.defmethod(compare_2a, "Ratio", default_compare)
core.defmethod(compare_2a, "BigDecimal", default_compare)
core.defmethod(compare_2a, "BigInteger", default_compare)
core.defmethod(compare_2a, "BigInt", default_compare)
local compare
do
  local compare0 = nil
  core.compare = function(...)
    local x, y = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.compare"))
      else
      end
    end
    return compare_2a(x, y)
  end
  compare0 = core.compare
  compare = core.compare
end
local Comparator
do
  local v_39_auto
  local function _1094_(_241)
    return ("#<" .. tostring(_241) .. ">")
  end
  local function _1096_(_1095_, x, y)
    local comp0 = _1095_.comp
    return comp0(x, y)
  end
  v_39_auto = {__name = "Comparator", __fennelview = _1094_, ["cljlib/class"] = true, __call = _1096_}
  core.Comparator = v_39_auto
  Comparator = v_39_auto
end
Comparator.new = function(...)
  local self, f = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "Comparator.new"))
    else
    end
  end
  if instance_3f(Comparator, f) then
    return f
  else
    self.__index = self
    self["cljlib/type"] = self
    if (f == compare) then
      return setmetatable({comp = f}, self)
    else
      local case_1098_ = class_name(f)
      if (case_1098_ == "Comparator") then
        return f
      elseif (case_1098_ == "function") then
        local function _1099_(x, y)
          if f(x, y) then
            return -1
          elseif f(y, x) then
            return 1
          elseif "else" then
            return 0
          else
            return nil
          end
        end
        return setmetatable({comp = _1099_}, self)
      else
        local _ = case_1098_
        return error("Expected a function")
      end
    end
  end
end
core.comparator = function(...)
  local pred = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.comparator"))
    else
    end
  end
  return Comparator:new(pred)
end
local function merge(arr, left, mid, right, compare0)
  local start2 = (mid + 1)
  if (compare0(arr[mid], arr[start2]) <= 0) then
    return nil
  else
    while ((left <= mid) and (start2 <= right)) do
      if (compare0(arr[left], arr[start2]) <= 0) then
        left = (left + 1)
      else
        local value = arr[start2]
        local index = start2
        while (index ~= left) do
          arr[index] = arr[(index - 1)]
          index = (index - 1)
        end
        arr[left] = value
        left = (left + 1)
        mid = (mid + 1)
        start2 = (start2 + 1)
      end
    end
    return nil
  end
end
local function merge_sort(arr, left, right, compare0)
  if (left < right) then
    local mid = m_2ffloor(((left + right) / 2))
    merge_sort(arr, left, mid, compare0)
    merge_sort(arr, (mid + 1), right, compare0)
    return merge(arr, left, mid, right, compare0)
  else
    return nil
  end
end
local sort
do
  local sort0 = nil
  core.sort = function(...)
    local case_1108_ = select("#", ...)
    if (case_1108_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "core.sort"))
    elseif (case_1108_ == 1) then
      local coll = ...
      return sort0(compare, coll)
    elseif (case_1108_ == 2) then
      local comparator, coll = ...
      if core.seq(coll) then
        local a0 = core["to-array"](coll)
        merge_sort(a0, 1, length_2a(a0), Comparator:new(comparator))
        return core.seq(a0)
      else
        return core.list()
      end
    else
      local _ = case_1108_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "core.sort"))
    end
  end
  sort0 = core.sort
  sort = core.sort
end
core["sort-by"] = function(...)
  local case_1112_ = select("#", ...)
  if (case_1112_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.sort-by"))
  elseif (case_1112_ == 1) then
    return error(("Wrong number of args (%s) passed to %s"):format(1, "core.sort-by"))
  elseif (case_1112_ == 2) then
    local keyfn, coll = ...
    return core["sort-by"](keyfn, core.compare, coll)
  elseif (case_1112_ == 3) then
    local keyfn, comparator, coll = ...
    local function _1113_(x, y)
      return comparator(keyfn(x), keyfn(y))
    end
    return sort(Comparator:new(_1113_), coll)
  else
    local _ = case_1112_
    return error(("Wrong number of args (%s) passed to %s"):format(_, "core.sort-by"))
  end
end
core.inst = function(...)
  local s = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.inst"))
    else
    end
  end
  local date = lua_inst(s)
  do
    local tmp_9_ = getmetatable(date)
    tmp_9_["cljlib/type"] = "inst"
    local function _1116_(_241)
      return ("#<inst: %04d-%s.%03d-00:00>"):format(_241.year, os.date("%m-%dT%H:%M:%S", os.time(_241)), _241.msec)
    end
    tmp_9_["__fennelview"] = _1116_
  end
  return date
end
core["inst?"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.inst?"))
    else
    end
  end
  local case_1118_ = getmetatable(x)
  if ((_G.type(case_1118_) == "table") and (case_1118_["cljlib/type"] == "inst")) then
    return true
  else
    local _ = case_1118_
    return false
  end
end
core["inst-ms"] = function(...)
  local inst = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.inst-ms"))
    else
    end
  end
  assert(core["inst?"](inst), "Expected a date instance")
  return ((os.time(inst) * 1000) + inst.msec)
end
local function start_task_runner(agent)
  local function _1121_()
    while (agent.status == "ready") do
      local _let_1122_ = a["<!"](agent.tasks)
      local f = _let_1122_[1]
      local args = _let_1122_[2]
      local task_ok_3f, state_or_msg = pcall(apply, f, agent.state, args)
      local task_ok_3f0, state_or_msg0
      if task_ok_3f then
        local validator_ok, err = pcall(agent.validator, state_or_msg)
        if validator_ok then
          task_ok_3f0, state_or_msg0 = true, state_or_msg
        else
          task_ok_3f0, state_or_msg0 = false, err
        end
      else
        task_ok_3f0, state_or_msg0 = false, state_or_msg
      end
      local case_1125_, case_1126_ = task_ok_3f0, state_or_msg0
      if ((case_1125_ == true) and true) then
        local _3fstate = case_1126_
        agent.state = _3fstate
      elseif ((case_1125_ == false) and (nil ~= case_1126_)) then
        local err = case_1126_
        if (agent["error-mode"] ~= "continue") then
          agent.status = "failed"
          agent.error = err
        else
        end
        if agent["error-handler"] then
          agent["error-handler"](agent, err)
        else
        end
      else
      end
    end
    return nil
  end
  a["go*"](_1121_)
  return nil
end
local agents = {}
core.agent = function(...)
  local _let_1130_ = require("io.gitlab.andreyorst.cljlib.core")
  local list_51_auto = _let_1130_.list
  local state = ...
  local options = list_51_auto(select(2, ...))
  local opts = apply(hash_map, options)
  local agent
  local _1131_
  if opts.validator then
    local function _1132_(newstate)
      if not opts.validator(newstate) then
        return error("Invalid reference state", 2)
      else
        return nil
      end
    end
    _1131_ = _1132_
  else
    local function _1134_()
      return true
    end
    _1131_ = _1134_
  end
  local or_1136_ = opts["error-handler"]
  if not or_1136_ then
    local function _1137_()
      return true
    end
    or_1136_ = _1137_
  end
  local function _1138_(self)
    return self.state
  end
  local function _1139_(agent0, task)
    if (agent0.status ~= "ready") then
      error(agent0.error, 3)
    else
    end
    local function _1141_()
      return a[">!"](agent0.tasks, task)
    end
    a["go*"](_1141_)
    return agent0
  end
  local function _1142_(agent0, view0, inspector, indent)
    local prefix = ("#<" .. string.gsub(tostring(agent0), "table", "agent") .. " ")
    local _1143_
    do
      inspector["one-line?"] = true
      _1143_ = inspector
    end
    return {(prefix .. view0({val = agent0.state, status = agent0.status}, _1143_, (indent + #prefix)) .. ">")}
  end
  agent = setmetatable({state = state, ["error-mode"] = (opts["error-mode"] or (opts["error-handler"] and "continue") or "fail"), ["og-validator"] = opts.validator, validator = _1131_, ["error-handler"] = or_1136_, status = "ready", tasks = a.chan()}, {["cljlib/type"] = "agent", ["cljlib/deref"] = _1138_, ["cljlib/send"] = _1139_, __fennelview = _1142_})
  start_task_runner(agent)
  agents[agent] = true
  return agent
end
core["set-error-handler!"] = function(...)
  local agent, handler_fn = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.set-error-handler!"))
    else
    end
  end
  agent["error-handler"] = handler_fn
  return nil
end
core["error-handler"] = function(...)
  local a0 = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.error-handler"))
    else
    end
  end
  return a0["error-handler"]
end
core["set-error-mode!"] = function(...)
  local agent, mode_keyword = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.set-error-mode!"))
    else
    end
  end
  agent["error-mode"] = mode_keyword
  return nil
end
core["error-mode"] = function(...)
  local a0 = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.error-mode"))
    else
    end
  end
  return a0["error-mode"]
end
core["agent-error"] = function(...)
  local agent = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.agent-error"))
    else
    end
  end
  return agent.error
end
core["restart-agent"] = function(...)
  local _let_1149_ = require("io.gitlab.andreyorst.cljlib.core")
  local list_51_auto = _let_1149_.list
  local agent, new_state = ...
  local options = list_51_auto(select(3, ...))
  if (agent.status ~= "failed") then
    error("Agent does not need a restart", 2)
  else
  end
  local opts = apply(hash_map, options)
  do
    agent["state"] = new_state
    agent["status"] = "ready"
    agent["error"] = nil
  end
  if opts["clear-actions"] then
    agent.tasks = a.chan()
  else
  end
  return start_task_runner(agent)
end
local send
do
  local send0 = nil
  core.send = function(...)
    local _let_1152_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_51_auto = _let_1152_.list
    local a0, f = ...
    local args = list_51_auto(select(3, ...))
    do
      local case_1153_ = getmetatable(a0)
      if ((_G.type(case_1153_) == "table") and (nil ~= case_1153_["cljlib/send"])) then
        local send1 = case_1153_["cljlib/send"]
        send1(a0, {f, args})
      else
        local _ = case_1153_
        error("object doesn't implement cljlib/send metamethod", 2)
      end
    end
    return a0
  end
  send0 = core.send
  send = core.send
end
core["shutdown-agents"] = function(...)
  do
    local cnt_69_auto = select("#", ...)
    if (0 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.shutdown-agents"))
    else
    end
  end
  for agent in pairs(agents) do
    agent.status = nil
    local function _1156_(x)
      return x
    end
    send(a, _1156_)
  end
  agents = {}
  return nil
end
core.await = function(...)
  local latch = {n = select("#", ...)}
  local count_down
  local function _1157_(agent)
    latch.n = (latch.n - 1)
    return agent
  end
  count_down = _1157_
  for i = 1, select("#", ...) do
    local a0 = select(i, ...)
    core.send(a0, count_down)
  end
  while (latch.n ~= 0) do
  end
  return nil
end
core["await-for"] = function(timeout, ...)
  local latch = {n = select("#", ...)}
  local count_down
  local function _1158_(agent)
    latch.n = (latch.n - 1)
    return agent
  end
  count_down = _1158_
  for i = 1, select("#", ...) do
    local a0 = select(i, ...)
    core.send(a0, count_down)
  end
  a["<!!"](a.timeout(timeout))
  return (latch.n == 0)
end
core.atom = function(...)
  local _let_1159_ = require("io.gitlab.andreyorst.cljlib.core")
  local list_51_auto = _let_1159_.list
  local x = ...
  local options = list_51_auto(select(2, ...))
  local opts = apply(hash_map, options)
  if (opts.validator and not opts.validator(x)) then
    error("Invalid reference state", 2)
  else
  end
  local _1161_
  if opts.validator then
    local function _1162_(newstate)
      if not opts.validator(newstate) then
        return error("Invalid reference state", 2)
      else
        return nil
      end
    end
    _1161_ = _1162_
  else
    local function _1164_(_newstate)
      return true
    end
    _1161_ = _1164_
  end
  local function _1166_(self)
    return self.val
  end
  local function _1167_(atom, view0, inspector, indent)
    local prefix = ("#<" .. string.gsub(tostring(atom), "table", "atom") .. " ")
    local _1168_
    do
      inspector["one-line?"] = true
      _1168_ = inspector
    end
    return {(prefix .. view0({val = atom.val, status = "ready"}, _1168_, (indent + #prefix)) .. ">")}
  end
  return setmetatable({val = x, ["og-validator"] = opts.validator, validator = _1161_}, {["cljlib/type"] = "atom", ["cljlib/deref"] = _1166_, __fennelview = _1167_})
end
core["swap!"] = function(atom, f, ...)
  local newval = f(atom.val, ...)
  atom.validator(newval)
  atom.val = newval
  return newval
end
core["reset!"] = function(...)
  local atom, newval = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.reset!"))
    else
    end
  end
  local function _1170_()
    return newval
  end
  return core["swap!"](atom, _1170_)
end
core["compare-and-set!"] = function(...)
  local atom, oldval, newval = ...
  do
    local cnt_69_auto = select("#", ...)
    if (3 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.compare-and-set!"))
    else
    end
  end
  local curval = deref(atom)
  if eq(curval, oldval) then
    core["reset!"](atom, newval)
    return true
  else
    return false
  end
end
core["reset-vals!"] = function(...)
  local atom, newval = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.reset-vals!"))
    else
    end
  end
  local oldval = deref(atom)
  return {oldval, core["reset!"](atom, newval)}
end
core["swap-vals!"] = function(atom, f, ...)
  local oldval = deref(atom)
  return {oldval, core["swap!"](atom, f, ...)}
end
core["volatile!"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.volatile!"))
    else
    end
  end
  local function _1175_(self)
    return self.val
  end
  local function _1176_(volatile, view0, inspector, indent)
    local prefix = ("#<" .. string.gsub(tostring(volatile), "table", "volatile") .. " ")
    local _1177_
    do
      inspector["one-line?"] = true
      _1177_ = inspector
    end
    return {(prefix .. view0({val = volatile.val, status = "ready"}, _1177_, (indent + #prefix)) .. ">")}
  end
  return setmetatable({val = x}, {["cljlib/type"] = "volatile", ["cljlib/deref"] = _1175_, __fennelview = _1176_})
end
core["vswap!"] = function(volatile, f, ...)
  local newval = f(volatile.val, ...)
  volatile.val = newval
  return newval
end
core["vreset!"] = function(...)
  local volatile, newval = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.vreset!"))
    else
    end
  end
  local function _1179_()
    return newval
  end
  return core["vswap!"](volatile, _1179_)
end
core["set-validator!"] = function(...)
  local agent_2fatom, validator_fn = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.set-validator!"))
    else
    end
  end
  if ((nil ~= validator_fn) and not validator_fn(deref(agent_2fatom))) then
    error("Invalid reference state", 2)
  else
  end
  agent_2fatom["og-validator"] = validator_fn
  local function _1182_(newstate)
    if not validator_fn(newstate) then
      return error("Invalid reference state", 2)
    else
      return nil
    end
  end
  agent_2fatom.validator = _1182_
  return nil
end
core["get-validator"] = function(...)
  local agent_2fatom = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.get-validator"))
    else
    end
  end
  return agent_2fatom["og-validator"]
end
local tap_ch = a.chan()
local mult_ch = a.mult(tap_ch)
local taps = {}
local remove_tap
do
  local remove_tap0 = nil
  core["remove-tap"] = function(...)
    local f = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.remove-tap"))
      else
      end
    end
    do
      local case_1186_ = taps[f]
      if (nil ~= case_1186_) then
        local c = case_1186_
        a.untap(mult_ch, c)
        a["close!"](c)
      else
      end
    end
    taps[f] = nil
    return nil
  end
  remove_tap0 = core["remove-tap"]
  remove_tap = core["remove-tap"]
end
core["add-tap"] = function(...)
  local f = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.add-tap"))
    else
    end
  end
  remove_tap(f)
  local c = a.chan()
  a.tap(mult_ch, c)
  local function _1189_()
    local function recur()
      local data = a["<!"](c)
      if data then
        f(data)
        return recur()
      else
        return nil
      end
    end
    return recur()
  end
  a["go*"](_1189_)
  taps[f] = c
  return nil
end
core["tap>"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.tap>"))
    else
    end
  end
  return a["offer!"](tap_ch, x)
end
core["random-uuid"] = function(...)
  do
    local cnt_69_auto = select("#", ...)
    if (0 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.random-uuid"))
    else
    end
  end
  return uuid["random-uuid"]()
end
core["uuid?"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.uuid?"))
    else
    end
  end
  return uuid["uuid?"](x)
end
core.Delay = function(fn1)
  local function _1194_(self)
    return (self.status ~= "pending")
  end
  local function _1195_(self)
    local case_1196_ = self.status
    if (case_1196_ == "ready") then
      return unpack_2a(self.val, 1, self.val.n)
    elseif (case_1196_ == "pending") then
      local ok, res
      local function _1197_()
        return pack_2a(fn1())
      end
      ok, res = pcall(_1197_)
      if ok then
        self.status = "ready"
      else
        self.status = "failed"
      end
      self.val = res
      if ok then
        return unpack_2a(res, 1, res.n)
      else
        return error(res)
      end
    elseif (case_1196_ == "failed") then
      return error(self.val)
    else
      return nil
    end
  end
  local function _1201_(d, view0, inspector, indent)
    local prefix = ("<" .. string.gsub(tostring(d), "table", "delay") .. " ")
    local _1202_
    do
      inspector["one-line?"] = true
      _1202_ = inspector
    end
    return {(prefix .. view0({val = d.val, status = d.status}, _1202_, (indent + #prefix)) .. ">")}
  end
  return setmetatable({status = "pending"}, {["cljlib/type"] = "delay", ["cljlib/realized?"] = _1194_, ["cljlib/deref"] = _1195_, __fennelview = _1201_})
end
core.force = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.force"))
    else
    end
  end
  local case_1204_ = getmetatable(x)
  if ((_G.type(case_1204_) == "table") and (case_1204_["cljlib/type"] == "delay") and (nil ~= case_1204_["cljlib/deref"])) then
    local f = case_1204_["cljlib/deref"]
    return f(x)
  else
    local _ = case_1204_
    return x
  end
end
core["delay?"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.delay?"))
    else
    end
  end
  local case_1207_ = getmetatable(x)
  if ((_G.type(case_1207_) == "table") and (case_1207_["cljlib/type"] == "delay")) then
    return true
  else
    local _ = case_1207_
    return false
  end
end
core.promise = function(...)
  do
    local cnt_69_auto = select("#", ...)
    if (0 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.promise"))
    else
    end
  end
  local p = a["promise-chan"]()
  local function fn_1210_(...)
    local case_1213_ = select("#", ...)
    if (case_1213_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "fn_1210_"))
    elseif (case_1213_ == 1) then
      local _ = ...
      local _1214_
      if a["main-thread?"]() then
        _1214_ = a["<!!"]
      else
        _1214_ = a["<!"]
      end
      return _1214_(p)
    elseif (case_1213_ == 2) then
      return error(("Wrong number of args (%s) passed to %s"):format(2, "fn_1210_"))
    elseif (case_1213_ == 3) then
      local _, timeout, timeout_val = ...
      local tout = a.timeout(timeout)
      if a["main-thread?"]() then
        local function _1216_()
          local case_1217_ = a["alts!"]({p, tout})
          if ((_G.type(case_1217_) == "table") and true and (case_1217_[2] == tout)) then
            local _0 = case_1217_[1]
            return timeout_val
          elseif ((_G.type(case_1217_) == "table") and (nil ~= case_1217_[1]) and (case_1217_[2] == p)) then
            local val = case_1217_[1]
            return val
          else
            return nil
          end
        end
        return a["<!!"](a["go*"](_1216_))
      else
        local case_1219_ = a["alts!"]({p, tout})
        if ((_G.type(case_1219_) == "table") and true and (case_1219_[2] == tout)) then
          local _0 = case_1219_[1]
          return timeout_val
        elseif ((_G.type(case_1219_) == "table") and (nil ~= case_1219_[1]) and (case_1219_[2] == p)) then
          local val = case_1219_[1]
          return val
        else
          return nil
        end
      end
    else
      local _ = case_1213_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "fn_1210_"))
    end
  end
  local function _1223_(self)
    return (self.status ~= "pending")
  end
  local function _1224_(self, val)
    local function _1225_()
      self.status = "ready"
      return nil
    end
    return a["put!"](p, val, _1225_)
  end
  local function _1226_(p0, view0, inspector, indent)
    local prefix = ("<" .. string.gsub(tostring(p0), "table", "promise") .. " ")
    local _1227_
    do
      inspector["one-line?"] = true
      _1227_ = inspector
    end
    return {(prefix .. view0({val = p0.val, status = p0.status}, _1227_, (indent + #prefix)) .. ">")}
  end
  return setmetatable({status = "pending"}, {["cljlib/type"] = "promise", ["cljlib/deref"] = fn_1210_, ["cljlib/realized?"] = _1223_, ["cljlib/deliver"] = _1224_, __fennelview = _1226_})
end
core.deliver = function(...)
  local promise, value = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.deliver"))
    else
    end
  end
  local case_1229_ = getmetatable(promise)
  if ((_G.type(case_1229_) == "table") and (case_1229_["cljlib/type"] == "promise") and (nil ~= case_1229_["cljlib/deliver"])) then
    local f = case_1229_["cljlib/deliver"]
    return f(promise, value)
  else
    return nil
  end
end
core.Future = function(fn1)
  local this = {status = "pending"}
  local thread
  local function _1231_()
    local ok_3f, res
    local function _1232_()
      return pack_2a(fn1())
    end
    ok_3f, res = pcall(_1232_)
    local _1233_
    if ok_3f then
      _1233_ = "ready"
    else
      _1233_ = "failed"
    end
    this["status"] = _1233_
    this["val"] = res
    return this
  end
  thread = a["go*"](_1231_)
  local unpack_result
  local function _1235_(this0)
    if ((_G.type(this0) == "table") and (this0.status == "ready") and (nil ~= this0.val)) then
      local val = this0.val
      if (nil ~= val) then
        return unpack_2a(val, 1, val.n)
      else
        return nil
      end
    elseif ((_G.type(this0) == "table") and (this0.status == "failed")) then
      return error(this0.val)
    else
      return nil
    end
  end
  unpack_result = _1235_
  local function _1238_(self)
    return (self.status ~= "pending")
  end
  local function _1239_(this0)
    a["close!"](thread)
    this0.cancelled = true
    return true
  end
  local function fn_1240_(...)
    local case_1243_ = select("#", ...)
    if (case_1243_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "fn_1240_"))
    elseif (case_1243_ == 1) then
      local this0 = ...
      if ((_G.type(this0) == "table") and (this0.status == "ready") and true) then
        local _3fval = this0.val
        if (nil ~= _3fval) then
          return unpack_2a(_3fval, 1, _3fval.n)
        else
          return nil
        end
      elseif ((_G.type(this0) == "table") and (this0.status == "pending")) then
        local _1245_
        if a["main-thread?"]() then
          _1245_ = a["<!!"]
        else
          _1245_ = a["<!"]
        end
        _1245_(thread)
        return unpack_result(this0)
      elseif ((_G.type(this0) == "table") and (this0.status == "failed")) then
        return error(this0.val)
      else
        return nil
      end
    elseif (case_1243_ == 2) then
      return error(("Wrong number of args (%s) passed to %s"):format(2, "fn_1240_"))
    elseif (case_1243_ == 3) then
      local this0, timeout, timeout_val = ...
      if ((_G.type(this0) == "table") and (this0.status == "ready") and true) then
        local _3fval = this0.val
        if (nil ~= _3fval) then
          return unpack_2a(_3fval, 1, _3fval.n)
        else
          return nil
        end
      elseif ((_G.type(this0) == "table") and (this0.status == "pending")) then
        local tout = a.timeout(timeout)
        if a["main-thread?"]() then
          local function _1249_()
            local case_1250_ = a["alts!"]({thread, tout})
            if ((_G.type(case_1250_) == "table") and true and (case_1250_[2] == tout)) then
              local _ = case_1250_[1]
              return timeout_val
            elseif ((_G.type(case_1250_) == "table") and true and (case_1250_[2] == thread)) then
              local _ = case_1250_[1]
              return unpack_result(this0)
            else
              return nil
            end
          end
          return a["<!!"](a["go*"](_1249_))
        else
          local case_1252_ = a["alts!"]({thread, tout})
          if ((_G.type(case_1252_) == "table") and true and (case_1252_[2] == tout)) then
            local _ = case_1252_[1]
            return timeout_val
          elseif ((_G.type(case_1252_) == "table") and true and (case_1252_[2] == thread)) then
            local _ = case_1252_[1]
            return unpack_result(this0)
          else
            return nil
          end
        end
      elseif ((_G.type(this0) == "table") and (this0.status == "failed")) then
        return error(this0.val)
      else
        return nil
      end
    else
      local _ = case_1243_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "fn_1240_"))
    end
  end
  local function _1257_(d, view0, inspector, indent)
    local prefix = ("<" .. string.gsub(tostring(d), "table", "future") .. " ")
    local _1258_
    do
      inspector["one-line?"] = true
      _1258_ = inspector
    end
    return {(prefix .. view0({val = d.val, status = d.status}, _1258_, (indent + #prefix)) .. ">")}
  end
  return setmetatable(this, {["cljlib/type"] = "future", ["cljlib/realized?"] = _1238_, ["cljlib/cancel"] = _1239_, ["cljlib/deref"] = fn_1240_, __fennelview = _1257_})
end
core["future-call"] = function(...)
  local f = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.future-call"))
    else
    end
  end
  return core.Future(f)
end
core["future?"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.future?"))
    else
    end
  end
  local case_1261_ = getmetatable(x)
  if ((_G.type(case_1261_) == "table") and (case_1261_["cljlib/type"] == "future")) then
    return true
  else
    local _ = case_1261_
    return false
  end
end
core["future-cancel"] = function(...)
  local f = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.future-cancel"))
    else
    end
  end
  local case_1264_ = getmetatable(f)
  if ((_G.type(case_1264_) == "table") and (case_1264_["cljlib/type"] == "future") and (nil ~= case_1264_["cljlib/cancel"])) then
    local cancel = case_1264_["cljlib/cancel"]
    return cancel(f)
  else
    local _ = case_1264_
    return error(("expected a Future, got: " .. type(f)))
  end
end
core["future-cancelled?"] = function(...)
  local f = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.future-cancelled?"))
    else
    end
  end
  local case_1267_ = getmetatable(f)
  if ((_G.type(case_1267_) == "table") and (case_1267_["cljlib/type"] == "future")) then
    return (f.cancelled or false)
  else
    local _ = case_1267_
    return error(("expected a Future, got: " .. type(f)))
  end
end
core["future-done?"] = function(...)
  local f = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.future-done?"))
    else
    end
  end
  local case_1270_ = getmetatable(f)
  if ((_G.type(case_1270_) == "table") and (case_1270_["cljlib/type"] == "future")) then
    return (f.status ~= "pending")
  else
    local _ = case_1270_
    return error(("expected a Future, got: " .. type(f)))
  end
end
core.pcalls = function(...)
  local _let_1272_ = require("io.gitlab.andreyorst.cljlib.core")
  local list_52_auto = _let_1272_.list
  local fns = list_52_auto(...)
  local function _1273_(_241)
    return _241()
  end
  return core.pmap(_1273_, fns)
end
core.trampoline = function(...)
  local case_1274_ = select("#", ...)
  if (case_1274_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.trampoline"))
  elseif (case_1274_ == 1) then
    local f = ...
    local ret = f()
    while fn_3f(ret) do
      ret = f()
    end
    return ret
  else
    local _ = case_1274_
    local _let_1275_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_51_auto = _let_1275_.list
    local f = ...
    local args = list_51_auto(select(2, ...))
    local function _1276_()
      return apply(f, args)
    end
    return core.trampoline(_1276_)
  end
end
core["sorted?"] = function(...)
  local coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.sorted?"))
    else
    end
  end
  local case_1279_ = getmetatable(coll)
  if ((_G.type(case_1279_) == "table") and (case_1279_["cljlib/sorted"] == true)) then
    return true
  else
    local _ = case_1279_
    return false
  end
end
SortedMap.__name = "SortedMap"
SortedMap["cljlib/class"] = true
SortedMap["cljlib/classname"] = "SortedMap"
SortedMap["cljlib/type"] = SortedMap
SortedMap["cljlib/sorted"] = true
local function _1281_(map0)
  return SortedMap:new(map0.compare)
end
SortedMap["cljlib/empty"] = _1281_
SortedMap["cljlib/conj"] = function(...)
  local case_1283_ = select("#", ...)
  if (case_1283_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "SortedMap.cljlib/conj"))
  elseif (case_1283_ == 1) then
    return error(("Wrong number of args (%s) passed to %s"):format(1, "SortedMap.cljlib/conj"))
  elseif (case_1283_ == 2) then
    local self, _let_1284_ = ...
    local _let_1285_ = _let_1284_
    local k = _let_1285_[1]
    local v = _let_1285_[2]
    return self:insert(k, v)
  else
    local _ = case_1283_
    local _let_1286_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_51_auto = _let_1286_.list
    local self, _let_1287_ = ...
    local _let_1288_ = _let_1287_
    local k = _let_1288_[1]
    local v = _let_1288_[2]
    local kvs = list_51_auto(select(3, ...))
    local res = self:insert(k, v)
    for _0, _1289_ in pairs(core.seq(kvs)) do
      local k0 = _1289_[1]
      local v0 = _1289_[2]
      res = res:insert(k0, v0)
    end
    return res
  end
end
SortedMap["cljlib/assoc"] = function(...)
  local case_1294_ = select("#", ...)
  if (case_1294_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "SortedMap.cljlib/assoc"))
  elseif (case_1294_ == 1) then
    return error(("Wrong number of args (%s) passed to %s"):format(1, "SortedMap.cljlib/assoc"))
  elseif (case_1294_ == 2) then
    return error(("Wrong number of args (%s) passed to %s"):format(2, "SortedMap.cljlib/assoc"))
  elseif (case_1294_ == 3) then
    local self, k, v = ...
    return self:insert(k, v)
  else
    local _ = case_1294_
    local _let_1295_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_51_auto = _let_1295_.list
    local self, k, v = ...
    local kvs = list_51_auto(select(4, ...))
    local res = self:insert(k, v)
    for _0, _1296_ in pairs(core.partition(2, kvs)) do
      local k0 = _1296_[1]
      local v0 = _1296_[2]
      print(res)
      res = res:insert(k0, v0)
    end
    return res
  end
end
SortedMap["cljlib/dissoc"] = function(...)
  local case_1299_ = select("#", ...)
  if (case_1299_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "SortedMap.cljlib/dissoc"))
  elseif (case_1299_ == 1) then
    return error(("Wrong number of args (%s) passed to %s"):format(1, "SortedMap.cljlib/dissoc"))
  elseif (case_1299_ == 2) then
    local self, k = ...
    return self:remove(k)
  else
    local _ = case_1299_
    local _let_1300_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_51_auto = _let_1300_.list
    local self, k = ...
    local ks = list_51_auto(select(3, ...))
    local res = self:remove(k)
    for _0, k0 in pairs(core.seq(ks)) do
      res = res:remove(k0)
    end
    return res
  end
end
SortedMap["cljlib/get"] = function(...)
  local self, key, not_found = ...
  do
    local cnt_69_auto = select("#", ...)
    if (3 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "SortedMap.cljlib/get"))
    else
    end
  end
  return self:get(key, not_found)
end
SortedMap.__call = function(self, key, not_found)
  return self:get(key, not_found)
end
SortedMap.__pairs = function(self)
  return self:inOrderIterator()
end
SortedMap.__fennelview = function(map0, view0, inspector, indent)
  local multiline_3f = false
  local items
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for k, v in pairs_2a(map0) do
      local val_28_
      do
        local k0 = (" " .. view0(k, inspector, (indent + 1), true))
        local v0 = view0(v, inspector, indent)
        multiline_3f = (multiline_3f or k0:find("\n") or v0:find("\n") or (inspector["line-length"] < length_2a((k0 .. " " .. v0))))
        val_28_ = {k0, v0}
      end
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    items = tbl_26_
  end
  local lines
  do
    local lines0 = {}
    for _, _1304_ in ipairs(items) do
      local k = _1304_[1]
      local v = _1304_[2]
      if multiline_3f then
        table.insert(lines0, k)
        table.insert(lines0, (" " .. v))
        lines0 = lines0
      else
        table.insert(lines0, (k .. " " .. v))
        lines0 = lines0
      end
    end
    lines = lines0
  end
  if next(lines) then
    lines[1] = ("{" .. string.gsub((lines[1] or ""), "^%s+", ""))
    lines[length_2a(lines)] = (lines[length_2a(lines)] .. "}")
    return lines
  else
    return {"{}"}
  end
end
SortedMap["cljlib/seq"] = function(...)
  local self = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "SortedMap.cljlib/seq"))
    else
    end
  end
  local nxt, coll = pairs_2a(self)
  local function recur(k)
    local k0, v = nxt(coll, k)
    if nil_3f(k0) then
      return nil
    else
      local function _1308_()
        return recur(k0)
      end
      return cons({k0, v}, lazy_seq_2a(_1308_))
    end
  end
  return lazy_seq_2a(recur)
end
core["sorted-map"] = function(...)
  local _let_1310_ = require("io.gitlab.andreyorst.cljlib.core")
  local list_52_auto = _let_1310_.list
  local keyvals = list_52_auto(...)
  local function _1312_(map0, _1311_)
    local k = _1311_[1]
    local v = _1311_[2]
    return map0:insert(k, v)
  end
  return reduce(_1312_, SortedMap:new(compare), core["partition-all"](2, keyvals))
end
core["sorted-map-by"] = function(...)
  local _let_1313_ = require("io.gitlab.andreyorst.cljlib.core")
  local list_51_auto = _let_1313_.list
  local comparator = ...
  local keyvals = list_51_auto(select(2, ...))
  local function _1315_(map0, _1314_)
    local k = _1314_[1]
    local v = _1314_[2]
    return map0:insert(k, v)
  end
  return reduce(_1315_, SortedMap:new(Comparator:new(comparator)), core["partition-all"](2, keyvals))
end
SortedSet.__name = "SortedSet"
SortedSet["cljlib/class"] = true
SortedSet["cljlib/classname"] = "SortedSet"
SortedSet["cljlib/type"] = SortedSet
SortedSet["cljlib/sorted"] = true
local function _1316_(s)
  return SortedSet:new(s.compare)
end
SortedSet["cljlib/empty"] = _1316_
SortedSet["cljlib/conj"] = function(...)
  local case_1318_ = select("#", ...)
  if (case_1318_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "SortedSet.cljlib/conj"))
  elseif (case_1318_ == 1) then
    return error(("Wrong number of args (%s) passed to %s"):format(1, "SortedSet.cljlib/conj"))
  elseif (case_1318_ == 2) then
    local self, k = ...
    return self:insert(k, k)
  else
    local _ = case_1318_
    local _let_1319_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_51_auto = _let_1319_.list
    local self, k = ...
    local ks = list_51_auto(select(3, ...))
    local res = self:insert(k, k)
    for _0, k0 in pairs(core.seq(ks)) do
      res = res:insert(k0, k0)
    end
    return res
  end
end
SortedSet["cljlib/disj"] = function(...)
  local case_1322_ = select("#", ...)
  if (case_1322_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "SortedSet.cljlib/disj"))
  elseif (case_1322_ == 1) then
    return error(("Wrong number of args (%s) passed to %s"):format(1, "SortedSet.cljlib/disj"))
  elseif (case_1322_ == 2) then
    local self, k = ...
    return self:remove(k)
  else
    local _ = case_1322_
    local _let_1323_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_51_auto = _let_1323_.list
    local self, k = ...
    local ks = list_51_auto(select(3, ...))
    local res = self:remove(k)
    for _0, k0 in pairs(core.seq(ks)) do
      res = res:remove(k0)
    end
    return res
  end
end
SortedSet["cljlib/get"] = function(...)
  local self, key, not_found = ...
  do
    local cnt_69_auto = select("#", ...)
    if (3 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "SortedSet.cljlib/get"))
    else
    end
  end
  return self:get(key, not_found)
end
SortedSet["cljlib/seq"] = function(...)
  local self = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "SortedSet.cljlib/seq"))
    else
    end
  end
  local nxt, coll = pairs_2a(self)
  local function recur(k)
    local k0 = nxt(coll, k)
    if nil_3f(k0) then
      return nil
    else
      local function _1327_()
        return recur(k0)
      end
      return cons(k0, lazy_seq_2a(_1327_))
    end
  end
  return lazy_seq_2a(recur)
end
SortedSet.__call = function(self, key, not_found)
  return self:get(key, not_found)
end
SortedSet.__pairs = function(self)
  return self:inOrderIterator()
end
SortedSet.__fennelview = function(Set, view0, inspector, indent)
  local prefix = "@set{"
  local set_indent = #prefix
  local indent_str = string.rep(" ", set_indent)
  local lines
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for v in pairs_2a(Set) do
      local val_28_ = (indent_str .. view0(v, inspector, (indent + set_indent), true))
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    lines = tbl_26_
  end
  if next(lines) then
    lines[1] = (prefix .. string.gsub((lines[1] or ""), "^%s+", ""))
    lines[length_2a(lines)] = (lines[length_2a(lines)] .. "}")
    return lines
  else
    return {(prefix .. "}")}
  end
end
core["sorted-set"] = function(...)
  local _let_1331_ = require("io.gitlab.andreyorst.cljlib.core")
  local list_52_auto = _let_1331_.list
  local keys = list_52_auto(...)
  local function _1332_(Set, k)
    return Set:insert(k, k)
  end
  return reduce(_1332_, SortedSet:new(compare), seq(keys))
end
core["sorted-set-by"] = function(...)
  local _let_1333_ = require("io.gitlab.andreyorst.cljlib.core")
  local list_51_auto = _let_1333_.list
  local comparator = ...
  local keys = list_51_auto(select(2, ...))
  local function _1334_(Set, k)
    return Set:insert(k, k)
  end
  return reduce(_1334_, SortedSet:new(Comparator:new(comparator)), seq(keys))
end
local function array_3f(array0)
  return ((vector_3f(array0) or core["empty?"](array0)) and not (getmetatable(array0) or {})["cljlib/type"])
end
local aget
do
  local aget0 = nil
  core.aget = function(...)
    local case_1336_ = select("#", ...)
    if (case_1336_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "core.aget"))
    elseif (case_1336_ == 1) then
      return error(("Wrong number of args (%s) passed to %s"):format(1, "core.aget"))
    elseif (case_1336_ == 2) then
      local array0, idx = ...
      assert(core["number?"](idx), "expected a number as an index")
      assert(array_3f(array0), "expected a Lua array")
      return array0[floor(idx)]
    else
      local _ = case_1336_
      local _let_1337_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_51_auto = _let_1337_.list
      local array0, idx = ...
      local idxs = list_51_auto(select(3, ...))
      local res = aget0(array0, idx)
      for _0, i in pairs_2a(idxs) do
        res = aget0(res, i)
      end
      return res
    end
  end
  aget0 = core.aget
  aget = core.aget
end
local aset
do
  local aset0 = nil
  core.aset = function(...)
    local case_1342_ = select("#", ...)
    if (case_1342_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "core.aset"))
    elseif (case_1342_ == 1) then
      return error(("Wrong number of args (%s) passed to %s"):format(1, "core.aset"))
    elseif (case_1342_ == 2) then
      return error(("Wrong number of args (%s) passed to %s"):format(2, "core.aset"))
    elseif (case_1342_ == 3) then
      local array0, idx, val = ...
      assert(core["number?"](idx), "expected a number as an index")
      assert(array_3f(array0), "expected a Lua array")
      array0[floor(idx)] = val
      return val
    else
      local _ = case_1342_
      local _let_1343_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_51_auto = _let_1343_.list
      local array0, idx, idx2 = ...
      local idxs = list_51_auto(select(4, ...))
      local idxs0 = cons(idx2, seq(idxs))
      local val = last(idxs0)
      local i = last(core.butlast(idxs0))
      local idxs1 = (core.butlast(core.butlast(idxs0)) or core.list())
      local a0 = apply(aget, array0, idx, idxs1)
      return aset0(a0, i, val)
    end
  end
  aset0 = core.aset
  aset = core.aset
end
core["aset-boolean"] = aset
core["aset-byte"] = aset
core["aset-char"] = aset
core["aset-double"] = aset
core["aset-float"] = aset
core["aset-int"] = aset
core["aset-long"] = aset
core["aset-short"] = aset
core.aclone = function(...)
  local array0 = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.aclone"))
    else
    end
  end
  assert(array_3f(array0), "expected a Lua array")
  local tbl_26_ = {}
  local i_27_ = 0
  for _, v in ipairs_2a(array0) do
    local val_28_ = v
    if (nil ~= val_28_) then
      i_27_ = (i_27_ + 1)
      tbl_26_[i_27_] = val_28_
    else
    end
  end
  return tbl_26_
end
core["to-array"] = function(...)
  local coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.to-array"))
    else
    end
  end
  if (core["seq?"](coll) or core["vector?"](coll)) then
    local tbl_26_ = {}
    local i_27_ = 0
    for _, v in ipairs_2a(coll) do
      local val_28_ = v
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    return tbl_26_
  else
    return error(string.format("can't coerce %s to array", coll))
  end
end
core["into-array"] = function(...)
  local case_1350_ = select("#", ...)
  if (case_1350_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.into-array"))
  elseif (case_1350_ == 1) then
    local aseq = ...
    return core["to-array"](aseq)
  elseif (case_1350_ == 2) then
    local _, aseq = ...
    return core["to-array"](aseq)
  else
    local _ = case_1350_
    return error(("Wrong number of args (%s) passed to %s"):format(_, "core.into-array"))
  end
end
local unpack = (_G.unpack or table.unpack)
local function make_array_2a(len)
  return {unpack({}, 1, len)}
end
core["make-array"] = function(...)
  local case_1353_ = select("#", ...)
  if (case_1353_ == 0) then
    return error(("Wrong number of args (%s) passed to %s"):format(0, "core.make-array"))
  elseif (case_1353_ == 1) then
    return error(("Wrong number of args (%s) passed to %s"):format(1, "core.make-array"))
  elseif (case_1353_ == 2) then
    local _, len = ...
    local case_1354_, case_1355_ = pcall(make_array_2a, len)
    if ((case_1354_ == true) and (nil ~= case_1355_)) then
      local a0 = case_1355_
      return a0
    else
      local _0 = case_1354_
      local a0 = {}
      for i = 1, len do
        a0[i] = nil
      end
      return a0
    end
  else
    local _ = case_1353_
    local _let_1357_ = require("io.gitlab.andreyorst.cljlib.core")
    local list_51_auto = _let_1357_.list
    local _0, dimension = ...
    local dimensions = list_51_auto(select(3, ...))
    local a0 = {}
    for i = 1, dimension do
      a0[i] = apply(core["make-array"], _0, dimensions)
    end
    return a0
  end
end
core["object-array"] = function(...)
  local size_or_seq = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.object-array"))
    else
    end
  end
  if core["number?"](size_or_seq) then
    return core["make-array"](floor(size_or_seq))
  else
    return core.aclone(size_or_seq)
  end
end
core["byte-array"] = core["object-array"]
core["char-array"] = core["object-array"]
core["double-array"] = core["object-array"]
core["float-array"] = core["object-array"]
core["int-array"] = core["object-array"]
core["long-array"] = core["object-array"]
core["object-array"] = core["object-array"]
core["short-array"] = core["object-array"]
core["boolean-array"] = core["object-array"]
core.ints = function(...)
  local coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.ints"))
    else
    end
  end
  assert(array_3f(coll), "expected a Lua array")
  return coll
end
core.booleans = core.ints
core.bytes = core.ints
core.chars = core.ints
core.doubles = core.ints
core.floats = core.ints
core.longs = core.ints
core.shorts = core.ints
core["bytes?"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.bytes?"))
    else
    end
  end
  assert(array_3f(x), "expected a Lua array")
  local res = true
  for _, v in ipairs(x) do
    if not res then break end
    res = ((0 <= v) and (v <= 255))
  end
  return res
end
core["to-array-2d"] = function(...)
  local coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.to-array-2d"))
    else
    end
  end
  local ret = core["make-array"](nil, length_2a(coll))
  local function recur(i, xs)
    if xs then
      aset(ret, i, core["to-array"](core.first(xs)))
      return recur((i + 1), core.next(xs))
    else
      return nil
    end
  end
  recur(1, seq(coll))
  return ret
end
core.alength = function(...)
  local array0 = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.alength"))
    else
    end
  end
  assert(array_3f(array0), "expected a Lua array")
  return #array0
end
core["coll?"] = function(...)
  local x = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.coll?"))
    else
    end
  end
  return (map_3f_2a(x) or core["set?"](x) or (core["vector?"](x) and not array_3f(x)) or core["seq?"](x))
end
core["indexed?"] = function(...)
  local coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (1 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "core.indexed?"))
    else
    end
  end
  return (vector_3f(coll) or array_3f(coll))
end
core.slurp = function(...)
  local _let_1368_ = require("io.gitlab.andreyorst.cljlib.core")
  local list_51_auto = _let_1368_.list
  local f = ...
  local _opts = list_51_auto(select(2, ...))
  local handle = io.open(f, "r")
  local function close_handlers_13_(ok_14_, ...)
    handle:close()
    if ok_14_ then
      return ...
    else
      return error(..., 0)
    end
  end
  local function _1370_(...)
    local args_15_ = {...}
    local n_16_ = select("#", ...)
    local unpack_17_ = (_G.unpack or _G.table.unpack)
    local function _1371_()
      local function _1372_(...)
        return handle:read("*a")
      end
      return _1372_(unpack_17_(args_15_, 1, n_16_))
    end
    local _1374_
    do
      local t_1373_ = _G
      if (nil ~= t_1373_) then
        t_1373_ = t_1373_.package
      else
      end
      if (nil ~= t_1373_) then
        t_1373_ = t_1373_.loaded
      else
      end
      if (nil ~= t_1373_) then
        t_1373_ = t_1373_.fennel
      else
      end
      _1374_ = t_1373_
    end
    local or_1378_ = _1374_ or _G.debug
    if not or_1378_ then
      local function _1379_()
        return ""
      end
      or_1378_ = {traceback = _1379_}
    end
    return _G.xpcall(_1371_, or_1378_.traceback)
  end
  return close_handlers_13_(_1370_(...))
end
core.spit = function(...)
  local _let_1380_ = require("io.gitlab.andreyorst.cljlib.core")
  local list_51_auto = _let_1380_.list
  local f, content = ...
  local options = list_51_auto(select(3, ...))
  do
    local opts = apply(hash_map, options)
    local handle
    local function _1381_(...)
      if opts.append then
        return "a"
      else
        return "w"
      end
    end
    handle = io.open(f, _1381_(...))
    local function close_handlers_13_(ok_14_, ...)
      handle:close()
      if ok_14_ then
        return ...
      else
        return error(..., 0)
      end
    end
    local function _1383_(...)
      local args_15_ = {...}
      local n_16_ = select("#", ...)
      local unpack_17_ = (_G.unpack or _G.table.unpack)
      local function _1384_()
        local function _1385_(...)
          return handle:write(content)
        end
        return _1385_(unpack_17_(args_15_, 1, n_16_))
      end
      local _1387_
      do
        local t_1386_ = _G
        if (nil ~= t_1386_) then
          t_1386_ = t_1386_.package
        else
        end
        if (nil ~= t_1386_) then
          t_1386_ = t_1386_.loaded
        else
        end
        if (nil ~= t_1386_) then
          t_1386_ = t_1386_.fennel
        else
        end
        _1387_ = t_1386_
      end
      local or_1391_ = _1387_ or _G.debug
      if not or_1391_ then
        local function _1392_()
          return ""
        end
        or_1391_ = {traceback = _1392_}
      end
      return _G.xpcall(_1384_, or_1391_.traceback)
    end
    close_handlers_13_(_1383_(...))
  end
  return nil
end
return core
