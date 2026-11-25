-- Split text into lines that fit a display width.
-- Pure: no vim.api calls (ADR-0003). Widths are display cells, so
-- "é" is 1 and "日" is 2.
local M = {}

local width_of = vim.fn.strdisplaywidth

--- Take as many characters from the start of `word` as fit in `width`
--- (at least one, so a lone wide character can't loop forever).
---@param word string
---@param width integer
---@return string head, string rest
local function take(word, width)
  local count = 0
  for i = 1, vim.fn.strchars(word) do
    if width_of(vim.fn.strcharpart(word, 0, i)) > width then
      break
    end
    count = i
  end
  count = math.max(count, 1)
  return vim.fn.strcharpart(word, 0, count), vim.fn.strcharpart(word, count)
end

--- Greedy word wrap of one newline-free piece of text.
---@param text string
---@param width integer
---@return string[]
local function wrap_piece(text, width)
  if width_of(text) <= width then
    return { text }
  end

  local out = {}
  local line = nil ---@type string|nil

  for _, word in ipairs(vim.split(text, " ", { plain = true })) do
    local candidate = line and (line .. " " .. word) or word
    if width_of(candidate) <= width then
      line = candidate
    elseif word == "" then
      -- An extra space right at a break: drop it rather than start a
      -- line with it.
    else
      if line then
        out[#out + 1] = line
      end
      while width_of(word) > width do
        local head
        head, word = take(word, width)
        out[#out + 1] = head
      end
      line = word
    end
  end

  if line then
    out[#out + 1] = line
  end
  return out
end

--- Split `text` on newlines, then wrap each piece to `width`.
---@param text string
---@param width integer|nil nil = only split on newlines.
---@return string[]
function M.wrap(text, width)
  local pieces = vim.split(text:gsub("\r", ""), "\n", { plain = true })
  -- A trailing newline shouldn't draw an empty row (one empty line stays
  -- so an empty message still gets its prefix).
  while #pieces > 1 and pieces[#pieces] == "" do
    pieces[#pieces] = nil
  end
  if not width then
    return pieces
  end

  local out = {}
  for _, piece in ipairs(pieces) do
    vim.list_extend(out, wrap_piece(piece, width))
  end
  return out
end

return M
