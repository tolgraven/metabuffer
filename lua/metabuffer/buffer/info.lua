-- [nfnl] fnl/metabuffer/buffer/info.fnl
local base_buffer_mod = require("metabuffer.buffer.base")
local M = {}
local function apply_info_buffer_opts_21(buf)
  return base_buffer_mod["apply-buffer-opts!"](buf, {buftype = "nofile", bufhidden = "wipe", filetype = "", modifiable = false, swapfile = false})
end
M["prepare-buffer!"] = function(buf)
  return apply_info_buffer_opts_21(buf)
end
M.new = function(buf)
  return base_buffer_mod["register-managed-buffer!"](buf, "info", "[Metabuffer Info]", {buftype = "nofile", bufhidden = "wipe", filetype = "", modifiable = false, swapfile = false}, nil)
end
return M
