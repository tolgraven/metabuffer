-- [nfnl] fnl/metabuffer/author_highlight.fnl
local M = {}
local util = require("metabuffer.util")
M["author-groups"] = util["build-group-names"]("MetaAuthor", 24)
M["author->group"] = {}
M["next-group-idx"] = 1
local function normalize_author(name)
  return string.lower(vim.trim(tostring((name or ""))))
end
M["group-for-author"] = function(author)
  local key = normalize_author(author)
  local existing = M["author->group"][key]
  if existing then
    return M["author-groups"][existing]
  else
    local idx = math.max(1, math.min((M["next-group-idx"] or 1), #M["author-groups"]))
    M["author->group"][key] = idx
    if (idx < #M["author-groups"]) then
      M["next-group-idx"] = (idx + 1)
    else
      M["next-group-idx"] = 1
    end
    return M["author-groups"][idx]
  end
end
return M
