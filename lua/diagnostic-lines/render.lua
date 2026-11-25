-- The "builder": turns layout rows into extmarks. All Neovim UI calls
-- for drawing live here.
local api = vim.api

local M = {}

--- One plugin namespace per diagnostic namespace (e.g. per LSP client),
--- so each can be cleared without touching the others.
---@type table<integer, integer>
local namespaces = {}

---@param source_ns integer Diagnostic namespace.
---@return integer
function M.namespace_for(source_ns)
  local ns = namespaces[source_ns]
  if not ns then
    ns = api.nvim_create_namespace("diagnostic_lines." .. source_ns)
    namespaces[source_ns] = ns
  end
  return ns
end

---@param source_ns integer
---@param bufnr integer
---@param lnum integer 0-based line the rows go under.
---@param rows DiagnosticLines.Row[]
---@param id? integer Existing extmark to update in place.
---@return integer id
function M.draw(source_ns, bufnr, lnum, rows, id)
  return api.nvim_buf_set_extmark(bufnr, M.namespace_for(source_ns), lnum, 0, {
    id = id,
    virt_lines = rows,
    virt_lines_leftcol = false,
  })
end

---@param source_ns integer
---@param bufnr integer
function M.clear(source_ns, bufnr)
  api.nvim_buf_clear_namespace(bufnr, M.namespace_for(source_ns), 0, -1)
end

return M
