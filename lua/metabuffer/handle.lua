-- [nfnl] fnl/metabuffer/handle.fnl
local M = {}
local function valid_buf_3f(x)
  return ((type(x) == "number") and pcall(vim.api.nvim_buf_is_valid, x) and vim.api.nvim_buf_is_valid(x))
end
local function valid_win_3f(x)
  return ((type(x) == "number") and pcall(vim.api.nvim_win_is_valid, x) and vim.api.nvim_win_is_valid(x))
end
local function get_local_opt(name, target)
  if valid_buf_3f(target) then
    local ok,v = pcall(vim.api.nvim_get_option_value, name, {buf = target})
    if ok then
      return v
    else
      if valid_win_3f(target) then
        local wok,wv = pcall(vim.api.nvim_get_option_value, name, {win = target})
        if wok then
          return wv
        else
          return vim.api.nvim_get_option_value(name, {scope = "local"})
        end
      else
        return vim.api.nvim_get_option_value(name, {scope = "local"})
      end
    end
  else
    if valid_win_3f(target) then
      local ok,v = pcall(vim.api.nvim_get_option_value, name, {win = target})
      if ok then
        return v
      else
        return vim.api.nvim_get_option_value(name, {scope = "local"})
      end
    else
      return vim.api.nvim_get_option_value(name, {scope = "local"})
    end
  end
end
local function set_local_opt(name, value, target)
  if valid_buf_3f(target) then
    local ok,_ = pcall(vim.api.nvim_set_option_value, name, value, {buf = target})
    if not ok then
      if valid_win_3f(target) then
        local wok,_w = pcall(vim.api.nvim_set_option_value, name, value, {win = target})
        if not wok then
          return pcall(vim.api.nvim_set_option_value, name, value, {scope = "local"})
        else
          return nil
        end
      else
        return pcall(vim.api.nvim_set_option_value, name, value, {scope = "local"})
      end
    else
      return nil
    end
  else
    if valid_win_3f(target) then
      local ok,_ = pcall(vim.api.nvim_set_option_value, name, value, {win = target})
      if not ok then
        return pcall(vim.api.nvim_set_option_value, name, value, {scope = "local"})
      else
        return nil
      end
    else
      return pcall(vim.api.nvim_set_option_value, name, value, {scope = "local"})
    end
  end
end
M.new = function(nvim, target, model, opts_from_model, opts)
  local self = {nvim = nvim, target = target, model = (model or target), ["saved-opts"] = {}, terminated = false}
  self["store-opt"] = function(name, _origin)
    if (self["saved-opts"][name] == nil) then
      self["saved-opts"][name] = get_local_opt(name, _origin)
      return nil
    else
      return nil
    end
  end
  self["store-opts"] = function(names, _origin)
    for _, name in ipairs((names or {})) do
      self["store-opt"](name, _origin)
    end
    return nil
  end
  self["apply-opts"] = function(tbl)
    for k, v in pairs((tbl or {})) do
      self["store-opt"](k, self.model)
      set_local_opt(k, v, self.target)
    end
    return nil
  end
  self["push-opt"] = function(name, value)
    self["store-opt"](name, self.model)
    return set_local_opt(name, value, self.target)
  end
  self["pop-opt"] = function(name)
    local v = self["saved-opts"][name]
    if (v ~= nil) then
      return set_local_opt(name, v, self.target)
    else
      return nil
    end
  end
  self["restore-opts"] = function()
    return self["apply-opts"](self["saved-opts"])
  end
  self.destroy = function()
    if not self.terminated then
      self["restore-opts"]()
      self.terminated = true
      return nil
    else
      return nil
    end
  end
  self["store-opts"](opts_from_model, model)
  self["apply-opts"](opts)
  return self
end
return M
