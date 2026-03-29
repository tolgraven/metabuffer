-- [nfnl] fnl/metabuffer/buffer/preview.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local base_buffer_mod = require("metabuffer.buffer.base")
local events = require("metabuffer.events")
local M = {}
local function apply_preview_scratch_opts_21(buf)
  return base_buffer_mod["apply-buffer-opts!"](buf, {bufhidden = "hide", buftype = "nofile", filetype = "", modifiable = false, swapfile = false})
end
M["prepare-scratch-buffer!"] = function(buf)
  return apply_preview_scratch_opts_21(buf)
end
M["new-scratch"] = function(buf)
  return base_buffer_mod["register-managed-buffer!"](buf, "preview", "[Metabuffer Preview]", {bufhidden = "hide", buftype = "nofile", filetype = "", modifiable = false, swapfile = false}, {["transient?"] = true})
end
M["mark-preview-buffer!"] = function(buf, transient_3f)
  if (buf and vim.api.nvim_buf_is_valid(buf)) then
    local _1_
    if (transient_3f == nil) then
      _1_ = true
    else
      _1_ = clj.boolean(transient_3f)
    end
    return events.send("on-buf-create!", {buf = buf, role = "preview", ["transient?"] = _1_})
  else
    return nil
  end
end
M["unmark-preview-buffer!"] = function(buf)
  if (buf and vim.api.nvim_buf_is_valid(buf) and not (true == pcall(vim.api.nvim_buf_get_var, buf, "meta_preview"))) then
    return events.send("on-buf-teardown!", {buf = buf, role = "preview"})
  else
    return nil
  end
end
return M
