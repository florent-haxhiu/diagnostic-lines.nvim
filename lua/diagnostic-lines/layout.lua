-- Turn the diagnostics of ONE source line into `virt_lines` rows.
-- Pure: no vim.api calls (ADR-0003). The "architect's floor plan":
-- it decides what goes where; `render` does the building.
--
--   local x = foo(bar, baz)
--             │   └──── W: unused local 'bar'
--             └──────── E: undefined global 'foo'
local wrap = require("diagnostic-lines.wrap")

local M = {}

---@class DiagnosticLines.Item
---@field col integer       0-based DISPLAY column on the source line
---@field severity integer  vim.diagnostic.severity (1..4)
---@field message string    already formatted; may contain "\n"

---@alias DiagnosticLines.Chunk { [1]: string, [2]: string? }
---@alias DiagnosticLines.Row DiagnosticLines.Chunk[]

M.HL = {
  "DiagnosticVirtualLinesError",
  "DiagnosticVirtualLinesWarn",
  "DiagnosticVirtualLinesInfo",
  "DiagnosticVirtualLinesHint",
}

M.PREFIX = { "E", "W", "I", "H" }

--- Below this many columns of space for the message, don't wrap.
M.MIN_WRAP_WIDTH = 10

local VERTICAL, CORNER, TEE, ARM = "│", "└", "├", "─"

--- Distance from the rightmost column to the severity prefix:
--- corner + 4 arm + 1 space.
local PREFIX_OFFSET = 6
--- Width of "E: ".
local PREFIX_WIDTH = 3

--- Rightmost column first, then most severe first; input order breaks ties.
---@param items DiagnosticLines.Item[]
---@return DiagnosticLines.Item[]
local function sort_items(items)
  local indexed = {}
  for i, item in ipairs(items) do
    indexed[i] = { item = item, index = i }
  end
  table.sort(indexed, function(a, b)
    if a.item.col ~= b.item.col then
      return a.item.col > b.item.col
    end
    if a.item.severity ~= b.item.severity then
      return a.item.severity < b.item.severity
    end
    return a.index < b.index
  end)
  local sorted = {}
  for i, entry in ipairs(indexed) do
    sorted[i] = entry.item
  end
  return sorted
end

--- Append text to a row, merging into the previous chunk when the
--- highlight matches (keeps rows short; spaces have no highlight).
---@param row DiagnosticLines.Row
---@param text string
---@param hl string|nil
local function push(row, text, hl)
  local last = row[#row]
  if last and last[2] == hl then
    last[1] = last[1] .. text
  else
    row[#row + 1] = { text, hl }
  end
end

--- Columns that still need a `│` because a later item lives there,
--- mapped to that item's highlight (the first later item wins).
---@param sorted DiagnosticLines.Item[]
---@param k integer
---@return table<integer, string>
local function pending_after(sorted, k)
  local pending = {}
  for j = #sorted, k + 1, -1 do
    pending[sorted[j].col] = M.HL[sorted[j].severity]
  end
  return pending
end

--- Fill columns [0, upto) with spaces and pending connectors.
---@param row DiagnosticLines.Row
---@param pending table<integer, string>
---@param upto integer
local function gutter(row, pending, upto)
  for col = 0, upto - 1 do
    local hl = pending[col]
    push(row, hl and VERTICAL or " ", hl)
  end
end

---@param items DiagnosticLines.Item[]
---@param width integer|nil Window text-area width; nil = don't wrap.
---@return DiagnosticLines.Row[]
function M.build(items, width)
  if #items == 0 then
    return {}
  end

  local sorted = sort_items(items)
  local prefix_col = sorted[1].col + PREFIX_OFFSET
  local text_col = prefix_col + PREFIX_WIDTH

  -- Every message starts at text_col, so they all share one wrap width.
  local available = width and (width - text_col)
  local wrap_width = (available and available >= M.MIN_WRAP_WIDTH) and available or nil

  local rows = {}
  for k, item in ipairs(sorted) do
    local hl = M.HL[item.severity]
    local pending = pending_after(sorted, k)
    local lines = wrap.wrap(item.message, wrap_width)

    local first = {}
    gutter(first, pending, item.col)
    push(first, pending[item.col] and TEE or CORNER, hl)
    push(first, ARM:rep(prefix_col - item.col - 2), hl)
    push(first, " ", nil)
    push(first, M.PREFIX[item.severity] .. ": " .. lines[1], hl)
    rows[#rows + 1] = first

    for i = 2, #lines do
      local continuation = {}
      gutter(continuation, pending, text_col)
      push(continuation, lines[i], hl)
      rows[#rows + 1] = continuation
    end
  end

  return rows
end

return M
