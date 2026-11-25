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

local api = vim.api
local handler = require("diagnostic-lines.handler")

vim.diagnostic.handlers.diagnostic_lines = handler

-- Rewrap when the space available changes (ADR-0004).
local group = api.nvim_create_augroup("diagnostic_lines", { clear = true })

api.nvim_create_autocmd("WinResized", {
  group = group,
  callback = function()
    local windows = vim.v.event.windows or {}
    if #windows == 0 then
      handler.refresh()
      return
    end
    local seen = {}
    for _, win in ipairs(windows) do
      if api.nvim_win_is_valid(win) then
        local bufnr = api.nvim_win_get_buf(win)
        if not seen[bufnr] then
          seen[bufnr] = true
          handler.refresh(bufnr)
        end
      end
    end
  end,
})

api.nvim_create_autocmd("VimResized", {
  group = group,
  callback = function()
    handler.refresh()
  end,
})

api.nvim_create_autocmd("BufWinEnter", {
  group = group,
  callback = function(args)
    handler.refresh(args.buf)
  end,
})

-- The gutter (sign/number/fold columns) can change width without any
-- resize event, e.g. when signcolumn=auto first shows a sign. At the end
-- of each redraw (when gutters are settled), rewrap any buffer whose
-- width moved. The rewrap itself is scheduled outside the redraw.
local pending = {}
api.nvim_set_decoration_provider(api.nvim_create_namespace("diagnostic_lines.watch"), {
  on_end = function()
    for _, bufnr in ipairs(handler.changed_buffers()) do
      if not pending[bufnr] then
        pending[bufnr] = true
        vim.schedule(function()
          pending[bufnr] = nil
          if api.nvim_buf_is_valid(bufnr) then
            handler.sync_width(bufnr)
          end
        end)
      end
    end
  end,
})

api.nvim_create_autocmd("BufWipeout", {
  group = group,
  callback = function(args)
    handler.forget(args.buf)
  end,
})
