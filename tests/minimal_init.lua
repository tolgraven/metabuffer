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

require("metabuffer").setup()
