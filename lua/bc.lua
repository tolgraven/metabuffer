local M = {}

local mt = {}

local function unwrap(x)
  if type(x) == 'table' and getmetatable(x) == mt then
    return x.value
  end
  return tonumber(x) or 0
end

local function wrap(x)
  return setmetatable({ value = unwrap(x) }, mt)
end

function M.new(x)
  return wrap(x)
end

function M.trunc(x)
  local n = unwrap(x)
  if n >= 0 then
    return wrap(math.floor(n))
  end
  return wrap(math.ceil(n))
end

function M.abs(x)
  return wrap(math.abs(unwrap(x)))
end

function M.tonumber(x)
  return unwrap(x)
end

function M.digits(_)
  return nil
end

mt.__add = function(a, b)
  return wrap(unwrap(a) + unwrap(b))
end

mt.__sub = function(a, b)
  return wrap(unwrap(a) - unwrap(b))
end

mt.__mul = function(a, b)
  return wrap(unwrap(a) * unwrap(b))
end

mt.__div = function(a, b)
  return wrap(unwrap(a) / unwrap(b))
end

mt.__mod = function(a, b)
  return wrap(unwrap(a) % unwrap(b))
end

mt.__pow = function(a, b)
  return wrap(unwrap(a) ^ unwrap(b))
end

mt.__unm = function(a)
  return wrap(-unwrap(a))
end

mt.__eq = function(a, b)
  return unwrap(a) == unwrap(b)
end

mt.__lt = function(a, b)
  return unwrap(a) < unwrap(b)
end

mt.__le = function(a, b)
  return unwrap(a) <= unwrap(b)
end

mt.__tostring = function(a)
  return tostring(unwrap(a))
end

return M
