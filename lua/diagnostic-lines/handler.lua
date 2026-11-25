-- The diagnostic handler (ADR-0001): a { show, hide } strategy that core
-- drives. Reads the buffer, asks `layout` what to draw, asks `render`
-- to draw it.
local api = vim.api
local config = require("diagnostic-lines.config")
local layout = require("diagnostic-lines.layout")
local render = require("diagnostic-lines.render")

local M = {}

--- Last diagnostics and options per buffer and diagnostic namespace,
--- kept so the lines can be redrawn when windows change size.
---@type table<integer, table<integer, { diagnostics: vim.Diagnostic[], opts: table }>>
local state = {}

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
  if not api.nvim_buf_is_loaded(bufnr) then
    return
  end

  local cfg = config.resolve(opts and opts.diagnostic_lines)
  render.clear(namespace, bufnr)

  local width = cfg.wrap and M.text_width(bufnr) or nil
  for lnum, items in pairs(items_by_line(bufnr, diagnostics, cfg)) do
    render.draw(namespace, bufnr, lnum, layout.build(items, width))
  end

  state[bufnr] = state[bufnr] or {}
  state[bufnr][namespace] = { diagnostics = diagnostics, opts = opts }
end

---@param namespace integer
---@param bufnr integer
function M.hide(namespace, bufnr)
  if api.nvim_buf_is_valid(bufnr) then
    render.clear(namespace, bufnr)
  end
  if state[bufnr] then
    state[bufnr][namespace] = nil
  end
end

--- Redraw from the remembered diagnostics, e.g. after a resize.
---@param bufnr? integer nil = every tracked buffer.
function M.refresh(bufnr)
  local targets = bufnr and { [bufnr] = state[bufnr] } or state
  for b, per_namespace in pairs(targets) do
    if not api.nvim_buf_is_valid(b) then
      state[b] = nil
    else
      for namespace, last in pairs(per_namespace) do
        M.show(namespace, b, last.diagnostics, last.opts)
      end
    end
  end
end

--- Drop everything remembered about a buffer (it's being wiped).
---@param bufnr integer
function M.forget(bufnr)
  state[bufnr] = nil
end

return M
