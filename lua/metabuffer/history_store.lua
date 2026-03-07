-- [nfnl] fnl/metabuffer/history_store.fnl
local M = {}
local history_file = (vim.fn.stdpath("data") .. "/metabuffer_prompt_history.json")
local function read_store()
  if (1 == vim.fn.filereadable(history_file)) then
    local raw = table.concat(vim.fn.readfile(history_file), "\n")
    local ok,data = pcall(vim.json.decode, raw)
    if (ok and (type(data) == "table")) then
      return data
    else
      return {}
    end
  else
    return {}
  end
end
local function write_store_21(history, saved)
  local payload = {history = (history or {}), saved = (saved or {})}
  local ok,json = pcall(vim.json.encode, payload)
  if ok then
    pcall(vim.fn.mkdir, vim.fn.fnamemodify(history_file, ":h"), "p")
    return pcall(vim.fn.writefile, {json}, history_file)
  else
    return nil
  end
end
local function ensure_loaded_21()
  if not vim.g.metabuffer_history_loaded then
    local store = read_store()
    local loaded_history
    if (type(store.history) == "table") then
      loaded_history = store.history
    else
      loaded_history = {}
    end
    local loaded_saved
    if (type(store.saved) == "table") then
      loaded_saved = store.saved
    else
      loaded_saved = {}
    end
    if (type(vim.g.metabuffer_prompt_history) == "table") then
      vim.g.metabuffer_prompt_history = vim.g.metabuffer_prompt_history
    else
      vim.g.metabuffer_prompt_history = loaded_history
    end
    if (type(vim.g.metabuffer_saved_prompts) == "table") then
      vim.g.metabuffer_saved_prompts = vim.g.metabuffer_saved_prompts
    else
      vim.g.metabuffer_saved_prompts = loaded_saved
    end
    vim.g.metabuffer_history_loaded = true
    return nil
  else
    return nil
  end
end
M.list = function()
  ensure_loaded_21()
  if (type(vim.g.metabuffer_prompt_history) == "table") then
    return vim.g.metabuffer_prompt_history
  else
    vim.g.metabuffer_prompt_history = {}
    return vim.g.metabuffer_prompt_history
  end
end
M.saved = function()
  ensure_loaded_21()
  if (type(vim.g.metabuffer_saved_prompts) == "table") then
    return vim.g.metabuffer_saved_prompts
  else
    vim.g.metabuffer_saved_prompts = {}
    return vim.g.metabuffer_saved_prompts
  end
end
local function persist_21()
  return write_store_21(M.list(), M.saved())
end
M["push!"] = function(text, max_items)
  if ((type(text) == "string") and (vim.trim(text) ~= "")) then
    local h = vim.deepcopy(M.list())
    if ((#h == 0) or (h[#h] ~= text)) then
      table.insert(h, text)
    else
    end
    while (#h > (max_items or 100)) do
      table.remove(h, 1)
    end
    vim.g.metabuffer_prompt_history = h
    return persist_21()
  else
    return nil
  end
end
M["save-tag!"] = function(tag, prompt)
  if ((type(tag) == "string") and (vim.trim(tag) ~= "") and (type(prompt) == "string") and (vim.trim(prompt) ~= "")) then
    local saved = vim.deepcopy(M.saved())
    saved[vim.trim(tag)] = prompt
    vim.g.metabuffer_saved_prompts = saved
    return persist_21()
  else
    return nil
  end
end
M["saved-entry"] = function(tag)
  if ((type(tag) == "string") and (vim.trim(tag) ~= "")) then
    return M.saved()[vim.trim(tag)]
  else
    return nil
  end
end
M["saved-items"] = function()
  local saved = M.saved()
  local tags = {}
  for k, _ in pairs(saved) do
    table.insert(tags, k)
  end
  table.sort(tags)
  local out = {}
  for _, tag in ipairs(tags) do
    table.insert(out, {tag = tag, prompt = (saved[tag] or "")})
  end
  return out
end
M.entry = function(idx)
  local h = M.list()
  local n = #h
  if ((idx > 0) and (idx <= n)) then
    return h[((n - idx) + 1)]
  else
    return nil
  end
end
return M
