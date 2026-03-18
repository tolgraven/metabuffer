-- [nfnl] .deps/git/io.gitlab.andreyorst/reader.fnl/515c2695fad06d01f279c92d91e9e530a4a427e7/src/io/gitlab/andreyorst/reader.fnl
local max = math.max
local function ok_3f(ok_3f0, ...)
  if ok_3f0 then
    return ...
  else
    return nil
  end
end
local Reader
local function _2_(this, ...)
  return ok_3f(pcall(this.close, this.source, ...))
end
local function _3_(this)
  local case_4_ = this.length
  if (nil ~= case_4_) then
    local len = case_4_
    return len(this.source)
  else
    return nil
  end
end
local function _6_(_241)
  return ("#<" .. tostring(_241):gsub("table:", "Reader:") .. ">")
end
Reader = {__close = _2_, __len = _3_, __name = "Reader", __fennelview = _6_}
local function make_reader(source, _7_)
  local read_bytes = _7_["read-bytes"]
  local read_line = _7_["read-line"]
  local close = _7_.close
  local peek = _7_.peek
  local len = _7_.length
  local _8_
  if close then
    local function _9_(this, ...)
      return close(this.source, ...)
    end
    _8_ = _9_
  else
    local function _10_()
      return nil
    end
    _8_ = _10_
  end
  local _12_
  if read_bytes then
    local function _13_(this, pattern, ...)
      return read_bytes(this.source, pattern, ...)
    end
    _12_ = _13_
  else
    local function _14_()
      return nil
    end
    _12_ = _14_
  end
  local _16_
  if read_line then
    local function _17_(this)
      local function _18_(_, ...)
        return read_line(this.source, ...)
      end
      return _18_
    end
    _16_ = _17_
  else
    local function _19_()
      local function _20_()
        return nil
      end
      return _20_
    end
    _16_ = _19_
  end
  local _22_
  if peek then
    local function _23_(this, pattern, ...)
      return peek(this.source, pattern, ...)
    end
    _22_ = _23_
  else
    local function _24_()
      return nil
    end
    _22_ = _24_
  end
  local _26_
  if len then
    local function _27_(this)
      return len(this.source)
    end
    _26_ = _27_
  else
    local function _28_()
      return nil
    end
    _26_ = _28_
  end
  return setmetatable({source = source, close = _8_, read = _12_, lines = _16_, peek = _22_, length = _26_}, Reader)
end
local open = io.open
local io_2ftype = io.type
local function file_reader(file)
  local file0
  do
    local case_30_ = (io_2ftype(file) or type(file))
    if (case_30_ == "string") then
      file0 = open(file, "r")
    elseif (case_30_ == "file") then
      file0 = file
    elseif (case_30_ == "closed file") then
      file0 = error("file is closed", 2)
    else
      local _ = case_30_
      file0 = error(("expected a string path or a file handle, got " .. _))
    end
  end
  local open_3f
  local function _32_(_241)
    local case_33_ = io_2ftype(_241)
    if (case_33_ == "file") then
      return true
    else
      return nil
    end
  end
  open_3f = _32_
  local close
  local function _35_(_241)
    if open_3f(_241) then
      return _241:close()
    else
      return nil
    end
  end
  close = _35_
  local function _37_(f, pattern)
    if open_3f(f) then
      local case_38_ = f:read(pattern)
      if (nil ~= case_38_) then
        local bytes = case_38_
        return bytes
      elseif (case_38_ == nil) then
        close(f)
        return nil
      else
        return nil
      end
    else
      return nil
    end
  end
  local function _41_(f)
    local next_line
    if open_3f(f) then
      next_line = f:lines()
    else
      next_line = nil
    end
    if open_3f(f) then
      local case_43_ = next_line()
      if (nil ~= case_43_) then
        local line = case_43_
        return line
      elseif (case_43_ == nil) then
        close(f)
        return nil
      else
        return nil
      end
    else
      return nil
    end
  end
  local function _46_(f, pattern)
    assert(("number" == type(pattern)), "expected number of bytes to peek")
    if open_3f(f) then
      local case_47_ = f:read(pattern)
      if (nil ~= case_47_) then
        local res = case_47_
        f:seek("cur", ( - pattern))
        return res
      else
        return nil
      end
    else
      return nil
    end
  end
  local function _50_(f)
    if open_3f(f) then
      local current = f:seek("cur")
      local len = (f:seek("end") - current)
      f:seek("cur", ( - len))
      return len
    else
      return nil
    end
  end
  return make_reader(file0, {close = close, ["read-bytes"] = _37_, ["read-line"] = _41_, peek = _46_, length = _50_})
end
local function string_reader(string)
  assert(("string" == type(string)), "expected a string as first argument")
  local i, closed_3f = 1, false
  local len = #string
  local try_read_line
  local function _52_(s, pattern)
    local case_53_, case_54_, case_55_ = s:find(pattern, i)
    if (true and (nil ~= case_54_) and (nil ~= case_55_)) then
      local _ = case_53_
      local _end = case_54_
      local s0 = case_55_
      i = (_end + 1)
      return s0
    else
      return nil
    end
  end
  try_read_line = _52_
  local read_line
  local function _57_(s)
    if (i <= len) then
      return (try_read_line(s, "(.-)\r?\n") or try_read_line(s, "(.-)\r?$"))
    else
      return nil
    end
  end
  read_line = _57_
  local function _59_(_)
    if not closed_3f then
      i = (len + 1)
      closed_3f = true
      return closed_3f
    else
      return nil
    end
  end
  local function _61_(s, pattern)
    if (i <= len) then
      if ((pattern == "*l") or (pattern == "l")) then
        return read_line(s)
      elseif ((pattern == "*a") or (pattern == "a")) then
        return s:sub(i)
      else
        local and_62_ = (nil ~= pattern)
        if and_62_ then
          local bytes = pattern
          and_62_ = ("number" == type(bytes))
        end
        if and_62_ then
          local bytes = pattern
          local res = s:sub(i, (i + bytes + -1))
          i = (i + bytes)
          return res
        else
          return nil
        end
      end
    else
      return nil
    end
  end
  local function _66_(s, pattern)
    if (i <= len) then
      local and_67_ = (nil ~= pattern)
      if and_67_ then
        local bytes = pattern
        and_67_ = ("number" == type(bytes))
      end
      if and_67_ then
        local bytes = pattern
        local res = s:sub(i, (i + bytes + -1))
        return res
      else
        local _ = pattern
        return error("expected number of bytes to peek")
      end
    else
      return nil
    end
  end
  local function _71_(s)
    if not closed_3f then
      return max(0, (#s - (i - 1)))
    else
      return nil
    end
  end
  return make_reader(string, {close = _59_, ["read-bytes"] = _61_, ["read-line"] = read_line, peek = _66_, length = _71_})
end
local ltn_reader = nil
do
  local case_73_, case_74_ = pcall(require, "ltn12")
  if ((case_73_ == true) and (nil ~= case_74_)) then
    local ltn12 = case_74_
    local sink_2ftable = ltn12.sink.table
    local sink_2fnull = ltn12.sink.null
    local concat = table.concat
    local function ltn12_reader(source, step)
      local step0 = (step or ltn12.pump.step)
      local buffer = ""
      local closed_3f = false
      local function read(source0, pattern)
        if not closed_3f then
          local rdr = string_reader(buffer)
          local content = rdr:read(pattern)
          local len = #(content or "")
          local data = {}
          local and_75_ = (nil ~= pattern)
          if and_75_ then
            local bytes = pattern
            and_75_ = ("number" == type(bytes))
          end
          if and_75_ then
            local bytes = pattern
            buffer = (rdr:read("*a") or "")
            if (len < pattern) then
              if step0(source0, sink_2ftable(data)) then
                buffer = (buffer .. (data[1] or ""))
                local case_77_ = read(source0, (bytes - len))
                local and_78_ = (nil ~= case_77_)
                if and_78_ then
                  local data0 = case_77_
                  and_78_ = data0
                end
                if and_78_ then
                  local data0 = case_77_
                  return ((content or "") .. data0)
                else
                  local _ = case_77_
                  return content
                end
              else
                return content
              end
            else
              return content
            end
          elseif ((pattern == "*a") or (pattern == "a")) then
            buffer = (rdr:read("*a") or "")
            while step0(source0, sink_2ftable(data)) do
            end
            return ((content or "") .. concat(data))
          elseif ((pattern == "*l") or (pattern == "l")) then
            if buffer:match("\n") then
              buffer = (rdr:read("*a") or "")
              return content
            else
              if step0(source0, sink_2ftable(data)) then
                buffer = (buffer .. (data[1] or ""))
                local case_83_ = read(source0, pattern)
                if (nil ~= case_83_) then
                  local data0 = case_83_
                  return ((content or "") .. data0)
                else
                  local _ = case_83_
                  return content
                end
              else
                buffer = (rdr:read("*a") or "")
                return content
              end
            end
          else
            return nil
          end
        else
          return nil
        end
      end
      local function _89_(source0)
        while step0(source0, sink_2fnull()) do
        end
        closed_3f = true
        return nil
      end
      local function _90_(_241)
        if not closed_3f then
          return read(_241, "*l")
        else
          return nil
        end
      end
      local function peek(source0, bytes)
        if not closed_3f then
          local rdr = string_reader(buffer)
          local content = rdr:peek(bytes)
          local len = #(content or "")
          local data = {}
          if (len < bytes) then
            if step0(source0, sink_2ftable(data)) then
              buffer = (buffer .. (data[1] or ""))
              local case_92_ = peek(source0, (bytes - len))
              local and_93_ = (nil ~= case_92_)
              if and_93_ then
                local data0 = case_92_
                and_93_ = data0
              end
              if and_93_ then
                local data0 = case_92_
                return data0
              else
                local _ = case_92_
                return content
              end
            else
              return content
            end
          else
            return content
          end
        else
          return nil
        end
      end
      return make_reader(source, {close = _89_, ["read-bytes"] = read, ["read-line"] = _90_, peek = peek})
    end
    ltn_reader = ltn12_reader
  else
  end
end
local function reader_3f(obj)
  local case_100_ = getmetatable(obj)
  if (case_100_ == Reader) then
    return true
  else
    local _ = case_100_
    return false
  end
end
return {["make-reader"] = make_reader, ["file-reader"] = file_reader, ["string-reader"] = string_reader, ["reader?"] = reader_3f, ["ltn12-reader"] = ltn_reader, __VERSION = "0.1.12"}
