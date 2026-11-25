-- The diagnostic handler (ADR-0001): a { show, hide } strategy that core
-- drives. Reads the buffer, asks `layout` what to draw, asks `render`
-- to draw it.
local api = vim.api
local config = require("diagnostic-lines.config")
local layout = require("diagnostic-lines.layout")
local render = require("diagnostic-lines.render")

local M = {}

--- What was drawn, per buffer and diagnostic namespace: the options and
--- the layout items behind each extmark. Redraws read each extmark's
--- *current* row, so lines that moved after edits stay put.
---@class DiagnosticLines.Drawn
---@field cfg DiagnosticLines.Config
---@field items table<integer, DiagnosticLines.Item[]> extmark id → items
---@type table<integer, table<integer, DiagnosticLines.Drawn>>
local state = {}

--- Text width each buffer was last laid out for (false = no window).
---@type table<integer, integer|false>
local laid_out_for = {}

---@param bufnr integer
---@return integer
local function resolve(bufnr)
  return (bufnr == nil or bufnr == 0) and api.nvim_get_current_buf() or bufnr
end

--- Width of the narrowest window text area showing `bufnr` (ADR-0004).
--- Virtual lines belong to the buffer, so they must fit every window.
---@param bufnr integer
---@return integer|nil nil when the buffer is in no window.
function M.text_width(bufnr)
  local narrowest
  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    local gutter = vim.fn.getwininfo(win)[1].textoff
    local width = api.nvim_win_get_width(win) - gutter
    narrowest = narrowest and math.min(narrowest, width) or width
  end
  return narrowest
end

--- Group diagnostics into layout items per (clamped) line number.
---@param bufnr integer
---@param diagnostics vim.Diagnostic[]
---@param cfg DiagnosticLines.Config
---@return table<integer, DiagnosticLines.Item[]>
local function items_by_line(bufnr, diagnostics, cfg)
  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local last = math.max(#lines - 1, 0)
  local by_line = {}

  -- strdisplaywidth() uses the current buffer's 'tabstop'.
  api.nvim_buf_call(bufnr, function()
    for _, d in ipairs(diagnostics) do
      local lnum = math.min(math.max(d.lnum, 0), last)
      local line = lines[lnum + 1] or ""
      local col = vim.fn.strdisplaywidth(line:sub(1, d.col or 0))
      col = math.min(col, math.max(vim.fn.strdisplaywidth(line) - 1, 0))

      -- Like core: format() returning nil hides the diagnostic.
      local message = d.message
      if cfg.format then
        message = cfg.format(d)
      end

      if message ~= nil then
        by_line[lnum] = by_line[lnum] or {}
        table.insert(by_line[lnum], {
          col = col,
          severity = d.severity,
          message = tostring(message),
        })
      end
    end
  end)

  return by_line
end

---@param namespace integer
---@param bufnr integer
---@param diagnostics vim.Diagnostic[]
---@param opts table Full resolved diagnostic opts; ours are under `diagnostic_lines`.
function M.show(namespace, bufnr, diagnostics, opts)
  bufnr = resolve(bufnr)
  if not api.nvim_buf_is_loaded(bufnr) then
    return
  end

  local cfg = config.resolve(opts and opts.diagnostic_lines)
  render.clear(namespace, bufnr)

  local text_width = M.text_width(bufnr)
  local width = cfg.wrap and text_width or nil
  local drawn = {}
  for lnum, items in pairs(items_by_line(bufnr, diagnostics, cfg)) do
    local id = render.draw(namespace, bufnr, lnum, layout.build(items, width))
    drawn[id] = items
  end

  state[bufnr] = state[bufnr] or {}
  state[bufnr][namespace] = { cfg = cfg, items = drawn }
  laid_out_for[bufnr] = text_width or false
end

---@param namespace integer
---@param bufnr integer
function M.hide(namespace, bufnr)
  bufnr = resolve(bufnr)
  if api.nvim_buf_is_valid(bufnr) then
    render.clear(namespace, bufnr)
  end
  if state[bufnr] then
    state[bufnr][namespace] = nil
  end
end

--- Lay out what's already drawn again at the current width, at each
--- extmark's current row.
---@param bufnr integer
local function redraw(bufnr)
  local text_width = M.text_width(bufnr)
  for namespace, drawn in pairs(state[bufnr]) do
    local width = drawn.cfg.wrap and text_width or nil
    for _, mark in ipairs(api.nvim_buf_get_extmarks(bufnr, render.namespace_for(namespace), 0, -1, {})) do
      local id, row = mark[1], mark[2]
      local items = drawn.items[id]
      if items then
        render.draw(namespace, bufnr, row, layout.build(items, width), id)
      end
    end
  end
  laid_out_for[bufnr] = text_width or false
end

--- Redraw, e.g. after a resize.
---@param bufnr? integer nil = every tracked buffer.
function M.refresh(bufnr)
  local targets = bufnr and { resolve(bufnr) } or vim.tbl_keys(state)
  for _, b in ipairs(targets) do
    if not api.nvim_buf_is_valid(b) then
      M.forget(b)
    elseif state[b] then
      redraw(b)
    end
  end
end

--- Redraw only if the available width changed since the last layout
--- (window resized, sign/number column appeared, narrow split closed).
---@param bufnr integer
function M.sync_width(bufnr)
  if M.width_changed(bufnr) then
    M.refresh(bufnr)
  end
end

--- Cheap check, safe to call during redraw.
---@param bufnr integer
---@return boolean
function M.width_changed(bufnr)
  return state[bufnr] ~= nil and (M.text_width(bufnr) or false) ~= laid_out_for[bufnr]
end

--- Tracked buffers whose available width changed since their last layout.
---@return integer[]
function M.changed_buffers()
  local changed = {}
  for bufnr in pairs(state) do
    if api.nvim_buf_is_valid(bufnr) and M.width_changed(bufnr) then
      changed[#changed + 1] = bufnr
    end
  end
  return changed
end

--- Drop everything remembered about a buffer (it's being wiped).
---@param bufnr integer
function M.forget(bufnr)
  state[bufnr] = nil
  laid_out_for[bufnr] = nil
end

return M
