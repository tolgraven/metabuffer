-- [nfnl] .deps/git/io.gitlab.andreyorst/uuid.fnl/209ff4f3a70ba8354034eaf90b70ddb0d14ea254/src/io/gitlab/andreyorst/uuid.fnl
--[[ "MIT License

Copyright (c) 2025 Andrey Listopadov

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
SOFTWARE.
" ]]
local m_2fmod = (math.fmod or math.mod)
local m_2ffloor = math.floor
local m_2frandom = math.random
local s_2fsub = string.sub
local s_2fformat = string.format
local function num__3ebs(num)
  local result, num0 = "", num
  if (num0 == 0) then
    return 0
  else
    while (num0 > 0) do
      result = (m_2fmod(num0, 2) .. result)
      num0 = m_2ffloor((num0 * 0.5))
    end
    return result
  end
end
local function bs__3enum(num)
  if (num == "0") then
    return 0
  else
    local index, result = 0, 0
    for p = #tostring(num), 1, -1 do
      local this_val = s_2fsub(num, p, p)
      if (this_val == "1") then
        result = (result + (2 ^ index))
      else
      end
      index = (index + 1)
    end
    return result
  end
end
local function padbits(num, bits)
  if (#tostring(num) == bits) then
    return num
  else
    local num0 = num
    for i = 1, (bits - #tostring(num0)) do
      num0 = ("0" .. num0)
    end
    return num0
  end
end
local function random_uuid()
  m_2frandom()
  local time_low_a = m_2frandom(0, 65535)
  local time_low_b = m_2frandom(0, 65535)
  local time_mid = m_2frandom(0, 65535)
  local time_hi = padbits(num__3ebs(m_2frandom(0, 4095)), 12)
  local time_hi_and_version = bs__3enum(("0100" .. time_hi))
  local clock_seq_hi_res = ("10" .. padbits(num__3ebs(m_2frandom(0, 63)), 6))
  local clock_seq_low = padbits(num__3ebs(m_2frandom(0, 255)), 8)
  local clock_seq = bs__3enum((clock_seq_hi_res .. clock_seq_low))
  local node = {nil, nil, nil, nil, nil, nil}
  for i = 1, 6 do
    node[i] = m_2frandom(0, 255)
  end
  local guid = ""
  do
    guid = (guid .. padbits(s_2fformat("%x", time_low_a), 4))
    guid = (guid .. padbits(s_2fformat("%x", time_low_b), 4) .. "-")
    guid = (guid .. padbits(s_2fformat("%x", time_mid), 4) .. "-")
    guid = (guid .. padbits(s_2fformat("%x", time_hi_and_version), 4) .. "-")
    guid = (guid .. padbits(s_2fformat("%x", clock_seq), 4) .. "-")
  end
  for i = 1, 6 do
    guid = (guid .. padbits(s_2fformat("%x", node[i]), 2))
  end
  return guid
end
local d = "[0-9a-fA-F]"
local uuid_pat = ("^" .. d .. d .. d .. d .. d .. d .. d .. d .. "%-" .. d .. d .. d .. d .. "%-" .. d .. d .. d .. d .. "%-" .. d .. d .. d .. d .. "%-" .. d .. d .. d .. d .. d .. d .. d .. d .. d .. d .. d .. d .. "$")
local function uuid_3f(x)
  if (("string" == type(x)) and x:match(uuid_pat)) then
    return true
  else
    return false
  end
end
return {["random-uuid"] = random_uuid, ["uuid?"] = uuid_3f}
