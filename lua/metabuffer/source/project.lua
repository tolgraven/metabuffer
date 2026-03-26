-- [nfnl] fnl/metabuffer/source/project.fnl
local M = {}
M["query-directive-specs"] = {{kind = "toggle", short = "h", long = "hidden", ["token-key"] = "include-hidden"}, {kind = "toggle", short = "i", long = "ignored", ["token-key"] = "include-ignored"}, {kind = "toggle", short = "d", long = "deps", ["token-key"] = "include-deps"}, {kind = "toggle", short = "b", long = "binary", ["token-key"] = "include-binary"}}
return M
