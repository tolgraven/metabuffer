--[[ MIT License

Copyright (c) 2021 Andrey Listopadov

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE. ]]

local date, time = os.date, os.time

local full_date_formats = {
    "(%-?%d%d%d%d)%-(1[012])%-([012]%d)",
    "(%-?%d%d%d%d)%-(1[012])%-(3[01])",
    "(%-?%d%d%d%d)%-(0%d)%-([012]%d)",
    "(%-?%d%d%d%d)%-(0%d)%-(3[01])",
    "(%-?%d%d%d%d)(1[012])([012]%d)",
    "(%-?%d%d%d%d)(1[012])(3[01])",
    "(%-?%d%d%d%d)(0%d)([012]%d)",
    "(%-?%d%d%d%d)(0%d)(3[01])",
}

local partial_date_formats = {
    "(%-?%d%d%d%d)%-(1[012])",
    "(%-?%d%d%d%d)%-(0%d)",
    "(%-?%d%d%d%d)(1[012])",
    "(%-?%d%d%d%d)(0%d)",
    "(%-?%d%d%d%d)",
}

local time_formats = {
    "([01]%d):([0-5]%d):([0-5]%d)%.(%d+)",
    "([2][0-4]):([0-5]%d):([0-5]%d)%.(%d+)",
    "([01]%d):([0-5]%d):(60)%.(%d+)",
    "([2][0-4]):([0-5]%d):(60)%.(%d+)",
    "([01]%d):([0-5]%d):([0-5]%d)",
    "([2][0-4]):([0-5]%d):([0-5]%d)",
    "([01]%d):([0-5]%d):(60)",
    "([2][0-4]):([0-5]%d):(60)",
}

local offset_formats = {
    "([+-])([01]%d):([0-5]%d)",
    "([+-])([2][0-4]):([0-5]%d)",
    "([+-])([01]%d)([0-5]%d)",
    "([+-])([2][0-4])([0-5]%d)",
    "([+-])([01]%d)",
    "([+-])([2][0-4])",
    "Z"
}

local months_w_thirty_one_days = {
    [1] = true,
    [3] = true,
    [5] = true,
    [7] = true,
    [8] = true,
    [10] = true,
    [12] = true
}

-- compiling all possible ISO8601 patterns
local iso8601_formats = {}
for _,date_fmt in ipairs(full_date_formats) do
    for _,time_fmt in ipairs(time_formats) do
        for _,offset_fmt in ipairs(offset_formats) do
            iso8601_formats[#iso8601_formats+1] = "^"..date_fmt.."T"..time_fmt..offset_fmt.."$"
end end end

local function is_leap_year(year)
    return 0 == year % 4 and (0 ~= year % 100 or 0 == year % 400)
end

local function parse_date_time (date_time_str)
    local year, mon, day, hh, mm, ss, ms, sign, off_h, off_m

    -- trying to parse a complete ISO8601 date
    for _,fmt in pairs(iso8601_formats) do
        year, mon, day, hh, mm, ss, ms, sign, off_h, off_m = date_time_str:match(fmt)
        if year then break end
    end

    -- milliseconds are optional, so offset may be stored in ms
    if not off_m and ms and ms:match("^[+-]") then
        off_m, off_h, sign, ms = off_h, sign, ms, 0
    end

    sign, off_h, off_m = sign or "+", off_h or 0, off_m or 0

    return year, mon, day, hh, mm, ss, ms, sign, off_h, off_m
end

local function parse_date (date_str)
    local year, mon, day
    for _,fmt in pairs(full_date_formats) do
        year, mon, day = date_str:match("^"..fmt.."$")
        if year ~= nil then break end
    end
    if not year then
        for _,fmt in pairs(partial_date_formats) do
            year, mon, day = date_str:match("^"..fmt.."$")
            if year ~= nil then break end
    end end
    return year, mon, day
end

local function parse_iso8601 (date_str)
    local year, mon, day, hh, mm, ss, ms, sign, off_h, off_m = parse_date_time(date_str)

    if not year then
        -- trying to parse only a year with optional month and day
        year, mon, day = parse_date(date_str)
    end

    if not year then
        error(("invalid date '%s': date string doesn't match ISO8601 pattern"):format(date_str), 2)
    end

    if is_leap_year(tonumber(year)) and mon and tonumber(mon) == 2 and day and tonumber(day) > 29 then
        error(("invalid date '%s': February has 29 days in leap years"):format(date_str), 2)
    elseif not is_leap_year(tonumber(year)) and mon and tonumber(mon) == 2 and day and tonumber(day) > 28 then
        error(("invalid date '%s': February has 28 days in non leap years"):format(date_str), 2)
    end

    if mon and day and tonumber(day) == 31 and not months_w_thirty_one_days[tonumber(mon)] then
        error(("invalid date '%s': month %d has 30 days"):format(date_str, mon), 2)
    end

    return { year = year,
             month = tonumber(mon) or 1,
             day = tonumber(day) or 1,
             hour = (tonumber(hh) or 0) - (tonumber(sign..off_h) or 0),
             min = (tonumber(mm) or 0) - (tonumber(sign..off_m) or 0),
             sec = tonumber(ss or 0),
             msec = tonumber(ms or 0) }
end

local function inst (date_str)
    local inst = parse_iso8601(date_str)
    return setmetatable(inst, {
        __tostring = function ()
            return ("#inst \"%04d-%s.%03d-00:00\""):format(inst.year, date("%m-%dT%H:%M:%S", time(inst)), inst.msec)
        end,
        __len = function (inst) return inst end
    })
end

return inst
