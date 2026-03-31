-- [nfnl] fnl/metabuffer/prompt/hooks_window.fnl
local hooks_window_layout_mod = require("metabuffer.prompt.hooks_window_layout")
local hooks_window_overlay_mod = require("metabuffer.prompt.hooks_window_overlay")
local M = {}
M.new = function(session_prompt_valid_3f)
  local overlay_hooks = hooks_window_overlay_mod.new()
  local layout_hooks = hooks_window_layout_mod.new(session_prompt_valid_3f)
  return {["covered-by-new-window?"] = overlay_hooks["covered-by-new-window?"], ["transient-overlay-buffer?"] = overlay_hooks["transient-overlay-buffer?"], ["first-window-for-buffer"] = overlay_hooks["first-window-for-buffer"], ["capture-expected-layout!"] = layout_hooks["capture-expected-layout!"], ["note-editor-size!"] = layout_hooks["note-editor-size!"], ["note-global-editor-resize!"] = layout_hooks["note-global-editor-resize!"], ["manual-prompt-resize?"] = layout_hooks["manual-prompt-resize?"], ["schedule-restore-expected-layout!"] = layout_hooks["schedule-restore-expected-layout!"], ["hidden-session-reachable?"] = overlay_hooks["hidden-session-reachable?"]}
end
return M
