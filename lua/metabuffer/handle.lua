local M = {}
M.new = function(nvim, target, model, opts_from_model, opts)
  local self = {nvim = nvim, target = target, model = (model or target), ["saved-opts"] = {}, terminated = false}
  self["store-opts"] = function(names, origin)
    for _, name in ipairs((names or {})) do
      self["saved-opts"][name] = vim.api.nvim_get_option_value(name, {scope = "local"})
    end
    return nil
  end
  self["apply-opts"] = function(tbl)
    for k, v in pairs((tbl or {})) do
      pcall(vim.api.nvim_set_option_value, k, v, {scope = "local"})
    end
    return nil
  end
  self["push-opt"] = function(name, value)
    self["saved-opts"][name] = vim.api.nvim_get_option_value(name, {scope = "local"})
    return pcall(vim.api.nvim_set_option_value, name, value, {scope = "local"})
  end
  self["pop-opt"] = function(name)
    local v = self["saved-opts"][name]
    if (v ~= nil) then
      return pcall(vim.api.nvim_set_option_value, name, v, {scope = "local"})
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
