-- [nfnl] fnl/metabuffer/compat/init.fnl
local airline = require("metabuffer.compat.airline")
local buffer_plugins = require("metabuffer.compat.buffer_plugins")
local conjure = require("metabuffer.compat.conjure")
local cmp = require("metabuffer.compat.cmp")
local hlsearch = require("metabuffer.compat.hlsearch")
local rainbow = require("metabuffer.compat.rainbow")
return {airline, buffer_plugins, conjure, cmp, hlsearch, rainbow}
