-- [nfnl] fnl/metabuffer/author_highlight.fnl
local M = {}
M["author-groups"] = {"MetaAuthor1", "MetaAuthor2", "MetaAuthor3", "MetaAuthor4", "MetaAuthor5", "MetaAuthor6", "MetaAuthor7", "MetaAuthor8", "MetaAuthor9", "MetaAuthor10", "MetaAuthor11", "MetaAuthor12", "MetaAuthor13", "MetaAuthor14", "MetaAuthor15", "MetaAuthor16", "MetaAuthor17", "MetaAuthor18", "MetaAuthor19", "MetaAuthor20", "MetaAuthor21", "MetaAuthor22", "MetaAuthor23", "MetaAuthor24"}
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
