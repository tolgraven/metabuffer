-- [nfnl] .deps/git/io.gitlab.andreyorst/fennel-cljlib/256d59ef6efd0f39ca35bb6815e9c29bc8b8584a/src/io/gitlab/andreyorst/cljlib/string.fnl
local function _1_()
  return "#<namespace: io.gitlab.andreyorst.cljlib.string>"
end
--[[ "Fennel String utilities.
Designed to wor" ]]
local _local_2_ = {setmetatable({}, {__fennelview = _1_, __name = "namespace"}), require("io.gitlab.andreyorst.cljlib.core"), require("fennel")}, nil
local string = _local_2_[1]
local _local_3_ = _local_2_[2]
local seq = _local_3_.seq
local vec = _local_3_.vec
local core = _local_3_
local _local_4_ = _local_2_[3]
local view = _local_4_.view
local fennel = _local_4_
local function pairs_2a(t)
  local case_5_ = getmetatable(t)
  if ((_G.type(case_5_) == "table") and (nil ~= case_5_.__pairs)) then
    local p = case_5_.__pairs
    return p(t)
  else
    local _ = case_5_
    return pairs(t)
  end
end
local starts_with_3f
do
  local starts_with_3f0 = nil
  string["starts-with?"] = function(...)
    local s, substr = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "string.starts-with?"))
      else
      end
    end
    return (s:sub(1, #substr) == substr)
  end
  starts_with_3f0 = string["starts-with?"]
  starts_with_3f = string["starts-with?"]
end
local ends_with_3f
do
  local ends_with_3f0 = nil
  string["ends-with?"] = function(...)
    local s, substr = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "string.ends-with?"))
      else
      end
    end
    return ((substr == "") or (s:sub(( - #substr)) == substr))
  end
  ends_with_3f0 = string["ends-with?"]
  ends_with_3f = string["ends-with?"]
end
local reverse
do
  local reverse0 = nil
  string.reverse = function(...)
    local s = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "string.reverse"))
      else
      end
    end
    return s:reverse()
  end
  reverse0 = string.reverse
  reverse = string.reverse
end
local join
do
  local join0 = nil
  string.join = function(...)
    local case_10_ = select("#", ...)
    if (case_10_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "string.join"))
    elseif (case_10_ == 1) then
      local coll = ...
      return join0("", coll)
    elseif (case_10_ == 2) then
      local separator, coll = ...
      local val_111_auto = seq(coll)
      if val_111_auto then
        local coll0 = val_111_auto
        local _11_
        do
          local tbl_26_ = {}
          local i_27_ = 0
          for _, elem in pairs_2a(coll0) do
            local val_28_
            if ("string" ~= type(elem)) then
              val_28_ = view(elem, {["one-line?"] = true})
            else
              val_28_ = elem
            end
            if (nil ~= val_28_) then
              i_27_ = (i_27_ + 1)
              tbl_26_[i_27_] = val_28_
            else
            end
          end
          _11_ = tbl_26_
        end
        return table.concat(_11_, tostring(separator))
      else
        return ""
      end
    else
      local _ = case_10_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "string.join"))
    end
  end
  join0 = string.join
  join = string.join
end
local replace
do
  local replace0 = nil
  string.replace = function(...)
    local case_19_ = select("#", ...)
    if (case_19_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "string.replace"))
    elseif (case_19_ == 1) then
      return error(("Wrong number of args (%s) passed to %s"):format(1, "string.replace"))
    elseif (case_19_ == 2) then
      return error(("Wrong number of args (%s) passed to %s"):format(2, "string.replace"))
    elseif (case_19_ == 3) then
      local s, pattern, replacement = ...
      return replace0(s, pattern, replacement, false)
    elseif (case_19_ == 4) then
      local s, pattern, replacement, literal_3f = ...
      local pattern0
      if literal_3f then
        pattern0 = pattern:gsub("([][().%+-*?^$)", "%%%1")
      else
        pattern0 = pattern
      end
      return (s:gsub(pattern0, replacement))
    else
      local _ = case_19_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "string.replace"))
    end
  end
  replace0 = string.replace
  replace = string.replace
end
local replace_first
do
  local replace_first0 = nil
  string["replace-first"] = function(...)
    local case_25_ = select("#", ...)
    if (case_25_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "string.replace-first"))
    elseif (case_25_ == 1) then
      return error(("Wrong number of args (%s) passed to %s"):format(1, "string.replace-first"))
    elseif (case_25_ == 2) then
      return error(("Wrong number of args (%s) passed to %s"):format(2, "string.replace-first"))
    elseif (case_25_ == 3) then
      local s, pattern, replacement = ...
      return replace_first0(s, pattern, replacement, false)
    elseif (case_25_ == 4) then
      local s, pattern, replacement, literal_3f = ...
      local pattern0
      if literal_3f then
        pattern0 = pattern:gsub("([][().%+-*?^$)", "%%%1")
      else
        pattern0 = pattern
      end
      return (s:gsub(pattern0, replacement, 1))
    else
      local _ = case_25_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "string.replace-first"))
    end
  end
  replace_first0 = string["replace-first"]
  replace_first = string["replace-first"]
end
local escape
do
  local escape0 = nil
  string.escape = function(...)
    local s, cmap = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "string.escape"))
      else
      end
    end
    return (s:gsub(".", cmap))
  end
  escape0 = string.escape
  escape = string.escape
end
local last_index_of
do
  local last_index_of0 = nil
  string["last-index-of"] = function(...)
    local case_30_ = select("#", ...)
    if (case_30_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "string.last-index-of"))
    elseif (case_30_ == 1) then
      return error(("Wrong number of args (%s) passed to %s"):format(1, "string.last-index-of"))
    elseif (case_30_ == 2) then
      local s, value = ...
      local len = #s
      local i, res = -1, nil
      while (not res and (i >= ( - len))) do
        res = s:find(value, i, true)
        i = (i - #value)
      end
      return res
    elseif (case_30_ == 3) then
      local s, value, from_index = ...
      return last_index_of0(s:sub(1, from_index), value)
    else
      local _ = case_30_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "string.last-index-of"))
    end
  end
  last_index_of0 = string["last-index-of"]
  last_index_of = string["last-index-of"]
end
local re_quote_replacement
do
  local re_quote_replacement0 = nil
  string["re-quote-replacement"] = function(...)
    local replacement = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "string.re-quote-replacement"))
      else
      end
    end
    return (replacement:gsub("([][().%+-*?^$])", "%%%1"))
  end
  re_quote_replacement0 = string["re-quote-replacement"]
  re_quote_replacement = string["re-quote-replacement"]
end
local includes_3f
do
  local includes_3f0 = nil
  string["includes?"] = function(...)
    local s, substr = ...
    do
      local cnt_69_auto = select("#", ...)
      if (2 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "string.includes?"))
      else
      end
    end
    return (s:find(substr, 1, true))
  end
  includes_3f0 = string["includes?"]
  includes_3f = string["includes?"]
end
local lower_case
do
  local lower_case0 = nil
  string["lower-case"] = function(...)
    local s = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "string.lower-case"))
      else
      end
    end
    return s:lower()
  end
  lower_case0 = string["lower-case"]
  lower_case = string["lower-case"]
end
local upper_case
do
  local upper_case0 = nil
  string["upper-case"] = function(...)
    local s = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "string.upper-case"))
      else
      end
    end
    return s:upper()
  end
  upper_case0 = string["upper-case"]
  upper_case = string["upper-case"]
end
local capitalize
do
  local capitalize0 = nil
  string.capitalize = function(...)
    local s = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "string.capitalize"))
      else
      end
    end
    return (upper_case(s:sub(1, 1)) .. lower_case(s:sub(2, -1)))
  end
  capitalize0 = string.capitalize
  capitalize = string.capitalize
end
local function split_2a(self, pat)
  local pat0 = (pat or "%s+")
  local g = self:gmatch(("()(" .. pat0 .. ")"))
  local st = 1
  local function getter(segs, seps, sep, cap1, ...)
    st = (sep and (seps + #sep))
    return self:sub(segs, ((seps or 0) - 1)), (cap1 or sep), ...
  end
  local function _37_()
    if st then
      return getter(st, g())
    else
      return nil
    end
  end
  return _37_
end
local split
do
  local split0 = nil
  string.split = function(...)
    local case_40_ = select("#", ...)
    if (case_40_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "string.split"))
    elseif (case_40_ == 1) then
      return error(("Wrong number of args (%s) passed to %s"):format(1, "string.split"))
    elseif (case_40_ == 2) then
      local s, pat = ...
      local res
      do
        local tbl_26_ = {}
        local i_27_ = 0
        for part in split_2a(s, pat) do
          local val_28_ = part
          if (nil ~= val_28_) then
            i_27_ = (i_27_ + 1)
            tbl_26_[i_27_] = val_28_
          else
          end
        end
        res = tbl_26_
      end
      while (res[#res] == "") do
        table.remove(res, #res)
      end
      return vec(res)
    elseif (case_40_ == 3) then
      local s, pat, limit = ...
      local parts = split_2a(s, pat)
      local function recur(cnt, last_end, res)
        local case_42_, case_43_ = parts()
        if ((nil ~= case_42_) and true) then
          local part = case_42_
          local _3fsep = case_43_
          if (cnt > 0) then
            local function _44_()
              table.insert(res, part)
              return res
            end
            return recur((cnt - 1), (last_end + #part + #(_3fsep or "")), _44_())
          else
            local case_45_ = s:sub(last_end, -1)
            if (case_45_ == "") then
              return res
            elseif (case_45_ == nil) then
              return res
            elseif (nil ~= case_45_) then
              local part0 = case_45_
              res[#res] = (res[#res] .. part0)
              return res
            else
              return nil
            end
          end
        else
          local _ = case_42_
          return res
        end
      end
      local _49_
      if (limit < 0) then
        _49_ = math.huge
      else
        _49_ = limit
      end
      return vec(recur(_49_, 0, {}))
    else
      local _ = case_40_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "string.split"))
    end
  end
  split0 = string.split
  split = string.split
end
local split_lines
do
  local split_lines0 = nil
  string["split-lines"] = function(...)
    local s = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "string.split-lines"))
      else
      end
    end
    return split(s, "\r?\n")
  end
  split_lines0 = string["split-lines"]
  split_lines = string["split-lines"]
end
local trim
do
  local trim0 = nil
  string.trim = function(...)
    local s = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "string.trim"))
      else
      end
    end
    return s:match("^%s*(.-)%s*$")
  end
  trim0 = string.trim
  trim = string.trim
end
local index_of
do
  local index_of0 = nil
  string["index-of"] = function(...)
    local case_55_ = select("#", ...)
    if (case_55_ == 0) then
      return error(("Wrong number of args (%s) passed to %s"):format(0, "string.index-of"))
    elseif (case_55_ == 1) then
      return error(("Wrong number of args (%s) passed to %s"):format(1, "string.index-of"))
    elseif (case_55_ == 2) then
      local s, value = ...
      return index_of0(s, value, 1)
    elseif (case_55_ == 3) then
      local s, value, from_index = ...
      return (s:find(value, from_index, true))
    else
      local _ = case_55_
      return error(("Wrong number of args (%s) passed to %s"):format(_, "string.index-of"))
    end
  end
  index_of0 = string["index-of"]
  index_of = string["index-of"]
end
local trimr
do
  local trimr0 = nil
  string.trimr = function(...)
    local s = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "string.trimr"))
      else
      end
    end
    return s:match("^(.-)%s*$")
  end
  trimr0 = string.trimr
  trimr = string.trimr
end
local triml
do
  local triml0 = nil
  string.triml = function(...)
    local s = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "string.triml"))
      else
      end
    end
    return s:match("^%s*(.-)$")
  end
  triml0 = string.triml
  triml = string.triml
end
local trim_newline
do
  local trim_newline0 = nil
  string["trim-newline"] = function(...)
    local s = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "string.trim-newline"))
      else
      end
    end
    return s:match("^(.-)[\n\r]*$")
  end
  trim_newline0 = string["trim-newline"]
  trim_newline = string["trim-newline"]
end
local blank_3f
do
  local blank_3f0 = nil
  string["blank?"] = function(...)
    local s = ...
    do
      local cnt_69_auto = select("#", ...)
      if (1 ~= cnt_69_auto) then
        error(("Wrong number of args (%s) passed to %s"):format(cnt_69_auto, "string.blank?"))
      else
      end
    end
    return ((nil == s) or ("" == s) or not s:find("[^%s]"))
  end
  blank_3f0 = string["blank?"]
  blank_3f = string["blank?"]
end
return string
