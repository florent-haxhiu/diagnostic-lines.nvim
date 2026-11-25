-- Minimal runtime for headless tests: this repo + mini.test, nothing else.
vim.opt.runtimepath:prepend(vim.fn.getcwd() .. "/deps/mini.test")
vim.opt.runtimepath:prepend(vim.fn.getcwd())

vim.o.swapfile = false

require("mini.test").setup()

vim.cmd("runtime plugin/diagnostic-lines.lua")
