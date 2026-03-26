-- [nfnl] fnl/metabuffer/compat/init.fnl
local events = require("metabuffer.events")
local airline = require("metabuffer.compat.airline")
local buffer_plugins = require("metabuffer.compat.buffer_plugins")
local cmp = require("metabuffer.compat.cmp")
local hlsearch = require("metabuffer.compat.hlsearch")
local rainbow = require("metabuffer.compat.rainbow")
for _, mod in ipairs({airline, buffer_plugins, cmp, hlsearch, rainbow}) do
  events["register!"](mod)
end
return {}
