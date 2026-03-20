-- [nfnl] fnl/metabuffer/author_highlight.fnl
local M = {}
local util = require("metabuffer.util")
M["author-groups"] = util["build-group-names"]("MetaAuthor", 24)
local function normalize_author(name)
  return string.lower(vim.trim(tostring((name or ""))))
end
local function bucket_for_author(author)
  local key = normalize_author(author)
  local n = math.max(1, #M["author-groups"])
  if (key == "") then
    return 1
  else
    local acc0 = 5381
    local acc = acc0
    for i = 1, #key do
      acc = (((acc * 33) + string.byte(key, i)) % 2147483647)
    end
    return ((acc % n) + 1)
  end
end
M["group-for-author"] = function(author)
  return M["author-groups"][bucket_for_author(author)]
end
return M
