-- [nfnl] fnl/metabuffer/compat/conjure.fnl
local tracked_bufs = {}
local function buf_valid_3f(buf)
  return (buf and vim.api.nvim_buf_is_valid(buf))
end
local function get_buf_var(buf, key)
  local ok,value = pcall(vim.api.nvim_buf_get_var, buf, key)
  if ok then
    return value
  else
    return vim.NIL
  end
end
local function set_buf_var_21(buf, key, value)
  return pcall(vim.api.nvim_buf_set_var, buf, key, value)
end
local function del_buf_var_21(buf, key)
  return pcall(vim.api.nvim_buf_del_var, buf, key)
end
local function ensure_buf_state(buf)
  local state = (tracked_bufs[buf] or {count = 0, saved = {}})
  if (tracked_bufs[buf] == nil) then
    tracked_bufs[buf] = state
  else
  end
  return state
end
local conjure_vars = {"conjure_disable", "conjure#client_on_load", "conjure#mapping#enable_ft_mappings", "conjure#mapping#enable_defaults", "conjure#mapping#doc_word", "conjure#log#hud#enabled"}
local function apply_conjure_compat_21(_3_)
  local buf = _3_.buf
  if buf_valid_3f(buf) then
    local state = ensure_buf_state(buf)
    local saved = state.saved
    if (state.count == 0) then
      for _, key in ipairs(conjure_vars) do
        saved[key] = get_buf_var(buf, key)
      end
      saved["omnifunc"] = vim.bo[buf].omnifunc
    else
    end
    state.count = (1 + (state.count or 0))
    set_buf_var_21(buf, "conjure_disable", true)
    set_buf_var_21(buf, "conjure#client_on_load", false)
    set_buf_var_21(buf, "conjure#mapping#enable_ft_mappings", false)
    set_buf_var_21(buf, "conjure#mapping#enable_defaults", false)
    set_buf_var_21(buf, "conjure#mapping#doc_word", false)
    set_buf_var_21(buf, "conjure#log#hud#enabled", false)
    local bo = vim.bo[buf]
    bo["omnifunc"] = ""
    return nil
  else
    return nil
  end
end
local function restore_conjure_compat_21(_6_)
  local buf = _6_.buf
  if buf_valid_3f(buf) then
    local state = tracked_bufs[buf]
    if state then
      state.count = math.max(0, ((state.count or 0) - 1))
      if (state.count == 0) then
        do
          local saved = state.saved
          for _, key in ipairs(conjure_vars) do
            local value = saved[key]
            if (value == vim.NIL) then
              del_buf_var_21(buf, key)
            else
              set_buf_var_21(buf, key, value)
            end
          end
          local bo = vim.bo[buf]
          if (saved.omnifunc == vim.NIL) then
            bo["omnifunc"] = ""
          else
            bo["omnifunc"] = (saved.omnifunc or "")
          end
        end
        tracked_bufs[buf] = nil
        return nil
      else
        return nil
      end
    else
      return nil
    end
  else
    return nil
  end
end
local function restore_all_21(_)
  for buf, _0 in pairs(tracked_bufs) do
    restore_conjure_compat_21({buf = buf})
  end
  return nil
end
return {name = "conjure", domain = "compat", events = {["on-buf-create!"] = {{handler = apply_conjure_compat_21, priority = 12}}, ["on-buf-teardown!"] = {{handler = restore_conjure_compat_21, priority = 88}}, ["on-session-stop!"] = {{handler = restore_all_21, priority = 89}}}}
