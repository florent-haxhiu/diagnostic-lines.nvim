local h = require("tests.helpers")
local eq, rows_text = h.eq, h.rows_text
local render = require("diagnostic-lines.render")

local ERROR, WARN = vim.diagnostic.severity.ERROR, vim.diagnostic.severity.WARN

local buf, ns

--- { [row] = rows_text(virt_lines) } for one source namespace.
local function virt(source_ns, bufnr)
  local out = {}
  local marks = vim.api.nvim_buf_get_extmarks(
    bufnr or buf,
    render.namespace_for(source_ns),
    0,
    -1,
    { details = true }
  )
  for _, m in ipairs(marks) do
    out[m[2]] = rows_text(m[4].virt_lines)
  end
  return out
end

local function set_lines(lines)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

--- Set diagnostics with defaults: line 0, col 0, ERROR, message "m".
local function set(source_ns, diagnostics)
  local list = {}
  for i, d in ipairs(diagnostics) do
    list[i] = vim.tbl_extend("keep", d, { lnum = 0, col = 0, severity = ERROR, message = "m" })
  end
  vim.diagnostic.set(source_ns, buf, list)
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_set_current_buf(buf)
      vim.diagnostic.config({
        virtual_text = false,
        virtual_lines = false,
        signs = false,
        diagnostic_lines = true,
      })
      ns = vim.api.nvim_create_namespace("test." .. tostring(buf))
    end,
    post_case = function()
      vim.cmd("silent! only")
      vim.o.number = false
      vim.diagnostic.reset()
      vim.api.nvim_buf_delete(buf, { force = true })
    end,
  },
})

T["handler is registered"] = function()
  eq(vim.diagnostic.handlers.diagnostic_lines, require("diagnostic-lines.handler"))
end

T["draws two diagnostics with connectors"] = function()
  set_lines({ "local x = foo(bar, baz)" })
  set(ns, {
    { col = 10, severity = ERROR, message = "undefined global 'foo'" },
    { col = 14, severity = WARN, message = "unused local 'bar'" },
  })
  eq(virt(ns), {
    [0] = {
      "          │   └──── W: unused local 'bar'",
      "          └──────── E: undefined global 'foo'",
    },
  })
end

T["draws each line under its own row"] = function()
  set_lines({ "a", "b", "c" })
  set(ns, { { lnum = 0, message = "one" }, { lnum = 2, message = "three" } })
  eq(virt(ns), { [0] = { "└──── E: one" }, [2] = { "└──── E: three" } })
end

T["hide() clears the lines"] = function()
  set_lines({ "a" })
  set(ns, { {} })
  vim.diagnostic.hide(ns, buf)
  eq(virt(ns), {})
end

T["disabled in config draws nothing"] = function()
  vim.diagnostic.config({ diagnostic_lines = false })
  set_lines({ "a" })
  set(ns, { {} })
  eq(virt(ns), {})
end

T["format option replaces the message"] = function()
  vim.diagnostic.config({
    diagnostic_lines = {
      format = function()
        return "X"
      end,
    },
  })
  set_lines({ "a" })
  set(ns, { { message = "original" } })
  eq(virt(ns), { [0] = { "└──── E: X" } })
end

T["column past end of line is clamped to the last column"] = function()
  set_lines({ "abc" })
  set(ns, { { col = 50 } })
  eq(virt(ns), { [0] = { "  └──── E: m" } })
end

T["tabs before the column use display width"] = function()
  vim.bo[buf].tabstop = 4
  set_lines({ "\tx = 1" })
  set(ns, { { col = 1 } })
  eq(virt(ns), { [0] = { "    └──── E: m" } })
end

T["multibyte text before the column uses display width"] = function()
  set_lines({ "é = x" })
  set(ns, { { col = 5 } })
  eq(virt(ns), { [0] = { "    └──── E: m" } })
end

T["line number past the end of the buffer is drawn under the last line"] = function()
  set_lines({ "only" })
  set(ns, { { lnum = 5 } })
  eq(virt(ns), { [0] = { "└──── E: m" } })
end

T["each diagnostic namespace is drawn and hidden independently"] = function()
  local ns2 = vim.api.nvim_create_namespace("test2." .. tostring(buf))
  set_lines({ "a" })
  set(ns, { { message = "a" } })
  set(ns2, { { message = "b" } })
  eq(virt(ns), { [0] = { "└──── E: a" } })
  eq(virt(ns2), { [0] = { "└──── E: b" } })

  vim.diagnostic.hide(ns, buf)
  eq(virt(ns), {})
  eq(virt(ns2), { [0] = { "└──── E: b" } })
end

T["format returning nil hides the diagnostic, like core"] = function()
  vim.diagnostic.config({
    diagnostic_lines = {
      format = function(d)
        return d.severity == ERROR and d.message or nil
      end,
    },
  })
  set_lines({ "a" })
  set(ns, { { message = "kept" }, { severity = WARN, message = "dropped" } })
  eq(virt(ns), { [0] = { "└──── E: kept" } })
end

T["format returning a non-string is shown as text"] = function()
  vim.diagnostic.config({
    diagnostic_lines = {
      format = function()
        return 42
      end,
    },
  })
  set_lines({ "a" })
  set(ns, { {} })
  eq(virt(ns), { [0] = { "└──── E: 42" } })
end

T["virtual lines scroll horizontally with the text (nowrap)"] = function()
  set_lines({ "a" })
  set(ns, { {} })
  local mark = vim.api.nvim_buf_get_extmarks(buf, render.namespace_for(ns), 0, -1, { details = true })[1]
  eq(mark[4].virt_lines_overflow, "scroll")
end

-- Wrapping to the window ----------------------------------------------------

local handler = require("diagnostic-lines.handler")

local LONG = "this is a very long message that would otherwise run off the edge of the window"

--- Put an unrelated window next to the current one (a lone window can't
--- be resized) and set the current window's width.
local function narrow_current(width)
  vim.cmd("vnew | wincmd p")
  vim.api.nvim_win_set_width(0, width)
end

local function row_count(source_ns, bufnr)
  return #(virt(source_ns, bufnr)[0] or {})
end

T["text_width()"] = MiniTest.new_set()

T["text_width()"]["subtracts the gutter"] = function()
  narrow_current(40)
  vim.wo.number = true
  local textoff = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1].textoff
  eq(textoff > 0, true)
  eq(handler.text_width(buf), 40 - textoff)
end

T["text_width()"]["uses the narrowest window showing the buffer"] = function()
  vim.cmd("vsplit")
  vim.api.nvim_win_set_width(0, 30)
  eq(handler.text_width(buf), 30)
end

T["text_width()"]["is nil for a buffer in no window"] = function()
  local hidden = vim.api.nvim_create_buf(true, true)
  eq(handler.text_width(hidden), nil)
  vim.api.nvim_buf_delete(hidden, { force = true })
end

T["wrapping"] = MiniTest.new_set()

T["wrapping"]["wraps long messages to the window"] = function()
  narrow_current(30)
  set_lines({ "x" })
  set(ns, { { message = LONG } })
  eq(row_count(ns) > 1, true)
end

T["wrapping"]["wrap = false keeps one row"] = function()
  vim.diagnostic.config({ diagnostic_lines = { wrap = false } })
  narrow_current(30)
  set_lines({ "x" })
  set(ns, { { message = LONG } })
  eq(row_count(ns), 1)
end

T["wrapping"]["refresh() rewraps after a resize"] = function()
  narrow_current(70)
  set_lines({ "x" })
  set(ns, { { message = LONG } })
  local wide = row_count(ns)

  vim.api.nvim_win_set_width(0, 30)
  handler.refresh(buf)
  eq(row_count(ns) > wide, true)
end

T["wrapping"]["VimResized rewraps"] = function()
  narrow_current(70)
  set_lines({ "x" })
  set(ns, { { message = LONG } })
  local wide = row_count(ns)

  vim.api.nvim_win_set_width(0, 30)
  vim.api.nvim_exec_autocmds("VimResized", {})
  eq(row_count(ns) > wide, true)
end

T["wrapping"]["hidden buffer is unwrapped, then rewrapped when shown"] = function()
  local hidden = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_lines(hidden, 0, -1, false, { "x" })
  vim.diagnostic.set(ns, hidden, { { lnum = 0, col = 0, severity = ERROR, message = LONG } })
  eq(row_count(ns, hidden), 1)

  narrow_current(30)
  vim.api.nvim_win_set_buf(0, hidden)
  eq(row_count(ns, hidden) > 1, true)

  vim.api.nvim_buf_delete(hidden, { force = true })
end

-- Redraws after edits, gutter changes and bufnr 0 -----------------------------

--- Widest row (display cells) drawn for `source_ns` in `bufnr`.
local function widest(source_ns, bufnr)
  local w = 0
  for _, rows in pairs(virt(source_ns, bufnr)) do
    for _, text in ipairs(rows) do
      w = math.max(w, vim.fn.strdisplaywidth(text))
    end
  end
  return w
end

T["redraws"] = MiniTest.new_set()

T["redraws"]["refresh() follows lines that moved after edits"] = function()
  set_lines({ "a", "b", "c" })
  set(ns, { { lnum = 2, message = "on c" } })
  vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "new 1", "new 2" })
  eq(virt(ns), { [4] = { "└──── E: on c" } })

  handler.refresh(buf)
  eq(virt(ns), { [4] = { "└──── E: on c" } })
end

T["redraws"]["sync_width() rewraps when the gutter grows"] = function()
  narrow_current(40)
  set_lines({ "x" })
  set(ns, { { message = LONG } })
  eq(widest(ns) <= handler.text_width(buf), true)

  vim.wo.number = true
  handler.sync_width(buf)
  eq(widest(ns) <= handler.text_width(buf), true)
end

T["redraws"]["bufnr 0 leaves nothing behind for other buffers"] = function()
  set_lines({ "a" })
  set(ns, { { message = "error in A" } })
  vim.diagnostic.show(ns, 0)
  vim.diagnostic.hide(ns, 0)

  local other = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_set_current_buf(other)
  vim.api.nvim_exec_autocmds("VimResized", {})
  eq(virt(ns, other), {})
  vim.api.nvim_buf_delete(other, { force = true })
end

T["redraws"]["end to end: wrapped text fits once the sign column appears"] = function()
  local child = MiniTest.new_child_neovim()
  child.start({ "--cmd", "set rtp^=" .. vim.fn.getcwd(), "--cmd", "runtime plugin/diagnostic-lines.lua" })
  child.o.lines, child.o.columns = 12, 50
  child.lua([[
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "x" })
    vim.diagnostic.config({ virtual_text = false, diagnostic_lines = true }) -- signs left on
    vim.diagnostic.set(vim.api.nvim_create_namespace("e2e"), 0, {
      { lnum = 0, col = 0, severity = 1, message = ...  },
    })
  ]], { LONG })
  child.cmd("redraw")
  child.lua("vim.wait(50)")
  child.cmd("redraw")
  local screen = table.concat(vim.tbl_map(function(l)
    return table.concat(l)
  end, child.get_screenshot().text), "\n")
  child.stop()
  -- the message's last word is fully on screen, not cut at the edge
  eq(screen:find("window", 1, true) ~= nil, true)
end

return T
