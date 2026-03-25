local root = vim.fn.getcwd()

vim.opt.runtimepath:prepend(root)

local mini_candidates = {
  root .. "/deps/mini.nvim",
  (vim.env.HOME or "") .. "/.local/share/nvim/lazy/mini.nvim",
}

for _, path in ipairs(mini_candidates) do
  if vim.fn.isdirectory(path) == 1 then
    vim.opt.runtimepath:prepend(path)
    break
  end
end

local ok, mini_test = pcall(require, "mini.test")
if not ok then
  vim.api.nvim_err_writeln("mini.test not found (checked deps/mini.nvim and lazy path)")
  vim.cmd("cquit 1")
  return
end

_G.MiniTest = mini_test
mini_test.setup()
require("tests.support.profiler").setup()
vim.o.showmode = false
vim.g.meta_test_no_startinsert = true
vim.g.meta_test_running = true

-- Keep project lazy behavior active in headless mini.test child sessions so
-- :Meta! tests exercise the same async path as interactive use.
vim.g.meta_project_lazy_disable_headless = false

local animations_enabled = vim.env.TEST_UI_ANIMATIONS == "1"

require("metabuffer").setup({
  options = {
    project_bootstrap_delay_ms = 0,
    project_bootstrap_idle_delay_ms = 0,
  },
  ui = {
    animation = {
      enabled = animations_enabled,
      loading_indicator = animations_enabled,
    },
  },
})

if not animations_enabled then
  vim.g.minianimate_disable = true
end
