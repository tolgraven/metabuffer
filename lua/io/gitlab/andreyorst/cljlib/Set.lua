-- [nfnl] .deps/git/io.gitlab.andreyorst/fennel-cljlib/256d59ef6efd0f39ca35bb6815e9c29bc8b8584a/src/io/gitlab/andreyorst/cljlib/Set.fnl
local function _1_()
  return "#<namespace: io.gitlab.andreyorst.cljlib.Set>"
end
--[[ "Set operations such as union/intersection." ]]
local _local_2_ = {setmetatable({}, {__fennelview = _1_, __name = "namespace"}), require("io.gitlab.andreyorst.cljlib.core")}, nil
local Set = _local_2_[1]
local _local_3_ = _local_2_[2]
local apply = _local_3_.apply
local assoc = _local_3_.assoc
local assoc_21 = _local_3_["assoc!"]
local conj = _local_3_.conj
local cons = _local_3_.cons
local contains_3f = _local_3_["contains?"]
local count = _local_3_.count
local disj = _local_3_.disj
local dissoc = _local_3_.dissoc
local every_3f = _local_3_["every?"]
local first = _local_3_.first
local get = _local_3_.get
local hash_map = _local_3_["hash-map"]
local hash_set = _local_3_["hash-set"]
local identical_3f = _local_3_["identical?"]
local into = _local_3_.into
local keys = _local_3_.keys
local map = _local_3_.map
local max_key = _local_3_["max-key"]
local merge = _local_3_.merge
local persistent_21 = _local_3_["persistent!"]
local reduce = _local_3_.reduce
local reduce_kv = _local_3_["reduce-kv"]
local remove = _local_3_.remove
local rest = _local_3_.rest
local select_keys = _local_3_["select-keys"]
local seq = _local_3_.seq
local transient = _local_3_.transient
local vals = _local_3_.vals
local core = _local_3_
local bubble_max_key
local function bubble_max_key0(...)
  local k, coll = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "bubble-max-key"))
    else
    end
  end
  local max = apply(max_key, k, coll)
  local function _5_(_241)
    return identical_3f(max, _241)
  end
  return cons(max, remove(_5_, coll))
end
bubble_max_key = bubble_max_key0
local union
do
  local union0 = nil
  Set.union = function(...)
    local case_6_ = select("#", ...)
    if (case_6_ == 0) then
      return hash_set()
    elseif (case_6_ == 1) then
      local s1 = ...
      return s1
    elseif (case_6_ == 2) then
      local s1, s2 = ...
      if (count(s1) < count(s2)) then
        return reduce(conj, s2, s1)
      else
        return reduce(conj, s1, s2)
      end
    else
      local _ = case_6_
      local _let_8_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_51_auto = _let_8_.list
      local s1, s2 = ...
      local sets = list_51_auto(select(3, ...))
      local bubbled_sets = bubble_max_key(count, conj(sets, s2, s1))
      return reduce(into, first(bubbled_sets), rest(bubbled_sets))
    end
  end
  union0 = Set.union
  union = Set.union
end
local map_invert
do
  local map_invert0 = nil
  Set["map-invert"] = function(...)
    local m = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "Set.map-invert"))
      else
      end
    end
    local function _11_(m0, k, v)
      return assoc_21(m0, v, k)
    end
    return persistent_21(reduce_kv(_11_, transient(hash_map()), m))
  end
  map_invert0 = Set["map-invert"]
  map_invert = Set["map-invert"]
end
local index
do
  local index0 = nil
  Set.index = function(...)
    local xrel, ks = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "Set.index"))
      else
      end
    end
    local function _13_(m, x)
      local ik = select_keys(x, ks)
      return assoc(m, ik, conj(get(m, ik, hash_set()), x))
    end
    return reduce(_13_, hash_map(), xrel)
  end
  index0 = Set.index
  index = Set.index
end
local intersection
do
  local intersection0 = nil
  Set.intersection = function(...)
    local case_14_ = select("#", ...)
    if (case_14_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "Set.intersection"))
    elseif (case_14_ == 1) then
      local s1 = ...
      return s1
    elseif (case_14_ == 2) then
      local s1, s2 = ...
      if (count(s2) < count(s1)) then
        return intersection0(s2, s1)
      else
        local function _15_(result, item)
          if contains_3f(s2, item) then
            return result
          else
            return disj(result, item)
          end
        end
        return reduce(_15_, s1, s1)
      end
    else
      local _ = case_14_
      local _let_18_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_51_auto = _let_18_.list
      local s1, s2 = ...
      local sets = list_51_auto(select(3, ...))
      local bubbled_sets
      local function _19_(_241)
        return ( - count(_241))
      end
      bubbled_sets = bubble_max_key(_19_, conj(sets, s2, s1))
      return reduce(intersection0, first(bubbled_sets), rest(bubbled_sets))
    end
  end
  intersection0 = Set.intersection
  intersection = Set.intersection
end
local rename_keys
do
  local rename_keys0 = nil
  Set["rename-keys"] = function(...)
    local map0, kmap = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "Set.rename-keys"))
      else
      end
    end
    local function _23_(m, _22_)
      local old = _22_[1]
      local new_2a = _22_[2]
      if contains_3f(map0, old) then
        return assoc(m, new_2a, get(map0, old))
      else
        return m
      end
    end
    return reduce(_23_, apply(dissoc, map0, keys(kmap)), kmap)
  end
  rename_keys0 = Set["rename-keys"]
  rename_keys = Set["rename-keys"]
end
local join
do
  local join0 = nil
  Set.join = function(...)
    local case_26_ = select("#", ...)
    if (case_26_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "Set.join"))
    elseif (case_26_ == 1) then
      return error(("Wrong number of args (%s) passed to %s"):format(1, "Set.join"))
    elseif (case_26_ == 2) then
      local xrel, yrel = ...
      if (seq(xrel) and seq(yrel)) then
        local ks = intersection(hash_set(keys(first(xrel))), hash_set(keys(first(yrel))))
        local function _27_(...)
          if (count(xrel) <= count(yrel)) then
            return {xrel, yrel}
          else
            return {yrel, xrel}
          end
        end
        local _let_28_ = _27_(...)
        local r = _let_28_[1]
        local s = _let_28_[2]
        local idx = index(r, ks)
        local function _29_(ret, x)
          local found = idx(select_keys(x, ks))
          if found then
            local function _30_(_241, _242)
              return conj(_241, merge(_242, x))
            end
            return reduce(_30_, ret, found)
          else
            return ret
          end
        end
        return reduce(_29_, hash_set(), s)
      else
        return hash_set()
      end
    elseif (case_26_ == 3) then
      local xrel, yrel, km = ...
      local function _33_(...)
        if (count(xrel) <= count(yrel)) then
          return {xrel, yrel, map_invert(km)}
        else
          return {yrel, xrel, km}
        end
      end
      local _let_34_ = _33_(...)
      local r = _let_34_[1]
      local s = _let_34_[2]
      local k = _let_34_[3]
      local idx = index(r, vals(k))
      local function _35_(ret, x)
        local found = idx(rename_keys(select_keys(x, keys(k)), k))
        if found then
          local function _36_(_241, _242)
            return conj(_241, merge(_242, x))
          end
          return reduce(_36_, ret, found)
        else
          return ret
        end
      end
      return reduce(_35_, hash_set(), s)
    else
      local _ = case_26_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "Set.join"))
    end
  end
  join0 = Set.join
  join = Set.join
end
Set.select = function(...)
  local pred, xset = ...
  do
    local cnt_69_auto = select("#", ...)
    if (2 ~= cnt_69_auto) then
      error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "Set.select"))
    else
    end
  end
  local function _40_(s, k)
    if pred(k) then
      return s
    else
      return disj(s, k)
    end
  end
  return reduce(_40_, xset, xset)
end
local superset_3f
do
  local superset_3f0 = nil
  Set["superset?"] = function(...)
    local set1, set2 = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "Set.superset?"))
      else
      end
    end
    local and_43_ = (count(set1) >= count(set2))
    if and_43_ then
      local function _44_(_241)
        return contains_3f(set1, _241)
      end
      and_43_ = every_3f(_44_, set2)
    end
    return and_43_
  end
  superset_3f0 = Set["superset?"]
  superset_3f = Set["superset?"]
end
local subset_3f
do
  local subset_3f0 = nil
  Set["subset?"] = function(...)
    local set1, set2 = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "Set.subset?"))
      else
      end
    end
    local and_46_ = (count(set1) <= count(set2))
    if and_46_ then
      local function _47_(_241)
        return contains_3f(set2, _241)
      end
      and_46_ = every_3f(_47_, set1)
    end
    return and_46_
  end
  subset_3f0 = Set["subset?"]
  subset_3f = Set["subset?"]
end
local rename
do
  local rename0 = nil
  Set.rename = function(...)
    local xrel, kmap = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "Set.rename"))
      else
      end
    end
    local function _49_(_241)
      return rename_keys(_241, kmap)
    end
    return hash_set(map(_49_, xrel))
  end
  rename0 = Set.rename
  rename = Set.rename
end
local project
do
  local project0 = nil
  Set.project = function(...)
    local xrel, ks = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "Set.project"))
      else
      end
    end
    local function _51_(_241)
      return select_keys(_241, ks)
    end
    return hash_set(map(_51_, xrel))
  end
  project0 = Set.project
  project = Set.project
end
local difference
do
  local difference0 = nil
  Set.difference = function(...)
    local case_52_ = select("#", ...)
    if (case_52_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "Set.difference"))
    elseif (case_52_ == 1) then
      local s1 = ...
      return s1
    elseif (case_52_ == 2) then
      local s1, s2 = ...
      if (count(s1) < count(s2)) then
        local function _53_(result, item)
          if contains_3f(s2, item) then
            return disj(result, item)
          else
            return result
          end
        end
        return reduce(_53_, s1, s1)
      else
        return reduce(disj, s1, s2)
      end
    else
      local _ = case_52_
      local _let_56_ = require("io.gitlab.andreyorst.cljlib.core")
      local list_51_auto = _let_56_.list
      local s1, s2 = ...
      local sets = list_51_auto(select(3, ...))
      return reduce(difference0, s1, conj(sets, s2))
    end
  end
  difference0 = Set.difference
  difference = Set.difference
end
return Set
