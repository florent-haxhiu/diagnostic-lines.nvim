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
      vim.diagnostic.config({ virtual_text = false, virtual_lines = false, diagnostic_lines = true })
      ns = vim.api.nvim_create_namespace("test." .. tostring(buf))
    end,
    post_case = function()
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

return T
