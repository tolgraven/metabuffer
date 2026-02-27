local router = require("metabuffer.router")
local M = {}
M.setup = function()
  local function _1_(args)
    return router.entry_start(args.args, args.bang)
  end
  vim.api.nvim_create_user_command("Meta", _1_, {nargs = "?", bang = true})
  local function _2_(args)
    return router.entry_resume(args.args)
  end
  vim.api.nvim_create_user_command("MetaResume", _2_, {nargs = "?"})
  local function _3_()
    return router.entry_cursor_word(false)
  end
  vim.api.nvim_create_user_command("MetaCursorWord", _3_, {nargs = 0})
  local function _4_()
    return router.entry_cursor_word(true)
  end
  vim.api.nvim_create_user_command("MetaResumeCursorWord", _4_, {nargs = 0})
  local function _5_(args)
    return router.entry_sync(args.args)
  end
  vim.api.nvim_create_user_command("MetaSync", _5_, {nargs = "?"})
  local function _6_()
    return router.entry_push()
  end
  vim.api.nvim_create_user_command("MetaPush", _6_, {nargs = 0})
  return true
end
return M
