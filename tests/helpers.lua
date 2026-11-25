-- Shared test helpers. Rows are `virt_lines`-shaped: a list of
-- { text, hl_group? } chunks.
local H = {}

H.eq = MiniTest.expect.equality
H.expect = MiniTest.expect

---@param row DiagnosticLines.Row
---@return string
function H.row_text(row)
  local parts = {}
  for _, chunk in ipairs(row) do
    parts[#parts + 1] = chunk[1]
  end
  return table.concat(parts)
end

---@param rows DiagnosticLines.Row[]
---@return string[]
function H.rows_text(rows)
  local out = {}
  for i, row in ipairs(rows) do
    out[i] = H.row_text(row)
  end
  return out
end

--- Highlight group of the chunk covering 0-based display column `col`.
---@param row DiagnosticLines.Row
---@param col integer
---@return string|nil
function H.hl_at(row, col)
  local start = 0
  for _, chunk in ipairs(row) do
    local finish = start + vim.fn.strdisplaywidth(chunk[1])
    if col >= start and col < finish then
      return chunk[2]
    end
    start = finish
  end
  return nil
end

return H
