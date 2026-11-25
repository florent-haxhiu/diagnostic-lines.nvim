-- Handler options: defaults, merging and validation.
-- Pure: no vim.api calls (ADR-0003).
local M = {}

---@class DiagnosticLines.Config
---@field wrap boolean Wrap long messages to fit the window.
---@field format? fun(d: vim.Diagnostic): string Replace a diagnostic's message text.

---@type DiagnosticLines.Config
M.defaults = { wrap = true }

--- Resolve the user's `diagnostic_lines` value from `vim.diagnostic.config()`.
---@param user boolean|table|nil `true`/`nil` mean "use defaults".
---@return DiagnosticLines.Config
function M.resolve(user)
  local overrides = type(user) == "table" and user or {}
  local cfg = vim.tbl_extend("force", {}, M.defaults, overrides)

  vim.validate("wrap", cfg.wrap, "boolean")
  vim.validate("format", cfg.format, "function", true)

  return cfg
end

return M
