-- [nfnl] .deps/git/io.gitlab.andreyorst/lazy-seq/c7148adc558097d3978674fcf27a6c622499259d/src/io/gitlab/andreyorst/lazy-seq/init.fnl
--[[ "MIT License

  Copyright (c) 2021 Andrey Listopadov

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the “Software”), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE." ]]
utf8 = _G.utf8
local function pairs_2a(t)
  local mt = getmetatable(t)
  if (("table" == mt) and mt.__pairs) then
    return mt.__pairs(t)
  else
    return pairs(t)
  end
end
local function ipairs_2a(t)
  local mt = getmetatable(t)
  if (("table" == mt) and mt.__ipairs) then
    return mt.__ipairs(t)
  else
    return ipairs(t)
  end
end
local function rev_ipairs(t)
  local function _3_(t0, i)
    local i0 = (i - 1)
    if (i0 == 0) then
      return nil
    else
      local _ = i0
      return i0, t0[i0]
    end
  end
  return _3_, t, (1 + #t)
end
local function length_2a(t)
  local mt = getmetatable(t)
  if (("table" == mt) and mt.__len) then
    return mt.__len(t)
  else
    return #t
  end
end
local function table_pack(...)
  local tmp_9_ = {...}
  tmp_9_["n"] = select("#", ...)
  return tmp_9_
end
local table_unpack = (table.unpack or _G.unpack)
local seq = nil
local cons_iter = nil
local function first(s)
  local case_6_ = seq(s)
  if (nil ~= case_6_) then
    local s_2a = case_6_
    return s_2a(true)
  else
    local _ = case_6_
    return nil
  end
end
local function empty_cons_view()
  return "@seq()"
end
local function empty_cons_len()
  return 0
end
local function empty_cons_index()
  return nil
end
local function cons_newindex()
  return error("cons cell is immutable")
end
local function empty_cons_next(_)
  return nil
end
local function empty_cons_pairs(s)
  return empty_cons_next, nil, s
end
local function gettype(x)
  local case_8_
  do
    local t_9_ = getmetatable(x)
    if (nil ~= t_9_) then
      t_9_ = t_9_["__lazy-seq/type"]
    else
    end
    case_8_ = t_9_
  end
  if (nil ~= case_8_) then
    local t = case_8_
    return t
  else
    local _ = case_8_
    return type(x)
  end
end
local function realize(c)
  if ("lazy-cons" == gettype(c)) then
    c()
  else
  end
  return c
end
local empty_cons = {}
local function empty_cons_call(tf)
  if tf then
    return nil
  else
    return empty_cons
  end
end
local function empty_cons_fennelrest()
  return empty_cons
end
local function empty_cons_eq(_, s)
  return rawequal(getmetatable(empty_cons), getmetatable(realize(s)))
end
setmetatable(empty_cons, {__call = empty_cons_call, __len = empty_cons_len, __fennelview = empty_cons_view, __fennelrest = empty_cons_fennelrest, ["__lazy-seq/type"] = "empty-cons", __newindex = cons_newindex, __index = empty_cons_index, __name = "cons", __eq = empty_cons_eq, __pairs = empty_cons_pairs})
local function rest(s)
  local case_14_ = seq(s)
  if (nil ~= case_14_) then
    local s_2a = case_14_
    return s_2a(false)
  else
    local _ = case_14_
    return empty_cons
  end
end
local function seq_3f(x)
  local tp = gettype(x)
  return ((tp == "cons") or (tp == "lazy-cons") or (tp == "empty-cons"))
end
local function empty_3f(x)
  return not seq(x)
end
local function next(s)
  return seq(realize(rest(seq(s))))
end
local function view_seq(list, options, view, indent, elements)
  table.insert(elements, view(first(list), options, indent))
  do
    local tail = next(list)
    if ("cons" == gettype(tail)) then
      view_seq(tail, options, view, indent, elements)
    else
    end
  end
  return elements
end
local function pp_seq(list, view, options, indent)
  local items = view_seq(list, options, view, (indent + 5), {})
  local lines
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for i, line in ipairs(items) do
      local val_28_
      if (i == 1) then
        val_28_ = line
      else
        val_28_ = ("     " .. line)
      end
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    lines = tbl_26_
  end
  lines[1] = ("@seq(" .. (lines[1] or ""))
  lines[#lines] = (lines[#lines] .. ")")
  return lines
end
local drop = nil
local function cons_fennelrest(c, i)
  return drop((i - 1), c)
end
local allowed_types = {cons = true, ["empty-cons"] = true, ["lazy-cons"] = true, ["nil"] = true, string = true, table = true}
local function cons_next(_, s)
  if (empty_cons ~= s) then
    local tail = next(s)
    local case_19_ = gettype(tail)
    if (case_19_ == "cons") then
      return tail, first(s)
    else
      local _0 = case_19_
      return empty_cons, first(s)
    end
  else
    return nil
  end
end
local function cons_pairs(s)
  return cons_next, nil, s
end
local function cons_eq(s1, s2)
  if rawequal(s1, s2) then
    return true
  else
    if (not rawequal(s2, empty_cons) and not rawequal(s1, empty_cons)) then
      local s10, s20, res = s1, s2, true
      while (res and s10 and s20) do
        res = (first(s10) == first(s20))
        s10 = next(s10)
        s20 = next(s20)
      end
      return res
    else
      return false
    end
  end
end
local function cons_len(s)
  local s0, len = s, 0
  while s0 do
    s0, len = next(s0), (len + 1)
  end
  return len
end
local function cons_index(s, i)
  if (i > 0) then
    local s0, i_2a = s, 1
    while ((i_2a ~= i) and s0) do
      s0, i_2a = next(s0), (i_2a + 1)
    end
    return first(s0)
  else
    return nil
  end
end
local function cons(head, tail)
  do local _ = {head, tail} end
  local tp = gettype(tail)
  assert(allowed_types[tp], ("expected nil, cons, table, or string as a tail, got: %s"):format(tp))
  local function _25_(_241, _242)
    if _242 then
      return head
    else
      if (nil ~= tail) then
        local s = tail
        return s
      elseif (tail == nil) then
        return empty_cons
      else
        return nil
      end
    end
  end
  return setmetatable({}, {__call = _25_, ["__lazy-seq/type"] = "cons", __index = cons_index, __newindex = cons_newindex, __len = cons_len, __pairs = cons_pairs, __name = "cons", __eq = cons_eq, __fennelview = pp_seq, __fennelrest = cons_fennelrest})
end
local function _28_(s)
  local case_29_ = gettype(s)
  if (case_29_ == "cons") then
    return s
  elseif (case_29_ == "lazy-cons") then
    return seq(realize(s))
  elseif (case_29_ == "empty-cons") then
    return nil
  elseif (case_29_ == "nil") then
    return nil
  elseif (case_29_ == "table") then
    return cons_iter(s)
  elseif (case_29_ == "string") then
    return cons_iter(s)
  else
    local _ = case_29_
    return error(("expected table, string or sequence, got %s"):format(_), 2)
  end
end
seq = _28_
local function lazy_seq_2a(f)
  local lazy_cons = cons(nil, nil)
  local realize0
  local function _31_()
    local s = seq(f())
    if (nil ~= s) then
      return setmetatable(lazy_cons, getmetatable(s))
    else
      return setmetatable(lazy_cons, getmetatable(empty_cons))
    end
  end
  realize0 = _31_
  local function _33_(_241, _242)
    return realize0()(_242)
  end
  local function _34_(_241, _242)
    return realize0()[_242]
  end
  local function _35_(...)
    realize0()
    return pp_seq(...)
  end
  local function _36_()
    return length_2a(realize0())
  end
  local function _37_()
    return pairs_2a(realize0())
  end
  local function _38_(_241, _242)
    return (realize0() == _242)
  end
  return setmetatable(lazy_cons, {__call = _33_, __index = _34_, __newindex = cons_newindex, __fennelview = _35_, __fennelrest = cons_fennelrest, __len = _36_, __pairs = _37_, __name = "lazy cons", __eq = _38_, ["__lazy-seq/type"] = "lazy-cons"})
end
local function list(...)
  local args = table_pack(...)
  local l = empty_cons
  for i = args.n, 1, -1 do
    l = cons(args[i], l)
  end
  return l
end
local function spread(arglist)
  local arglist0 = seq(arglist)
  if (nil == arglist0) then
    return nil
  elseif (nil == next(arglist0)) then
    return seq(first(arglist0))
  elseif "else" then
    return cons(first(arglist0), spread(next(arglist0)))
  else
    return nil
  end
end
local function list_2a(...)
  local case_40_, case_41_, case_42_, case_43_, case_44_ = select("#", ...), ...
  if ((case_40_ == 1) and true) then
    local _3fargs = case_41_
    return seq(_3fargs)
  elseif ((case_40_ == 2) and true and true) then
    local _3fa = case_41_
    local _3fargs = case_42_
    return cons(_3fa, seq(_3fargs))
  elseif ((case_40_ == 3) and true and true and true) then
    local _3fa = case_41_
    local _3fb = case_42_
    local _3fargs = case_43_
    return cons(_3fa, cons(_3fb, seq(_3fargs)))
  elseif ((case_40_ == 4) and true and true and true and true) then
    local _3fa = case_41_
    local _3fb = case_42_
    local _3fc = case_43_
    local _3fargs = case_44_
    return cons(_3fa, cons(_3fb, cons(_3fc, seq(_3fargs))))
  else
    local _ = case_40_
    return spread(list(...))
  end
end
local function kind(t)
  local case_46_ = type(t)
  if (case_46_ == "table") then
    local len = length_2a(t)
    local nxt, t_2a, k = pairs_2a(t)
    local function _47_()
      if (len == 0) then
        return k
      else
        return len
      end
    end
    if (nil ~= nxt(t_2a, _47_())) then
      return "assoc"
    elseif (len > 0) then
      return "seq"
    else
      return "empty"
    end
  elseif (case_46_ == "string") then
    local len
    if utf8 then
      len = utf8.len(t)
    else
      len = #t
    end
    if (len > 0) then
      return "string"
    else
      return "empty"
    end
  else
    local _ = case_46_
    return "else"
  end
end
local function rseq(rev)
  local case_52_ = gettype(rev)
  if (case_52_ == "table") then
    local case_53_ = kind(rev)
    if (case_53_ == "seq") then
      local function wrap(nxt, t, i)
        local i0, v = nxt(t, i)
        if (nil ~= i0) then
          local function _54_()
            return wrap(nxt, t, i0)
          end
          return cons(v, lazy_seq_2a(_54_))
        else
          return empty_cons
        end
      end
      return wrap(rev_ipairs(rev))
    elseif (case_53_ == "empty") then
      return nil
    else
      local _ = case_53_
      return error("can't create an rseq from a non-sequential table")
    end
  else
    local _ = case_52_
    return error(("can't create an rseq from a " .. _))
  end
end
local function _58_(t)
  local case_59_ = kind(t)
  if (case_59_ == "assoc") then
    local function wrap(nxt, t0, k)
      local k0, v = nxt(t0, k)
      if (nil ~= k0) then
        local function _60_()
          return wrap(nxt, t0, k0)
        end
        return cons({k0, v}, lazy_seq_2a(_60_))
      else
        return empty_cons
      end
    end
    return wrap(pairs_2a(t))
  elseif (case_59_ == "seq") then
    local function wrap(nxt, t0, i)
      local i0, v = nxt(t0, i)
      if (nil ~= i0) then
        local function _62_()
          return wrap(nxt, t0, i0)
        end
        return cons(v, lazy_seq_2a(_62_))
      else
        return empty_cons
      end
    end
    return wrap(ipairs_2a(t))
  elseif (case_59_ == "string") then
    local char
    if utf8 then
      char = utf8.char
    else
      char = string.char
    end
    local function wrap(nxt, t0, i)
      local i0, v = nxt(t0, i)
      if (nil ~= i0) then
        local function _65_()
          return wrap(nxt, t0, i0)
        end
        return cons(char(v), lazy_seq_2a(_65_))
      else
        return empty_cons
      end
    end
    local function _67_()
      if utf8 then
        return utf8.codes(t)
      else
        return ipairs_2a({string.byte(t, 1, #t)})
      end
    end
    return wrap(_67_())
  elseif (case_59_ == "empty") then
    return nil
  else
    return nil
  end
end
cons_iter = _58_
local function every_3f(pred, coll)
  local case_69_ = seq(coll)
  if (nil ~= case_69_) then
    local s = case_69_
    if pred(first(s)) then
      local case_70_ = next(s)
      if (nil ~= case_70_) then
        local r = case_70_
        return every_3f(pred, r)
      else
        local _ = case_70_
        return true
      end
    else
      return false
    end
  else
    local _ = case_69_
    return false
  end
end
local function some_3f(pred, coll)
  local case_74_ = seq(coll)
  if (nil ~= case_74_) then
    local s = case_74_
    local or_75_ = pred(first(s))
    if not or_75_ then
      local case_76_ = next(s)
      if (nil ~= case_76_) then
        local r = case_76_
        or_75_ = some_3f(pred, r)
      else
        local _ = case_76_
        or_75_ = nil
      end
    end
    return or_75_
  else
    local _ = case_74_
    return nil
  end
end
local function pack(s)
  local res = {}
  local n = 0
  do
    local case_82_ = seq(s)
    if (nil ~= case_82_) then
      local s_2a = case_82_
      for _, v in pairs_2a(s_2a) do
        n = (n + 1)
        res[n] = v
      end
    else
    end
  end
  res["n"] = n
  return res
end
local function count(s)
  local case_84_ = seq(s)
  if (nil ~= case_84_) then
    local s_2a = case_84_
    return length_2a(s_2a)
  else
    local _ = case_84_
    return 0
  end
end
local function unpack(s)
  local t = pack(s)
  return table_unpack(t, 1, t.n)
end
local function concat(...)
  local case_86_ = select("#", ...)
  if (case_86_ == 0) then
    return empty_cons
  elseif (case_86_ == 1) then
    local x = ...
    local function _87_()
      return x
    end
    return lazy_seq_2a(_87_)
  elseif (case_86_ == 2) then
    local x, y = ...
    local function _88_()
      local case_89_ = seq(x)
      if (nil ~= case_89_) then
        local s = case_89_
        return cons(first(s), concat(rest(s), y))
      elseif (case_89_ == nil) then
        return y
      else
        return nil
      end
    end
    return lazy_seq_2a(_88_)
  else
    local _ = case_86_
    local pv_91_, pv_92_ = ...
    return concat(concat(pv_91_, pv_92_), select(3, ...))
  end
end
local function reverse(s)
  local function helper(s0, res)
    local case_94_ = seq(s0)
    if (nil ~= case_94_) then
      local s_2a = case_94_
      return helper(rest(s_2a), cons(first(s_2a), res))
    else
      local _ = case_94_
      return res
    end
  end
  return helper(s, empty_cons)
end
local function map(f, ...)
  local case_96_ = select("#", ...)
  if (case_96_ == 0) then
    return nil
  elseif (case_96_ == 1) then
    local col = ...
    local function _97_()
      local case_98_ = seq(col)
      if (nil ~= case_98_) then
        local x = case_98_
        return cons(f(first(x)), map(f, seq(rest(x))))
      else
        local _ = case_98_
        return nil
      end
    end
    return lazy_seq_2a(_97_)
  elseif (case_96_ == 2) then
    local s1, s2 = ...
    local function _100_()
      local s10 = seq(s1)
      local s20 = seq(s2)
      if (s10 and s20) then
        return cons(f(first(s10), first(s20)), map(f, rest(s10), rest(s20)))
      else
        return nil
      end
    end
    return lazy_seq_2a(_100_)
  elseif (case_96_ == 3) then
    local s1, s2, s3 = ...
    local function _102_()
      local s10 = seq(s1)
      local s20 = seq(s2)
      local s30 = seq(s3)
      if (s10 and s20 and s30) then
        return cons(f(first(s10), first(s20), first(s30)), map(f, rest(s10), rest(s20), rest(s30)))
      else
        return nil
      end
    end
    return lazy_seq_2a(_102_)
  else
    local _ = case_96_
    local s = list(...)
    local function _104_()
      local function _105_(_2410)
        return (nil ~= seq(_2410))
      end
      if every_3f(_105_, s) then
        return cons(f(unpack(map(first, s))), map(f, unpack(map(rest, s))))
      else
        return nil
      end
    end
    return lazy_seq_2a(_104_)
  end
end
local function map_indexed(f, coll)
  local mapi
  local function mapi0(idx, coll0)
    local function _108_()
      local case_109_ = seq(coll0)
      if (nil ~= case_109_) then
        local s = case_109_
        return cons(f(idx, first(s)), mapi0((idx + 1), rest(s)))
      else
        local _ = case_109_
        return nil
      end
    end
    return lazy_seq_2a(_108_)
  end
  mapi = mapi0
  return mapi(1, coll)
end
local function mapcat(f, ...)
  local step
  local function step0(colls)
    local function _111_()
      local case_112_ = seq(colls)
      if (nil ~= case_112_) then
        local s = case_112_
        local c = first(s)
        return concat(c, step0(rest(colls)))
      else
        local _ = case_112_
        return nil
      end
    end
    return lazy_seq_2a(_111_)
  end
  step = step0
  return step(map(f, ...))
end
local function take(n, coll)
  local function _114_()
    if (n > 0) then
      local case_115_ = seq(coll)
      if (nil ~= case_115_) then
        local s = case_115_
        return cons(first(s), take((n - 1), rest(s)))
      else
        local _ = case_115_
        return nil
      end
    else
      return nil
    end
  end
  return lazy_seq_2a(_114_)
end
local function take_while(pred, coll)
  local function _118_()
    local case_119_ = seq(coll)
    if (nil ~= case_119_) then
      local s = case_119_
      local v = first(s)
      if pred(v) then
        return cons(v, take_while(pred, rest(s)))
      else
        return nil
      end
    else
      local _ = case_119_
      return nil
    end
  end
  return lazy_seq_2a(_118_)
end
local function _122_(n, coll)
  local step
  local function step0(n0, coll0)
    local s = seq(coll0)
    if ((n0 > 0) and s) then
      return step0((n0 - 1), rest(s))
    else
      return s
    end
  end
  step = step0
  local function _124_()
    return step(n, coll)
  end
  return lazy_seq_2a(_124_)
end
drop = _122_
local function drop_while(pred, coll)
  local step
  local function step0(pred0, coll0)
    local s = seq(coll0)
    if (s and pred0(first(s))) then
      return step0(pred0, rest(s))
    else
      return s
    end
  end
  step = step0
  local function _126_()
    return step(pred, coll)
  end
  return lazy_seq_2a(_126_)
end
local function drop_last(...)
  local case_127_ = select("#", ...)
  if (case_127_ == 0) then
    return empty_cons
  elseif (case_127_ == 1) then
    return drop_last(1, ...)
  else
    local _ = case_127_
    local n, coll = ...
    local function _128_(x)
      return x
    end
    return map(_128_, coll, drop(n, coll))
  end
end
local function take_last(n, coll)
  local function loop(s, lead)
    if lead then
      return loop(next(s), next(lead))
    else
      return s
    end
  end
  return loop(seq(coll), seq(drop(n, coll)))
end
local function take_nth(n, coll)
  local function _131_()
    local case_132_ = seq(coll)
    if (nil ~= case_132_) then
      local s = case_132_
      return cons(first(s), take_nth(n, drop(n, s)))
    else
      return nil
    end
  end
  return lazy_seq_2a(_131_)
end
local function split_at(n, coll)
  return {take(n, coll), drop(n, coll)}
end
local function split_with(pred, coll)
  return {take_while(pred, coll), drop_while(pred, coll)}
end
local function filter(pred, coll)
  local function _134_()
    local case_135_ = seq(coll)
    if (nil ~= case_135_) then
      local s = case_135_
      local x = first(s)
      local r = rest(s)
      if pred(x) then
        return cons(x, filter(pred, r))
      else
        return filter(pred, r)
      end
    else
      local _ = case_135_
      return nil
    end
  end
  return lazy_seq_2a(_134_)
end
local function keep(f, coll)
  local function _138_()
    local case_139_ = seq(coll)
    if (nil ~= case_139_) then
      local s = case_139_
      local case_140_ = f(first(s))
      if (nil ~= case_140_) then
        local x = case_140_
        return cons(x, keep(f, rest(s)))
      elseif (case_140_ == nil) then
        return keep(f, rest(s))
      else
        return nil
      end
    else
      local _ = case_139_
      return nil
    end
  end
  return lazy_seq_2a(_138_)
end
local function keep_indexed(f, coll)
  local keepi
  local function keepi0(idx, coll0)
    local function _143_()
      local case_144_ = seq(coll0)
      if (nil ~= case_144_) then
        local s = case_144_
        local x = f(idx, first(s))
        if (nil == x) then
          return keepi0((1 + idx), rest(s))
        else
          return cons(x, keepi0((1 + idx), rest(s)))
        end
      else
        return nil
      end
    end
    return lazy_seq_2a(_143_)
  end
  keepi = keepi0
  return keepi(1, coll)
end
local function remove(pred, coll)
  local function _147_(_241)
    return not pred(_241)
  end
  return filter(_147_, coll)
end
local function cycle(coll)
  local function _148_()
    return concat(seq(coll), cycle(coll))
  end
  return lazy_seq_2a(_148_)
end
local function _repeat(x)
  local function step(x0)
    local function _149_()
      return cons(x0, step(x0))
    end
    return lazy_seq_2a(_149_)
  end
  return step(x)
end
local function repeatedly(f, ...)
  local args = table_pack(...)
  local f0
  local function _150_()
    return f(table_unpack(args, 1, args.n))
  end
  f0 = _150_
  local function step(f1)
    local function _151_()
      return cons(f1(), step(f1))
    end
    return lazy_seq_2a(_151_)
  end
  return step(f0)
end
local function iterate(f, x)
  local x_2a = f(x)
  local function _152_()
    return iterate(f, x_2a)
  end
  return cons(x, lazy_seq_2a(_152_))
end
local function nthnext(coll, n)
  local function loop(n0, xs)
    local and_153_ = (nil ~= xs)
    if and_153_ then
      local xs_2a = xs
      and_153_ = (n0 > 0)
    end
    if and_153_ then
      local xs_2a = xs
      return loop((n0 - 1), next(xs_2a))
    else
      local _ = xs
      return xs
    end
  end
  return loop(n, seq(coll))
end
local function nthrest(coll, n)
  local function loop(n0, xs)
    local case_156_ = seq(xs)
    local and_157_ = (nil ~= case_156_)
    if and_157_ then
      local xs_2a = case_156_
      and_157_ = (n0 > 0)
    end
    if and_157_ then
      local xs_2a = case_156_
      return loop((n0 - 1), rest(xs_2a))
    else
      local _ = case_156_
      return xs
    end
  end
  return loop(n, coll)
end
local function dorun(s)
  local case_160_ = seq(s)
  if (nil ~= case_160_) then
    local s_2a = case_160_
    return dorun(next(s_2a))
  else
    local _ = case_160_
    return nil
  end
end
local function doall(s)
  dorun(s)
  return s
end
local function partition(...)
  local case_162_ = select("#", ...)
  if (case_162_ == 2) then
    local n, coll = ...
    return partition(n, n, coll)
  elseif (case_162_ == 3) then
    local n, step, coll = ...
    local function _163_()
      local case_164_ = seq(coll)
      if (nil ~= case_164_) then
        local s = case_164_
        local p = take(n, s)
        if (n == length_2a(p)) then
          return cons(p, partition(n, step, nthrest(s, step)))
        else
          return nil
        end
      else
        local _ = case_164_
        return nil
      end
    end
    return lazy_seq_2a(_163_)
  elseif (case_162_ == 4) then
    local n, step, pad, coll = ...
    local function _167_()
      local case_168_ = seq(coll)
      if (nil ~= case_168_) then
        local s = case_168_
        local p = take(n, s)
        if (n == length_2a(p)) then
          return cons(p, partition(n, step, pad, nthrest(s, step)))
        else
          return list(take(n, concat(p, pad)))
        end
      else
        local _ = case_168_
        return nil
      end
    end
    return lazy_seq_2a(_167_)
  else
    local _ = case_162_
    return error("wrong amount arguments to 'partition'")
  end
end
local function partition_by(f, coll)
  local function _172_()
    local case_173_ = seq(coll)
    if (nil ~= case_173_) then
      local s = case_173_
      local v = first(s)
      local fv = f(v)
      local run
      local function _174_(_2410)
        return (fv == f(_2410))
      end
      run = cons(v, take_while(_174_, next(s)))
      local function _175_()
        return drop(length_2a(run), s)
      end
      return cons(run, partition_by(f, lazy_seq_2a(_175_)))
    else
      return nil
    end
  end
  return lazy_seq_2a(_172_)
end
local function partition_all(...)
  local case_177_ = select("#", ...)
  if (case_177_ == 2) then
    local n, coll = ...
    return partition_all(n, n, coll)
  elseif (case_177_ == 3) then
    local n, step, coll = ...
    local function _178_()
      local case_179_ = seq(coll)
      if (nil ~= case_179_) then
        local s = case_179_
        local p = take(n, s)
        return cons(p, partition_all(n, step, nthrest(s, step)))
      else
        local _ = case_179_
        return nil
      end
    end
    return lazy_seq_2a(_178_)
  else
    local _ = case_177_
    return error("wrong amount arguments to 'partition-all'")
  end
end
local function reductions(...)
  local case_182_ = select("#", ...)
  if (case_182_ == 2) then
    local f, coll = ...
    local function _183_()
      local case_184_ = seq(coll)
      if (nil ~= case_184_) then
        local s = case_184_
        return reductions(f, first(s), rest(s))
      else
        local _ = case_184_
        return list(f())
      end
    end
    return lazy_seq_2a(_183_)
  elseif (case_182_ == 3) then
    local f, init, coll = ...
    local function _186_()
      local case_187_ = seq(coll)
      if (nil ~= case_187_) then
        local s = case_187_
        return reductions(f, f(init, first(s)), rest(s))
      else
        return nil
      end
    end
    return cons(init, lazy_seq_2a(_186_))
  else
    local _ = case_182_
    return error("wrong amount arguments to 'reductions'")
  end
end
local function contains_3f(coll, elt)
  local case_190_ = gettype(coll)
  if (case_190_ == "table") then
    local case_191_ = kind(coll)
    if (case_191_ == "seq") then
      local res = false
      for _, v in ipairs_2a(coll) do
        if res then break end
        if (elt == v) then
          res = true
        else
          res = false
        end
      end
      return res
    elseif (case_191_ == "assoc") then
      if coll[elt] then
        return true
      else
        return false
      end
    else
      return nil
    end
  else
    local _ = case_190_
    local function loop(coll0)
      local case_195_ = seq(coll0)
      if (nil ~= case_195_) then
        local s = case_195_
        if (elt == first(s)) then
          return true
        else
          return loop(rest(s))
        end
      elseif (case_195_ == nil) then
        return false
      else
        return nil
      end
    end
    return loop(coll)
  end
end
local function distinct(coll)
  local function step(xs, seen)
    local loop
    local function loop0(_199_, seen0)
      local f = _199_[1]
      local xs0 = _199_
      local case_200_ = seq(xs0)
      if (nil ~= case_200_) then
        local s = case_200_
        if seen0[f] then
          return loop0(rest(s), seen0)
        else
          local function _201_()
            seen0[f] = true
            return seen0
          end
          return cons(f, step(rest(s), _201_()))
        end
      else
        local _ = case_200_
        return nil
      end
    end
    loop = loop0
    local function _204_()
      return loop(xs, seen)
    end
    return lazy_seq_2a(_204_)
  end
  return step(coll, {})
end
local function inf_range(x, step)
  local function _205_()
    return cons(x, inf_range((x + step), step))
  end
  return lazy_seq_2a(_205_)
end
local function fix_range(x, _end, step)
  local function _206_()
    if (((step >= 0) and (x < _end)) or ((step < 0) and (x > _end))) then
      return cons(x, fix_range((x + step), _end, step))
    elseif ((step == 0) and (x ~= _end)) then
      return cons(x, fix_range(x, _end, step))
    else
      return nil
    end
  end
  return lazy_seq_2a(_206_)
end
local function range(...)
  local case_208_ = select("#", ...)
  if (case_208_ == 0) then
    return inf_range(0, 1)
  elseif (case_208_ == 1) then
    local _end = ...
    return fix_range(0, _end, 1)
  elseif (case_208_ == 2) then
    local x, _end = ...
    return fix_range(x, _end, 1)
  else
    local _ = case_208_
    return fix_range(...)
  end
end
local function realized_3f(s)
  local case_210_ = gettype(s)
  if (case_210_ == "lazy-cons") then
    return false
  elseif (case_210_ == "empty-cons") then
    return true
  elseif (case_210_ == "cons") then
    return true
  else
    local _ = case_210_
    return error(("expected a sequence, got: %s"):format(_))
  end
end
local function line_seq(file)
  local next_line = file:lines()
  local function step(f)
    local line = f()
    if ("string" == type(line)) then
      local function _212_()
        return step(f)
      end
      return cons(line, lazy_seq_2a(_212_))
    else
      return nil
    end
  end
  return step(next_line)
end
local function tree_seq(branch_3f, children, root)
  local function walk(node)
    local function _214_()
      local function _215_()
        if branch_3f(node) then
          return mapcat(walk, children(node))
        else
          return nil
        end
      end
      return cons(node, _215_())
    end
    return lazy_seq_2a(_214_)
  end
  return walk(root)
end
local function interleave(...)
  local case_216_, case_217_, case_218_ = select("#", ...), ...
  if (case_216_ == 0) then
    return empty_cons
  elseif ((case_216_ == 1) and true) then
    local _3fs = case_217_
    local function _219_()
      return _3fs
    end
    return lazy_seq_2a(_219_)
  elseif ((case_216_ == 2) and true and true) then
    local _3fs1 = case_217_
    local _3fs2 = case_218_
    local function _220_()
      local s1 = seq(_3fs1)
      local s2 = seq(_3fs2)
      if (s1 and s2) then
        return cons(first(s1), cons(first(s2), interleave(rest(s1), rest(s2))))
      else
        return nil
      end
    end
    return lazy_seq_2a(_220_)
  elseif true then
    local _ = case_216_
    local cols = list(...)
    local function _222_()
      local seqs = map(seq, cols)
      local function _223_(_2410)
        return (nil ~= seq(_2410))
      end
      if every_3f(_223_, seqs) then
        return concat(map(first, seqs), interleave(unpack(map(rest, seqs))))
      else
        return nil
      end
    end
    return lazy_seq_2a(_222_)
  else
    return nil
  end
end
local function interpose(separator, coll)
  return drop(1, interleave(_repeat(separator), coll))
end
local function keys(t)
  assert(("assoc" == kind(t)), "expected an associative table")
  local function _226_(_241)
    return _241[1]
  end
  return map(_226_, t)
end
local function vals(t)
  assert(("assoc" == kind(t)), "expected an associative table")
  local function _227_(_241)
    return _241[2]
  end
  return map(_227_, t)
end
local function zipmap(keys0, vals0)
  local t = {}
  local function loop(s1, s2)
    if (s1 and s2) then
      t[first(s1)] = first(s2)
      return loop(next(s1), next(s2))
    else
      return nil
    end
  end
  loop(seq(keys0), seq(vals0))
  return t
end
local _local_229_ = require("io.gitlab.andreyorst.reduced")
local reduced = _local_229_.reduced
local reduced_3f = _local_229_["reduced?"]
local function reduce(f, ...)
  local case_230_, case_231_, case_232_ = select("#", ...), ...
  if (case_230_ == 0) then
    return error("expected a collection")
  elseif ((case_230_ == 1) and true) then
    local _3fcoll = case_231_
    local case_233_ = count(_3fcoll)
    if (case_233_ == 0) then
      return f()
    elseif (case_233_ == 1) then
      return first(_3fcoll)
    else
      local _ = case_233_
      return reduce(f, first(_3fcoll), rest(_3fcoll))
    end
  elseif ((case_230_ == 2) and true and true) then
    local _3fval = case_231_
    local _3fcoll = case_232_
    local case_235_ = seq(_3fcoll)
    if (nil ~= case_235_) then
      local coll = case_235_
      local done_3f = false
      local res = _3fval
      for _, v in pairs_2a(coll) do
        if done_3f then break end
        local res0 = f(res, v)
        if reduced_3f(res0) then
          done_3f = true
          res = res0:unbox()
        else
          res = res0
        end
      end
      return res
    else
      local _ = case_235_
      return _3fval
    end
  else
    return nil
  end
end
return {first = first, rest = rest, nthrest = nthrest, next = next, nthnext = nthnext, cons = cons, seq = seq, rseq = rseq, ["seq?"] = seq_3f, ["empty?"] = empty_3f, ["lazy-seq*"] = lazy_seq_2a, list = list, ["list*"] = list_2a, ["every?"] = every_3f, ["some?"] = some_3f, pack = pack, unpack = unpack, count = count, concat = concat, map = map, ["map-indexed"] = map_indexed, mapcat = mapcat, take = take, ["take-while"] = take_while, ["take-last"] = take_last, ["take-nth"] = take_nth, drop = drop, ["drop-while"] = drop_while, ["drop-last"] = drop_last, remove = remove, ["split-at"] = split_at, ["split-with"] = split_with, partition = partition, ["partition-by"] = partition_by, ["partition-all"] = partition_all, filter = filter, keep = keep, ["keep-indexed"] = keep_indexed, ["contains?"] = contains_3f, distinct = distinct, cycle = cycle, ["repeat"] = _repeat, repeatedly = repeatedly, reductions = reductions, iterate = iterate, range = range, ["realized?"] = realized_3f, dorun = dorun, doall = doall, ["line-seq"] = line_seq, ["tree-seq"] = tree_seq, reverse = reverse, interleave = interleave, interpose = interpose, keys = keys, vals = vals, zipmap = zipmap, reduce = reduce, reduced = reduced, ["reduced?"] = reduced_3f, __VERSION = "0.1.127"}
