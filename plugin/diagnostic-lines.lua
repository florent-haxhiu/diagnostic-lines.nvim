-- Registers the `diagnostic_lines` handler. Nothing is drawn until the
-- user enables it with vim.diagnostic.config({ diagnostic_lines = ... }).
if vim.g.loaded_diagnostic_lines then
  return
end
vim.g.loaded_diagnostic_lines = true

if vim.fn.has("nvim-0.11") == 0 then
  vim.notify("diagnostic-lines.nvim requires Neovim 0.11+", vim.log.levels.WARN)
  return
end

vim.diagnostic.handlers.diagnostic_lines = require("diagnostic-lines.handler")
